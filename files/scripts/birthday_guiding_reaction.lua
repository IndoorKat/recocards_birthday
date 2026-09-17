local e = GetUpdatedEntityID()
if e == nil or e == 0 then return end

local frame = GameGetFrameNum()

local last =
    tonumber(
        GlobalsGetValue(
            "recocards_guiding_last_burst_frame",
            "-1000"
        )
    ) or -1000

if frame-last < 8 then
    return
end

local tx =
    tonumber(
        GlobalsGetValue(
            "recocards_guiding_target_x",
            ""
        )
    )

local ty =
    tonumber(
        GlobalsGetValue(
            "recocards_guiding_target_y",
            ""
        )
    )

if tx == nil or ty == nil then
    return
end

local sx,sy = EntityGetTransform(e)

local dx = tx-sx
local dy = ty-sy
local len = math.sqrt(dx*dx+dy*dy)

if len < 1 then return end

GlobalsSetValue(
    "recocards_guiding_last_burst_frame",
    tostring(frame)
)

local nx = dx/len
local ny = dy/len

local particles =
    EntityLoad(
        "mods/recocards_birthday/files/entities/birthday_guiding_particles.xml",
        sx,
        sy
    )

if particles ~= nil and particles ~= 0 then
    EntityAddComponent2(
        particles,
        "VariableStorageComponent",
        {
            name="recocards_guiding_particle_nx",
            value_float=nx
        }
    )

    EntityAddComponent2(
        particles,
        "VariableStorageComponent",
        {
            name="recocards_guiding_particle_ny",
            value_float=ny
        }
    )

    EntityAddComponent2(
        particles,
        "VariableStorageComponent",
        {
            name="recocards_guiding_particle_start_frame",
            value_int=frame
        }
    )
end

GamePlaySound(
    "data/audio/Desktop/misc.bank",
    "misc/orb_powder/create",
    sx,
    sy
)
