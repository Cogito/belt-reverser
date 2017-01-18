function adjacentPosition(position, direction)
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

function positionIsBeltWithDirection(surface, position, direction)
    local belt = surface.find_entity("transport-belt", position)
    return belt and belt.direction == direction
end

function findAdjacentBelt(belt, direction)
    local newBelt = belt.surface.find_entity("transport-belt", adjacentPosition(belt.position, direction))
    return newBelt
end

function findStartOfBelt(currentBelt, initialBelt)
    -- check if this is a continuation of another belt in a straight line
    local linearBelt = findAdjacentBelt(currentBelt, oppositeDirection[currentBelt.direction])
    if linearBelt ~= nil and linearBelt.direction == currentBelt.direction then
        if linearBelt == initialBelt then return currentBelt end
        return findStartOfBelt(linearBelt, initialBelt)
    end
    -- check for belts feeding from left or right (but not both!)
    local leftTurnBelt = findAdjacentBelt(currentBelt, leftTurn[currentBelt.direction])
    local rightTurnBelt = findAdjacentBelt(currentBelt, rightTurn[currentBelt.direction])
    local feedsLeft, feedsRight
    if leftTurnBelt and leftTurnBelt.direction == rightTurn[currentBelt.direction] then feedsLeft = true end
    if rightTurnBelt and rightTurnBelt.direction == leftTurn[currentBelt.direction] then feedsRight = true end

    if feedsLeft and not feedsRight then
        if leftTurnBelt == initialBelt then return currentBelt end
        return findStartOfBelt(leftTurnBelt, initialBelt)
    elseif feedsRight and not feedsLeft then
        if rightTurnBelt == initialBelt then return currentBelt end
        return findStartOfBelt(rightTurnBelt, initialBelt)
    else return currentBelt
    end
end

function reverseDownstreamBelts(currentBelt, startOfBelt)
    local newBelt = findAdjacentBelt(currentBelt, currentBelt.direction)
    if      -- there is no belt
               newBelt == nil
            -- currentBelt and newBelt run into each other
            or newBelt.direction == oppositeDirection[currentBelt.direction]
            or newBelt.direction ~= currentBelt.direction and (
                -- currentBelt is sideloading on to newBelt - newBelt is sandwiched between two belts
                 positionIsBeltWithDirection(currentBelt.surface, adjacentPosition(newBelt.position, currentBelt.direction), oppositeDirection[currentBelt.direction])
                -- currentBelt is sideloading on to newBelt - newBelt is continuing another belt
                or positionIsBeltWithDirection(currentBelt.surface, adjacentPosition(newBelt.position, oppositeDirection[newBelt.direction]), newBelt.direction)
               ) then
        return -- we've nothing left to do as at end of belt
    elseif newBelt == startOfBelt then
        -- special case for when we detect a loop
        -- Normally the head of the belt is simply reversed. Here, the head of the belt is part of the loop so remember to set its direction correctly later
        directionToTurnStartBelt = oppositeDirection[currentBelt.direction]
        return
    else
        -- set newBelt direction to the opposite of current belt - this should reverse the entire line - but do it after reversing downstream
        reverseDownstreamBelts(newBelt, startOfBelt)
        newBelt.direction = oppositeDirection[currentBelt.direction]
    end
end

function reverseEntireBelt(event)
    -- find belt under cursor
    local player = game.players[event.player_index]
    if player.connected and player.selected and player.controller_type ~= defines.controllers.ghost then
        local initialBelt = player.selected
        if initialBelt and initialBelt.type == "transport-belt" then
            local startOfBelt = findStartOfBelt(initialBelt, initialBelt)
            directionToTurnStartBelt = oppositeDirection[startOfBelt.direction]
            reverseDownstreamBelts(startOfBelt, startOfBelt)
            startOfBelt.direction = directionToTurnStartBelt
        end
    end
end

script.on_event('ReverseEntireBelt', reverseEntireBelt)