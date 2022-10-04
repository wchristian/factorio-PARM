-- /c game.print(serpent.block( game.player.gui.relative.children[3] ))

function get_child(parent, name)
  for i = 1,  #parent.children_names do
    if parent.children_names[i] == name then
      return parent.children[i]
    end
  end

  error('could not find a child named ['.. name ..'].')
end

script.on_event(defines.events.on_gui_opened, function(event)
  if not event.entity then return end
  if event.entity.name ~= 'se-space-capsule' then return end

  local player = game.get_player(event.player_index)

  local container = get_child(player.gui.relative, 'se-space-capsule-gui')
  local capsule_gui_frame = get_child(container, 'capsule_gui_inner')
  local subheader_frame = inner.children[1]

  local subheader_child = {
    capacity = 1,
    sections = 2,
    fuel     = 3,
    status   = 4,
  }

  local fuel_label = subheader_frame.children[subheader_child.fuel].children[3] -- [text, spacer, min/max]
  local current_fuel = fuel_label.caption[2]
  local required_fuel = fuel_label.caption[3]

  game.print(current_fuel)
  game.print(required_fuel)
end)
