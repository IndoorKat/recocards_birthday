-- streaming_hook.lua  (Moist Mobbing POC: raw chat capture + sub/gift trigger)
--
-- Appended onto Noita's data/scripts/streaming_integration/event_utilities.lua
-- via ModLuaFileAppend (see init.lua). The engine calls the GLOBAL
-- _streaming_on_irc callback for every PRIVMSG. We chain any previous
-- definition so we co-exist with other mods.
--
-- This context has NO `io`, so we log via the Globals-queue logger
-- (debug_log.lua), which init.lua drains to files each frame. Two channels:
--   * "debug"    -> full RAW frame + decoded sender/message (debug.log)
--   * "triggers" -> only messages that fire Moist Mobbing, simplified
--                   (triggers.log)
--
-- TWO detections, both CONFIG-DRIVEN (moist_mob_config.lua):
--   1. SUB/GIFT (opens the mob pulse window): a message from the configured
--      chat bot that contains any trigger phrase. We don't care about sub
--      COUNT or TYPE -- every sub/gift is equal. We DO extract the celebrant
--      NAME (subscriber or gifter) from the bot text to name the gifter
--      sweatling; if the pattern misses we fall back and still trigger.
--   2. MOB PULSE member: any chatter whose message contains a mob phrase
--      (dnkM). The mob sweatlings are NAMELESS, so we don't need the display
--      name -- we pull the stable numeric `user-id` from the raw IRC tags and
--      queue THAT, so the spawner resolves cosmetics via users.by_twitch_id
--      (no login lookup, no non-ASCII display-name handling).

dofile_once("mods/recocards_birthday/files/scripts/sweatling/debug_log.lua")
local CFG = dofile_once("mods/recocards_birthday/files/scripts/sweatling/moist_mob_config.lua")

local previous_streaming_on_irc = _streaming_on_irc

-- Master Moist Mobbing toggle (settings.lua, ON by default). When OFF we don't
-- enqueue anything here, so nothing accumulates in the Globals queues while the
-- effect is disabled. Guarded for the sandboxed context (nil ModSettingGet ->
-- treat as enabled, matching value_default = true).
local function moist_mobbing_enabled()
    if ModSettingGet == nil then return true end
    return ModSettingGet("recocards_birthday.moist_mobbing_enabled") ~= false
end

-- Is this message from the configured bot? The bot's login is always ASCII, so
-- the decoded `sender` matches bot_name directly (case-insensitive). An EMPTY
-- bot_name (DEBUG profile) matches ANY sender, so you can self-type test
-- sub/gift messages without being the bot.
local function is_configured_bot(sender)
    if CFG.bot_name == "" then return true end
    return type(sender) == "string"
        and type(CFG.bot_name) == "string"
        and string.lower(sender) == string.lower(CFG.bot_name)
end

-- Find the FIRST trigger entry whose plain-substring `phrase` is in `message`.
-- Returns the entry (so we can use its `name` pattern), or nil.
local function matched_trigger(message)
    if type(message) ~= "string" then return nil end
    for _, entry in ipairs(CFG.triggers or {}) do
        if entry.phrase and string.find(message, entry.phrase, 1, true) then
            return entry
        end
    end
    return nil
end

-- Extract the celebrant name for a matched entry, or the configured fallback.
-- `entry.name` is a Lua pattern with one capture (subscriber or gifter). If it's
-- absent or doesn't match (e.g. a non-ASCII name the engine dropped), we return
-- the fallback so the effect still fires with a sensible name.
local function celebrant_name(entry, message)
    if entry.name and type(message) == "string" then
        local captured = string.match(message, entry.name)
        if captured and captured ~= "" then
            return captured
        end
    end
    return CFG.fallback_name or "someone"
end

-- On a sub/gift trigger: log it, and ENQUEUE a Moist Mobbing effect request for
-- init.lua to execute. We can't spawn entities safely from this sandboxed
-- callback context (no reliable world/player access here), so we cross the
-- context boundary via a Globals queue -- the same pattern the logger uses. Each
-- request is one record; init.lua drains them in OnWorldPreUpdate (main context)
-- and does the actual spawn at the player position.
local SUBGIFT_QUEUE_KEY = "recocards_birthday_moist_mob_queue"    -- sub/gift events
local CHATTER_QUEUE_KEY = "recocards_birthday_moist_chatter_queue" -- dnkM chatter ids
local RECORD_SEP = "\30"

local function enqueue_subgift(celebrant)
    local existing = GlobalsGetValue(SUBGIFT_QUEUE_KEY, "")
    GlobalsSetValue(SUBGIFT_QUEUE_KEY, existing .. tostring(celebrant) .. RECORD_SEP)
end

local function enqueue_chatter(twitch_id)
    local existing = GlobalsGetValue(CHATTER_QUEUE_KEY, "")
    GlobalsSetValue(CHATTER_QUEUE_KEY, existing .. tostring(twitch_id) .. RECORD_SEP)
end

local function trigger_moist_mobbing(celebrant, message)
    LOG("triggers", "celebrant=" .. tostring(celebrant) ..
        " | " .. tostring(message))
    enqueue_subgift(celebrant)
end

-- Does a chat message contain a mob keyword? Plain substring.
local function has_mob_phrase(message)
    if type(message) ~= "string" then return false end
    for _, phrase in ipairs(CFG.mob_phrases or {}) do
        if string.find(message, phrase, 1, true) then return true end
    end
    return false
end

-- Pull the sender's stable numeric twitch id from the raw IRC tags
-- (`user-id=<digits>`). Always ASCII, so it survives decoding intact -- unlike a
-- display name. Returns the id string, or nil if the tag is absent (e.g. JOINs).
local function twitch_id_from_raw(raw)
    if type(raw) ~= "string" then return nil end
    return string.match(raw, "user%-id=(%d+)")
end

LOG("debug", "streaming hook loaded (bot=" .. tostring(CFG.bot_name) .. ")")

function _streaming_on_irc(is_userstate, sender_username, message, raw)
    if not is_userstate and moist_mobbing_enabled() then
        -- Full capture to the debug channel: decoded sender/message + raw frame.
        LOG("debug", "chat from=" .. tostring(sender_username) ..
            " | msg=" .. tostring(message))
        LOG("debug", "  raw=" .. tostring(raw))

        -- Sub/gift and mob-keyword are INDEPENDENT checks, not either/or. In
        -- DEBUG mode bot_name = "" makes is_configured_bot() true for everyone,
        -- so an if/elseif would let the (always-true) bot branch swallow every
        -- message and the mob branch would never run. Evaluate both.
        if is_configured_bot(sender_username) then
            -- Bot sub/gift announcement -> open window + gifter/emitters.
            local entry = matched_trigger(message)
            if entry ~= nil then
                trigger_moist_mobbing(celebrant_name(entry, message), message)
            end
        end

        if has_mob_phrase(message) then
            -- Any chatter using dnkM/dnkMM -> queue a nameless mob sweatling,
            -- keyed by their numeric twitch id (for cosmetics). init.lua gates
            -- this on the window (ignored if no recent sub/gift).
            enqueue_chatter(twitch_id_from_raw(raw))
        end
    end

    if previous_streaming_on_irc ~= nil then
        return previous_streaming_on_irc(is_userstate, sender_username, message, raw)
    end
end
