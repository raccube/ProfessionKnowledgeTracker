local ADDON_NAME, PKT = ...

KnowledgeSourceListMixin = CreateFromMixins(CallbackRegistryMixin)
KnowledgeSourceListMixin:GenerateCallbackEvents(
{
    "OnKnowledgeSourceSelected",
})

function KnowledgeSourceListMixin:OnLoad()
    CallbackRegistryMixin.OnLoad(self)

    local indent = 10
    local padLeft = 0
    local pad = 5
    local spacing = 1
    local view = CreateScrollBoxListTreeListView(indent, pad, pad, padLeft, pad, spacing)

    view:SetElementFactory(function(factory, node)
        local elementData = node:GetData()
        if elementData.categoryName then
            local function Initializer(button, node)
                button:Init(node)
                button:SetText(elementData.categoryName)
                node:SetCollapsed(elementData.collapsed)
                button:SetCollapseState(elementData.collapsed)

                button:SetScript("OnClick", function(button, buttonName)
                    node:ToggleCollapsed()
                    button:SetCollapseState(node:IsCollapsed())
                end)

                button:SetScript("OnEnter", function()
                    EventRegistry:TriggerEvent("PKT.SourceEntered", button, node.categoryName)
                    KnowledgeSourceListCategoryMixin.OnEnter(button)
                end)
            end
            factory("KnowledgeSourceListCategoryTemplate", Initializer)
        else
            local function Initializer(button, node)
                button:Init(node)
                button:SetText(elementData.text)
                button.LockedIcon:SetShown(elementData:IsLocked());

                local selected = self.selectionBehavior:IsElementDataSelected(node)
                button:SetSelected(selected)

                button:SetScript("OnClick", function(button, buttonName, down)
                    if buttonName == "LeftButton" then
                        self.selectionBehavior:Select(button)
                    end

                    PlaySound(SOUNDKIT.UI_90_BLACKSMITHING_TREEITEMCLICK)
                end)

                button:SetScript("OnEnter", function()
                    KnowledgeSourceListSourceMixin.OnEnter(button)
                    EventRegistry:TriggerEvent("PKT.KnowledgeSourceListSourceEntered", button, elementData)
                end)
            end
            factory("KnowledgeSourceListSourceTemplate", Initializer)
        end
    end)

    ScrollUtil.InitScrollBoxListWithScrollBar(self.ScrollBox, self.ScrollBar, view)

    local function OnSelectionChanged(o, elementData, selected)
        local button = self.ScrollBox:FindFrame(elementData)
        if button then
            button:SetSelected(selected)
        end

        if selected then
            local data = elementData:GetData()

            local newItemID = data:GetId()
            local changed = self.previousItemID ~= newItemID
            if changed then
                EventRegistry:TriggerEvent("PKT.Event.OnKnowledgeSourceSelected", data, self)

                if newItemID then
                    self.previousItemID = newItemID
                end
            end
        end
    end

    self.selectionBehavior = ScrollUtil.AddSelectionBehavior(self.ScrollBox)
    self.selectionBehavior:RegisterCallback(SelectionBehaviorMixin.Event.OnSelectionChanged, OnSelectionChanged, self)

    self:InitFilterMenu(self.FilterDropdown)
end

function KnowledgeSourceListMixin:GetCurrentFilterSet()
    return {
        textFilter = self.SearchBox:GetText(),
    }
end

function KnowledgeSourceListMixin:InitFilterMenu(dropdown)
    dropdown:SetupMenu(function(dropdown, rootDescription)
        rootDescription:SetTag("MENU_PROFESSIONS_FILTER")

        local function IsExpansionChecked(professionInfo)
            return C_TradeSkillUI.GetChildProfessionInfo().professionID == professionInfo.professionID;
        end

        local function SetExpansionChecked(professionInfo)
            EventRegistry:TriggerEvent("Professions.SelectSkillLine", professionInfo);
        end

        local childProfessionInfos = C_TradeSkillUI.GetChildProfessionInfos()
        if #childProfessionInfos > 0 then
            for _, professionInfo in ipairs(childProfessionInfos) do
                local radioButton = rootDescription:CreateRadio(professionInfo.expansionName, IsExpansionChecked, SetExpansionChecked, professionInfo)
                if not PKT.DB[professionInfo.professionID] then
                    radioButton:SetEnabled(false)
                end
            end
        end
    end)
end

KnowledgeSourceListSourceMixin = {}

function KnowledgeSourceListSourceMixin:Init(node)
    ---@type PKT.Item elementData
    local elementData = node:GetData()
    self.Label:SetText(elementData:GetCategoryIcon() .. " " .. elementData:GetName() or "")
end

function KnowledgeSourceListSourceMixin:OnLoad()
end

function KnowledgeSourceListSourceMixin:OnEnter()
    self:SetLabelFontColors(HIGHLIGHT_FONT_COLOR)
    local elementData = self:GetElementData()

    EventRegistry:TriggerEvent("PKT.KnowledgeSourceListOnEnter", self, elementData.data)
end

function KnowledgeSourceListSourceMixin:OnLeave()
end

function KnowledgeSourceListSourceMixin:SetLabelFontColors(color)
    self.Label:SetVertexColor(color:GetRGB())
    self.Count:SetVertexColor(color:GetRGB())
end

function KnowledgeSourceListSourceMixin:SetSelected(selected)
    self.SelectedOverlay:SetShown(selected)
    self.HighlightOverlay:SetShown(not selected)
end

KnowledgeSourceListCategoryMixin = {}

function KnowledgeSourceListCategoryMixin:Init(node)
    local elementData = node:GetData()
    self:SetCollapseState(node:IsCollapsed())

    self.Label:SetText(elementData.categoryName)
end

function KnowledgeSourceListCategoryMixin:OnLoad()
end

function KnowledgeSourceListCategoryMixin:OnEnter()
    self.Label:SetFontObject(GameFontHighlight_NoShadow)
end

function KnowledgeSourceListCategoryMixin:OnLeave()
    self.Label:SetFontObject(GameFontNormal_NoShadow)
end

function KnowledgeSourceListCategoryMixin:SetCollapseState(collapsed)
    local atlas = collapsed and "Professions-recipe-header-expand" or "Professions-recipe-header-collapse"
    self.CollapseIcon:SetAtlas(atlas, TextureKitConstants.UseAtlasSize)
    self.CollapseIconAlphaAdd:SetAtlas(atlas, TextureKitConstants.UseAtlasSize)
end
