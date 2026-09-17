local CUSTOM_FILE = "mods/recocards_birthday/files/custom_credits/custom_credits.txt"
local CREDITS_FILE = "data/credits.txt"

local function expand_space_commands(text)
    text = string.gsub(text, "\r\n", "\n")
    text = string.gsub(text, "\r", "\n")
    local output = {}
    for line in string.gmatch(text .. "\n", "(.-)\n") do
        local count = string.match(line, "^%s*%[SPACE:(%d+)%]%s*$")
        if count ~= nil then
            count = tonumber(count) or 1
            if count > 100 then count = 100 end
            for i = 1, count do
                table.insert(output, " ")
            end
        elseif string.match(line, "^%s*%[SPACE%]%s*$") then
            table.insert(output, " ")
        elseif line == "" then
            table.insert(output, " ")
        else
            table.insert(output, line)
        end
    end
    return table.concat(output, "\n")
end

function BirthdayCredits_OnModInit()
    local custom = ModTextFileGetContent(CUSTOM_FILE)
    local vanilla = ModTextFileGetContent(CREDITS_FILE)
    if custom ~= nil and custom ~= "" and vanilla ~= nil then
        custom = expand_space_commands(custom)
        ModTextFileSetContent(CREDITS_FILE, custom .. "\n \n" .. vanilla)
    end
end
