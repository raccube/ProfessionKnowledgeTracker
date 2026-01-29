local ADDON_NAME, PKT = ...

KnowledgePageMixin = {}

function KnowledgePageMixin:GetDesiredPageWidth()
    return 942
end

function KnowledgePageMixin:Refresh(professionInfo)
    self.DetailsForm.Background:SetAtlas(Professions.GetProfessionBackgroundAtlas(professionInfo), TextureKitConstants.IgnoreAtlasSize)

    local dataProvider = PKT.CreateKnowledgeDataProvider(professionInfo)
    self.SourceList.ScrollBox:SetDataProvider(dataProvider)
    self.WaypointButton:SetPoint("BOTTOMRIGHT", -9, 7)
    self.WaypointButton:SetText(PKT.L.WAYPOINT_BUTTON_INACTIVE_TEXT)
end

-- TODO: Make this trigger when professionID changes
function KnowledgePageMixin:OnShow()
    print("KnowledgePageMixin:OnShow()")

    if Professions.InLocalCraftingMode() and C_ProfSpecs.ShouldShowSpecTab() then
        local professionInfo = C_TradeSkillUI.GetChildProfessionInfo()

        if professionInfo.professionID ~= 0 then
            self:Refresh(professionInfo)
        end
    end
end

function KnowledgePageMixin:OnHide()
end

function KnowledgePageMixin:OnEvent(event, ...)
end

function KnowledgePageMixin:OnLoad()
    if Professions.InLocalCraftingMode() and C_ProfSpecs.ShouldShowSpecTab() then
        local professionInfo = C_TradeSkillUI.GetChildProfessionInfo()

        if professionInfo.professionID ~= 0 then
            self:Refresh(professionInfo)
        end
    end

    EventRegistry:RegisterCallback("PKT.Event.OnKnowledgeSourceSelected", self.OnKnowledgeSourceSelected, self)
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

---@param source PKT.Item
function KnowledgePageMixin:OnKnowledgeSourceSelected(source)
    local item, icon, name, link, quality
    if source.item then
        item = source.item
        icon = item:GetItemIcon()
        name = item:GetItemName()
        link = item:GetItemLink()
        quality = C_Item.GetItemQualityByID(source.itemId)
    else
        icon = source:GetIcon()
        name = source:GetName()
        quality = Enum.ItemQuality.Epic
    end

    if self.transaction then
        self.reagentSlotPool:ReleaseAll()
        self.transaction = nil
    end

    self.slots = {}
    if source.itemRequirements then
        self.reagentSlotPool = CreateFramePool("FRAME", self, "ProfessionsReagentSlotTemplate")
        self.DetailsForm.Reagents:Show()
        local recipeSchematic = CreateFakeRecipeSchematic(source.itemRequirements, source.currency)
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

    self.DetailsForm.SourceIcon.Icon:SetTexture(icon)
    SetItemButtonQuality(self.DetailsForm.SourceIcon, quality, link)
    self.DetailsForm.DetailText:SetText(source:GetDescription())

    _, _, _, colour = GetItemQualityColor(quality)
    self.DetailsForm.SourceName:SetText(WrapTextInColorCode(name, colour))
    self.WaypointButton:SetEnabled(source.waypoint ~= nil)
    if PKT.trackedItem == source then
        self.WaypointButton:SetText(PKT.L.WAYPOINT_BUTTON_ACTIVE_TEXT)
    else
        self.WaypointButton:SetText(PKT.L.WAYPOINT_BUTTON_INACTIVE_TEXT)
    end
    self.WaypointButton:SetScript("OnClick", GenerateClosure(self.Waypoint, self))
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