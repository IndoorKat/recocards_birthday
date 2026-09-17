local MOD_ID = "recocards_birthday/files/celebratium"
local MATERIAL = "celebratium_confetti"
local SENSOR_NAME = "celebratium_heal_sensor"

ModMaterialsFileAdd("mods/" .. MOD_ID .. "/files/materials.xml")
ModLuaFileAppend("data/scripts/items/potion.lua", "mods/recocards_birthday/files/celebratium/files/scripts/celebratium_potion_pool.lua")

local translations = ModTextFileGetContent("data/translations/common.csv")
translations = translations .. "\nmat_celebratium,Celebratium,,,,,,,,,,,,,\n"
translations = translations .. "mat_celebratium_spent,Celebratium Confetti (Spent),,,,,,,,,,,,,\n"
translations = translations:gsub("\r", "")
translations = translations:gsub("\n+", "\n")
ModTextFileSetContent("data/translations/common.csv", translations)


local function add_heal_sensor(player)
    local children = EntityGetAllChildren(player) or {}
    for _, child in ipairs(children) do
        if EntityGetName(child) == SENSOR_NAME then
            return
        end
    end

    local sensor = EntityCreateNew(SENSOR_NAME)
    EntityAddTag(sensor, "celebratium_sensor")
    EntityAddComponent2(sensor, "InheritTransformComponent", {})

    local checker = EntityAddComponent2(sensor, "MaterialAreaCheckerComponent", {
        update_every_x_frame = 1,
        look_for_failure = false,
        count_min = 1,
        always_check_fullness = true,
        kill_after_message = false,
    })
    ComponentSetValue2(checker, "material", CellFactory_GetType(MATERIAL))
    ComponentSetValue2(checker, "area_aabb", -5, -12, 5, 4)

    EntityAddComponent2(sensor, "LuaComponent", {
        execute_every_n_frame = -1,
        script_material_area_checker_success = "mods/recocards_birthday/files/celebratium/files/scripts/celebratium_heal_sensor.lua",
    })

    EntityAddChild(player, sensor)
end

function Celebratium_OnPlayerSpawned(player)
    add_heal_sensor(player)
end
