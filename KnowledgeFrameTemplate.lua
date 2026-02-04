local ADDON_NAME, PKT = ...

KnowledgePageMixin = {}

function KnowledgePageMixin:GetDesiredPageWidth()
    return 942
end

function KnowledgePageMixin:Refresh(professionInfo)
    local profession = PKT.DB[professionInfo.professionID]

    local remainingKps = profession:CalculateRemainingKps()
    self.Counters.Unique:SetText(PKT.L.COUNTERS.UNIQUE:format(remainingKps.unique))
    self.Counters.Weekly:SetText(PKT.L.COUNTERS.WEEKLY:format(remainingKps.weekly))
    self.Counters.CatchUp:SetText(PKT.L.COUNTERS.CATCH_UP:format(remainingKps.catchUp))

    self.DetailsForm.Background:SetAtlas(Professions.GetProfessionBackgroundAtlas(professionInfo), TextureKitConstants.IgnoreAtlasSize)

    PKT.dataProvider = PKT.CreateKnowledgeDataProvider(professionInfo)
    self.SourceList.ScrollBox:SetDataProvider(PKT.dataProvider)

    self.WaypointButton:SetPoint("BOTTOMRIGHT", -9, 7)
    self.WaypointButton:SetText(PKT.L.WAYPOINT_BUTTON_INACTIVE_TEXT)
end

function KnowledgePageMixin:OnShow()
    local professionInfo = C_TradeSkillUI.GetChildProfessionInfo()

    if PKT.DB[professionInfo.professionID] then
        self:Refresh(professionInfo)
    end
end

function KnowledgePageMixin:OnHide()
end

function KnowledgePageMixin:OnEvent(event, ...)
end

---@param professionInfo ProfessionInfo
function KnowledgePageMixin:OnProfessionSelected(professionInfo)
    if PKT.DB[professionInfo.professionID] then
        self:Refresh(professionInfo)
    end
end

function KnowledgePageMixin:OnTabSet(_, tabID)
    if tabID == PKT.tabID then
        if not self.SourceList.selectionBehavior:HasSelection() then
            local firstNode = FindFirstSource(PKT.dataProvider)
            self.SourceList.selectionBehavior:SelectFirstElementData(function(node)
                local data = node:GetData()
                return data.itemId == firstNode.itemId
            end)
        end
    end
end

function KnowledgePageMixin:OnLoad()
    self.DetailsForm.Reagents.Label:SetText(PKT.L.REQUIREMENTS)

    if Professions.InLocalCraftingMode() and C_ProfSpecs.ShouldShowSpecTab() then
        local professionInfo = C_TradeSkillUI.GetChildProfessionInfo()

        if professionInfo.professionID ~= 0 then
            self:Refresh(professionInfo)
        end
    end

    EventRegistry:RegisterCallback("PKT.Event.OnKnowledgeSourceSelected", self.OnKnowledgeSourceSelected, self)
    EventRegistry:RegisterCallback("Professions.ProfessionSelected", self.OnProfessionSelected, self)
    EventRegistry:RegisterCallback("ProfessionsFrame.TabSet", self.OnTabSet, self)
    self.DetailsForm.SourceIcon.CountShadow:Hide()

    self.DetailsForm.SourceIcon:SetScript("OnEnter", function()
        local selected = self.SourceList.selectionBehavior:GetSelectedElementData()

        if selected and selected[1].data.itemId then
            GameTooltip:SetOwner(self.DetailsForm.SourceIcon, "ANCHOR_RIGHT")
            GameTooltip:SetItemByID(selected[1].data.itemId)
        end
    end)

    self.DetailsForm.SourceIcon:SetScript("OnLeave", function()
        GameTooltip_Hide()
        self.DetailsForm.SourceIcon:SetScript("OnUpdate", nil)
    end)
end

function CreateFakeRecipeSchematic(items, currency)
    local schematic = {
        recipeID = 0,
        icon = 0,
        quantityMin = 0,
        quantityMax = 0,
        name = "",
        reagentSlotSchematics = {},
        isRecraft = false,
        hasCraftingOperationInfo = true,
    }

    if currency then
        local slotSchematic = {
            reagents = { { currencyID = currency.id } },
            reagentType = Enum.CraftingReagentType.Basic,
            quantityRequired = currency.quality,
            dataSlotIndex = slotIndex,
            slotIndex = slotIndex,
            required = true,
        }

        function slotSchematic:GetQuantityRequired()
            return currency.quantity
        end

        table.insert(schematic.reagentSlotSchematics, slotSchematic)
    end

    for slotIndex, itemDetails in ipairs(items) do
        local slotSchematic = {
            reagents = { { itemID = itemDetails.id } },
            reagentType = Enum.CraftingReagentType.Basic,
            quantityRequired = itemDetails.quantity,
            dataSlotIndex = slotIndex,
            slotIndex = slotIndex,
            required = true,
        }

        function slotSchematic:GetQuantityRequired()
            return itemDetails.quantity
        end

        table.insert(schematic.reagentSlotSchematics, slotSchematic)
    end

    return schematic
end

function KnowledgePageMixin:SetUpRequiredItems()
    self.slots = {}
    if PKT.selected.itemRequirements then
        self.reagentSlotPool = CreateFramePool("FRAME", self, "ProfessionsReagentSlotTemplate")
        self.DetailsForm.Reagents:Show()
        local recipeSchematic = CreateFakeRecipeSchematic(PKT.selected.itemRequirements, PKT.selected.currency)
        self.transaction = CreateProfessionsRecipeTransaction(recipeSchematic)

        for _, reagentSlotSchematic in ipairs(recipeSchematic.reagentSlotSchematics) do
            local slot = self.reagentSlotPool:Acquire()
            slot:Init(self.transaction, reagentSlotSchematic)
            slot:Show()
            slot:SetOverrideQuantity(
                    C_Item.GetItemCount(
                            reagentSlotSchematic.reagents[1].itemID,
                            false,
                            true,
                            false,
                            false
                    ),
                    false
            )
            slot:UpdateAllocationText()
            table.insert(self.slots, slot)
        end

        local spacingX = 5
        local spacingY = -5
        local stride = 4
        local direction = GridLayoutMixin.Direction.TopLeftToBottomRightVertical
        Professions.LayoutReagentSlots(self.slots, self.DetailsForm.Reagents, spacingX, spacingY, stride, direction)
    else
        self.DetailsForm.Reagents:Hide()
    end
end

function KnowledgePageMixin:ShowSource()
    local source = PKT.selected
    local icon = source.item and source.item:GetItemIcon() or source:GetIcon()
    local name = source.item and source.item:GetItemName() or source:GetName()
    local link = source.item and source.item:GetItemLink() or ""
    local quality = source.item and C_Item.GetItemQualityByID(source.itemId) or Enum.ItemQuality.Epic

    if self.transaction then
        self.reagentSlotPool:ReleaseAll()
        self.transaction = nil
    end

    self:SetUpRequiredItems()

    self.DetailsForm.SourceIcon.Icon:SetTexture(icon)
    SetItemButtonQuality(self.DetailsForm.SourceIcon, quality, link, true, false, false)
    self.DetailsForm.DetailText:SetText(source:GetFullDescription())

    local _, _, _, colour = C_Item.GetItemQualityColor(quality)
    self.DetailsForm.SourceName:SetText(WrapTextInColorCode(name, colour))
    self.WaypointButton:SetEnabled(source.waypoint ~= nil)
    if PKT.trackedItem == source then
        self.WaypointButton:SetText(PKT.L.WAYPOINT_BUTTON_ACTIVE_TEXT)
    else
        self.WaypointButton:SetText(PKT.L.WAYPOINT_BUTTON_INACTIVE_TEXT)
    end
    self.WaypointButton:SetScript("OnClick", GenerateClosure(self.Waypoint, self))
end

---@param source PKT.Item
function KnowledgePageMixin:OnKnowledgeSourceSelected(source)
    PKT.selected = source
    self:ShowSource()
end

function KnowledgePageMixin:Waypoint()
    local selected = self.SourceList.selectionBehavior:GetSelectedElementData()
    ---@type PKT.Item source
    local source = selected[1].data

    source:ToggleTrack()
    if source:IsHighlighted() then
        self.WaypointButton:SetText(PKT.L.WAYPOINT_BUTTON_ACTIVE_TEXT)
    else
        self.WaypointButton:SetText(PKT.L.WAYPOINT_BUTTON_INACTIVE_TEXT)
    end
end