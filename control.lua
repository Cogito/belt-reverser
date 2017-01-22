require("flipBeltLines")

local function adjacentPosition(position, direction)
    if direction == defines.direction.north then return { position.x, position.y - 1 }
    elseif direction == defines.direction.south then return { position.x, position.y + 1 }
    elseif direction == defines.direction.east then return { position.x + 1, position.y }
    elseif direction == defines.direction.west then return { position.x - 1, position.y }
    end
end

local oppositeDirection = {
    [defines.direction.north] = defines.direction.south,
    [defines.direction.south] = defines.direction.north,
    [defines.direction.east] = defines.direction.west,
    [defines.direction.west] = defines.direction.east,
}
local leftTurn = {
    [defines.direction.north] = defines.direction.west,
    [defines.direction.south] = defines.direction.east,
    [defines.direction.east] = defines.direction.north,
    [defines.direction.west] = defines.direction.south,
}
local rightTurn = {
    [defines.direction.north] = defines.direction.east,
    [defines.direction.south] = defines.direction.west,
    [defines.direction.east] = defines.direction.south,
    [defines.direction.west] = defines.direction.north,
}

local function getBeltLike(surface, position, type)
    return surface.find_entities_filtered{ position = position, type = type, }[1]
end

local function isBeltTerminatingDownstream(belt)
    local downstreamBelt   = getBeltLike(belt.surface, adjacentPosition(belt.position, belt.direction), "transport-belt")
    local downstreamUGBelt = getBeltLike(belt.surface, adjacentPosition(belt.position, belt.direction), "underground-belt")
    local downstreamLoader = getBeltLike(belt.surface, adjacentPosition(belt.position, belt.direction), "loader")
    if downstreamBelt   and downstreamBelt.direction ~= oppositeDirection[belt.direction] then return false end
    if downstreamUGBelt and (downstreamUGBelt.direction ~= oppositeDirection[belt.direction]
            and not (downstreamUGBelt.direction == belt.direction and downstreamUGBelt.belt_to_ground_type == "output")) then return false end
    if downstreamLoader and downstreamLoader.direction ~= oppositeDirection[belt.direction] then return false end
    return true
end

local function isBeltSideloadingDownstream(belt)
    local downstreamBelt   = getBeltLike(belt.surface, adjacentPosition(belt.position, belt.direction), "transport-belt")
    local downstreamUGBelt = getBeltLike(belt.surface, adjacentPosition(belt.position, belt.direction), "underground-belt")
    local downstreamLoader = getBeltLike(belt.surface, adjacentPosition(belt.position, belt.direction), "loader")
    if downstreamLoader then return false end
    if downstreamUGBelt and (downstreamUGBelt.direction == belt.direction or downstreamUGBelt.direction == oppositeDirection[belt.direction]) then return false end
    if downstreamBelt   then
        if (downstreamBelt.direction   == belt.direction or downstreamBelt.direction   == oppositeDirection[belt.direction]) then return false else
        local upstreamBelt   = getBeltLike(belt.surface, adjacentPosition(downstreamBelt.position, oppositeDirection[downstreamBelt.direction]), "transport-belt")
        local upstreamUGBelt = getBeltLike(belt.surface, adjacentPosition(downstreamBelt.position, oppositeDirection[downstreamBelt.direction]), "underground-belt")
        local upstreamLoader = getBeltLike(belt.surface, adjacentPosition(downstreamBelt.position, oppositeDirection[downstreamBelt.direction]), "loader")
        local oppositeBelt   = getBeltLike(belt.surface, adjacentPosition(downstreamBelt.position, belt.direction), "transport-belt")
        local oppositeUGBelt = getBeltLike(belt.surface, adjacentPosition(downstreamBelt.position, belt.direction), "underground-belt")
        local oppositeLoader = getBeltLike(belt.surface, adjacentPosition(downstreamBelt.position, belt.direction), "loader")

        local continuingBelt = true
        if not (upstreamBelt or upstreamUGBelt or upstreamLoader) then continuingBelt = false end
        if upstreamBelt   and upstreamBelt.direction   ~= downstreamBelt.direction then continuingBelt = false end
        if upstreamUGBelt and not (upstreamUGBelt.direction == downstreamBelt.direction and upstreamUGBelt.belt_to_ground_type == "output") then continuingBelt = false end
        if upstreamLoader and upstreamLoader.direction ~= downstreamBelt.direction then continuingBelt = false end

        local sandwichBelt = true
        if not (oppositeBelt or oppositeUGBelt or oppositeLoader) then sandwichBelt = false end
        if oppositeBelt   and oppositeBelt.direction   ~= oppositeDirection[belt.direction] then sandwichBelt = false end
        if oppositeUGBelt and not (oppositeUGBelt.direction == oppositeDirection[belt.direction] and oppositeUGBelt.belt_to_ground_type == "output") then sandwichBelt = false end
        if oppositeLoader and oppositeLoader.direction ~= oppositeDirection[belt.direction] then sandwichBelt = false end

        if not continuingBelt and not sandwichBelt then return false end
    end end
    return true
end

local function getNextBeltDownstream(belt)
    if belt.type == "underground-belt" and belt.belt_to_ground_type == "input" then
        if belt.neighbours then return belt.neighbours[1] else return nil end
    end

    local downstreamBelt   = getBeltLike(belt.surface, adjacentPosition(belt.position, belt.direction), "transport-belt")
    local downstreamUGBelt = getBeltLike(belt.surface, adjacentPosition(belt.position, belt.direction), "underground-belt")
    local downstreamLoader = getBeltLike(belt.surface, adjacentPosition(belt.position, belt.direction), "loader")

    if isBeltTerminatingDownstream(belt) then return nil end
    if isBeltSideloadingDownstream(belt) then return nil end
    local returnBelt = downstreamBelt or downstreamUGBelt or downstreamLoader
    return returnBelt
end

local function getUpstreamBeltInDirection(belt, direction)
    local upstreamBelt   = getBeltLike(belt.surface, adjacentPosition(belt.position, direction), "transport-belt")
    local upstreamUGBelt = getBeltLike(belt.surface, adjacentPosition(belt.position, direction), "underground-belt")
    local upstreamLoader = getBeltLike(belt.surface, adjacentPosition(belt.position, direction), "loader")
    if upstreamBelt and upstreamBelt.direction == oppositeDirection[direction] then return upstreamBelt end
    if upstreamLoader and upstreamLoader.direction == oppositeDirection[direction] then return upstreamLoader end
    if upstreamUGBelt and upstreamUGBelt.direction == oppositeDirection[direction] and upstreamUGBelt.belt_to_ground_type == "output" then return upstreamUGBelt end
    return nil
end

local function getNextBeltUpstream(belt)
    if belt.type == "underground-belt" and belt.belt_to_ground_type == "output" then
        if belt.neighbours then return belt.neighbours[1] else return nil end
    end

    local linearBelt    = getUpstreamBeltInDirection(belt, oppositeDirection[belt.direction])
    local leftTurnBelt  = getUpstreamBeltInDirection(belt, leftTurn[belt.direction])
    local rightTurnBelt = getUpstreamBeltInDirection(belt, rightTurn[belt.direction])
    if linearBelt then return linearBelt end
    if leftTurnBelt and not rightTurnBelt then
        return leftTurnBelt end
    if rightTurnBelt and not leftTurnBelt then
        return rightTurnBelt end
    return nil
end

local function findStartOfBelt(currentBelt, initialBelt)
    local newBelt  = getNextBeltUpstream(currentBelt)
    if not newBelt then return currentBelt end
    if newBelt == initialBelt then
        if newBelt.type == "underground-belt" and newBelt.belt_to_ground_type == "input" then
            return newBelt
        else
            return currentBelt
        end
    end
    return findStartOfBelt(newBelt, initialBelt)
end

local function reverseBelt(belt, direction)
    if belt.type == "underground-belt" then
        -- only reverse inputs, unless the output is not connected - then reverse it too
        -- for now, assume that reversing ug belt just means reversing it
        if belt.belt_to_ground_type == "input" then
            local output = belt.neighbours[1]
            local surface = belt.surface
            local newInput, newOutput, newInputParams, newOutputParams, savedInputLines, savedOutputLines

            savedInputLines = flipBeltLines.copyUGBeltLines(belt)
            newOutputParams = {
                name         = belt.name,
                position     = belt.position,
                force        = belt.force,
                direction    = oppositeDirection[belt.direction],
                type         = "output",
                player = player,
            }

            if output then
                savedOutputLines = flipBeltLines.copyUGBeltLines(output)
                newInputParams = {
                    name         = output.name,
                    position     = output.position,
                    force        = output.force,
                    direction    = oppositeDirection[output.direction],
                    type         = "input",
                    player = player,
                }
            end

            belt.destroy()
            if output then
                output.destroy()
                newInput = surface.create_entity(newInputParams)
            end
            newOutput = surface.create_entity(newOutputParams)

            if newInput then
                flipBeltLines.replaceBeltLane(newInput.get_transport_line(1), savedInputLines[2])
                flipBeltLines.replaceBeltLane(newInput.get_transport_line(2), savedInputLines[1])
                flipBeltLines.replaceBeltLane(newInput.get_transport_line(3), savedInputLines[4])
                flipBeltLines.replaceBeltLane(newInput.get_transport_line(4), savedInputLines[3])
                flipBeltLines.replaceBeltLane(newOutput.get_transport_line(1), savedOutputLines[2])
                flipBeltLines.replaceBeltLane(newOutput.get_transport_line(2), savedOutputLines[1])
                flipBeltLines.replaceBeltLane(newOutput.get_transport_line(3), savedOutputLines[4])
                flipBeltLines.replaceBeltLane(newOutput.get_transport_line(4), savedOutputLines[3])
            end
        elseif not belt.neighbours[1] then
            local newInput = belt.surface.create_entity{
                name         = belt.name,
                position     = belt.position,
                force        = belt.force,
                direction    = oppositeDirection[belt.direction],
                type         = "input",
                fast_replace = true,
                spill        = false,
            }
        end
    else
        belt.direction = direction
        flipBeltLines.flipBeltLines(belt)
    end
end

local function reverseDownstreamBelts(currentBelt, startOfBelt)
    local newBelt = getNextBeltDownstream(currentBelt)
    if newBelt == nil then return -- we've nothing left to do as at end of belt
    elseif newBelt == startOfBelt then
        -- special case for when we detect a loop
        -- Normally the head of the belt is simply reversed. Here, the head of the belt is part of the loop so remember to set its direction correctly later
        directionToTurnStartBelt = oppositeDirection[currentBelt.direction]
        return
    else
        -- set newBelt direction to the opposite of current belt - this should reverse the entire line - but do it after reversing downstream
        reverseDownstreamBelts(newBelt, startOfBelt)
        reverseBelt(newBelt, oppositeDirection[currentBelt.direction])
    end
end

local function reverseEntireBelt(event)
    -- find belt under cursor
    player = game.players[event.player_index]
    if player.connected and player.selected and player.controller_type ~= defines.controllers.ghost then
        local initialBelt = player.selected
        if initialBelt and (initialBelt.type == "transport-belt" or initialBelt.type == "underground-belt" or initialBelt.type == "loader") then
            local startOfBelt = findStartOfBelt(initialBelt, initialBelt)
            directionToTurnStartBelt = oppositeDirection[startOfBelt.direction]
            reverseDownstreamBelts(startOfBelt, startOfBelt)
            reverseBelt(startOfBelt, directionToTurnStartBelt)
        end
    end
end

script.on_event('ReverseEntireBelt', reverseEntireBelt)
