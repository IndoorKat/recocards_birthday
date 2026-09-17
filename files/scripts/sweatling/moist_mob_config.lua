-- moist_mob_config.lua
-- Settings for Moist Mobbing sub/gift detection. Always needed -- this is the
-- single source of truth the streaming hook and spawner read at load.
--
-- DEBUG vs LIVE: the "Debug Moist Mobbing" mod setting
-- (recocards_birthday.debug_moist_mobbing) picks between two detection profiles that
-- differ ONLY in `bot_name` + `triggers` (everything else is shared):
--   * DEBUG: bot_name = "" (match ANY sender, so you can self-type test
--     messages) and simple "sub"/"gift" triggers. Also auto-plays the recorded
--     dnkM burst (simulate_chat_moist_mob) so a lone tester sees a full mob.
--   * LIVE:  bot_name = "WizeBot" and the real WizeBot announcement patterns.
-- The consuming check (is_configured_bot in streaming_hook.lua) treats an empty
-- bot_name as "match any sender".
--
-- DETECTION MODEL: a chat message triggers Moist Mobbing when
--   (a) it is sent by `bot_name` (case-insensitive; "" matches ANY sender), AND
--   (b) its text contains ANY trigger entry's `phrase` (plain substring).
-- We do NOT distinguish sub vs resub vs gift -- every sub/gift is celebrated
-- equally. We DO want the celebrant's NAME: the SUBSCRIBER (self/re-sub) or the
-- GIFTER (gift) -- never the gift recipient.
--
-- NAME EXTRACTION: each trigger entry may carry a `name` = a Lua PATTERN with
-- ONE capture that pulls the celebrant out of the bot's message text. For the
-- FIRST entry whose `phrase` matches, its `name` pattern (if set) is applied.
-- If `name` is nil or fails to match, we STILL trigger, using `fallback_name`.
--
-- ASCII CAVEAT (observed in-game): the engine decodes chat to ASCII 1-255, so
-- decorative unicode (arrows, gift/person emoji) arrives MANGLED and non-ASCII
-- characters are dropped. Anchor phrases/patterns ONLY on pure-ASCII text (e.g.
-- "RE-SUB", "NEW SUB", "subscriptions to the community"). A subscriber/gifter
-- with a NON-ASCII display name may not be extractable from the message; that's
-- fine -- we fall back to `fallback_name` and still celebrate.

-- Is the "Debug Moist Mobbing" mod setting on? Guarded for sandboxed contexts
-- that lack ModSettingGet (defaults to LIVE if it can't be read).
local function debug_moist_mobbing()
    if ModSettingGet == nil then return false end
    return ModSettingGet("recocards_birthday.debug_moist_mobbing") == true
end

local debug_enabled = debug_moist_mobbing()

-- DEBUG profile: any sender ("" bot_name) + self-typable "sub"/"gift" triggers.
-- The `name` pattern grabs a word after a colon (e.g. "test sub: alice"); when
-- it doesn't match we fall back to `fallback_name`.
local debug_profile = {
    bot_name = "",
    triggers = {
        { phrase = "sub",  name = ": ([%w_]+)" },
        { phrase = "gift", name = ": ([%w_]+)" },
    },
}

-- LIVE profile: the real WizeBot on dunkorslam. Patterns anchor on the ASCII
-- text that survives (the engine strips WizeBot's decorative arrows/emoji).
-- Verified in-game WizeBot resub format: " RE-SUB  <subscriber> (+N) ".
local live_profile = {
    bot_name = "WizeBot",
    triggers = {
        -- resub: subscriber sits between "RE-SUB" and " (+N)".
        { phrase = "RE-SUB",  name = "RE%-SUB%s+([%w_]+)%s*%(%+" },
        -- new (gifted) sub: celebrate the GIFTER after "Offered by".
        { phrase = "NEW SUB", name = "Offered by%s+([%w_]+)" },
        -- community bulk gift: celebrate the GIFTER before "just offered".
        { phrase = "subscriptions to the community",
          name = "([%w_]+)%s+just offered" },
    },
}

local profile = debug_enabled and debug_profile or live_profile

return {
    -- Profile-driven (DEBUG vs LIVE): see above.
    bot_name = profile.bot_name,
    triggers = profile.triggers,

    -- Shared across both profiles.
    fallback_name = "someone",

    -- MOB keyword: any chatter (NOT just the bot) whose message contains any of
    -- these plain substrings joins the mob pulse -- a nameless sweatling spawns
    -- in the ring around the gifter -- but ONLY while the sub/gift window is
    -- open. Matched case-sensitively.
    mob_phrases = { "dnkMM", "dnkM" },

    -- Lifetimes (frames) set on each spawn's LifetimeComponent. Single source of
    -- truth: the entity XML has a placeholder that we overwrite at spawn.
    --   mob: a ring sweatling; also the ring-LOCK duration (a ring locks when
    --        its last slot fills and unlocks this many frames later).
    --   gifter: the central sweatling; persists the whole 30s window.
    mob_lifetime_frames    = 3 * 60,     -- 3s
    gifter_lifetime_frames = 30 * 60,    -- 30s (matches the window)

    -- When true, a sub/gift also auto-plays the recorded dnkM burst
    -- (moist_mob_test_data.lua) into the mob, so a lone tester sees a full pulse
    -- without a live chat. Tied to debug mode -- never replays on a live channel.
    simulate_chat_moist_mob = debug_enabled,
}
