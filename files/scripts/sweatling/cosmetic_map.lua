-- cosmetic_map.lua
-- Runtime mapper over the scraped cosmetic catalog (cosmetics_map_data.lua).
-- Resolves cosmetics by id / name / random-by-layer, and returns the converted
-- sprite path under gfx/cosmetics/<layer>/<id>.xml (consumer-agnostic: caller
-- gets the relative path; here we include the full mod gfx prefix).
--
-- Usage:
--   local cmap = dofile_once("mods/recocards_birthday/files/scripts/sweatling/cosmetic_map.lua")
--   local e = cmap.by_id(1)                 -> entry {id,name,layer,md5} or nil
--   local e = cmap.by_name("All Might Hair")-> entry or nil
--   local list = cmap.list("hat")           -> array of entries
--   local e = cmap.random("hat")            -> random entry (equal weight)
--   local head = cmap.random_head()         -> 2-tier: {full_head=e} OR {hat=e, face=e}
--   local path = cmap.path(entry)           -> "mods/.../gfx/cosmetics/hat/1.xml"

local SCRAPED = dofile_once("mods/recocards_birthday/files/scripts/sweatling/cosmetics_map_data.lua")
local MOD = dofile_once("mods/recocards_birthday/files/scripts/sweatling/sweatling_extras_map_data.lua")
local GFX_COSMETICS = "mods/recocards_birthday/files/gfx/cosmetics/"

-- Merge scraped + mod-added layers into one layer table. Scraped data is the
-- dunkbin catalog (never hand-edited); sweatling_extras adds our own layers
-- (sweatling emotes, hand sign, border). Both share the same entry schema.
local LAYERS = {}
local function merge_layers(src)
    for layer, entries in pairs((src or {}).layers or {}) do
        local dst = LAYERS[layer] or {}
        for _, e in ipairs(entries) do dst[#dst + 1] = e end
        LAYERS[layer] = dst
    end
end
merge_layers(SCRAPED)
merge_layers(MOD)

-- Build id/name indices once (keys are per-layer-unique; ids may be int or str).
local by_id_idx, by_name_idx = {}, {}
for _, entries in pairs(LAYERS) do
    for _, e in ipairs(entries) do
        by_id_idx[e.id] = e
        by_name_idx[string.lower(e.name)] = e  -- first exact (case-insensitive)
    end
end

local M = {}

function M.by_id(id)
    if id == nil then return nil end
    return by_id_idx[tonumber(id)]
end

function M.by_name(name)
    if name == nil then return nil end
    return by_name_idx[string.lower(name)]
end

function M.list(layer)
    return LAYERS[layer] or {}
end

-- Equal-weighted random entry for a layer (nil if the layer is empty).
function M.random(layer)
    local list = M.list(layer)
    if #list == 0 then return nil end
    return list[Random(1, #list)]
end

-- 2-tier head roll: pick full_head XOR (hat + face). Returns a table with the
-- chosen slots so the caller can render whichever the roll produced.
-- The exclusivity rule lives HERE, not in the data.
function M.random_head()
    -- 50/50 between a full head and a hat+face combo (tune as desired).
    if Random(1, 2) == 1 then
        return { full_head = M.random("full_head") }
    else
        return { hat = M.random("hat"), face = M.random("face") }
    end
end

-- Resolve an entry to its sprite xml path. Honors an explicit `path` (mod
-- assets), else falls back to the scraped convention gfx/cosmetics/<layer>/<id>.
function M.path(entry)
    if entry == nil then return nil end
    if entry.path ~= nil then return entry.path end
    return GFX_COSMETICS .. entry.layer .. "/" .. tostring(entry.id) .. ".xml"
end

-- Convenience: path from a layer + id. Looks up the entry first so mod-asset
-- `path` overrides are honored; falls back to the scraped convention.
function M.path_for(layer, id)
    if layer == nil or id == nil then return nil end
    local e = by_id_idx[id]
    if e ~= nil and e.layer == layer then
        return M.path(e)
    end
    return GFX_COSMETICS .. layer .. "/" .. tostring(id) .. ".xml"
end

return M
