dofile_once("mods/recocards_birthday/files/scripts/util.lua")

local function get_string_var(entity,name)
    local vars = EntityGetComponent(entity,"VariableStorageComponent") or {}
    for _,c in ipairs(vars) do
        if ComponentGetValue2(c,"name") == name then
            return ComponentGetValue2(c,"value_string")
        end
    end
    return nil
end

local function get_drop_var(entity)
    local vars = EntityGetComponent(entity,"VariableStorageComponent") or {}
    for _,c in ipairs(vars) do
        if ComponentGetValue2(c,"name") == "recocards_drop_done" then
            return c
        end
    end
    return nil
end

function RQ_DropBirthdayPageFromSpirit(spirit)
    if spirit == nil or spirit == 0 then return false end

    local drop_var = get_drop_var(spirit)
    if drop_var ~= nil and ComponentGetValue2(drop_var,"value_int") == 1 then
        return false
    end

    if drop_var == nil then
        drop_var = EntityAddComponent2(spirit,"VariableStorageComponent",{
            name="recocards_drop_done",
            value_int=0
        })
    end

    local id = get_string_var(spirit,"recocard_id")
    local author = get_string_var(spirit,"recocard_author") or "Birthday Spirit"

    if id == nil or id == "" then return false end
    if GameHasFlagRun(RQ_FoundFlag(id)) then return false end

    local x,y = EntityGetTransform(spirit)

    local berserk = EntityLoad("data/entities/particles/berserk.xml",x,y)
    if berserk ~= nil and berserk ~= 0 then
        EntityAddComponent2(berserk,"LifetimeComponent",{ lifetime=180 })
    end

    local page = EntityLoad(
        "mods/recocards_birthday/files/entities/birthday_page_drop.xml",
        x,
        y
    )
    if page == nil or page == 0 then
        GamePrint("Birthday Quest: failed to drop page for " .. author)
        return false
    end

    ComponentSetValue2(drop_var,"value_int",1)

    EntitySetName(page,author .. "'s Birthday Page")

    EntityAddComponent2(page,"VariableStorageComponent",{
        name="recocard_id",
        value_string=id
    })
    EntityAddComponent2(page,"VariableStorageComponent",{
        name="recocard_author",
        value_string=author
    })

    local item = EntityGetFirstComponentIncludingDisabled(page,"ItemComponent")
    if item ~= nil then
        ComponentSetValue2(item,"item_name",author .. "'s Birthday Page")
        ComponentSetValue2(item,"ui_description","A page left behind by " .. author .. ".")
    end

    return true
end
