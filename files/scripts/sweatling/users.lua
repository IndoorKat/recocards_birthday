-- users.lua
-- Per-user cosmetic loadout map. Looks up which cosmetics a given twitch user
-- wears on each layer, by twitch_id (or login).
--
-- Cosmetic values are dunkbin cosmetic IDs (see gfx/cosmetics/<layer>/<id>).
-- Head is EITHER full_head OR (hat + face); the unused slot(s) are nil.
-- A nil layer means "no cosmetic on that layer".
--
-- This is a PLACEHOLDER built from our two example loadouts. A real export
-- from another dev will replace the entries (same schema).
--
-- Usage:
--   local users = dofile_once("mods/recocards_birthday/files/scripts/sweatling/users.lua")
--   local u = users.by_twitch_id("241636")   -- or users.by_login("dunkorslam")
--   -- u.body, u.full_head, u.hat, u.face, u.neck  (ids or nil)

local USERS = {
    {
        twitch_id = "22191281",
        login     = "shortman422",
        -- full-head loadout (no hat/face)
        body      = 1702,
        full_head = 1646,
        hat       = nil,
        face      = nil,
        neck      = 1647,
    },
    {
        twitch_id = "241636",
        login     = "dunkorslam",
        -- hat + face loadout (no full_head)
        body      = 1498,
        full_head = nil,
        hat       = 997,
        face      = 293,
        neck      = 998,
    },
    {
        twitch_id = "44749427",
        login     = "teh60",
        -- hat + face loadout (no full_head)
        body      = 1498,
        full_head = nil,
        hat       = 997,
        face      = 293,
        neck      = 998,
    },
}

-- Build lookup indices once.
local by_id, by_login = {}, {}
for _, u in ipairs(USERS) do
    by_id[u.twitch_id] = u
    by_login[string.lower(u.login)] = u
end

local M = {}

function M.by_twitch_id(twitch_id)
    return by_id[tostring(twitch_id)]
end

function M.by_login(login)
    if login == nil then return nil end
    return by_login[string.lower(login)]
end

-- Full list, if a caller wants to iterate all users.
function M.all()
    return USERS
end

return M
