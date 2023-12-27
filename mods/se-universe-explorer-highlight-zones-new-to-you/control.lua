script.on_init(function(event)
  global.next_tick_events = {}

  global.player_index_to_selected_zones_map = {}
end)

local util = require('__space-exploration-scripts__.util')
local Zonelist = require('__space-exploration-scripts__.zonelist')

local function on_post_gui_opened(event)
  local player = game.get_player(event.player_index)

  local root = Zonelist.get(player)
  if not root then return end

  local scroll_pane = util.get_gui_element(root, Zonelist.path_list_rows_scroll_pane)
  if not scroll_pane then return end

  -- game.print(table_size( scroll_pane.children ))

  -- [img=utility/notification]

  for _, row in pairs(scroll_pane.children) do

    -- game.print(row.tags.zone_index)

    -- row.row_flow.ignored_by_interaction = false
    -- row.row_flow.children[2].caption = row.row_flow.children[2].caption .. '[img=utility/notification]'

    -- row.row_flow.children[2].style.left_padding = -5
    -- row.row_flow.children[2].style.horizontal_align = "right"

    if not global.player_index_to_selected_zones_map[event.player_index] or not global.player_index_to_selected_zones_map[event.player_index][row.tags.zone_index] then
      row.row_flow.children[2].add{ -- Zone icon
        type = "sprite",
        sprite = "utility/notification",
        -- caption = "[img=utility/notification]",
        style = "se_zonelist_row_cell_type_notification"
      }
    end

    -- row.row_flow.children[2].children[1].style.width = 54
    -- row.row_flow.children[2].children[1].style.left_margin = 10
    -- row.row_flow.children[2].children[1].style.left_padding = 28
    -- row.row_flow.children[2].children[1].style.horizontal_align = "right"
  end
end

local function on_tick(event)
  local next_tick_events = global.next_tick_events
  global.next_tick_events = {}
  
  for _, e in ipairs(next_tick_events) do
    if e.name == defines.events.on_gui_opened then on_post_gui_opened(e) end
  end

  if #global.next_tick_events > 0 then return end
  script.on_event(defines.events.on_tick, nil)
end

script.on_load(function(event)
  if #global.next_tick_events > 0 then
    script.on_event(defines.events.on_tick, Handler.on_tick)
  end
end)

script.on_event(defines.events.on_gui_opened, function(event)
  table.insert(global.next_tick_events, event)
  script.on_event(defines.events.on_tick, on_tick)
end)

script.on_event(defines.events.on_gui_click, function(event)
  -- game.print(event.element.name)

  if event.element and event.element.tags and event.element.tags.action == Zonelist.action_zone_row_button then
  --game.print('selected zone ' .. event.element.tags.zone_index)
    global.player_index_to_selected_zones_map[event.player_index] = global.player_index_to_selected_zones_map[event.player_index] or {}
    global.player_index_to_selected_zones_map[event.player_index][event.element.tags.zone_index] = true

    local notification = event.element.row_flow.children[2].children[1]
    if notification then notification.destroy() end
  end

  -- tags = {
  --   action = Zonelist.action_zone_row_button,
  --   zone_type = zone.type,
  --   zone_index = zone.index
  -- },
end)
