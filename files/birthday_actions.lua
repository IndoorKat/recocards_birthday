table.insert(actions,{
    id="BIRTHDAY_SPIRIT_RADAR",
    name="Birthday Spirit Radar",
    description="Shows the direction of the nearest missing Birthday Spirit while this wand is held.",
    sprite="data/ui_gfx/animal_icons/playerghost.png",
    sprite_unidentified="data/ui_gfx/animal_icons/playerghost.png",
    type=ACTION_TYPE_PASSIVE,
    spawn_level="1,2,3,4,5,6",
    spawn_probability="0.05,0.6,0.6,0.6,0.6,0.6",
    price=220,
    mana=10,
    max_uses=-1,
    action=function()
        draw_actions(1,true)
    end
})
