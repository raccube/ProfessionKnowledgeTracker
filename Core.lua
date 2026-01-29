---@class PKT
local ADDON_NAME, PKT = ...

PKT.states = {}

local function OnEvent(self, event, ...)
    if event == "ADDON_LOADED" and ... == ADDON_NAME then
        local frame = CreateFrame("Frame", "PKTFrame", ProfessionsFrame, "KnowledgeFrameTemplate")
        local tabID = ProfessionsFrame:AddNamedTab(PKT.L.TAB_NAME, frame)
        ProfessionsFrame.TabSystem:SetTabShown(tabID, false)
        hooksecurefunc(ProfessionsFrame, "UpdateTabs", function(f)
            local shouldShowTab = Professions.InLocalCraftingMode() and C_ProfSpecs.ShouldShowSpecTab()
            f.TabSystem:SetTabShown(tabID, shouldShowTab)
        end)
    elseif event == "CURRENCY_DISPLAY_UPDATE" then
        -- TODO: Do this
        local currencyId = select(1, ...)
        local profession = PKT.professionCatchUpCurrencyIdIdx[currencyId]

        if profession then
            profession:FillState(states)
            for _, item in pairs(profession:GetAvailableItems()) do
                item:FillState(states)
            end
        end
    end
end

local Handler = CreateFrame("Frame")
Handler:RegisterEvent("ADDON_LOADED")
Handler:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
Handler:SetScript("OnEvent", OnEvent)
