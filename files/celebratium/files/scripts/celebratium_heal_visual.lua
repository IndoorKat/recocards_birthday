local entity = GetUpdatedEntityID()
if entity == nil or entity == 0 then
    return
end

local now = GameGetFrameNum()
local storage = nil
local storages =
    EntityGetComponentIncludingDisabled(
        entity,
        "VariableStorageComponent"
    ) or {}

for _,component in ipairs(storages) do
    if
        ComponentGetValue2(
            component,
            "name"
        ) == "celebratium_visual_start_frame"
    then
        storage = component
        break
    end
end

if storage == nil then
    return
end

local start_frame =
    ComponentGetValue2(
        storage,
        "value_int"
    ) or -1

if start_frame < 0 then
    ComponentSetValue2(
        storage,
        "value_int",
        now
    )
    return
end

if now > start_frame then
    local emitters =
        EntityGetComponentIncludingDisabled(
            entity,
            "SpriteParticleEmitterComponent"
        ) or {}

    for _,component in ipairs(emitters) do
        EntitySetComponentIsEnabled(
            entity,
            component,
            false
        )
    end

    local lua =
        EntityGetFirstComponentIncludingDisabled(
            entity,
            "LuaComponent"
        )

    if lua ~= nil then
        EntitySetComponentIsEnabled(
            entity,
            lua,
            false
        )
    end
end
