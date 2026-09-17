dofile_once("mods/recocards_birthday/files/scripts/birthday_spirit_drop_helper.lua")

local e = GetUpdatedEntityID()
if e == nil or e == 0 or not EntityGetIsAlive(e) then return end

local damage = EntityGetFirstComponentIncludingDisabled(e,"DamageModelComponent")
if damage == nil then return end

local hp = ComponentGetValue2(damage,"hp")
if hp ~= nil and hp <= 0 then
    RQ_DropBirthdayPageFromSpirit(e)
    EntityKill(e)
end
