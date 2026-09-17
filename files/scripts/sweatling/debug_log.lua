-- debug_log.lua
-- Reusable, context-agnostic file logger for the Twitch work, supporting
-- MULTIPLE named channels (e.g. "debug" = full raw chat, "triggers" = only the
-- messages that fire Moist Mobbing).
--
-- PROBLEM this solves: some contexts (notably the appended _streaming_on_irc
-- callback) run sandboxed WITHOUT the unsafe `io` library, so they cannot write
-- files. But EVERY context can read/write Noita Globals, and Globals are shared
-- across contexts. So:
--   * ANY context calls LOG(channel, msg) -> appends to that channel's Globals
--     queue.
--   * init.lua (which HAS io) drains every channel's queue each frame to its
--     file (LOG_DrainAll), and truncates them once at world init (LOG_ResetAll).
--
-- dofile_once'd from BOTH the streaming hook (producer) and init.lua (consumer).
-- Producers only touch Globals; the consumer touches io.
--
-- Records are separated by \30 (ASCII record separator), which never appears in
-- our ASCII-decoded IRC text, so it is a safe delimiter.

local RECORD_SEP = "\30"
local GEN_DIR = "mods/recocards_birthday/files/generated/"

-- Channel registry: name -> { queue_key, path }. Add channels here.
LOG_CHANNELS = LOG_CHANNELS or {
    debug    = { queue_key = "recocards_birthday_log_q_debug",    path = GEN_DIR .. "debug.log" },
    triggers = { queue_key = "recocards_birthday_log_q_triggers", path = GEN_DIR .. "triggers.log" },
}

-- Logging toggle (settings.lua). When OFF, producers don't even enqueue, so
-- there's zero logging work (no Globals churn, no later IO) -- giving a clean
-- isolation of the moist-mob lag. Guarded in case a sandboxed context lacks
-- ModSettingGet; defaults to NOT logging if it can't be read.
local function logging_enabled()
    if ModSettingGet == nil then return false end
    return ModSettingGet("recocards_birthday.logging_enabled") == true
end

-- Producer side (safe in ANY context: only Globals). Appends one line to the
-- named channel's queue, frame-stamped for ordering. Unknown channel = no-op.
-- No-op entirely when logging is disabled.
-- Callers log directly via LOG("debug", msg) / LOG("triggers", msg). There is
-- intentionally NO DBG() wrapper -- one entry point keeps the channel explicit
-- at every call site.
function LOG(channel, msg)
    if not logging_enabled() then return end
    local ch = LOG_CHANNELS[channel]
    if ch == nil then return end
    local line = "[" .. tostring(GameGetFrameNum()) .. "] " .. tostring(msg)
    local existing = GlobalsGetValue(ch.queue_key, "")
    GlobalsSetValue(ch.queue_key, existing .. line .. RECORD_SEP)
end

-- Consumer side (context WITH io only): drain ONE channel's queue to its file.
local function drain_channel(ch)
    local queue = GlobalsGetValue(ch.queue_key, "") or ""
    if queue == "" then return 0 end
    GlobalsSetValue(ch.queue_key, "")

    if io == nil or io.open == nil then
        GlobalsSetValue(ch.queue_key, queue)  -- no io here; preserve for later
        return 0
    end

    local f = io.open(ch.path, "a")
    if f == nil then
        GlobalsSetValue(ch.queue_key, queue)
        return 0
    end

    local count = 0
    for record in string.gmatch(queue, "([^" .. RECORD_SEP .. "]+)") do
        f:write(record .. "\n")
        count = count + 1
    end
    f:flush()
    f:close()
    return count
end

-- Consumer side: drain ALL channels (call each frame from init.lua).
function LOG_DrainAll()
    for _, ch in pairs(LOG_CHANNELS) do
        drain_channel(ch)
    end
end

-- Consumer side: truncate ALL channel files (fresh per session; call once at
-- world init from init.lua). Safe no-op without io.
function LOG_ResetAll()
    if io == nil or io.open == nil then return end
    for name, ch in pairs(LOG_CHANNELS) do
        local f = io.open(ch.path, "w")
        if f ~= nil then
            f:write("==== " .. name .. ".log reset @ frame " ..
                    tostring(GameGetFrameNum()) .. " ====\n")
            f:flush()
            f:close()
        end
    end
end
