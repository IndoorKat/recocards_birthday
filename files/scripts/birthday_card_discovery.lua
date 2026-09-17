dofile_once("mods/recocards_birthday/files/scripts/util.lua")

function RQ_DiscoverBirthdayCard(id,author)
    if id == nil or id == "" then return false end

    local flag = RQ_FoundFlag(id)

    if GameHasFlagRun(flag) then
        return false
    end

    GameAddFlagRun(flag)
    ModSettingSet(
        "recocards_birthday.found_" .. id,
        true
    )

    local found =
        tonumber(
            GlobalsGetValue(
                "recocards_found",
                "0"
            )
        ) or 0

    local total =
        tonumber(
            GlobalsGetValue(
                "recocards_total",
                "0"
            )
        ) or 0

    found = found + 1

    GlobalsSetValue(
        "recocards_found",
        tostring(found)
    )

    local sequence =
        tonumber(
            GlobalsGetValue(
                "recocards_discovery_sequence",
                "0"
            )
        ) or 0

    local persistent_sequence =
        tonumber(
            ModSettingGet(
                "recocards_birthday.discovery_sequence"
            )
        ) or 0

    if persistent_sequence > sequence then
        sequence = persistent_sequence
    end

    sequence = sequence + 1

    GlobalsSetValue(
        "recocards_discovery_sequence",
        tostring(sequence)
    )

    GlobalsSetValue(
        "recocards_discovery_order_" .. id,
        tostring(sequence)
    )

    ModSettingSet(
        "recocards_birthday.discovery_order_" .. id,
        sequence
    )

    ModSettingSet(
        "recocards_birthday.discovery_sequence",
        sequence
    )

    GamePrintImportant(
        (author or "Birthday Spirit") .. "'s Birthday Page",
        tostring(found) ..
        " / " ..
        tostring(total) ..
        " cards added to the book"
    )

    return true
end
