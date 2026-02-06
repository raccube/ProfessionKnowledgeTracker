local ADDON_NAME, PKT = ...

local L = {
    enGB = {
        TAB = {
            NAME = "Knowledge Sources",
            TOOLTIP = "Profession Knowledge Tracker\nby Raccube",
        },
        CATEGORY = {
            Available = "Available",
            Completed = "Completed",
            Unavailable = "Unavailable",
        },
        WAYPOINT_BUTTON_INACTIVE_TEXT = "Track",
        WAYPOINT_BUTTON_ACTIVE_TEXT = "Unrack",
        REQUIRES_QUEST = "Finish %s to unlock.",
        REQUIRES_MULTIPLE_QUESTS = "Finish the following quests to unlock:",
        DESCRIPTION = {
            CATCH_UP = "Catch-up mechanic.\n",
            CATCH_UP_GATHERING = {
                [Enum.Profession.Enchanting] = "Looted through disenchanting items, after looting Gleaming Telluric Crystal",
                [Enum.Profession.Herbalism] = "Looted through collecting herbs, after looting Deepgrove Rose",
                [Enum.Profession.Mining] = "Looted through mining nodes, after looting Erosion-Polished Slate",
                [Enum.Profession.Skinning] = "Looted through skinning mobs, after looting Abyssal Fur",
            },
            CATCH_UP_WORK_ORDER = "%s ~24 hours %s ~84 hours",
            SMALL_GATHERING_YIELD = {
                [Enum.Profession.Enchanting] = "Randomly looted while disenchanting",
                [Enum.Profession.Herbalism] = "Randomly looted while gathering herbs",
                [Enum.Profession.Mining] = "Randomly looted while mining",
                [Enum.Profession.Skinning] = "Randomly looted while skinning",
            },
            LARGE_GATHERING_YIELD = {
                [Enum.Profession.Enchanting] = "Looted from disenchanting, after looting 5 Fleeting Arcane Manifestation",
                [Enum.Profession.Herbalism] = "Looted through herbs, after gathering 5 petals",
                [Enum.Profession.Mining] = "Looted through mining, after 5 Slabs of Slate",
                [Enum.Profession.Skinning] = "Looted through skinning, after 5 pelts",
            },
            TREASURES = "%s Found in treasures around Khaz Algar",
            TREATISE = "Obtained through Inscription work orders",
            TRAINER_QUEST = "Obtained through a quest from your profession trainer",
            KP_COUNT = "Completing this will award you %d %s.",
        },
        COUNTERS = {
            UNIQUE = "Unique: %d",
            WEEKLY = "This Week: %d",
            CATCH_UP = "Catch-Up: %d",
        },
        UNKNOWN_ITEM = "Item not loaded",
        UNKNOWN = "Not loaded yet",
        REQUIREMENTS = "Requirements:",
        WEEKLY_CATCH_UP = "Available Weekly Catch-Up Knowledge Points",
    },
    deDE = {
        TAB = {
            NAME = "Wissensquellen",
            TOOLTIP = "Berufswissensquellen Tracker\nvon Raccube"
        },
        CATEGORY = {
            Available = "Verfügbar",
            Completed = "Erledigt",
            Unavailable = "Nicht verfügbar",
        },
        WAYPOINT_BUTTON_INACTIVE_TEXT = "Beobachten",
        WAYPOINT_BUTTON_ACTIVE_TEXT = "Nicht mehr folgen",
        REQUIRES_QUEST = "Schließe die Quest %s ab.",
        REQUIRES_MULTIPLE_QUESTS = "Schließe die folgenden Quests ab, um Folgendes freizuschalten:\n%s",
        DESCRIPTION = {
            CATCH_UP = "Aufholmechanismus\n",
            CATCH_UP_GATHERING = {
                [Enum.Profession.Enchanting] = "Durch Entzauberung von Gegenständen geplündert, nach Plünderung von Strahlender tellurischer Kristall",
                [Enum.Profession.Herbalism] = "Durch das Sammeln von Kräutern geplündert, nach dem Plündern von Tiefenhainrose",
                [Enum.Profession.Mining] = "Durch Bergbauknoten geplündert, nach dem Plündern von Erosionspolierte Steintafel",
                [Enum.Profession.Skinning] = "Durch das Häuten von Mobs erbeutet, nach dem Plündern von Abyssischer Pelz",
            },
            SMALL_GATHERING_YIELD = {
                [Enum.Profession.Enchanting] = "Wird beim Entzaubern zufällig geplündert",
                [Enum.Profession.Herbalism] = "Wird beim Sammeln von Kräutern zufällig geplündert",
                [Enum.Profession.Mining] = "Wird beim Bergbau zufällig geplündert",
                [Enum.Profession.Skinning] = "Wird beim Häuten zufällig geplündert",
            },
            LARGE_GATHERING_YIELD = {
                [Enum.Profession.Enchanting] = "Beute aus Entzauberung, nach Plünderung von 5 flüchtigen arkanen Manifestationen",
                [Enum.Profession.Herbalism] = "Beute aus Kräutern, nach Sammeln von 5 Blütenblättern",
                [Enum.Profession.Mining] = "Beute aus Bergbau, nach 5 Schieferplatten",
                [Enum.Profession.Skinning] = "Beute aus Häuten, nach 5 Fellen",
            },
            CATCH_UP_WORK_ORDER = "%s ~24 Std. %s ~84 Std.",
            TREASURES = "%s Gefunden auf Schätzen rund um Khaz Algar",
            TREATISE = "Erhalten durch Inschriftenkunde-Handwerksaufträge",
            TRAINER_QUEST = "Erhalten durch eine Quest von deinem Berufsausbilder",
            KP_COUNT = "Wenn Sie dies abschließen, erhalten Sie %d %s.",
        },
        COUNTERS = {
            UNIQUE = "Einzigartig: %d",
            WEEKLY = "Diese Woche: %d",
            CATCH_UP = "Aufholung: %d",
        },
        UNKNOWN_ITEM = "Gegenstand nicht geladen",
        UNKNOWN = "Noch nicht geladen",
        REQUIREMENTS = "Anforderungen:",
        WEEKLY_CATCH_UP = "Verfügbare wöchentliche Nachholungs-Wissenspunkte",
    },
}

PKT.L = L[GetLocale()] or L["enGB"]