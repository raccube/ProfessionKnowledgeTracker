local PKT = select(2, ...)

---@class PKT.EntryState
PKT.EntryState = EnumUtil.MakeEnum("Available", "Unavailable", "Completed")

---@class PKT.Item
PKT.Item = {}

function PKT.Item:New(item)
    item = item or {}
    setmetatable(item, self)
    self.__index = self
    if item.itemId then
        item.item = Item:CreateFromItemID(item.itemId)
    end

    return item
end

---@return number ItemID
function PKT.Item:GetId()
    return self.itemId and 'item:' .. self.itemId or 'quest:' .. self.questId[1]
end

---@return boolean
function PKT.Item:IsUnique()
    return false
end

---@return boolean
function PKT.Item:IsCatchUp()
    return false
end

---@return boolean
function PKT.Item:IsAvailable()
    return true
end

---@return PKT.EntryState
function PKT.Item:GetState()
    if not self:IsAvailable() then
        return PKT.EntryState.Unavailable
    elseif self:GetRemainingKnowledgePoints() > 0 then
        return PKT.EntryState.Available
    else
        return PKT.EntryState.Completed
    end
end


---@return string
function PKT.Item:GetName()
    if self.name then
        return self.name
    end

    self.name = self.item:GetItemName() or self.text

    return self.name or ""
end

---@return number Icon ID
function PKT.Item:GetIcon()
    if self.icon then
        return self.icon
    end

    self.icon = select(5, C_Item.GetItemInfoInstant(self.itemId))

    return self.icon
end

---@return string
function PKT.Item:GetCategoryIcon()
    return CreateAtlasMarkup(self.atlasIcon, 16, 16)
end

---@return number
function PKT.Item:GetRemainingTurnInCount()
    local questCount = 0

    for _, questId in ipairs(self.questId) do
        if not C_QuestLog.IsQuestFlaggedCompleted(questId) then
            questCount = questCount + 1
        end
    end

    return questCount
end

---@return number
function PKT.Item:GetRemainingKnowledgePoints()
    return self:GetRemainingTurnInCount() * self.kp
end

---@return boolean
function PKT.Item:MeetRenownRequirements()
    if not self.renown then
        return true
    end

    local renownLevel = C_MajorFactions.GetCurrentRenownLevel(self.renown.majorFactionId) or 0
    return renownLevel >= self.renown.levelRequired
end

---@return boolean
function PKT.Item:MeetItemRequirements()
    for _, v in pairs(self.itemRequirements or {}) do
        local itemCount = C_Item.GetItemCount(v.id)
        if v.quantity > itemCount then
            return false
        end
    end
    return true
end

---@return boolean
function PKT.Item:MeetUnlockRequirements()
    for _, v in pairs(self.unlockRequirements or {}) do
        if v:GetRemainingKnowledgePoints() > 0 then
            return false
        end
    end
    return true
end

---@return boolean
function PKT.Item:MeetCurrencyRequirements()
    if not self.currency then
        return true
    end

    local currencyInfo = C_CurrencyInfo.GetCurrencyInfo(self.currency.id)
    return currencyInfo.quantity >= self.currency.quantity
end

---@return boolean
function PKT.Item:IsLocked()
    return not self:MeetRenownRequirements() and not self:MeetUnlockRequirements()
end

---@return boolean
function PKT.Item:MeetRequirements()
    return self:MeetItemRequirements() and self:MeetCurrencyRequirements()
end

PKT.trackedItem = nil

---@return PKT.Item
function PKT.Item:ToggleTrack()
    if self:IsHighlighted() then
        self:Untrack()
        return nil
    end

    local untracked = PKT.trackedItem
    if untracked then
        untracked:Untrack()
    end

    local wp = self.waypoint
    if wp then
        local mapPoint = UiMapPoint.CreateFromCoordinates(wp.map, wp.x, wp.y)
        C_Map.SetUserWaypoint(mapPoint)
        C_SuperTrack.SetSuperTrackedUserWaypoint(true)
        local _, isTomTomLoaded = C_AddOns.IsAddOnLoaded("TomTom")
        if isTomTomLoaded and TomTom then
            local itemName = self:GetName() or PKT.L.UNKNOWN_ITEM
            self.tomtomUid = TomTom:AddWaypoint(wp.map, wp.x, wp.y, { title = itemName, persistent = false, source = "PKT.WA" })
        end
    end
    PKT.trackedItem = self
    return untracked
end

function PKT.Item:Untrack()
    if PKT.trackedItem ~= self then
        return
    end

    C_SuperTrack.SetSuperTrackedUserWaypoint(false)
    C_Map.ClearUserWaypoint()
    if TomTom and self.tomtomUid then
        TomTom:RemoveWaypoint(self.tomtomUid)
    end
    PKT.trackedItem = nil
end

---@return boolean
function PKT.Item:IsHighlighted()
    return PKT.trackedItem == self
end

---@return string
function PKT.Item:GetDescription()
    return self.text or self.name or PKT.L.UNKNOWN
end

---@return string
function PKT.Item:GetFullDescription()
    if not self.waypoint then
        return self:GetDescription() or PKT.L.DESCRIPTION.TREASURES:format(CreateAtlasMarkup("VignetteLoot", 20, 20))
    end
    local renownText = ""
    if not self:MeetRenownRequirements() then
        local renownInfo = C_MajorFactions.GetMajorFactionData(self.renown.majorFactionId)
        if renownInfo then
            renownText = renownInfo.name .. ": \124cffFF0000" .. tostring(renownInfo.renownLevel) .. "\124r/" .. tostring(self.renown.levelRequired) .. "\n"
        end
    end
    local name = self:GetDescription()
    local mapInfo = C_Map.GetMapInfo(self.waypoint.map)
    local turnInCount = self:GetRemainingTurnInCount()
    local kpCount = ""

    local currency = C_CurrencyInfo.GetCurrencyLink(self.profession.knowledgeCurrencyId, self:GetRemainingKnowledgePoints())
    if turnInCount == 1 then
        kpCount = PKT.L.DESCRIPTION.KP_COUNT:format(self:GetRemainingKnowledgePoints(), currency)
    elseif turnInCount > 1 then
        kpCount = PKT.L.DESCRIPTION.KP_COUNT_MULTIPLE:format(self:GetRemainingKnowledgePoints(), currency, turnInCount)
    end

    return string.format("%s%s\n%s - x:%.2f y:%.2f\n%s", renownText, name, mapInfo.name, self.waypoint.x * 100, self.waypoint.y * 100, kpCount)
end

---@class PKT.CatchUp
PKT.CatchUp = PKT.Item:New()

function PKT.CatchUp:GetRemainingKnowledgePoints()
    local weekly = self.profession:GetCatchUpCurrencyLeft()
    for _, requirement in ipairs(self.unlockRequirements) do
        weekly = weekly - requirement:GetRemainingKnowledgePoints()
    end
    return weekly
end

function PKT.CatchUp:GetType()
    return 4
end

function PKT.CatchUp:GetName()
    if self.text then
        return self.text
    end
    return PKT.Item.GetName(self)
end

function PKT.CatchUp:IsCatchUp()
    return true
end

function PKT.CatchUp:MeetRequirements()
    return self.text ~= nil or PKT.Item.MeetRequirements(self)
end

function PKT.CatchUp:GetDescription()
    local professionInfo = C_TradeSkillUI.GetChildProfessionInfo()

    local gatheringCatchUp = PKT.L.DESCRIPTION.CATCH_UP_GATHERING[professionInfo.profession]
    local workOrderSuffix = "\n" .. PKT.L.DESCRIPTION.CATCH_UP_WORK_ORDER:format(CreateSimpleTextureMarkup(4914670, 16, 16), CreateSimpleTextureMarkup(5976939, 16, 16))

    if gatheringCatchUp then
        return PKT.L.DESCRIPTION.CATCH_UP .. gatheringCatchUp
    elseif not self.text then
        return PKT.L.DESCRIPTION.CATCH_UP .. PROFESSIONS_CRAFTING_ORDERS_PAGE_NAME:format(PROFESSIONS_CRAFTER_ORDER_TAB_NPC) .. workOrderSuffix
    end

    if self.text then
        return self.text .. workOrderSuffix
    end

    return PKT.L.DESCRIPTION.CATCH_UP .. PKT.L.REQUIRES_MULTIPLE_QUESTS:format(self:GetRequirementsText())
end

function PKT.CatchUp:GetRequirementsText()
    local text = ""

    for _, v in ipairs(self.unlockRequirements or {}) do
        local questId = v.questId[1]
        local name = QuestUtils_GetQuestName(questId)
        if name ~= "" then
            text = text .. ' - '  .. QuestUtils_DecorateQuestText(questId, name, false, true, true, false) .. '\n'
        else
            text = text .. ' - '  .. v:GetCategoryIcon() .. ' ' .. GetItemInfo(v.itemId) .. '\n'
        end
    end

    return text
end

---@class PKT.DarkmoonQuest
PKT.DarkmoonQuest = PKT.Item:New()

function PKT.DarkmoonQuest:GetId()
    return self.questId[1]
end

function PKT.DarkmoonQuest:GetName()
    if self.name then
        return self.name
    end

    self.name = C_QuestLog.GetTitleForQuestID(self:GetId())
    return self.name
end

function PKT.DarkmoonQuest:GetIcon()
    -- Darkmoon eye IconId
    return 1100023
end

function PKT.DarkmoonQuest:IsAvailable()
    local dayOfWeek = tonumber(date("%w"))
    local dayOfMonth = tonumber(date("%e"))

    local firstSundayOfMonth = ((dayOfMonth - (dayOfWeek + 1)) % 7) + 1
    local daysSinceFirstSunday = dayOfMonth - firstSundayOfMonth
    return daysSinceFirstSunday >= 0 and daysSinceFirstSunday <= 6
end

function PKT.DarkmoonQuest:GetCategoryIcon()
    return CreateAtlasMarkup("quest-recurring-available", 16, 16)
end

function PKT.DarkmoonQuest:GetType()
    return 3
end

---@class PKT.UniqueBook
PKT.UniqueBook = PKT.Item:New()

function PKT.UniqueBook:IsUnique()
    return true
end

function PKT.UniqueBook:GetRemainingKnowledgePoints()
    if self._done then
        return 0
    end
    local remainingKp = PKT.Item.GetRemainingKnowledgePoints(self)
    self._done = remainingKp == 0
    return remainingKp
end

function PKT.UniqueBook:GetCategoryIcon()
    local atlasIcon = self.atlasIcon or "Levelup-Icon-Bag"
    return CreateAtlasMarkup(atlasIcon, 16, 16)
end

function PKT.UniqueBook:GetType()
    return 1
end

---@class PKT.UniqueTreasure
PKT.UniqueTreasure = PKT.UniqueBook:New()

function PKT.UniqueTreasure:GetCategoryIcon()
    local atlasIcon = self.atlasIcon or "poi-islands-table"
    local waypoint = self.waypoint
    local playerMap = C_Map.GetBestMapForUnit("player")

    if waypoint and playerMap then
        local parentMap = C_Map.GetMapInfo(C_Map.GetMapInfo(playerMap).parentMapID or playerMap)
        playerMap = parentMap.mapType == 3 and parentMap.mapID or playerMap

        local waypointMap = waypoint.map
        local parentWaypointMap = C_Map.GetMapInfo(C_Map.GetMapInfo(waypointMap).parentMapID)
        waypointMap = parentWaypointMap.mapType == 3 and parentWaypointMap.mapID or waypointMap

        if waypointMap == playerMap or self:GetRemainingKnowledgePoints() == 0 then
            return CreateAtlasMarkup(atlasIcon, 16, 16)
        end
    end

    return CreateAtlasMarkup("poi-islands-table", 16, 16, 0, 0, 64, 64, 64)
end

---@class PKT.WeeklyTreasure
PKT.WeeklyTreasure = PKT.Item:New()

function PKT.WeeklyTreasure:GetCategoryIcon()
    local atlasIcon = self.atlasIcon or "VignetteLoot"
    return CreateAtlasMarkup(atlasIcon, 16, 16)
end

function PKT.WeeklyTreasure:GetType()
    return 2
end

---@class PKT.WeeklyQuestItem
PKT.WeeklyQuestItem = PKT.Item:New()

function PKT.WeeklyQuestItem:GetName()
    local questName = QuestUtils_GetQuestName(self.questId[1])

    if questName ~= "" then
        return questName
    end

    return self.item:GetItemName()
end

---@return number
function PKT.WeeklyQuestItem:GetRemainingKnowledgePoints()
    for _, questId in ipairs(self.questId) do
        if C_QuestLog.IsQuestFlaggedCompleted(questId) then
            return 0
        end
    end

    return self.kp
end

function PKT.WeeklyQuestItem:GetDescription()
    return PKT.L.DESCRIPTION.TRAINER_QUEST
end

function PKT.WeeklyQuestItem:GetCategoryIcon()
    return CreateAtlasMarkup("quest-recurring-available", 16, 16)
end

function PKT.WeeklyQuestItem:GetType()
    return 2
end

---@class PKT.Treatise
PKT.Treatise = PKT.WeeklyTreasure:New()

function PKT.Treatise:GetDescription()
    return PKT.L.DESCRIPTION.TREATISE
end


PKT.professionSpellIdIdx = {}
PKT.professionCatchUpCurrencyIdIdx = {}

---@class PKT.Profession
PKT.Profession = {}
PKT.Profession.__index = PKT.Profession

---@param professionId number
---@param spellId number
---@param catchUpCurrencyId number
---@param knowledgeCurrencyId number
---@return PKT.Profession
function PKT.Profession:New(professionId, spellId, catchUpCurrencyId, knowledgeCurrencyId)
    local profession = {}
    setmetatable(profession, self)
    profession.id = professionId
    profession.spellId = spellId
    profession.catchUpCurrencyId = catchUpCurrencyId
    profession.knowledgeCurrencyId = knowledgeCurrencyId

    PKT.professionSpellIdIdx[spellId] = profession
    PKT.professionCatchUpCurrencyIdIdx[catchUpCurrencyId] = profession

    local info = C_TradeSkillUI.GetProfessionInfoBySkillLineID(profession.id)
    profession.name = info.parentProfessionName
    profession.skillLine = info.parentProfessionID
    profession.icon = C_TradeSkillUI.GetTradeSkillTexture(profession.id)
    profession.entries = {}
    profession.index = profession.id * 1000
    return profession
end

PKT.spellIdIdx = {}
PKT.questIdIdx = {}
PKT.idIdx = {}

---@param entry PKT.Item
---@return self
function PKT.Profession:AddEntry(entry)
    entry.profession = self
    if entry.spell then
        PKT.spellIdIdx[entry.spell] = entry
    end

    PKT.idIdx[entry:GetId()] = entry

    for _, questId in ipairs(entry.questId) do
        PKT.questIdIdx[questId] = entry
    end

    table.insert(self.entries, entry)
    entry.index = self.index + #self.entries
    return self
end

function PKT.Profession:GetSkillLevel()
    local prof1, prof2, _ = GetProfessions()
    if prof1 then
        local _, _, skillLevel, maxSkillLevel, _, _, skillLine, bonusSkill, _ = GetProfessionInfo(prof1)
        if skillLine == self.skillLine then
            return { skillLevel = skillLevel, maxSkillLevel = maxSkillLevel, bonusSkill = bonusSkill }
        end
    end
    if prof2 then
        local _, _, skillLevel, maxSkillLevel, _, _, skillLine, bonusSkill, _ = GetProfessionInfo(prof2)
        if skillLine == self.skillLine then
            return { skillLevel = skillLevel, maxSkillLevel = maxSkillLevel, bonusSkill = bonusSkill }
        end
    end

    return { skillLevel = 0, maxSkillLevel = 0, bonusSkill = 0 }

end

function PKT.Profession:CalculateRemainingKps()
    -- TODO: Display these at the top of the frame
    local weekly, unique, catchUp = 0, 0, 0
    for _, item in pairs(self.entries) do
        local remaining = item:GetRemainingKnowledgePoints()
        if item:IsUnique() then
            unique = unique + remaining
        elseif item:IsCatchUp() then
            catchUp = catchUp + remaining
        else
            weekly = weekly + remaining
        end
    end
    return { weekly = weekly, unique = unique, catchUp = catchUp }
end

function PKT.Profession:GetCatchUpCurrencyLeft()
    local currencyInfo = C_CurrencyInfo.GetCurrencyInfo(self.catchUpCurrencyId)
    return currencyInfo.maxQuantity - currencyInfo.quantity
end

function PKT.Profession:GetAvailableItems()
    return self.entries
end

local function GetPointsMissingForTree(configID, nodeID)
    local todo = { nodeID }
    local missing = 0
    while next(todo) do
        local removedNodeID = table.remove(todo)
        tAppendAll(todo, C_ProfSpecs.GetChildrenForPath(removedNodeID))
        local info = C_Traits.GetNodeInfo(configID, removedNodeID)
        if info then
            -- Enabling a node counts as 1 rank but doesn't cost anything
            local enableFix = info.activeRank == 0 and 1 or 0
            missing = missing + info.maxRanks - info.activeRank - enableFix
        end
    end
    return missing
end

function PKT.Profession:CalculateSpendableKps()
    local configID = C_ProfSpecs.GetConfigIDForSkillLine(self.id)
    local traitTreeIDs = C_ProfSpecs.GetSpecTabIDsForSkillLine(self.id)
    local totalMissing = 0
    for _, traitTreeID in ipairs(traitTreeIDs) do
        local tabInfo = C_ProfSpecs.GetTabInfo(traitTreeID)
        totalMissing = totalMissing + GetPointsMissingForTree(configID, tabInfo.rootNodeID)
    end
    local currencyInfo = C_ProfSpecs.GetCurrencyInfoForSkillLine(self.id) or { numAvailable = 0 }
    return totalMissing - currencyInfo.numAvailable
end

---@param professionInfo ProfessionInfo
function PKT.CreateKnowledgeDataProvider(professionInfo, searchText)
    local profession = PKT.DB[professionInfo.professionID]

    if not profession then
        return nil
    end

    local dataProvider = CreateTreeDataProvider()
    local root = dataProvider:GetRootNode()
    local searching = searchText ~= ""
    searchText = string.lower(searchText)

    local categories = {
        [PKT.EntryState.Available] = root:Insert({ categoryName = PKT.L.CATEGORY.Available, collapsed = false }),
        [PKT.EntryState.Unavailable] = root:Insert({ categoryName = PKT.L.CATEGORY.Unavailable, collapsed = true }),
        [PKT.EntryState.Completed] = root:Insert({ categoryName = PKT.L.CATEGORY.Completed, collapsed = true }),
    }

    for _, source in ipairs(profession:GetAvailableItems()) do
        local category = source:GetState()
        local name = string.lower(source:GetName())
        if (searching and string.find(name, searchText)) or not searching then
            categories[category]:Insert(source)
        end
    end

    return dataProvider
end
