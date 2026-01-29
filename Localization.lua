local ADDON_NAME, PKT = ...

local L = {
    enGB = {
        TAB_NAME = "Knowledge Sources",
        AVAILABLE_CATEGORY = "Available",
        COMPLETED_CATEGORY = "Completed",
        UNAVAILABLE_CATEGORY = "Unavailable",
        WAYPOINT_BUTTON_INACTIVE_TEXT = "Track",
        WAYPOINT_BUTTON_ACTIVE_TEXT = "Unrack",
        REQUIRES_QUEST = "Finish %s to unlock.",
        DESCRIPTION = {
            CATCH_UP = "%s ~24 hours %s ~84 hours",
            TREASURES = "%s Found in treasures around Khaz Algar",
            TREATISE = "Obtained through Inscription work orders",
        },
        UNKNOWN_ITEM = "Item not loaded",
        UNKNOWN = "Not loaded yet",
    },
    deDE = {
        TAB_NAME = "Wissensquellen",
        AVAILABLE_CATEGORY = "Verfügbar",
        COMPLETED_CATEGORY = "Erledigt",
        UNAVAILABLE_CATEGORY = "Nicht verfügbar",
        WAYPOINT_BUTTON_INACTIVE_TEXT = "Beobachten",
        WAYPOINT_BUTTON_ACTIVE_TEXT = "Nicht mehr folgen",
        REQUIRES_QUEST = "Schließe die Quest %s ab.",
        DESCRIPTION = {
            CATCH_UP = "%s ~24 Std. %s ~84 Std.",
            TREASURES = "%s Gefunden auf Schätzen rund um Khaz Algar",
            TREATISE = "Erhalten durch Inschriftenkunde-Handwerksaufträge",
        },
        UNKNOWN_ITEM = "Gegenstand nicht geladen",
        UNKNOWN = "Noch nicht geladen",
    },
}

PKT.L = L[GetLocale()] or L["enGB"]