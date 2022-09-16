local ltn = require('scripts.ltn')

local speaker = {}

function speaker.init()
  global.entries = {}

  global.deathrattles = global.deathrattles or {}

  global.deliveries = global.deliveries or {}
  global.logistic_train_stops = global.logistic_train_stops or {}

  global.train_stops = {}
  for _, surface in pairs(game.surfaces) do
    for _, entity in pairs(surface.find_entities_filtered{type = "train-stop"}) do
      global.train_stops[entity.unit_number] = entity

      if entity.name == 'logistic-train-stop' then
        speaker.add_speaker_to_ltn_stop(entity)
      end
    end
  end
end

function speaker.on_created_entity(event)
  local entity = event.created_entity or event.entity or event.destination

  -- todo: figure out how to remove copper wires from ghosts
  if entity.name == "entity-ghost" and entity.ghost_name == "logistic-train-stop-announcer" then
    -- entity.disconnect_neighbour()

    -- for _, neighbour in ipairs(entity.neighbours) do
    --   game.print(neighbour.name)
    -- end
  end

  if entity.name ~= 'logistic-train-stop' then return end

  speaker.add_speaker_to_ltn_stop(entity)
end

function speaker.add_speaker_to_ltn_stop(entity)
  local speakerpole = nil

  local multiblock = entity.surface.find_entities(ltn.search_area(entity))
  for _, mb_entity in ipairs(multiblock) do
    if mb_entity.name == "entity-ghost" then
      if mb_entity.ghost_name == 'logistic-train-stop-announcer' then
        _, speakerpole = mb_entity.revive()
      end
    else
      if mb_entity.name == 'logistic-train-stop-announcer' then
        speakerpole = mb_entity
      end
    end
  end

  speakerpole = speakerpole or entity.surface.create_entity({
    name = 'logistic-train-stop-announcer',
    position = ltn.pos_for_speaker(entity),
    force = entity.force,
  })

  speakerpole.operable = false
  speakerpole.destructible = false

  -- disconnect any/only coppy wires
  speakerpole.disconnect_neighbour()

  -- mark speaker pole for death if the station dissapears
  global.deathrattles[script.register_on_entity_destroyed(entity)] = {speakerpole}

  local red_signal = speakerpole.surface.create_entity({
    name = 'logistic-train-stop-announcer-red-signal',
    position = speakerpole.position,
    force = speakerpole.force,
  })

  local green_signal = speakerpole.surface.create_entity({
    name = 'logistic-train-stop-announcer-green-signal',
    position = speakerpole.position,
    force = speakerpole.force,
  })

  -- mark both color combinators for death if the speaker pole dissapears
  global.deathrattles[script.register_on_entity_destroyed(speakerpole)] = {red_signal, green_signal}

  speakerpole.connect_neighbour({
    target_entity = red_signal,
    wire = defines.wire_type.red,
  })

  speakerpole.connect_neighbour({
    target_entity = green_signal,
    wire = defines.wire_type.green,
  })

  global.entries[entity.unit_number] = {
    speakerpole = speakerpole,
    red_signal = red_signal,
    green_signal = green_signal, 
  }

  red_signal.get_control_behavior().parameters = {{index = 1, signal = {type="virtual", name="signal-red"}, count = 1 }}
  green_signal.get_control_behavior().parameters = {{index = 1, signal = {type="virtual", name="signal-green"}, count = 1 }}
  
end

function speaker.on_train_schedule_changed(event)

  -- is an LTN train between dispatched and delivery state
  if not global.deliveries[event.train.id] then return end

  print('schedule + delivery:')
  print(serpent.block( event.train.schedule ))
  print(serpent.block( global.deliveries[event.train.id] ))
end

function speaker.on_dispatcher_updated(event)
  print('on_dispatcher_updated @ ' .. event.tick)
  global.deliveries = event.deliveries
end

function speaker.on_stops_updated(event)
  print('on_stops_updated_event @ ' .. event.tick)
  global.logistic_train_stops = event.logistic_train_stops
end

function speaker.on_entity_destroyed(event)
  if not global.deathrattles[event.registration_number] then return end

  for _, entity in ipairs(global.deathrattles[event.registration_number]) do
    entity.destroy()
  end

  global.deathrattles[event.registration_number] = nil
end

return speaker
