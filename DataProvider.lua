local PKT = select(2, ...)

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
    return self.itemId
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
function PKT.Item:Show()
    return self:GetRemainingKnowledgePoints() > 0
end

---@return string
function PKT.Item:GetName()
    if self.name then
        return self.name
    end

    self.name = self.item:GetItemName() or self.text

    return self.name
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
function PKT.Item:GetRemainingKnowledgePoints()
    local questCount = 0

    for _, questId in ipairs(self.questId) do
        if not C_QuestLog.IsQuestFlaggedCompleted(questId) then
            questCount = questCount + 1
        end
    end

    return questCount * self.kp
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
function PKT.Item:MeetRequirements()
    return self:MeetRenownRequirements()
            and self:MeetItemRequirements()
            and self:MeetCurrencyRequirements()
            and self:MeetUnlockRequirements()
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
    if not self.waypoint then
        return self.text or PKT.L.DESCRIPTION.TREASURES:format(CreateAtlasMarkup("VignetteLoot", 20, 20))
    end
    local renownText = ""
    if not self:MeetRenownRequirements() then
        local renownInfo = C_MajorFactions.GetMajorFactionData(self.renown.majorFactionId)
        if renownInfo then
            renownText = renownInfo.name .. ": \124cffFF0000" .. tostring(renownInfo.renownLevel) .. "\124r/" .. tostring(self.renown.levelRequired) .. "\n"
        end
    end
    local itemRequirements = ""
    if self.itemRequirements then
        for _, v in pairs(self.itemRequirements) do
            local itemName = C_Item.GetItemNameByID(v.id) or PKT.L.UNKNOWN_ITEM
            local itemCount = C_Item.GetItemCount(v.id)
            local meetsRequirements = itemCount >= v.quantity
            if meetsRequirements then
                itemRequirements = itemRequirements .. tostring(itemCount) .. "/" .. tostring(v.quantity) .. " " .. itemName .. "\n"
            else
                itemRequirements = itemRequirements .. WrapTextInColorCode(tostring(itemCount), "ffff0000") .. "/" .. tostring(v.quantity) .. " " .. itemName .. "\n"
            end
        end
    end

    local currencyRequirements = ""
    local requiredCurrency = self.currency
    if requiredCurrency then
        local currencyInfo = C_CurrencyInfo.GetCurrencyInfo(requiredCurrency.id)
        local meetsRequirements = currencyInfo.quantity >= requiredCurrency.quantity
        local currentQuantityStr = meetsRequirements and tostring(currencyInfo.quantity) or WrapTextInColorCode(tostring(currencyInfo.quantity), "ffff0000")
        currencyRequirements = CreateSimpleTextureMarkup(currencyInfo.iconFileID, 16, 16) .. " " .. currencyInfo.name .. ": " .. currentQuantityStr .. "/" .. tostring(requiredCurrency.quantity) .. "\n"
    end

    local name = self.text or self.name or PKT.L.UNKNOWN
    local mapInfo = C_Map.GetMapInfo(self.waypoint.map)
    return string.format("%s%s\n%s - x:%.2f y:%.2f", renownText .. itemRequirements .. currencyRequirements, name, mapInfo.name, self.waypoint.x * 100, self.waypoint.y * 100)
end

---@return boolean
function PKT.Item:FillState()
    local state = PKT.states[self:GetId()] or { atlasIcon = self:GetCategoryIcon(), icon = self:GetIcon(), itemId = self.itemId, type = self:GetType(), index = self.index }

    local remainingPoints = self:GetRemainingKnowledgePoints()
    local meetsRequirements = self:MeetRequirements()

    local changed = state.atlasIcon ~= self:GetCategoryIcon()
            or state.glow ~= self:IsHighlighted()
            or state.meetRequirements ~= meetsRequirements
            or state.name ~= self:GetName()
            or state.remainingPoints ~= remainingPoints

    if not changed then
        return false
    end

    state.changed = true
    state.atlasIcon = self:GetCategoryIcon()
    state.glow = self:IsHighlighted()
    state.meetRequirements = meetsRequirements
    state.name = self:GetName()
    state.remainingPoints = remainingPoints

    PKT.states[self:GetId()] = state

    return true
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

function PKT.CatchUp:Show()
    return not PKT.Item.Show(self)
end

function PKT.CatchUp:MeetRequirements()
    return self.text ~= nil or PKT.Item.MeetRequirements(self)
end

function PKT.CatchUp:GetDescription()
    if self.text then
        return self.text .. "\n" .. PKT.L.DESCRIPTION.CATCH_UP:format(CreateSimpleTextureMarkup(4914670, 16, 16), CreateSimpleTextureMarkup(5976939, 16, 16))
    end

    return PKT.L.REQUIRES_QUEST:format(self:GetNextRequirementText())
end

function PKT.CatchUp:GetNextRequirementText()
    for _, v in ipairs(self.unlockRequirements or {}) do
        local questId = v.questId[1]
        local name = QuestUtils_GetQuestName(questId)
        if name ~= "" then
            return QuestUtils_DecorateQuestText(questId, name, false, true, true, false)
        else
            return v:GetCategoryIcon() .. ' ' .. GetItemInfo(v.itemId)
        end
    end

    return ""
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

function PKT.DarkmoonQuest:IsDmfUp()
    local dayOfWeek = tonumber(date("%w"))
    local dayOfMonth = tonumber(date("%e"))

    local firstSundayOfMonth = ((dayOfMonth - (dayOfWeek + 1)) % 7) + 1
    local daysSinceFirstSunday = dayOfMonth - firstSundayOfMonth
    return daysSinceFirstSunday >= 0 and daysSinceFirstSunday <= 6
end

function PKT.DarkmoonQuest:GetRemainingKnowledgePoints()
    return not self:IsDmfUp() and 0 or PKT.Item.GetRemainingKnowledgePoints(self)
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

function PKT.UniqueBook:Show()
    return PKT.Item.Show(self)
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
    return QuestUtils_GetQuestName(self.questId[1])
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

function PKT.WeeklyQuestItem:GetCategoryIcon()
    return CreateAtlasMarkup("quest-recurring-available", 16, 16)
end

function PKT.WeeklyQuestItem:GetType()
    return 2
end

---@class PKT.Treatise
PKT.Treatise = PKT.WeeklyTreasure:New()

function PKT.Treatise:Show()
    return PKT.Item.Show(self)
end

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
---@return PKT.Profession
function PKT.Profession:New(professionId, spellId, catchUpCurrencyId)
    local profession = {}
    setmetatable(profession, self)
    profession.id = professionId
    profession.spellId = spellId
    profession.catchUpCurrencyId = catchUpCurrencyId

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

function PKT.Profession:FillState()
    local state = PKT.states[self.id] or { name = self.name, icon = self.icon, index = self.index, glow = false, type = 0 }

    local remaining = self:CalculateRemainingKps()
    local skillLevel = self:GetSkillLevel()
    local kpsToMaxTree = self:CalculateSpendableKps()

    local changed = state.skillLevel ~= skillLevel.skillLevel
            or state.maxSkillLevel ~= skillLevel.maxSkillLevel
            or state.bonusSkill ~= skillLevel.bonusSkill
            or state.remainingUniqueKp ~= remaining.unique
            or state.remainingWeeklyKp ~= remaining.weekly
            or state.remainingCatchUpKp ~= remaining.catchUp
            or state.kpsToMaxTree ~= kpsToMaxTree

    if not changed then
        return false
    end

    state.changed = true
    state.skillLevel = skillLevel.skillLevel
    state.maxSkillLevel = skillLevel.maxSkillLevel
    state.bonusSkill = skillLevel.bonusSkill
    state.remainingUniqueKp = remaining.unique
    state.remainingWeeklyKp = remaining.weekly
    state.remainingCatchUpKp = remaining.catchUp
    state.kpsToMaxTree = kpsToMaxTree
    state.formattedKpsToMaxTree = WrapTextInColorCode("+" .. tostring(math.max(0, kpsToMaxTree)), "ffff9900")
    state.formattedCatchUp = WrapTextInColorCode("+" .. tostring(remaining.catchUp), "ff00ff00")

    PKT.states[self.id] = state

    return true
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
function PKT.CreateKnowledgeDataProvider(professionInfo)
    local profession = PKT.DB[professionInfo.professionID]
    local dataProvider = CreateTreeDataProvider()
    local root = dataProvider:GetRootNode()

    local availableCategory = root:Insert({ categoryName = PKT.L.AVAILABLE_CATEGORY })
    local unavailableCategory = root:Insert({ categoryName = PKT.L.UNAVAILABLE_CATEGORY })
    local completedCategory = root:Insert({ categoryName = PKT.L.COMPLETED_CATEGORY })

    for _, source in ipairs(profession:GetAvailableItems()) do
        local remainingKp = source:GetRemainingKnowledgePoints()
        if remainingKp == 0 then
            completedCategory:Insert(source)
        elseif source:MeetRequirements() and remainingKp > 0 then
            availableCategory:Insert(source)
        else
            unavailableCategory:Insert(source)
        end
    end

    return dataProvider
end
