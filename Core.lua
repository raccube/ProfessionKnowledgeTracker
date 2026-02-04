---@class PKT
local ADDON_NAME, PKT = ...

PKT.states = {}

function FindFirstSource(dataProvider)
    for _, node in dataProvider:EnumerateEntireRange() do
        local data = node:GetData()

        if data.itemId then
            return data
        end
    end
end

local function OnEvent(_, event, ...)
    if event == "ADDON_LOADED" and ... == ADDON_NAME then
        PKT.frame = CreateFrame("Frame", "PKTFrame", ProfessionsFrame, "KnowledgeFrameTemplate")
        PKT.tabID = ProfessionsFrame:AddNamedTab(PKT.L.TAB.NAME, PKT.frame)
        ProfessionsFrame.TabSystem:SetTabShown(PKT.tabID, false)
        ProfessionsFrame.TabSystem:GetTabButton(PKT.tabID)
                        :SetTooltipText(WrapTextInColorCode(PKT.L.TAB.TOOLTIP, C_ClassColor.GetClassColor("MONK"):GenerateHexColor()))

        hooksecurefunc(ProfessionsFrame, "SetProfessionInfo", function(f, professionInfo)
            local shouldShowTab = Professions.InLocalCraftingMode() and C_ProfSpecs.ShouldShowSpecTab()
            local hasProfessionInDb = PKT.DB[professionInfo.professionID] ~= nil
            local shown = shouldShowTab and hasProfessionInDb

            f.TabSystem:SetTabShown(PKT.tabID, shown)

            if f.TabSystem.selectedTabID == PKT.tabID and not shown then
                f.TabSystem:SetTab(ProfessionsFrame.recipesTabID, false)
            end
        end)
    elseif event == "QUEST_TURNED_IN" then
        local questId, _ = ...
        local entry = PKT.questIdIdx[questId]

        if entry and ProfessionsFrame:IsShown() then
            local profession = C_TradeSkillUI.GetChildProfessionInfo()
            C_Timer.After(.5, function() PKT.frame:Refresh(profession) end)
        end
    end
end

local Handler = CreateFrame("Frame")
Handler:RegisterEvent("ADDON_LOADED")
Handler:RegisterEvent("QUEST_TURNED_IN")
Handler:SetScript("OnEvent", OnEvent)
