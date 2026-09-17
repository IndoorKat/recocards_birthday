local celebratium_original_potion_init = init

local function has_forced_potion_material(entity_id)
    local components =
        EntityGetComponent(
            entity_id,
            "VariableStorageComponent"
        ) or {}

    for _,component in ipairs(components) do
        if ComponentGetValue(component,"name") == "potion_material" then
            return true
        end
    end

    return false
end

function init(entity_id)
    local x,y =
        EntityGetTransform(entity_id)

    if not has_forced_potion_material(entity_id) then
        SetRandomSeed(
            x + 156008746,
            y + 9173
        )

        if Random(1,100) <= 15 then
            EntityAddComponent2(
                entity_id,
                "VariableStorageComponent",
                {
                    name="potion_material",
                    value_string="celebratium_confetti"
                }
            )
        end
    end

    celebratium_original_potion_init(entity_id)

    local material_id =
        GetMaterialInventoryMainMaterial(entity_id)

    local celebratium_id =
        CellFactory_GetType(
            "celebratium_confetti"
        )

    if material_id == celebratium_id then
        local item =
            EntityGetFirstComponentIncludingDisabled(
                entity_id,
                "ItemComponent"
            )

        if item ~= nil then
            ComponentSetValue2(
                item,
                "ui_description",
                "to be sprayed into the air"
            )
        end
    end
end
