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

function reverseDownstreamBelts2(player, currentBelt, seenBelts)
    player.print("enter reverse downstream")
    --seenBelts = seenBelts or {}
    local newBelt = currentBelt.surface.find_entity("transport-belt", adjacentPosition(currentBelt.position, currentBelt.direction))
    --player.print("new belt at "..printPosition(newBelt.position))
    --player.print("new belt direction: "..newBelt.direction)
    --player.print("current belt direction: "..currentBelt.direction)
    --player.print(newBelt.direction == oppositeDirection[currentBelt.direction])

    if      -- there is no belt
               newBelt == nil then return end
            -- we've been here befores
            --or
    if seenBelts[newBelt.position] then
        player.print("apparently I've seen this before: "..printPosition(newBelt.position))
        return
    end
    if false
            -- currentBelt and newBelt run into each other
            or newBelt.direction == oppositeDirection[currentBelt.direction]
            or newBelt.direction ~= currentBelt.direction and (
                -- currentBelt is sideloading on to newBelt - newBelt is sandwiched between two belts
                 positionIsBeltWithDirection(currentBelt.surface, adjacentPosition(newBelt.position, currentBelt.direction), oppositeDirection[currentBelt.direction])
                -- currentBelt is sideloading on to newBelt - newBelt is continuing another belt
                or positionIsBeltWithDirection(currentBelt.surface, adjacentPosition(newBelt.position, oppositeDirection[newBelt.direction]), newBelt.direction)
               ) then
        return -- we've nothing left to do as at end of belt
    else
        --player.print("reversing "..printPosition(newBelt.position))
        -- set newBelt direction to the opposite of current belt - this should reverse the entire line - but do it after reversing downstream
        player.print("in front")
        --player.print("I am at new belt"..printPosition(newBelt.position)..", I have already seen: goobly")
        --for key,value in pairs(seenBelts) do player.print(printPosition(key)..": "..tostring(value)) end
        --seenBelts[newBelt.position] = true
        player.print("second time x2")
        --for key,value in pairs(seenBelts) do player.print(printPosition(key)..": "..tostring(value)) end
        reverseDownstreamBelts2(player, newBelt, seenBelts)
        newBelt.direction = oppositeDirection[currentBelt.direction]
    end
end

function printPosition(position)
    return "("..position.x..","..position.y..")"
end

function reverseEntireBelt(event)
    -- find belt under cursor
    local player = game.players[event.player_index]
    if player.connected and player.selected and player.controller_type ~= defines.controllers.ghost then
        local initialBelt = player.selected
        if initialBelt and initialBelt.type == "transport-belt" then
            player.print("initial belt at "..printPosition(initialBelt.position))
            local startOfBelt = findStartOfBelt(initialBelt)
            player.print("start of belt at "..printPosition(startOfBelt.position))
            reverseDownstreamBelts2(player, startOfBelt, {[startOfBelt.position] = true})
            startOfBelt.direction = oppositeDirection[startOfBelt.direction]
        end
    end
end

script.on_event('ReverseEntireBelt', reverseEntireBelt)
