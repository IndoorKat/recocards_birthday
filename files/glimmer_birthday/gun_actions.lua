local bdayGlimmer = {
    id                      = "BDAYGLIMMER_COLOUR_BDAY",
    name                    = "$bdayGlimmer_name",
    description             = "$bdayGlimmer_desc",
    sprite                  = "mods/recocards_birthday/files/glimmer_birthday/colour_bday.png",
    related_extra_entities  = { "mods/recocards_birthday/files/glimmer_birthday/colour_bday.xml" },
    type                    = ACTION_TYPE_MODIFIER,
    spawn_level             = "1,2,3",
    spawn_probability       = "0.2,0.2,0.1",
    price                   = 40,
    mana                    = 0,
    action = function()
        c.extra_entities    = c.extra_entities .. "mods/recocards_birthday/files/glimmer_birthday/colour_bday.xml,"
        c.screenshake       = math.max(0, c.screenshake - 2.5)
        draw_actions( 1, true )
    end,
    author                  = "Sharpy796",
    origin                  = "Glimmers Birthdayed",
    is_glimmer              = true,
}

table.insert(actions, bdayGlimmer)