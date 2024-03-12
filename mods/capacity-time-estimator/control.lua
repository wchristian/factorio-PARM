script.on_event(defines.events.on_gui_opened, function(event)
    local entity = event.entity
    if entity and entity.name == 'capacity-time-estimator' then
        -- close this gui and open a lua one, or attach to player.gui.relative
    end
end)

local function on_created_entity(event)
    local entity = event.created_entity or event.entity or event.destination

    entity.active = false

    local internal_combinator = entity.surface.find_entity('capacity-time-estimator-internal', entity.position)
    if internal_combinator == nil then
        internal_combinator =
            entity.surface.create_entity { name = 'capacity-time-estimator-internal', force = entity.force, position = entity.position }

        internal_combinator.destructible = false

        internal_combinator.connect_neighbour({
            target_entity = entity,
            wire = defines.wire_type.red,
            target_circuit_id = defines.circuit_connector_id.combinator_output,
        })
        internal_combinator.connect_neighbour({
            target_entity = entity,
            wire = defines.wire_type.green,
            target_circuit_id = defines.circuit_connector_id.combinator_output,
        })

        global.children[script.register_on_entity_destroyed(entity)] = internal_combinator
    end

    global.structs[entity.unit_number]
    = { unit_number = entity.unit_number, entity = entity, internal = internal_combinator, value = 0, rate = 0 }
end

for _, event in ipairs({
    defines.events.on_built_entity,
    defines.events.on_robot_built_entity,
    defines.events.script_raised_built,
    defines.events.script_raised_revive,
    defines.events.on_entity_cloned,
}) do
    script.on_event(event, on_created_entity, { { filter = 'name', name = 'capacity-time-estimator' }, })
end

local function on_configuration_changed()
    global.structs = global.structs or {}
    global.children = global.children or {}
end

script.on_init(on_configuration_changed)
script.on_configuration_changed(on_configuration_changed)

local function int(num)
    return math.min(math.max(num, -2147483647), 2147483647)
end

local function tick_combinator(struct, ticks_per)
    local entity = struct.entity
    local signal_port = defines.circuit_connector_id.combinator_input
    local input = entity.get_merged_signal({ type = "virtual", name = "signal-I" }, signal_port)
    local target = entity.get_merged_signal({ type = "virtual", name = "signal-T" }, signal_port) or 0
    local smoothing = math.max(1, entity.get_merged_signal({ type = "virtual", name = "signal-S" }, signal_port) or 10)

    local diff = input - struct.value
    struct.value = input
    struct.rate = struct.rate + ((diff - struct.rate) / smoothing)
    local estimate = ((target - struct.value) / struct.rate) * (ticks_per / 60)

    local out = {}

    table.insert(out, { signal = { type = "virtual", name = "signal-R" }, count = int(struct.rate), index = #out + 1 })
    table.insert(out, { signal = { type = "virtual", name = "signal-D" }, count = int(diff), index = #out + 1 })
    table.insert(out, { signal = { type = "virtual", name = "signal-E" }, count = int(estimate), index = #out + 1 })
    table.insert(out, { signal = { type = "virtual", name = "signal-V" }, count = int(struct.value), index = #out + 1 })

    struct.internal.get_control_behavior().parameters = out
end

local ticks_per = 1200
script.on_nth_tick(ticks_per, function(event)
    for unit_number, struct in pairs(global.structs) do
        if struct.entity.valid then
            tick_combinator(struct, ticks_per)
        else
            global.structs[unit_number] = nil
        end
    end
end)

script.on_event(defines.events.on_entity_destroyed, function(event)
    local child = global.children[event.registration_number]
    if child then
        global.children[event.registration_number] = nil
        child.destroy()
    end
end)
