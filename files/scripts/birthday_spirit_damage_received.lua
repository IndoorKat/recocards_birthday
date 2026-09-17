dofile_once("mods/recocards_birthday/files/scripts/birthday_spirit_drop_helper.lua")

function damage_received(damage,message,entity_thats_responsible,is_fatal)
    if not is_fatal then return end

    local e = GetUpdatedEntityID()
    if e == nil or e == 0 then return end

    RQ_DropBirthdayPageFromSpirit(e)
end
