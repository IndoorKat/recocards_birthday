function RQ_ReadAll(path)
    local f = io.open(path,"r")
    if f == nil then return nil end
    local s = f:read("*a")
    f:close()
    return s
end

function RQ_ReadConfig(path)
    local out = {}
    local s = RQ_ReadAll(path)
    if s == nil then return out end
    for line in string.gmatch(s,"[^\r\n]+") do
        if string.sub(line,1,1) ~= "#" then
            local k,v = string.match(line,"^%s*([^=]+)%s*=%s*(.-)%s*$")
            if k ~= nil then out[k] = tonumber(v) or v end
        end
    end
    return out
end

local function rq_percent_decode(value)
    if value == nil then return "" end

    return string.gsub(value,"%%(%x%x)",function(hex)
        return string.char(tonumber(hex,16))
    end)
end

local function rq_parse_manifest_links(encoded)
    local out = {}

    if encoded == nil or encoded == "" then
        return out
    end

    for value in string.gmatch(encoded,"[^,]+") do
        local url = rq_percent_decode(value)

        if
            string.sub(url,1,7) == "http://" or
            string.sub(url,1,8) == "https://"
        then
            table.insert(out,url)
        end
    end

    return out
end

function RQ_ReadManifest(path)
    local cards = {}
    local s = RQ_ReadAll(path)
    if s == nil then return cards,"" end

    for line in string.gmatch(s,"[^\r\n]+") do
        local order,id,file,w,h,frames,fps,author,links =
            string.match(
                line,
                "^(%d+)|([^|]+)|([^|]+)|(%d+)|(%d+)|(%d+)|([%d%.]+)|([^|]*)|(.*)$"
            )

        if order == nil then
            order,id,file,w,h,frames,fps,author =
                string.match(
                    line,
                    "^(%d+)|([^|]+)|([^|]+)|(%d+)|(%d+)|(%d+)|([%d%.]+)|([^|]*)$"
                )
            links = ""
        end

        if order == nil then
            order,id,file,w,h =
                string.match(
                    line,
                    "^(%d+)|([^|]+)|([^|]+)|(%d+)|(%d+)$"
                )
            frames = "1"
            fps = "0"
            author = "Birthday Spirit"
            links = ""
        end

        if order ~= nil then
            table.insert(cards,{
                order=tonumber(order),
                id=id,
                file=file,
                w=tonumber(w),
                h=tonumber(h),
                frames=tonumber(frames) or 1,
                fps=tonumber(fps) or 0,
                author=(author ~= nil and author ~= "") and author or "Birthday Spirit",
                links=rq_parse_manifest_links(links)
            })
        end
    end

    table.sort(cards,function(a,b) return a.order < b.order end)
    return cards,s
end

function RQ_CardFrameFile(card, frame)
    if card == nil or (card.frames or 1) <= 1 then
        return card.file
    end

    local f = math.max(1,math.min(card.frames,frame or 1))
    return "card_" .. card.id .. "_f" .. string.format("%03d",f) .. ".png"
end

function RQ_CardCurrentFrame(card)
    if card == nil or (card.frames or 1) <= 1 or (card.fps or 0) <= 0 then
        return 1
    end

    local game_fps = 60
    local frames_per_image = math.max(
        1,
        math.floor((game_fps / card.fps) + 0.5)
    )

    return (
        math.floor(GameGetFrameNum() / frames_per_image) %
        card.frames
    ) + 1
end

function RQ_CardCurrentFile(card)
    return RQ_CardFrameFile(card,RQ_CardCurrentFrame(card))
end

function RQ_ReadZones(path)
    local zones = {}
    local s = RQ_ReadAll(path)
    if s == nil then return zones end
    for line in string.gmatch(s,"[^\r\n]+") do
        if string.sub(line,1,1) ~= "#" and string.match(line,"%S") then
            local name,x1,y1,x2,y2,weight =
                string.match(line,"^([^,]+),([%-%.%d]+),([%-%.%d]+),([%-%.%d]+),([%-%.%d]+),([%-%.%d]+)$")
            if name ~= nil then
                table.insert(zones,{
                    name=name,
                    x1=tonumber(x1),y1=tonumber(y1),
                    x2=tonumber(x2),y2=tonumber(y2),
                    weight=tonumber(weight) or 1
                })
            end
        end
    end
    return zones
end

function RQ_Rng(seed)
    local state = seed % 2147483647
    if state <= 0 then state = state + 2147483646 end
    return function()
        state = (state * 16807) % 2147483647
        return (state - 1) / 2147483646
    end
end

function RQ_FoundFlag(id)
    return "recocards_found_" .. id
end
