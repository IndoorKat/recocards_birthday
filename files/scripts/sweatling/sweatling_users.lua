-- sweatling_users.lua
-- Per-author cosmetic loadout map. Looks up which cosmetics a given recocards
-- card author wears on each layer, keyed by the recocards **author** string.
--
-- This mirrors the POC's sweatlingTest/files/scripts/users.lua schema, but keys
-- by the recocards author string (not a twitch id/login), since recocards
-- identifies cards by author.
--
-- Cosmetic values are dunkbin cosmetic IDs (see gfx/cosmetics/<layer>/<id>).
-- Head is EITHER full_head OR (hat + face); the unused slot(s) are nil.
-- A nil layer means "no cosmetic on that layer".
--
-- This is a PLACEHOLDER built from our two example loadouts. A real export from
-- another dev will replace the entries (same schema, author-keyed).
--
-- Usage:
--   local users = dofile_once("mods/recocards_birthday/files/scripts/sweatling/sweatling_users.lua")
--   local u = users.by_author("dunkorslam")
--   -- u.body, u.full_head, u.hat, u.face, u.neck  (ids or nil)

local USERS = {
    {
        author    = "shortman422",
        -- full-head loadout (no hat/face)
        body      = 1702,
        full_head = 1646,
        hat       = nil,
        face      = nil,
        neck      = 1647,
    },
    {
        -- Test author present in the card list; same cosmetics as shortman422
        -- so the author-mapped path can be exercised in-game.
        author    = "teh60",
        body      = 1702,
        full_head = 1646,
        hat       = nil,
        face      = nil,
        neck      = 1647,
    },
    {
        author    = "dunkorslam",
        -- hat + face loadout (no full_head)
        body      = 1498,
        full_head = nil,
        hat       = 997,
        face      = 293,
        neck      = 998,
    },
}

-- Build lookup index once (case-insensitive on the author string).
local by_author = {}
for _, u in ipairs(USERS) do
    by_author[string.lower(u.author)] = u
end

local M = {}

-- Look up a loadout by recocards author string. Returns the loadout table or nil.
function M.by_author(author)
    if author == nil then return nil end
    return by_author[string.lower(author)]
end

-- Full list, if a caller wants to iterate all configured authors.
function M.all()
    return USERS
end

return M
