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

function findStartOfBelt(currentBelt, seenBelts)
    seenBelts = seenBelts or {}
    -- check if this is a continuation of another belt in a straight line
    local linearBelt = currentBelt.surface.find_entity("transport-belt",
        adjacentPosition(currentBelt.position, oppositeDirection[currentBelt.direction]))
    if linearBelt ~= nil and linearBelt.direction == currentBelt.direction then
        if seenBelts[linearBelt.position] then return currentBelt end
        seenBelts[linearBelt.position] = true
        return findStartOfBelt(linearBelt, seenBelts)
    end
    -- check for belts feeding from left or right (but not both!)
    local leftTurnBelt = currentBelt.surface.find_entity("transport-belt", adjacentPosition(currentBelt.position, leftTurn[currentBelt.direction]))
    local rightTurnBelt = currentBelt.surface.find_entity("transport-belt", adjacentPosition(currentBelt.position, rightTurn[currentBelt.direction]))
    local feedsLeft, feedsRight
    if leftTurnBelt and leftTurnBelt.direction == rightTurn[currentBelt.direction] then feedsLeft = true end
    if rightTurnBelt and rightTurnBelt.direction == leftTurn[currentBelt.direction] then feedsRight = true end

    if feedsLeft and not feedsRight then
        if seenBelts[leftTurnBelt.position] then return currentBelt end
        seenBelts[leftTurnBelt.position] = true
        return findStartOfBelt(leftTurnBelt, seenBelts)
    elseif feedsRight and not feedsLeft then
        if seenBelts[rightTurnBelt.position] then return currentBelt end
        seenBelts[rightTurnBelt.position] = true
        return findStartOfBelt(rightTurnBelt, seenBelts)
    else return currentBelt
    end
end

function reverseDownstreamBelts(currentBelt, seenBelts)
    seenBelts = seenBelts or {}
    local newBelt = currentBelt.surface.find_entity("transport-belt", adjacentPosition(currentBelt.position, currentBelt.direction))
    if      -- there is no belt
               newBelt == nil
            -- we've been here before
            or seenBelts[newBelt.position]
            -- currentBelt and newBelt run into each other
            or newBelt.direction == oppositeDirection[currentBelt.direction]
            -- currentBelt is sideloading on to newBelt - newBelt is sandwiched between two belts
            or positionIsBeltWithDirection(currentBelt.surface, adjacentPosition(newBelt.position, currentBelt.direction), oppositeDirection[currentBelt.direction])
            -- currentBelt is sideloading on to newBelt - newBelt is continuing another belt
            or positionIsBeltWithDirection(currentBelt.surface, adjacentPosition(newBelt.position, oppositeDirection[newBelt.direction]), newBelt.direction) then
        return -- we've nothing left to do as at end of belt
    else
        -- set newBelt direction to the opposite of current belt - this should reverse the entire line - but do it after reversing downstream
        seenBelts[newBelt.position] = newBelt
        reverseDownstreamBelts(newBelt, seenBelts)
        newBelt.direction = oppositeDirection[currentBelt.direction]
    end
end

function reverseEntireBelt(event)
    -- find belt under cursor
    local player = game.players[event.player_index]
    local initialBelt = player.surface.find_entity("transport-belt", player.cursor_position)
    if initialBelt then
        local startOfBelt = findStartOfBelt(initialBelt)
        reverseDownstreamBelts(startOfBelt)
        startOfBelt.direction = oppositeDirection[startOfBelt.direction]
    end
end

script.on_event('ReverseEntireBelt', reverseEntireBelt)