local function get_active_wand(player)
    local inventory =
        EntityGetFirstComponentIncludingDisabled(
            player,
            "Inventory2Component"
        )

    if inventory == nil then
        return 0
    end

    local active =
        ComponentGetValue2(
            inventory,
            "mActiveItem"
        )

    if active == nil or active == 0 then
        return 0
    end

    if not EntityHasTag(active,"wand") then
        return 0
    end

    return active
end

local function entity_tree_has_action(entity,action_id)
    local component =
        EntityGetFirstComponentIncludingDisabled(
            entity,
            "ItemActionComponent"
        )

    if component ~= nil then
        local id =
            ComponentGetValue2(
                component,
                "action_id"
            )

        if id == action_id then
            return true
        end
    end

    local children =
        EntityGetAllChildren(entity) or {}

    for _,child in ipairs(children) do
        if entity_tree_has_action(child,action_id) then
            return true
        end
    end

    return false
end

local function get_target()
    local x =
        tonumber(
            GlobalsGetValue(
                "recocards_guiding_target_x",
                ""
            )
        )

    local y =
        tonumber(
            GlobalsGetValue(
                "recocards_guiding_target_y",
                ""
            )
        )

    if x == nil or y == nil then
        return nil,nil
    end

    return x,y
end

function RQ_UpdateBirthdaySpiritRadar()
    local players =
        EntityGetWithTag(
            "player_unit"
        ) or {}

    if #players == 0 then
        return
    end

    local player = players[1]
    local wand = get_active_wand(player)

    if wand == 0 then
        return
    end

    if not entity_tree_has_action(
        wand,
        "BIRTHDAY_SPIRIT_RADAR"
    ) then
        return
    end

    local tx,ty = get_target()

    if tx == nil or ty == nil then
        return
    end

    local px,py =
        EntityGetTransform(player)

    local dx = tx-px
    local dy = ty-py
    local distance =
        math.sqrt(dx*dx+dy*dy)

    if distance < 1 then
        return
    end

    local radius = 32
    local marker_x =
        px +
        dx/distance*radius
    local marker_y =
        py +
        dy/distance*radius

    GameCreateSpriteForXFrames(
        "mods/recocards_birthday/files/gfx/birthday_spirit_radar_blip.png",
        marker_x,
        marker_y,
        true,
        0,
        0,
        2,
        true
    )
end
