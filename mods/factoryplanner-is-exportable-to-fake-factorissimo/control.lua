local print_gui = require('scripts.print_gui')
local shared = require('shared')

local mod_prefix = 'fietff-'

local item_box_products = 1
local item_box_byproducts = 2
local item_box_ingredients = 3

local function split_class_and_name(class_and_name)
  local class, name = class_and_name:match('([^/]+)/([^/]+)')
  assert(class)
  assert(name)
  return class, name
end

local function active_radio_button(buttons)
  for _, button in ipairs(buttons) do
    if button.toggled then return button end
  end
  error('none of the buttons are active')
end

local function prefix_to_multiplier(locale_key)
  local multiplier = 1
  local prefixes = {"kilo", "mega", "giga", "tera", "peta", "exa", "zetta", "yotta"}

  if locale_key == nil then
    return multiplier
  end

  for _, prefix in ipairs(prefixes) do
    if 'fp.prefix_' .. prefix == locale_key then
      return multiplier * 1000
    else
      multiplier = multiplier * 1000
    end
  end
end

local function get_item_box_contents(root, item_box_index)
  local products = {}
  for _, sprite_button in ipairs(root.children[2].children[2].children[1].children[item_box_index].children[2].children[1].children[1].children) do
    if sprite_button.sprite ~= "utility/add" then
      local class, name = split_class_and_name(sprite_button.sprite)
      table.insert(products, {type = class, name = name, amount = sprite_button.number})
    end
  end
  return products
end

script.on_event(defines.events.on_gui_opened, function(event)
  if event.gui_type ~= defines.gui_type.custom then return end
  if event.element.name ~= "fp_frame_main_dialog" then return end
  local root = event.element

  -- game.print(root.name .. ' @ ' .. event.tick)

  -- log(print_gui.serpent( root ))
  -- log(print_gui.serpent( root.children[2].children[1].children[2].children[3].children[1].children[3] ))
  -- log(print_gui.path_to_tooltip(root, 'fp.timescale_tt', 'root'))

  local ingredient_labels = root.children[2].children[2].children[1].children[item_box_products].children[1]
  if not ingredient_labels['ingredients_to_factorissimo'] then
    local button_factorissimo = ingredient_labels.add{
      name = "ingredients_to_factorissimo",
      type = "sprite-button",
      sprite = "entity/fietff-container-1",
      tooltip = {"fp.ingredients_to_factorissimo_tt"},
      mouse_button_filter = {"left"},
    }
    button_factorissimo.style.size = 24
    button_factorissimo.style.padding = -2
    button_factorissimo.style.left_margin = 4
  end
end)

script.on_event(defines.events.on_gui_click, function(event)
  if event.element.name ~= "ingredients_to_factorissimo" then return end
  local player = game.get_player(event.player_index)
  local root = player.opened
  assert(root.name == 'fp_frame_main_dialog')

  local items_per_timescale_button = root.children[2].children[2].children[2].children[1].children[9].children[1]
  assert(items_per_timescale_button.caption[2][1] == "fp.pu_item")
  if items_per_timescale_button.toggled == false then
    return player.create_local_flying_text{
      text = "Timescale must be set to items.", -- [items/s-m-h] so we can extract the doubles we need for math
      create_at_cursor = true,
    }
  end

  local products = get_item_box_contents(root, item_box_products)
  local byproducts = get_item_box_contents(root, item_box_byproducts)
  local ingredients = get_item_box_contents(root, item_box_ingredients)

  log('products: ' .. serpent.line(products))
  log('byproducts: ' .. serpent.line(byproducts))
  log('ingredients: ' .. serpent.line(ingredients))

  if #ingredients == 0 then
    return player.create_local_flying_text{
      text = "No ingredients defined at all.",
      create_at_cursor = true,
    }
  end

  for _, ingredient in ipairs(ingredients) do
    if ingredient.type == "entity" then
      return player.create_local_flying_text{
        text = "Mining drills are not supported.", -- it seems selecting pumpjacks does not allow for oil to be selected
        create_at_cursor = true,
      }
    end
  end
  
  local _table = table
  local table = root.children[2].children[2].children[2].children[3].children[1].children[1]
  local columns = {} -- [fp.pu_recipe, fp.pu_machine, fp.pu_beacon]
  for i, cell in ipairs(table.children) do -- the table has no rows, everything is a cell
    if cell.type ~= "label" then break end -- stop once we have all the column names
    columns[cell.caption[1]] = i -- thanks to preferences the amount & positions of columns can vary
  end

  local column_count = table_size(columns) + 1 -- + 1 for the horizontal flow
  local row_count = #table.children / column_count

  for row = 2, row_count do
    local offset = (row - 1) * column_count
    
    -- if the sprite ever changes into something else yet still doesn't have a `/` in it an assert will failsafe-block it
    if table.children[offset + columns['fp.pu_machine']].children[1].sprite == 'fp_generic_assembler' then
      return player.create_local_flying_text{
        text = "Subfloors are not supported.",
        create_at_cursor = true,
      }
    end
    
    local recipe_class, recipe_name = split_class_and_name(table.children[offset + columns['fp.pu_recipe']].children[2].sprite)
    local machine_class, machine_name = split_class_and_name(table.children[offset + columns['fp.pu_machine']].children[1].sprite)

    local modules = {}
    for i = 2, #table.children[offset + columns['fp.pu_machine']].children do
      local module_button = table.children[offset + columns['fp.pu_machine']].children[i]
      if module_button.sprite ~= "utility/add" then
        local module_class, module_name = split_class_and_name(module_button.sprite)
        _table.insert(modules, {type = module_class, name = module_name, amount = module_button.number})
      end
    end

    log(serpent.line({recipe_name, machine_name, modules}))

    if #table.children[offset + columns['fp.pu_beacon']].children > 1 then -- 1 = supports beacons, 2+ = beacon and module(s) selected
      return player.create_local_flying_text{
        text = "Beacons are not supported.",
        create_at_cursor = true,
      }
    end

    local force_recipe = player.force.recipes[recipe_name]
    if force_recipe.enabled == false then -- wouldn't want players obtaining item outputs they shouldn't have unlocked yet (or cheaper recipes)
      -- return player.create_local_flying_text{
      --   text = string.format("Recipe [%s] not researched yet.", recipe_name),
      --   create_at_cursor = true,
      -- }
    end
  end

  if player.clear_cursor() == false then
    return player.create_local_flying_text{
      text = "Failed to empty your hand.",
      create_at_cursor = true,
    }
  end

  local energy_amount = tonumber(root.children[2].children[1].children[2].children[1].children[3].children[1].tooltip[2])
  local energy_prefix = root.children[2].children[1].children[2].children[1].children[3].children[1].tooltip[3][1] -- k/m/w (watt)
  log(energy_amount * prefix_to_multiplier(energy_prefix)) -- /60 = number to put into electric energy interface usage (* for buffer)

  local pollution_per_minute = tonumber(root.children[2].children[1].children[2].children[1].children[3].children[3].tooltip[2])
  local pollution_per_minute_prefix = root.children[2].children[1].children[2].children[1].children[3].children[3].tooltip[3][1]
  log(pollution_per_minute * prefix_to_multiplier(pollution_per_minute_prefix))

  local timescale_buttons = root.children[2].children[1].children[2].children[3].children[1].children[3].children
  local timescale_button = active_radio_button(timescale_buttons)
  log(timescale_button.caption[3][1])

  if energy_amount == 0 then
    return player.create_local_flying_text{
      text = "Factory must use (some) power.", -- because i want to use an interface's buffer as progress bar #lazy
      create_at_cursor = true,
    }
  end

  player.cursor_stack.set_stack({name = mod_prefix .. 'item-1', count = 1})
  -- player.opened = nil
end)

local function on_created_entity(event)
  local entity = event.created_entity or event.entity or event.destination

  local eei = entity.surface.create_entity{
    name = mod_prefix .. 'electric-energy-interface-1',
    force = entity.force,
    position = {entity.position.x, entity.position.y + shared.electric_energy_interface_1_y_offset},
  }

  eei.destructible = false
end

for _, event in ipairs({
  defines.events.on_built_entity,
  defines.events.on_robot_built_entity,
  defines.events.script_raised_built,
  defines.events.script_raised_revive,
  -- defines.events.on_entity_cloned,
}) do
  script.on_event(event, on_created_entity, {
    {filter = 'name', name = mod_prefix .. 'container-1'},
    {filter = 'name', name = mod_prefix .. 'container-2'},
    {filter = 'name', name = mod_prefix .. 'container-3'},
  })
end