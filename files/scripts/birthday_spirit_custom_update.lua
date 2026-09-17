local e = GetUpdatedEntityID()
if e == nil or e == 0 or not EntityGetIsAlive(e) then return end

local players = EntityGetWithTag("player_unit") or {}
if #players == 0 then return end

local player = players[1]
local x,y = EntityGetTransform(e)
local px,py = EntityGetTransform(player)

local dx = px-x

local sprites =
    EntityGetComponentIncludingDisabled(
        e,
        "SpriteComponent"
    ) or {}

for _,sprite in ipairs(sprites) do
    local image =
        ComponentGetValue2(
            sprite,
            "image_file"
        ) or ""

    if string.find(image,"playerghost.xml",1,true) ~= nil then
        ComponentSetValue2(
            sprite,
            "has_special_scale",
            true
        )

        ComponentSetValue2(
            sprite,
            "special_scale_x",
            dx < 0 and -1 or 1
        )
    end
end

if GameGetFrameNum() % 20 == 0 then
    local safe_done = false
    local vars =
        EntityGetComponentIncludingDisabled(
            e,
            "VariableStorageComponent"
        ) or {}

    for _,var in ipairs(vars) do
        if
            ComponentGetValue2(var,"name") ==
            "recocards_safe_position_done"
        then
            safe_done =
                ComponentGetValue2(var,"value_int") == 1
            break
        end
    end

    if not safe_done then
        local free_x,free_y =
            FindFreePositionForBody(
                x,
                y,
                0,
                0,
                8
            )

        if free_x ~= nil and free_y ~= nil then
            local moved_x = math.abs(free_x-x)
            local moved_y = math.abs(free_y-y)

            if moved_x > 2 or moved_y > 2 then
                EntitySetTransform(
                    e,
                    free_x,
                    free_y,
                    0
                )
            end
        end
    end
end
