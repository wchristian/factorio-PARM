script.on_event(defines.events.on_gui_opened, function(event)
    local entity = event.entity
    if entity and entity.name == 'parm-combinator' then
        -- close this gui and open a lua one, or attach to player.gui.relative
    end
end)

local function on_created_entity(event)
    local entity = event.created_entity or event.entity or event.destination

    entity.active = false

    local internal_combinator = entity.surface.find_entity('parm-combinator-internal', entity.position)
    if internal_combinator == nil then
        internal_combinator =
            entity.surface.create_entity { name = 'parm-combinator-internal', force = entity.force, position = entity.position }

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
    = { unit_number = entity.unit_number, entity = entity, internal = internal_combinator, resources = {}, next_tick = 0 }
end

for _, event in ipairs({
    defines.events.on_built_entity,
    defines.events.on_robot_built_entity,
    defines.events.script_raised_built,
    defines.events.script_raised_revive,
    defines.events.on_entity_cloned,
}) do
    script.on_event(event, on_created_entity, { { filter = 'name', name = 'parm-combinator' }, })
end

local function on_configuration_changed()
    global.structs = global.structs or {}
    global.children = global.children or {}
end

script.on_init(on_configuration_changed)
script.on_configuration_changed(on_configuration_changed)

local function try_tick_combinator(struct, tick)
    if tick < struct.next_tick then return end

    local entity = struct.entity
    local signal_port = defines.circuit_connector_id.combinator_input

    local red_network = entity.get_circuit_network(defines.wire_type.red, signal_port)
    local green_network = entity.get_circuit_network(defines.wire_type.green, signal_port)

    local target = 0
    local smoothing = 2
    local update_rate = 20
    local time_divisor = 60
    local limit = 2147483647
    local mode = 1

    if green_network and green_network.signals then
        for _, signal in ipairs(green_network.signals) do
            if signal.signal.name == "signal-T" then target = math.max(signal.count, 0) end
            if signal.signal.name == "signal-S" then smoothing = math.max(signal.count, 1) end
            if signal.signal.name == "signal-U" then update_rate = math.max(signal.count, 1) end
            if signal.signal.name == "signal-D" then time_divisor = math.max(signal.count, 1) end
            if signal.signal.name == "signal-L" then limit = math.max(signal.count, 1) end
            if signal.signal.name == "signal-M" then mode = math.min(math.max(signal.count, 1), 2) end
        end
    end

    local red_signals_by_name = {}

    if red_network and red_network.signals then
        for _, signal in ipairs(red_network.signals) do
            local name = signal.signal.type .. ":" .. signal.signal.name
            if signal.count < 0 then
                struct.resources[name] = nil
            else
                struct.resources[name]    = struct.resources[name] or { signal = signal.signal }
                red_signals_by_name[name] = signal.count
            end
        end
    end

    local out = {}

    for name, resource in pairs(struct.resources) do
        local signal_value = red_signals_by_name[name] or 0
        local speed        = (signal_value - (resource.value or signal_value)) / update_rate
        resource.value     = signal_value
        local old_speed    = resource.speed or speed
        resource.speed     = old_speed + ((speed - old_speed) / smoothing)
        local estimate
        if mode == 1 then
            local remaining = target - resource.value
            estimate        = (remaining / resource.speed) / time_divisor
            estimate        =
                estimate ~= estimate and (remaining == 0 and 0 or limit)
                or estimate < 0 and limit
                or math.min(estimate, limit)
        elseif mode == 2 then
            estimate = tonumber(string.format("%.0f", resource.speed / time_divisor))
        end
        table.insert(out, { signal = resource.signal, count = estimate, index = #out + 1 })
    end

    struct.internal.get_control_behavior().parameters = out

    struct.next_tick = tick + math.max(1, update_rate * 60)
end

script.on_nth_tick(60, function(event)
    for unit_number, struct in pairs(global.structs) do
        if struct.entity.valid then
            try_tick_combinator(struct, event.tick)
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
