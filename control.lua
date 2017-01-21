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

local function isBeltTerminatingDownstream(belt)
    local downstreamBelt   = belt.surface.find_entity("transport-belt", adjacentPosition(belt.position, belt.direction))
    local downstreamUGBelt = belt.surface.find_entity("underground-belt", adjacentPosition(belt.position, belt.direction))
    local downstreamLoader = belt.surface.find_entity("loader", adjacentPosition(belt.position, belt.direction))
    if downstreamBelt   and downstreamBelt.direction ~= oppositeDirection[belt.direction] then return false end
    if downstreamUGBelt and (downstreamUGBelt.direction ~= oppositeDirection[belt.direction]
            and not (downstreamUGBelt.direction == belt.direction and downstreamUGBelt.belt_to_ground_type == "output")) then return false end
    if downstreamLoader and downstreamLoader.direction ~= oppositeDirection[belt.direction] then return false end
    return true
end

local function isBeltSideloadingDownstream(belt)
    local downstreamBelt   = belt.surface.find_entity("transport-belt", adjacentPosition(belt.position, belt.direction))
    local downstreamUGBelt = belt.surface.find_entity("underground-belt", adjacentPosition(belt.position, belt.direction))
    local downstreamLoader = belt.surface.find_entity("loader", adjacentPosition(belt.position, belt.direction))
    if downstreamLoader then return false end
    if downstreamUGBelt and (downstreamUGBelt.direction == belt.direction or downstreamUGBelt.direction == oppositeDirection[belt.direction]) then return false end
    if downstreamBelt   then
        if (downstreamBelt.direction   == belt.direction or downstreamBelt.direction   == oppositeDirection[belt.direction]) then return false else
        local upstreamBelt   = belt.surface.find_entity("transport-belt", adjacentPosition(downstreamBelt.position, oppositeDirection[downstreamBelt.direction]))
        local upstreamUGBelt = belt.surface.find_entity("underground-belt", adjacentPosition(downstreamBelt.position, oppositeDirection[downstreamBelt.direction]))
        local upstreamLoader = belt.surface.find_entity("loader", adjacentPosition(downstreamBelt.position, oppositeDirection[downstreamBelt.direction]))
        local oppositeBelt   = belt.surface.find_entity("transport-belt", adjacentPosition(downstreamBelt.position, belt.direction))
        local oppositeUGBelt = belt.surface.find_entity("underground-belt", adjacentPosition(downstreamBelt.position, belt.direction))
        local oppositeLoader = belt.surface.find_entity("loader", adjacentPosition(downstreamBelt.position, belt.direction))

        local continuingBelt = true
        if not (upstreamBelt or upstreamUGBelt or upstreamLoader) then continuingBelt = false end
        if upstreamBelt   and upstreamBelt.direction   ~= downstreamBelt.direction then continuingBelt = false end
        if upstreamUGBelt and upstreamUGBelt.direction ~= downstreamBelt.direction and upstreamUGBelt.belt_to_ground_type ~= "output" then continuingBelt = false end
        if upstreamLoader and upstreamLoader.direction ~= downstreamBelt.direction then continuingBelt = false end

        local sandwichBelt = true
        if not (oppositeBelt or oppositeUGBelt or oppositeLoader) then sandwichBelt = false end
        if oppositeBelt   and oppositeBelt.direction   ~= oppositeDirection[belt.direction] then sandwichBelt = false end
        if oppositeUGBelt and oppositeUGBelt.direction ~= oppositeDirection[belt.direction] and oppositeUGBelt.belt_to_ground_type ~= "output" then sandwichBelt = false end
        if oppositeLoader and oppositeLoader.direction ~= oppositeDirection[belt.direction] then sandwichBelt = false end

        if not continuingBelt and not sandwichBelt then return false end
    end end
    return true
end

local function getNextBeltDownstream(belt)
    if belt.type == "underground-belt" and belt.belt_to_ground_type == "input" then
        if belt.neighbours then return belt.neighbours[1] else return nil end
    end

    local downstreamBelt   = belt.surface.find_entity("transport-belt", adjacentPosition(belt.position, belt.direction))
    local downstreamUGBelt = belt.surface.find_entity("underground-belt", adjacentPosition(belt.position, belt.direction))
    local downstreamLoader = belt.surface.find_entity("loader", adjacentPosition(belt.position, belt.direction))

    if isBeltTerminatingDownstream(belt) then return nil end
    if isBeltSideloadingDownstream(belt) then return nil end
    local returnBelt = downstreamBelt or downstreamUGBelt or downstreamLoader
    return returnBelt
end

local function getUpstreamBeltInDirection(belt, direction)
    local upstreamBelt   = belt.surface.find_entity("transport-belt", adjacentPosition(belt.position, direction))
    local upstreamUGBelt = belt.surface.find_entity("underground-belt", adjacentPosition(belt.position, direction))
    local upstreamLoader = belt.surface.find_entity("loader", adjacentPosition(belt.position, direction))
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
    if not newBelt or newBelt == initialBelt then return currentBelt end
    return findStartOfBelt(newBelt, initialBelt)
end

local function reverseBelt(belt, direction)
    if belt.type == "underground-belt" then
        -- only reverse inputs, unless the output is not connected - then reverse it too
        -- for now, assume that reversing ug belt just means reversing it
        if belt.belt_to_ground_type == "input" then
            local output = belt.neighbours[1]
            local surface = belt.surface

            local newInputParams
            if output then end
            local newOutputParams = {
                name         = belt.name,
                position     = belt.position,
                force        = belt.force,
                direction    = oppositeDirection[belt.direction],
                type         = "output",
                player = player,
            }
            belt.destroy()
            if output then
                newInputParams = {
                    name         = output.name,
                    position     = output.position,
                    force        = output.force,
                    direction    = oppositeDirection[output.direction],
                    type         = "input",
                    player = player,
                }
                output.destroy()
                local newInput = surface.create_entity(newInputParams)
            end
            local newOutput = surface.create_entity(newOutputParams)
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
