local MOD_ID = "recocards_birthday"
local BASE = "mods/recocards_birthday/files/rhythm_arcade/"
local AUDIO_GUIDS = BASE .. "files/audio/GUIDs.txt"
local HIGHSCORE_KEY = MOD_ID .. ".rhythm_arcade_highscore"
local BEST_COMBO_KEY = MOD_ID .. ".rhythm_arcade_best_combo"
local HIGHSCORE_ACCURACY_KEY = MOD_ID .. ".rhythm_arcade_highscore_accuracy"
local HIGHSCORE_ACCURACY_TENTHS_KEY = MOD_ID .. ".rhythm_arcade_highscore_accuracy_tenths"
local STARTING_SCORE = 1500
local MISS_PENALTY = 1000
local PERFECT_POINTS = 500
local GOOD_POINTS = 250
local OK_POINTS = 100
local COMBO_BONUS_PER_HIT = 5
local COMBO_BONUS_CAP = 500
local MACHINE_CLIP_SCAN_MAX = 99
local CHART_AUDIO_DURATION = 165.8062585
local FMOD_AUDIO_DURATION = 165.8514167
local AUDIO_TIME_SCALE = CHART_AUDIO_DURATION / FMOD_AUDIO_DURATION
local AUDIO_START_OFFSET = 0.0
local GAME_OVER_MIN_DURATION = 3.0
dofile_once("data/scripts/debug/keycodes.lua")
local chart = dofile_once(BASE .. "files/scripts/chart.lua")


function RhythmArcade_OnModInit()
  if ModRegisterAudioEventMappings == nil then
    return
  end

  if ModDoesFileExist ~= nil and not ModDoesFileExist(AUDIO_GUIDS) then
    return
  end

  pcall(ModRegisterAudioEventMappings, AUDIO_GUIDS)
end

local gui = nil

local function destroy_arcade_gui()
  if gui ~= nil then
    GuiDestroy(gui)
    gui = nil
  end
end

local state = {
  active = false,
  phase = "idle",
  machine = 0,
  current_machine_clip = 0,
  machine_clip_order = {},
  machine_clip_index = 0,
  machine_clip_end_frame = 0,
  machine_clip_durations = {},
  machine_clip_indices = {},
  player = 0,
  lock_x = 0,
  lock_y = 0,
  start_time = 0,
  score = 0,
  combo = 0,
  max_combo = 0,
  judgement = "",
  judgement_until = 0,
  hit = {},
  missed = {},
  hold_active = {},
  hold_failed = {},
  hold_completed = {},
  music_entity = 0,
  highscore = 0,
  best_combo = 0,
  highscore_accuracy = 0,
  feedback_dir = "",
  feedback_kind = "",
  feedback_until = 0,
  game_over_ui_until = 0,
  game_over_animation_until = 0,
  game_over_score = 0,
  game_over_machine = 0,
  miss_count = 0,
  perfect_count = 0,
  good_count = 0,
  ok_count = 0,
  reward_given = false,
  last_points_text = "",
}

local idle_machine = 0
local idle_machine_probe_frame = -1

local lanes = {"left","down","up","right"}
local target_imgs = {
  left  = BASE.."files/gfx/target_left.png",
  down  = BASE.."files/gfx/target_down.png",
  up    = BASE.."files/gfx/target_up.png",
  right = BASE.."files/gfx/target_right.png",
}
local note_imgs = {
  left  = BASE.."files/gfx/arrow_left.png",
  down  = BASE.."files/gfx/arrow_down.png",
  up    = BASE.."files/gfx/arrow_up.png",
  right = BASE.."files/gfx/arrow_right.png",
}

local hold_imgs = {
  left  = BASE.."files/gfx/hold_left.png",
  down  = BASE.."files/gfx/hold_down.png",
  up    = BASE.."files/gfx/hold_up.png",
  right = BASE.."files/gfx/hold_right.png",
}

local feedback_imgs = {
  PERFECT = {
    left=BASE.."files/gfx/feedback_perfect_left.png", down=BASE.."files/gfx/feedback_perfect_down.png",
    up=BASE.."files/gfx/feedback_perfect_up.png", right=BASE.."files/gfx/feedback_perfect_right.png",
  },
  GREAT = {
    left=BASE.."files/gfx/feedback_great_left.png", down=BASE.."files/gfx/feedback_great_down.png",
    up=BASE.."files/gfx/feedback_great_up.png", right=BASE.."files/gfx/feedback_great_right.png",
  },
  GOOD = {
    left=BASE.."files/gfx/feedback_good_left.png", down=BASE.."files/gfx/feedback_good_down.png",
    up=BASE.."files/gfx/feedback_good_up.png", right=BASE.."files/gfx/feedback_good_right.png",
  },
  MISS = {
    left=BASE.."files/gfx/feedback_miss_left.png", down=BASE.."files/gfx/feedback_miss_down.png",
    up=BASE.."files/gfx/feedback_miss_up.png", right=BASE.."files/gfx/feedback_miss_right.png",
  },
}

local function now()
  return GameGetRealWorldTimeSinceStarted()
end

local function song_time()
  if state.start_time == 0 then return 0 end
  local elapsed = now() - state.start_time
  local t = (elapsed * AUDIO_TIME_SCALE) + AUDIO_START_OFFSET
  if t < 0 then return 0 end
  return t
end

local function get_player()
  local p = EntityGetWithTag("player_unit")
  if p ~= nil and #p > 0 then return p[1] end
  return 0
end

local function dist2(x1,y1,x2,y2)
  local dx,dy=x2-x1,y2-y1
  return dx*dx+dy*dy
end

local function is_temple_name(name)
  if name == nil then return false end
  local n = string.lower(tostring(name))
  return string.find(n, "temple", 1, true) ~= nil
      or string.find(n, "holy", 1, true) ~= nil
      or string.find(n, "mountain", 1, true) ~= nil
end

local function ensure_machine()
  if state.active then return end

  local flag = "rhythm_arcade_spawned_fixed_v011"
  if GameHasFlagRun(flag) then return end

  local player = get_player()
  if player == 0 then return end
  local x,y = EntityGetTransform(player)
  local ok, biome = pcall(BiomeMapGetName, x, y)
  if not ok or not is_temple_name(biome) then return end

  local spawn_x, spawn_y = -680, 1418
  local existing = EntityGetInRadiusWithTag(spawn_x,spawn_y,80,"rhythm_arcade_machine") or {}

  if #existing == 0 then
    idle_machine = EntityLoad(BASE.."files/arcade_machine.xml", spawn_x, spawn_y) or 0
  else
    idle_machine = existing[1]
  end

  GameAddFlagRun(flag)
end


local function read_number_setting(key)
  if ModSettingGet == nil then return 0 end
  local ok, value = pcall(ModSettingGet, key)
  if not ok or value == nil then return 0 end
  return tonumber(value) or 0
end

local function write_number_setting(key, value)
  if ModSettingSet ~= nil then
    pcall(ModSettingSet, key, value)
  end
  if ModSettingSetNextValue ~= nil then
    pcall(ModSettingSetNextValue, key, value, false)
  end
end

local function load_records()
  state.highscore = read_number_setting(HIGHSCORE_KEY)
  state.best_combo = read_number_setting(BEST_COMBO_KEY)

  local stored_tenths = read_number_setting(HIGHSCORE_ACCURACY_TENTHS_KEY)
  if stored_tenths > 0 then
    state.highscore_accuracy = stored_tenths / 1000
  else
    state.highscore_accuracy = read_number_setting(HIGHSCORE_ACCURACY_KEY)
  end
end

local function save_records()
  if state.score > state.highscore then
    state.highscore = state.score
    write_number_setting(HIGHSCORE_KEY, state.highscore)
  end

  local total = state.perfect_count + state.good_count + state.ok_count + state.miss_count
  if total > 0 then
    local earned =
        (state.perfect_count * 1.00)
      + (state.good_count * 0.75)
      + (state.ok_count * 0.50)

    local run_accuracy = earned / total
    local run_accuracy_tenths = math.floor((run_accuracy * 1000) + 0.5)
    local stored_accuracy_tenths = math.floor((state.highscore_accuracy * 1000) + 0.5)

    if run_accuracy_tenths > stored_accuracy_tenths then
      state.highscore_accuracy = run_accuracy_tenths / 1000
      write_number_setting(HIGHSCORE_ACCURACY_KEY, state.highscore_accuracy)
      write_number_setting(HIGHSCORE_ACCURACY_TENTHS_KEY, run_accuracy_tenths)
    end
  end

  if state.max_combo > state.best_combo then
    state.best_combo = state.max_combo
    write_number_setting(BEST_COMBO_KEY, state.best_combo)
  end
end

local function set_machine_interact_text(machine, text)
  if machine == 0 or not EntityGetIsAlive(machine) then return end
  local components = EntityGetComponentIncludingDisabled(machine, "InteractableComponent") or {}
  for _,component in ipairs(components) do
    ComponentSetValue2(component, "ui_text", text)
  end
end

local function reset_run()
  state.score = STARTING_SCORE
  state.combo = 0
  state.max_combo = 0
  state.judgement = ""
  state.judgement_until = 0
  state.hit = {}
  state.missed = {}
  state.hold_active = {}
  state.hold_failed = {}
  state.hold_completed = {}
  state.feedback_dir = ""
  state.feedback_kind = ""
  state.feedback_until = 0
  state.miss_count = 0
  state.perfect_count = 0
  state.good_count = 0
  state.ok_count = 0
  state.reward_given = false
  state.last_points_text = ""
end

local function stop_music()
  if state.music_entity ~= 0 and EntityGetIsAlive(state.music_entity) then
    EntityKill(state.music_entity)
  end
  state.music_entity = 0
end

local function start_music()
  stop_music()

  local music = EntityCreateNew("rhythm_arcade_music")
  if music == nil or music == 0 then
    GamePrint("RHYTHM ARCADE - AUDIO ENTITY FAILED")
    return false
  end

  EntitySetTransform(music, state.lock_x, state.lock_y)
  EntityAddComponent2(music, "AudioComponent", {
    file = BASE .. "files/audio/rhythm_arcade.snd",
    event_root = "rhythm_arcade",
    set_latest_event_position = false,
    remove_latest_event_on_destroyed = true,
    send_message_on_event_dead = false,
    play_only_if_visible = false,
  })

  state.music_entity = music
  return true
end

local function read_animation_duration(path)
  if ModTextFileGetContent == nil then return nil end
  local ok, content = pcall(ModTextFileGetContent, path)
  if not ok or content == nil or content == "" then return nil end
  local count = tonumber(content:match('frame_count%s*=%s*"([%d%.]+)"'))
  local wait = tonumber(content:match('frame_wait%s*=%s*"([%d%.]+)"'))
  if count == nil or wait == nil or count <= 0 or wait <= 0 then return nil end
  return count * wait
end

local function read_machine_clip_duration(index)
  local path = BASE .. "files/gfx/arcade_machine_clip_" .. tostring(index) .. ".xml"
  local duration = read_animation_duration(path)
  if duration == nil then return nil end
  local ok, content = pcall(ModTextFileGetContent, path)
  if not ok or content == nil or content == "" then return nil end
  local count = tonumber(content:match('frame_count%s*=%s*"([%d%.]+)"'))
  if count == nil or count <= 1 then return nil end
  return duration
end

local function read_game_over_duration()
  return read_animation_duration(BASE .. "files/gfx/arcade_machine_game_over.xml") or GAME_OVER_MIN_DURATION
end

local function create_machine_game_over_component(machine, enabled)
  if machine == 0 or not EntityGetIsAlive(machine) or EntityAddComponent2 == nil then return nil end
  local component = EntityAddComponent2(machine, "SpriteComponent", {
    _tags = "rhythm_arcade_game_over_sprite",
    image_file = BASE .. "files/gfx/arcade_machine_game_over.xml",
    rect_animation = "game_over",
    offset_x = 20,
    offset_y = 60,
    z_index = 0.8,
  })
  if component ~= nil then
    EntitySetComponentIsEnabled(machine, component, enabled == true)
  end
  return component
end

local function ensure_machine_game_over_component(machine)
  if machine == 0 or not EntityGetIsAlive(machine) then return end
  local components = EntityGetComponentIncludingDisabled(machine, "SpriteComponent", "rhythm_arcade_game_over_sprite") or {}
  if #components == 0 then
    create_machine_game_over_component(machine, false)
  end
end

local function restart_machine_game_over_component(machine)
  if machine == 0 or not EntityGetIsAlive(machine) then return end
  local components = EntityGetComponentIncludingDisabled(machine, "SpriteComponent", "rhythm_arcade_game_over_sprite") or {}
  if EntityRemoveComponent ~= nil then
    for _,component in ipairs(components) do
      EntityRemoveComponent(machine, component)
    end
    create_machine_game_over_component(machine, true)
  else
    for _,component in ipairs(components) do
      EntitySetComponentIsEnabled(machine, component, false)
      ComponentSetValue2(component, "rect_animation", "")
      ComponentSetValue2(component, "rect_animation", "game_over")
      EntitySetComponentIsEnabled(machine, component, true)
    end
    if #components == 0 then
      create_machine_game_over_component(machine, true)
    end
  end
end

local function ensure_machine_clip_components(machine)
  if machine == 0 or not EntityGetIsAlive(machine) then return end
  for _,index in ipairs(state.machine_clip_indices) do
    local tag = "rhythm_arcade_clip_" .. tostring(index) .. "_sprite"
    local components = EntityGetComponentIncludingDisabled(machine, "SpriteComponent", tag) or {}
    if #components == 0 and EntityAddComponent2 ~= nil then
      local component = EntityAddComponent2(machine, "SpriteComponent", {
        _tags = tag,
        image_file = BASE .. "files/gfx/arcade_machine_clip_" .. tostring(index) .. ".xml",
        rect_animation = "clip",
        offset_x = 20,
        offset_y = 60,
        z_index = 0.8,
      })
      if component ~= nil then
        EntitySetComponentIsEnabled(machine, component, false)
      end
    end
  end
end

local function set_machine_animation(machine, mode, clip_index)
  if machine == 0 or not EntityGetIsAlive(machine) then return end
  if mode == "game_over" then
    restart_machine_game_over_component(machine)
  else
    ensure_machine_game_over_component(machine)
  end

  local idle_components = EntityGetComponentIncludingDisabled(machine, "SpriteComponent", "rhythm_arcade_idle_sprite") or {}
  for _,component in ipairs(idle_components) do
    EntitySetComponentIsEnabled(machine, component, mode == "idle")
  end

  local title_components = EntityGetComponentIncludingDisabled(machine, "SpriteComponent", "rhythm_arcade_title_sprite") or {}
  for _,component in ipairs(title_components) do
    EntitySetComponentIsEnabled(machine, component, mode == "title")
  end

  local game_over_components = EntityGetComponentIncludingDisabled(machine, "SpriteComponent", "rhythm_arcade_game_over_sprite") or {}
  for _,component in ipairs(game_over_components) do
    EntitySetComponentIsEnabled(machine, component, mode == "game_over")
  end

  for _,i in ipairs(state.machine_clip_indices) do
    local components = EntityGetComponentIncludingDisabled(machine, "SpriteComponent", "rhythm_arcade_clip_"..tostring(i).."_sprite") or {}
    local enabled = mode == "clip" and i == clip_index
    for _,component in ipairs(components) do
      EntitySetComponentIsEnabled(machine, component, enabled)
    end
  end
end

local function rebuild_machine_clip_durations()
  state.machine_clip_durations = {}
  state.machine_clip_indices = {}
  for i=1,MACHINE_CLIP_SCAN_MAX do
    local duration = read_machine_clip_duration(i)
    if duration ~= nil then
      state.machine_clip_durations[i] = duration
      state.machine_clip_indices[#state.machine_clip_indices + 1] = i
    end
  end
  ensure_machine_clip_components(state.machine)
end

local function shuffle_machine_clips()
  local order = {}
  for _,i in ipairs(state.machine_clip_indices) do
    order[#order + 1] = i
  end

  for i=#order,2,-1 do
    local j
    if Random ~= nil then
      j = Random(1, i)
    else
      j = (GameGetFrameNum() % i) + 1
    end
    order[i], order[j] = order[j], order[i]
  end

  if #order > 1 and state.current_machine_clip ~= 0 and order[1] == state.current_machine_clip then
    order[1], order[2] = order[2], order[1]
  end

  state.machine_clip_order = order
  state.machine_clip_index = 0
end

local function play_next_machine_clip()
  if state.machine == 0 or not EntityGetIsAlive(state.machine) then return end
  if #state.machine_clip_order == 0 or state.machine_clip_index >= #state.machine_clip_order then
    shuffle_machine_clips()
  end
  if #state.machine_clip_order == 0 then return end

  state.machine_clip_index = state.machine_clip_index + 1
  local clip = state.machine_clip_order[state.machine_clip_index]
  local duration = state.machine_clip_durations[clip] or 0.1
  state.current_machine_clip = clip
  state.machine_clip_end_frame = GameGetFrameNum() + math.max(1, math.ceil(duration * 60))
  set_machine_animation(state.machine, "clip", clip)
end

local function update_machine_clip_sequence()
  if state.phase ~= "playing" then return end
  if state.current_machine_clip == 0 then
    play_next_machine_clip()
    return
  end
  if GameGetFrameNum() >= state.machine_clip_end_frame then
    play_next_machine_clip()
  end
end

local function suppress_noita_music()
  if GameTriggerMusicFadeOutAndDequeueAll ~= nil then
    GameTriggerMusicFadeOutAndDequeueAll(100.0)
  end
end

local function restore_noita_music()
  if GameTriggerMusicEvent ~= nil then
    local x, y = EntityGetTransform(state.player)
    GameTriggerMusicEvent("music/temple/enter", true, x, y)
  end
end

local function start_game(player, machine)
  destroy_arcade_gui()
  suppress_noita_music()
  state.active = true
  set_machine_interact_text(machine, "$0: quit RHYTHM ARCADE")
  state.phase = "ready"
  state.player = player
  state.machine = machine
  state.current_machine_clip = 0
  state.machine_clip_order = {}
  state.machine_clip_index = 0
  state.machine_clip_end_frame = 0
  rebuild_machine_clip_durations()
  set_machine_animation(machine, "title")
  state.lock_x, state.lock_y = EntityGetTransform(player)
  state.start_time = 0
  load_records()
  reset_run()
  stop_music()
end


local function stop_game()
  destroy_arcade_gui()

  if state.max_combo > state.best_combo then
    state.best_combo = state.max_combo
    write_number_setting(BEST_COMBO_KEY, state.best_combo)
  end
  stop_music()
  restore_noita_music()
  set_machine_animation(state.machine, "idle")
  set_machine_interact_text(state.machine, "$0: play RHYTHM ARCADE")
  state.current_machine_clip = 0
  state.machine_clip_order = {}
  state.machine_clip_index = 0
  state.machine_clip_end_frame = 0
  if state.active and state.player ~= 0 and EntityGetIsAlive(state.player) then
    EntitySetTransform(state.player, state.lock_x, state.lock_y)
  end
  state.active = false
  state.phase = "idle"
  state.machine = 0
  state.player = 0
  state.judgement = ""
end

local function controls(player)
  return EntityGetFirstComponentIncludingDisabled(player, "ControlsComponent")
end

local function key_just_down(code)
  if InputIsKeyJustDown == nil or code == nil then return false end
  local ok, pressed = pcall(InputIsKeyJustDown, code)
  return ok and pressed == true
end

local function key_down(code)
  if InputIsKeyDown == nil or code == nil then return false end
  local ok, pressed = pcall(InputIsKeyDown, code)
  return ok and pressed == true
end

local function direction_key_down(dir)
  if dir == "left" then
    return key_down(Key_LEFT)
  elseif dir == "down" then
    return key_down(Key_DOWN)
  elseif dir == "up" then
    return key_down(Key_UP)
  elseif dir == "right" then
    return key_down(Key_RIGHT)
  end
  return false
end

local function button_pressed(comp, dir)
  if dir == "left" then
    return key_just_down(Key_LEFT)
  elseif dir == "down" then
    return key_just_down(Key_DOWN)
  elseif dir == "up" then
    return key_just_down(Key_UP)
  elseif dir == "right" then
    return key_just_down(Key_RIGHT)
  end
  return false
end

local function interact_pressed(comp)
  return comp ~= nil and ComponentGetValue2(comp, "mButtonFrameInteract") == GameGetFrameNum()
end

local function register_miss(dir)
  state.combo = 0
  state.miss_count = state.miss_count + 1
  state.score = state.score - MISS_PENALTY
  state.last_points_text = "-" .. tostring(MISS_PENALTY)
  state.judgement = "MISS"
  state.judgement_until = now() + 0.35
  state.feedback_dir = dir or ""
  state.feedback_kind = "MISS"
  state.feedback_until = now() + 0.18
end

local function register_timed_hit(dir, delta)
  local points = 0
  if delta <= 0.065 then
    state.judgement = "PERFECT"
    points = PERFECT_POINTS
    state.feedback_kind = "PERFECT"
  elseif delta <= 0.120 then
    state.judgement = "GOOD"
    points = GOOD_POINTS
    state.feedback_kind = "GREAT"
  else
    state.judgement = "OK"
    points = OK_POINTS
    state.feedback_kind = "GOOD"
  end

  if state.judgement == "PERFECT" then
    state.perfect_count = state.perfect_count + 1
  elseif state.judgement == "GOOD" then
    state.good_count = state.good_count + 1
  elseif state.judgement == "OK" then
    state.ok_count = state.ok_count + 1
  end

  state.feedback_dir = dir
  state.feedback_until = now() + 0.18
  state.combo = state.combo + 1
  if state.combo > state.max_combo then state.max_combo = state.combo end

  local combo_bonus = math.min(state.combo * COMBO_BONUS_PER_HIT, COMBO_BONUS_CAP)
  local awarded = points + combo_bonus
  state.score = state.score + awarded
  state.last_points_text = "+" .. tostring(awarded) .. " (" .. tostring(points) .. " + " .. tostring(combo_bonus) .. " COMBO)"
  state.judgement_until = now() + 0.35
end

local function judge_input(dir, song_t)
  local best_i, best_delta = nil, 999
  for i,n in ipairs(chart.notes) do
    if n.dir == dir and not state.hit[i] and not state.missed[i] then
      local delta = math.abs(song_t - n.time)
      if delta < best_delta then
        best_i, best_delta = i, delta
      end
    end
  end

  if best_i == nil or best_delta > 0.20 then
    register_miss(dir)
    return false
  end

  state.hit[best_i] = true
  local note = chart.notes[best_i]
  if (tonumber(note.duration) or 0) > 0 then
    state.hold_active[best_i] = true
  end
  register_timed_hit(dir, best_delta)
  return true
end

local function update_holds(song_t)
  for i,n in ipairs(chart.notes) do
    if state.hold_active[i] then
      local duration = tonumber(n.duration) or 0
      local hold_end = n.time + duration
      local released = not direction_key_down(n.dir)

      if released then
        state.hold_active[i] = nil
        local delta = math.abs(song_t - hold_end)
        if delta <= 0.20 then
          state.hold_completed[i] = true
          register_timed_hit(n.dir, delta)
        else
          state.hold_failed[i] = true
          register_miss(n.dir)
        end
      elseif song_t > hold_end + 0.20 then
        state.hold_active[i] = nil
        state.hold_failed[i] = true
        register_miss(n.dir)
      end
    end
  end
end

local function mark_misses(song_t)
  for i,n in ipairs(chart.notes) do
    if not state.hit[i] and not state.missed[i] and song_t > n.time + 0.20 then
      state.missed[i] = true
      register_miss(n.dir)
    end
  end
end

local function accuracy_ratio()
  local total = state.perfect_count + state.good_count + state.ok_count + state.miss_count
  if total <= 0 then return 0 end

  local earned =
      (state.perfect_count * 1.00)
    + (state.good_count * 0.75)
    + (state.ok_count * 0.50)

  return earned / total
end

local function draw_gui(song_t)
  if gui == nil then gui = GuiCreate() end
  GuiStartFrame(gui)
  local sw, sh = GuiGetScreenDimensions(gui)

  local spacing = 34
  local total = spacing*3 + 24
  local x0 = math.floor(sw/2 - total/2)
  local target_y = math.floor(sh*0.28)
  local panel_w = 260
  local panel_x = (sw - panel_w) / 2
  local panel_y = target_y - 98
  local panel_h = sh - panel_y + 4

  local glow = math.max(0, math.min(1, (state.combo - 10) / 115))
  
  
  GuiZSetForNextWidget(gui, 100)
  GuiImage(gui, 9000, panel_x, panel_y, BASE .. "files/ui/rhythm_panel.png",
    0.82, panel_w / 256, panel_h / 256, 0)

  if state.phase == "playing" and glow > 0 then
    local pulse = 0.86 + 0.14 * math.sin(now() * 5.0)
    local intensity = math.min(glow, 1.0) * pulse

    local outer = 3
    if state.combo >= 20 then outer = 4 end
    if state.combo >= 40 then outer = 6 end
    if state.combo >= 60 then outer = 8 end
    if state.combo >= 90 then outer = 10 end
    if state.combo >= 120 then outer = 12 end

    local glow_alpha = 0.24 + intensity * 0.52
    local core_alpha = 0.40 + intensity * 0.55

    GuiZSetForNextWidget(gui, 50)
    GuiImage(gui, 9401,
      panel_x - outer, panel_y - outer,
      BASE .. "files/ui/glow_h.png",
      glow_alpha,
      (panel_w + outer * 2) / 16,
      (outer * 2) / 8,
      0)

    GuiZSetForNextWidget(gui, 50)
    GuiImage(gui, 9402,
      panel_x - outer, panel_y + panel_h - outer,
      BASE .. "files/ui/glow_h.png",
      glow_alpha,
      (panel_w + outer * 2) / 16,
      (outer * 2) / 8,
      0)

    GuiZSetForNextWidget(gui, 50)
    GuiImage(gui, 9403,
      panel_x - outer, panel_y - outer,
      BASE .. "files/ui/glow_v.png",
      glow_alpha,
      (outer * 2) / 8,
      (panel_h + outer * 2) / 16,
      0)

    GuiZSetForNextWidget(gui, 50)
    GuiImage(gui, 9404,
      panel_x + panel_w - outer, panel_y - outer,
      BASE .. "files/ui/glow_v.png",
      glow_alpha,
      (outer * 2) / 8,
      (panel_h + outer * 2) / 16,
      0)

    GuiZSetForNextWidget(gui, 45)
    GuiImage(gui, 9411,
      panel_x, panel_y,
      BASE .. "files/ui/glow_core.png",
      core_alpha,
      panel_w, 1, 0)

    GuiZSetForNextWidget(gui, 45)
    GuiImage(gui, 9412,
      panel_x, panel_y + panel_h - 1,
      BASE .. "files/ui/glow_core.png",
      core_alpha,
      panel_w, 1, 0)

    GuiZSetForNextWidget(gui, 45)
    GuiImage(gui, 9413,
      panel_x, panel_y,
      BASE .. "files/ui/glow_core.png",
      core_alpha,
      1, panel_h, 0)

    GuiZSetForNextWidget(gui, 45)
    GuiImage(gui, 9414,
      panel_x + panel_w - 1, panel_y,
      BASE .. "files/ui/glow_core.png",
      core_alpha,
      1, panel_h, 0)

    local inner_alpha = 0.16 + intensity * 0.30

    GuiZSetForNextWidget(gui, 44)
    GuiImage(gui, 9421,
      panel_x + 2, panel_y + 2,
      BASE .. "files/ui/glow_core.png",
      inner_alpha,
      panel_w - 4, 1, 0)

    GuiZSetForNextWidget(gui, 44)
    GuiImage(gui, 9422,
      panel_x + 2, panel_y + panel_h - 3,
      BASE .. "files/ui/glow_core.png",
      inner_alpha,
      panel_w - 4, 1, 0)

    GuiZSetForNextWidget(gui, 44)
    GuiImage(gui, 9423,
      panel_x + 2, panel_y + 2,
      BASE .. "files/ui/glow_core.png",
      inner_alpha,
      1, panel_h - 4, 0)

    GuiZSetForNextWidget(gui, 44)
    GuiImage(gui, 9424,
      panel_x + panel_w - 3, panel_y + 2,
      BASE .. "files/ui/glow_core.png",
      inner_alpha,
      1, panel_h - 4, 0)
  end

  GuiZSetForNextWidget(gui, 0)

  local reward_w = 150
  local reward_h = 234
  local reward_x = math.max(4, panel_x - reward_w - 8)
  local reward_y = math.max(4, math.min(panel_y + 38, sh - reward_h - 4))

  GuiZSetForNextWidget(gui, 0)
  GuiImage(gui, 9100, reward_x, reward_y, BASE .. "files/ui/reward_table.png",
    1, 1, 1, 0)

  local spawn_y = math.floor(sh*0.84)

  local hud_x = sw/2 - 100
  GuiText(gui, hud_x, target_y - 87, "RHYTHM ARCADE - DUNKTALES BY SHANKMO")
  GuiText(gui, hud_x, target_y - 73, "SCORE "..tostring(state.score))
  local combo_text = "COMBO "..tostring(state.combo)
  local combo_x = sw/2 - 5
  if state.phase == "playing" and glow > 0 and GuiColorSetForNextWidget ~= nil then
    local glow_alpha = 0.10 + glow * 0.22
    local offsets = {{-1,0},{1,0},{0,-1},{0,1}}
    if state.combo >= 70 then
      offsets = {{-2,0},{2,0},{0,-2},{0,2},{-1,-1},{1,-1},{-1,1},{1,1}}
    end
    for i,o in ipairs(offsets) do
      GuiColorSetForNextWidget(gui, 1.0, 0.55 + glow * 0.20, 0.10, glow_alpha)
      GuiText(gui, combo_x + o[1], target_y - 73 + o[2], combo_text)
    end
    GuiColorSetForNextWidget(gui, 1.0, 0.82, 0.30, 1.0)
  end
  GuiText(gui, combo_x, target_y - 73, combo_text)

  GuiText(gui, hud_x, target_y - 63,
    string.format("HS %d   ACC %.1f%%   BEST %d", state.highscore, state.highscore_accuracy * 100, state.best_combo))

  local acc = accuracy_ratio() * 100
  GuiText(gui, hud_x, target_y - 53, string.format("ACCURACY %.1f%%   %s", acc, state.last_points_text))
  GuiText(gui, hud_x, target_y - 43,
    "P "..tostring(state.perfect_count)..
    "  G "..tostring(state.good_count)..
    "  OK "..tostring(state.ok_count)..
    "  M "..tostring(state.miss_count))

  for lane_i,dir in ipairs(lanes) do
    local x = x0 + (lane_i-1)*spacing
    local img = target_imgs[dir]
    if state.feedback_dir == dir and now() <= state.feedback_until then
      local group = feedback_imgs[state.feedback_kind]
      if group ~= nil and group[dir] ~= nil then img = group[dir] end
    end
    GuiImage(gui, 100+lane_i, x, target_y, img, 1, 1, 1)
  end

  if state.phase == "playing" then
    local travel = chart.travel_time or 1.35
    for i,n in ipairs(chart.notes) do
      local duration = tonumber(n.duration) or 0
      local is_hold = duration > 0
      local visible = (not state.hit[i] and not state.missed[i]) or state.hold_active[i]

      if visible then
        local head_time = state.hold_active[i] and song_t or n.time
        local head_dt = head_time - song_t
        local end_dt = (n.time + duration) - song_t

        if head_dt <= travel and end_dt >= -0.20 then
          local head_progress = 1 - (head_dt / travel)
          local head_y = spawn_y + (target_y - spawn_y) * head_progress
          local lane_index = 1
          for li,d in ipairs(lanes) do if d == n.dir then lane_index = li break end end
          local x = x0 + (lane_index-1)*spacing

          if is_hold then
            local end_progress = 1 - (end_dt / travel)
            local end_y = spawn_y + (target_y - spawn_y) * end_progress
            if state.hold_active[i] then head_y = target_y end

            local body_top = math.min(head_y + 10, end_y)
            local body_bottom = math.max(head_y + 10, end_y)
            local body_h = math.max(2, body_bottom - body_top)

            GuiZSetForNextWidget(gui, 1)
            GuiImage(gui, 4000+i, x + 9, body_top, hold_imgs[n.dir],
              state.hold_active[i] and 1.0 or 0.82,
              1,
              body_h / 8,
              0)
          end

          if state.hold_active[i] then
            GuiImage(gui, 6000+i, x, target_y, note_imgs[n.dir], 0.90, 1, 1)
          else
            GuiImage(gui, 1000+i, x, head_y, note_imgs[n.dir], 1, 1, 1)
          end
        end
      end
    end
  end

  if state.judgement ~= "" and now() <= state.judgement_until then
    if GuiColorSetForNextWidget ~= nil then
      if state.judgement == "PERFECT" then
        GuiColorSetForNextWidget(gui, 0.25, 1.0, 0.35, 1.0)
      elseif state.judgement == "GREAT" then
        GuiColorSetForNextWidget(gui, 0.75, 1.0, 0.20, 1.0)
      elseif state.judgement == "GOOD" then
        GuiColorSetForNextWidget(gui, 1.0, 0.65, 0.15, 1.0)
      else
        GuiColorSetForNextWidget(gui, 1.0, 0.20, 0.15, 1.0)
      end
    end
    if GuiColorSetForNextWidget ~= nil then
      if state.judgement == "PERFECT" then
        GuiColorSetForNextWidget(gui, 0.35, 1.00, 0.45, 1.0)
      elseif state.judgement == "GOOD" then
        GuiColorSetForNextWidget(gui, 0.78, 1.00, 0.30, 1.0)
      elseif state.judgement == "OK" then
        GuiColorSetForNextWidget(gui, 1.00, 0.72, 0.20, 1.0)
      else
        GuiColorSetForNextWidget(gui, 1.00, 0.18, 0.16, 1.0)
      end
    end
    GuiText(gui, sw/2 - 24, target_y + 36, state.judgement)
  end
  if state.phase == "ready" then
    if GuiColorSetForNextWidget ~= nil then
      GuiColorSetForNextWidget(gui, 1.0, 0.88, 0.35, 1.0)
    end
    GuiText(gui, sw/2 - 56, target_y + 72, "PRESS SPACE TO START")
  elseif state.phase == "finished" then
    if GuiColorSetForNextWidget ~= nil then
      GuiColorSetForNextWidget(gui, 0.45, 1.0, 0.55, 1.0)
    end
    GuiText(gui, sw/2 - 55, target_y + 72, "SPACE - PLAY AGAIN")
  end
  GuiText(gui, sw/2 - 50, spawn_y + 25, "Arrow Keys = notes")
end


local function spawn_gold_value(amount, x, y)
  local denominations = {
    {200000, "data/entities/items/pickup/goldnugget_200000.xml"},
    {10000,  "data/entities/items/pickup/goldnugget_10000.xml"},
    {1000,   "data/entities/items/pickup/goldnugget_1000.xml"},
    {200,    "data/entities/items/pickup/goldnugget_200.xml"},
    {50,     "data/entities/items/pickup/goldnugget_50.xml"},
    {10,     "data/entities/items/pickup/goldnugget_10.xml"},
  }

  local spawned = 0
  for _,entry in ipairs(denominations) do
    local value = entry[1]
    local path = entry[2]
    while amount >= value do
      local ox = ((spawned % 5) - 2) * 7
      local oy = math.floor(spawned / 5) * 4
      EntityLoad(path, x + ox, y + oy)
      amount = amount - value
      spawned = spawned + 1
    end
  end
end

local function spawn_chest_entity(path, x, y)
  EntityLoad(path, x, y)
end

local function give_completion_reward()
  if state.reward_given then return end
  state.reward_given = true

  local acc = accuracy_ratio()
  local x = state.lock_x
  local y = state.lock_y - 14

  if acc >= 1.0 and state.good_count == 0 and state.ok_count == 0 and state.miss_count == 0 then
    spawn_gold_value(250000, x, y)
    spawn_chest_entity("data/entities/items/pickup/chest_random_super.xml", x - 30, y - 5)
    spawn_chest_entity("data/entities/items/pickup/chest_random_super.xml", x - 10, y + 3)
    spawn_chest_entity("data/entities/items/pickup/chest_random_super.xml", x + 12, y - 2)
    spawn_chest_entity("data/entities/items/pickup/chest_random_super.xml", x + 32, y + 5)
    GamePrint("RHYTHM ARCADE - REWARD: 250000 GOLD + 4x GREATER TREASURE CHEST")
  elseif acc >= 0.95 then
    spawn_gold_value(50000, x - 12, y)
    spawn_chest_entity("data/entities/items/pickup/chest_random_super.xml", x + 20, y + 3)
    GamePrint("RHYTHM ARCADE - REWARD: 50000 GOLD + GREATER TREASURE CHEST")
  elseif acc >= 0.90 then
    spawn_gold_value(10000, x, y)
    spawn_chest_entity("data/entities/items/pickup/chest_random.xml", x - 30, y - 4)
    spawn_chest_entity("data/entities/items/pickup/chest_random.xml", x - 10, y + 3)
    spawn_chest_entity("data/entities/items/pickup/chest_random.xml", x + 12, y - 2)
    spawn_chest_entity("data/entities/items/pickup/chest_random.xml", x + 32, y + 5)
    GamePrint("RHYTHM ARCADE - REWARD: 10000 GOLD + 4x TREASURE CHEST")
  elseif acc >= 0.85 then
    spawn_gold_value(5000, x, y)
    spawn_chest_entity("data/entities/items/pickup/chest_random.xml", x - 17, y - 3)
    spawn_chest_entity("data/entities/items/pickup/chest_random.xml", x + 19, y + 4)
    GamePrint("RHYTHM ARCADE - REWARD: 5000 GOLD + 2x TREASURE CHEST")
  elseif acc >= 0.80 then
    spawn_gold_value(1000, x - 10, y)
    spawn_chest_entity("data/entities/items/pickup/chest_random.xml", x + 20, y + 3)
    GamePrint("RHYTHM ARCADE - REWARD: 1000 GOLD + TREASURE CHEST")
  elseif acc >= 0.75 then
    spawn_gold_value(750, x, y)
    GamePrint("RHYTHM ARCADE - REWARD: 750 GOLD")
  elseif acc >= 0.50 then
    spawn_gold_value(500, x, y)
    GamePrint("RHYTHM ARCADE - REWARD: 500 GOLD")
  elseif acc >= 0.30 then
    spawn_gold_value(100, x, y)
    GamePrint("RHYTHM ARCADE - REWARD: 100 GOLD")
  else
    spawn_gold_value(10, x, y)
    GamePrint("RHYTHM ARCADE - REWARD: 10 GOLD")
  end
end

local function begin_run()
  reset_run()

  if not start_music() then
    state.phase = "ready"
    state.start_time = 0
    return
  end

  state.start_time = now()
  state.phase = "playing"
  shuffle_machine_clips()
  play_next_machine_clip()
end

local function finish_run()
  save_records()
  give_completion_reward()
  stop_music()
  state.phase = "finished"
  state.current_machine_clip = 0
  state.machine_clip_order = {}
  state.machine_clip_index = 0
  state.machine_clip_end_frame = 0
  set_machine_animation(state.machine, "title")
  GamePrint(string.format(
    "RHYTHM ARCADE - %.2f%% | P %d G %d OK %d M %d",
    accuracy_ratio() * 100,
    state.perfect_count,
    state.good_count,
    state.ok_count,
    state.miss_count
  ))
end

local function trigger_game_over()
  if state.max_combo > state.best_combo then
    state.best_combo = state.max_combo
    write_number_setting(BEST_COMBO_KEY, state.best_combo)
  end
  local machine = state.machine
  local animation_duration = read_game_over_duration()
  local started_at = now()
  local animation_duration_total = GAME_OVER_MIN_DURATION
  if animation_duration > 0 then
    local loops = math.ceil((GAME_OVER_MIN_DURATION + 0.05) / animation_duration)
    animation_duration_total = math.max(GAME_OVER_MIN_DURATION, loops * animation_duration)
  end
  state.game_over_score = state.score
  state.game_over_ui_until = started_at + GAME_OVER_MIN_DURATION
  state.game_over_animation_until = started_at + animation_duration_total
  state.game_over_machine = machine
  GamePrint("RHYTHM ARCADE - GAME OVER")
  stop_game()
  set_machine_animation(machine, "game_over")
end

local function draw_game_over()
  local t = now()
  if state.game_over_animation_until <= t then
    if state.game_over_machine ~= 0 then
      set_machine_animation(state.game_over_machine, "idle")
      state.game_over_machine = 0
    end
    return false
  end
  if state.game_over_ui_until > t then
    if gui == nil then gui = GuiCreate() end
    GuiStartFrame(gui)
    local sw, sh = GuiGetScreenDimensions(gui)
    if GuiColorSetForNextWidget ~= nil then
      GuiColorSetForNextWidget(gui, 1.0, 0.15, 0.10, 1.0)
    end
    GuiText(gui, sw/2 - 32, sh*0.42, "GAME OVER")
    GuiText(gui, sw/2 - 48, sh*0.42 + 14, "SCORE "..tostring(state.game_over_score))
    GuiText(gui, sw/2 - 75, sh*0.42 + 26,
      string.format("HS %d   ACC %.1f%%", state.highscore, state.highscore_accuracy * 100))
    GuiText(gui, sw/2 - 60, sh*0.42 + 38, "BEST COMBO "..tostring(state.best_combo))
  end
  return true
end

local function update_idle()
  ensure_machine()
  if draw_game_over() then return end

  local player = get_player()
  if player == 0 then return end
  local px,py = EntityGetTransform(player)

  if idle_machine ~= 0 and not EntityGetIsAlive(idle_machine) then
    idle_machine = 0
  end

  if idle_machine == 0 then
    local frame = GameGetFrameNum()

    if
      idle_machine_probe_frame < 0 or
      frame - idle_machine_probe_frame >= 10
    then
      idle_machine_probe_frame = frame

      if dist2(px,py,-680,1418) <= 6400 then
        local machines =
          EntityGetInRadiusWithTag(
            -680,
            1418,
            80,
            "rhythm_arcade_machine"
          ) or {}

        if #machines > 0 then
          idle_machine = machines[1]
        end
      end
    end
  end

  if idle_machine == 0 then return end

  local mx,my = EntityGetTransform(idle_machine)
  if dist2(px,py,mx,my) > 1156 then return end

  local comp = controls(player)
  if interact_pressed(comp) then
    start_game(player, idle_machine)
  end
end

local function update_active()
  suppress_noita_music()
  local player = state.player
  if player == 0 or not EntityGetIsAlive(player) then
    stop_game()
    return
  end

  EntitySetTransform(player, state.lock_x, state.lock_y)

  local comp = controls(player)
  if interact_pressed(comp) then
    stop_game()
    GamePrint("Rhythm Arcade cancelled.")
    return
  end

  if state.phase == "ready" then
    draw_gui(0)
    if key_just_down(Key_SPACE) then
      begin_run()
    end
    return
  end

  if state.phase == "finished" then
    draw_gui(chart.length)
    if key_just_down(Key_SPACE) then
      begin_run()
    end
    return
  end

  local t = song_time()
  draw_gui(t)

  update_machine_clip_sequence()

  for _,dir in ipairs(lanes) do
    if button_pressed(comp, dir) then
      judge_input(dir, t)
    end
  end
  update_holds(t)
  mark_misses(t)

  if state.score < 0 then
    trigger_game_over()
    return
  end

  if t >= chart.length then
    finish_run()
  end
end

function RhythmArcade_OnWorldPreUpdate()
  if state.active then update_active() else update_idle() end
end

function RhythmArcade_OnPlayerDied()
  stop_game()
end
