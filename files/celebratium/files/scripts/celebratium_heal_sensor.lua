local EFFECT = "mods/recocards_birthday/files/celebratium/files/entities/celebratium_regen_pulse.xml"
local CONSUMER = "mods/recocards_birthday/files/celebratium/files/entities/celebratium_consumer.xml"
local COOLDOWN_FRAMES = 8
local HEAL_AMOUNT = 0.01

local function get_storage(entity, name)
    local comps = EntityGetComponentIncludingDisabled(entity, "VariableStorageComponent") or {}
    for _, comp in ipairs(comps) do
        if ComponentGetValue2(comp, "name") == name then
            return comp
        end
    end
    return nil
end

function material_area_checker_success(pos_x, pos_y)
    local sensor = GetUpdatedEntityID()
    if sensor == nil or sensor == 0 then return end

    local player = EntityGetParent(sensor)
    if player == nil or player == 0 then return end

    local now = GameGetFrameNum()
    local storage = get_storage(sensor, "celebratium_next_regen_frame")
    if storage ~= nil then
        local next_frame = ComponentGetValue2(storage, "value_int") or 0
        if now < next_frame then
            return
        end
        ComponentSetValue2(storage, "value_int", now + COOLDOWN_FRAMES)
    end

    EntityLoad(CONSUMER, pos_x, pos_y)

    local damage =
        EntityGetFirstComponentIncludingDisabled(
            player,
            "DamageModelComponent"
        )

    if damage ~= nil then
        local hp =
            ComponentGetValue2(
                damage,
                "hp"
            )

        local max_hp =
            ComponentGetValue2(
                damage,
                "max_hp"
            )

        ComponentSetValue2(
            damage,
            "hp",
            math.min(
                max_hp,
                hp + HEAL_AMOUNT
            )
        )
    end

    local visual =
        EntityLoad(
            EFFECT,
            0,
            0
        )

    if visual ~= nil and visual ~= 0 then
        EntityAddChild(
            player,
            visual
        )
    end

    local x,y =
        EntityGetTransform(
            player
        )

    GamePlaySound(
        "data/audio/Desktop/misc.bank",
        "game_effect/regeneration/create",
        x,
        y
    )
end
