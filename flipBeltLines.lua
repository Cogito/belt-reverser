local moduleName = flipBeltLines
local M = {}
flipBeltLines = M

function M.flipBeltLines(beltEntity)
    local laneOne = beltEntity.get_transport_line(1)
    local laneTwo = beltEntity.get_transport_line(2)
    local contentsOne = laneOne.get_contents()
    local contentsTwo = laneTwo.get_contents()
    M.replaceBeltLane(laneTwo,contentsOne)
    M.replaceBeltLane(laneOne,contentsTwo)
end

-- Original code by Articulating, modifications by Cogito
function M.replaceBeltLane(lane, contents)
    lane.clear()
    local currentPosition = 0
    for name, count in pairs(contents) do
        for _ = 1, count do
            lane.insert_at(currentPosition, {name=name, count=1})
            currentPosition = currentPosition + 0.03125 * 9
        end
    end

end

function M.copyBeltLines(belt)
    local lines = {}
    for name, line in pairs(defines.transport_line) do
        lines[name] = belt.get_transport_line(line)
        --game.print(tostring(lines[name]))
    end
    return lines
end

function M.copyUGBeltLines(belt)
    local lines = {}
    local index
    for index = 1,4 do
        lines[index] = belt.get_transport_line(index).get_contents()
        --game.print("("..belt.belt_to_ground_type.."-"..belt.unit_number.."-"..index..") "..belt.get_transport_line(index).get_item_count()..": "..M.contentsToString(lines[index], index))
    end
    return lines
end

function M.contentsToString (contents, i)
    local output = ""
    for name, count in pairs(contents) do
        output = output..""..name.."("..count..")"
    end
    return output
end

function M.replace_loader(entity)
    local name, position, surface, force, direction,loader_type,last_user = entity.name, entity.position, entity.surface, entity.force, entity.direction, entity.loader_type, entity.last_user
    local filters = {}
    for slot = 1, entity.filter_slot_count do
        filters[slot] = entity.get_filter(slot)
    end
    entity.destroy()
    loader_type = loader_type == "input" and "output" or "input"
    direction = (direction + 4) % 8
    local new = surface.create_entity{name=name, position=position, force=force, direction=direction,type=loader_type}
    if new and new.valid then
        for slot, filter in pairs(filters) do
            new.set_filter(slot, filter)
        end
        new.last_user = last_user
        -- TODO raise events -- game.raise_event(defines.events.on_built_entity, {corrected_loader=true, player_index=player_index, created_entity=new})
    end
end
