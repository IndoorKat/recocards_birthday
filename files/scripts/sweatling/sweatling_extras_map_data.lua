-- sweatling_extras_map_data.lua
-- Hand-authored, mod-added assets that are NOT part of the scraped dunkbin
-- catalog (emotes, the HBD sign, the border frame). Kept SEPARATE from
-- cosmetics_map_data.lua so re-scraping never clobbers them.
--
-- Same shape as the scraped map: { layers = { <layer> = { <entry>, ... } } }.
-- Entries use a STRING id (asset name) and an explicit `path` relative to the
-- mod root, because these assets live outside gfx/cosmetics/<layer>/<id>.xml
-- (e.g. emotes are under gfx/sweatling/). The mapper honors `path` when set.

local GFX = "mods/recocards_birthday/files/gfx/"

return {
  version = 1,
  layers = {
    -- Base face emotes (character layer). Under gfx/sweatling/.
    sweatling = {
      { id = "emote_angry", name = "Angry", layer = "sweatling", path = GFX .. "sweatling/emote_angry.xml" },
      { id = "emote_cry",   name = "Cry",   layer = "sweatling", path = GFX .. "sweatling/emote_cry.xml" },
      { id = "emote_happy", name = "Happy", layer = "sweatling", path = GFX .. "sweatling/emote_happy.xml" },
      { id = "emote_love",  name = "Love",  layer = "sweatling", path = GFX .. "sweatling/emote_love.xml" },
      { id = "emote_shock", name = "Shock", layer = "sweatling", path = GFX .. "sweatling/emote_shock.xml" },
      { id = "emote_smile", name = "Smile", layer = "sweatling", path = GFX .. "sweatling/emote_smile.xml" },
      { id = "emote_wink",  name = "Wink",  layer = "sweatling", path = GFX .. "sweatling/emote_wink.xml" },
    },
    -- Raised sign (the "hand" slot). Under gfx/cosmetics/hand/.
    hand = {
      { id = "hbd", name = "Happy Birthday Sign", layer = "hand", path = GFX .. "cosmetics/hand/hbd.xml" },
    },
    -- Decorative frames. Under gfx/cosmetics/border/. Variant-specific:
    -- giftling (interactable) and moist_mob (mob/gifter) borders.
    border = {
      { id = "border", name = "Border", layer = "border", path = GFX .. "cosmetics/border/border.xml" },
      { id = "border_giftling", name = "Giftling Border", layer = "border", path = GFX .. "cosmetics/border/border_giftling.xml" },
      { id = "border_moist_mob", name = "Moist Mob Border", layer = "border", path = GFX .. "cosmetics/border/border_moist_mob.xml" },
    },
  },
}
