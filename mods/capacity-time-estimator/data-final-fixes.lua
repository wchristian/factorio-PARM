local search_n_replace = {
    ['__base__/graphics/icons/decider-combinator.png'] =
    '__capacity-time-estimator__/graphics/icons/capacity-time-estimator.png',
    ['__base__/graphics/entity/combinator/decider-combinator.png'] =
    '__capacity-time-estimator__/graphics/entity/combinator/capacity-time-estimator.png',
    ['__base__/graphics/entity/combinator/hr-decider-combinator.png'] =
    '__capacity-time-estimator__/graphics/entity/combinator/hr-capacity-time-estimator.png',
}

-- i am too lazy to key-value replace these in all the directions myself lol, so hey: automatic function :)
local function do_search_n_replace(t)
    for key, value in pairs(t) do
        if type(value) == 'string' and search_n_replace[value] then
            t[key] = search_n_replace[value]
        end
        if type(value) == 'table' then
            do_search_n_replace(value)
        end
    end
end

local combinator = table.deepcopy(data.raw['decider-combinator']['decider-combinator'])
combinator.name = 'capacity-time-estimator'
combinator.minable.result = 'capacity-time-estimator'
combinator.energy_source = { type = 'void' }

do_search_n_replace(combinator)
data:extend { combinator }

local item = table.deepcopy(data.raw['item']['decider-combinator'])
item.name = 'capacity-time-estimator'
item.place_result = 'capacity-time-estimator'
item.order = 'c[combinators]-d[capacity-time-estimator]'

do_search_n_replace(item)
data:extend { item }

local recipe = table.deepcopy(data.raw['recipe']['decider-combinator'])
recipe.name = 'capacity-time-estimator'
recipe.result = 'capacity-time-estimator'
recipe.ingredients = { { 'constant-combinator', 1 }, { 'decider-combinator', 1 } }

do_search_n_replace(recipe)
data:extend { recipe }

local technology = data.raw['technology']['circuit-network']
for _, effect in ipairs(technology.effects) do
    if effect.type == 'unlock-recipe' and effect.recipe == 'decider-combinator' then
        table.insert(technology.effects, _ + 1, {
            type = 'unlock-recipe', recipe = 'capacity-time-estimator'
        })
        break
    end
end

local internal = table.deepcopy(data.raw['constant-combinator']['constant-combinator'])
internal.name = 'capacity-time-estimator-internal'
internal.minable = nil
internal.collision_mask = {}
internal.flags = { "placeable-off-grid" }

internal.selectable_in_game = false
internal.sprites = nil
internal.draw_circuit_wires = false

data:extend { internal }
