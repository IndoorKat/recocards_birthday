dofile_once("mods/recocards_birthday/files/scripts/birthday_spirit_drop_helper.lua")

local e = GetUpdatedEntityID()
if e == nil or e == 0 then return end

RQ_DropBirthdayPageFromSpirit(e)
