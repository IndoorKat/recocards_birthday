dofile_once("data/scripts/gun/procedural/gun_action_utils.lua")
dofile_once("data/scripts/lib/utilities.lua")

local TRANSLATIONS = "mods/recocards_birthday/files/glimmer_birthday/translations.csv"

function BirthdayGlimmer_OnModInit()
    local new_translations = ModTextFileGetContent(TRANSLATIONS)
    local translations = ModTextFileGetContent("data/translations/common.csv")
    translations = translations .. new_translations
    translations = translations:gsub("\r", ""):gsub("\n\n+", "\n")
    ModTextFileSetContent("data/translations/common.csv", translations)
end

function BirthdayGlimmer_OnPlayerSpawned(player_id)
    if GameHasFlagRun("bday_spawn_always_cast") then return end
    local inventory = EntityGetWithName("inventory_quick")
    local wands = nil
    if inventory ~= nil and inventory ~= 0 then
        wands = EntityGetAllChildren(inventory, "wand")
    end
    if wands then
        for _, wand in ipairs(wands) do
            AddGunActionPermanent(wand, "BDAYGLIMMER_COLOUR_BDAY")
        end
    end
    GamePickUpInventoryItem(player_id, CreateItemActionEntity("BDAYGLIMMER_COLOUR_BDAY", 0, 0))
    GameAddFlagRun("bday_spawn_always_cast")
end
