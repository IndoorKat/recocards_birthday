local e = GetUpdatedEntityID()
if e == nil or e == 0 then return end

local emitter =
    EntityGetFirstComponentIncludingDisabled(
        e,
        "ParticleEmitterComponent"
    )

if emitter == nil then
    return
end

local vars =
    EntityGetComponentIncludingDisabled(
        e,
        "VariableStorageComponent"
    ) or {}

local nx = 0
local ny = 0
local start_frame = GameGetFrameNum()

for _,var in ipairs(vars) do
    local name = ComponentGetValue2(var,"name")

    if name == "recocards_guiding_particle_nx" then
        nx = ComponentGetValue2(var,"value_float")
    elseif name == "recocards_guiding_particle_ny" then
        ny = ComponentGetValue2(var,"value_float")
    elseif name == "recocards_guiding_particle_start_frame" then
        start_frame = ComponentGetValue2(var,"value_int")
    end
end

local speed = 96
local spread = 2.5

ComponentSetValue2(
    emitter,
    "x_vel_min",
    nx*speed-spread
)

ComponentSetValue2(
    emitter,
    "x_vel_max",
    nx*speed+spread
)

ComponentSetValue2(
    emitter,
    "y_vel_min",
    ny*speed-spread
)

ComponentSetValue2(
    emitter,
    "y_vel_max",
    ny*speed+spread
)

local colors = {
    "recocards_guiding_particle_red",
    "recocards_guiding_particle_orange",
    "recocards_guiding_particle_yellow",
    "recocards_guiding_particle_green",
    "recocards_guiding_particle_cyan",
    "recocards_guiding_particle_blue",
    "recocards_guiding_particle_violet"
}

local age =
    math.max(
        0,
        GameGetFrameNum()-start_frame
    )

local index =
    math.floor(age/2)%#colors+1

ComponentSetValue2(
    emitter,
    "emitted_material_name",
    colors[index]
)
