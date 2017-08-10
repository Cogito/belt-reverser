--- Belt Helper module

Belts = {}

--- Find a downstream connected belt.
-- @param sideloading true if sideloaded belts are considered connected
function Belts.downstream(belt, sideloading)
    local distance = 1
    if belt.type == "underground-belt" and belt.belt_to_ground_type == "input" then
        if belt.neighbours then return belt.neighbours[1] else return nil end
    end

    if belt.type == "loader" then
        if belt.loader_type == "output" then distance = 1.5 else return nil end
    end

    if isBeltTerminatingDownstream(belt, distance) then return nil end
    if isBeltSideloadingDownstream(belt, distance) then return nil end
    return Belts.outputBelt(belt)
end

--- Find the belt that this belt is directly connected to
-- @tparam[opt=true] boolean sideloading true if sideloaded belts are considered connected. defaults to false
function Belts.outputBelt(belt, sideloading)
    sideloading = sideloading or false
    -- The output of an underground belt input is its neighbour
    if belt.type == "underground-belt" and belt.belt_to_ground_type == "input" then
        if belt.neighbours then return belt.neighbours[1] else return nil end
    end
    -- A loader input has no output
    if belt.type == "loader" and belt.loader_type == "input" then return nil end
    -- This is the distance from the centre of the belt to the centre of the next tile.
    local distance = 0.5 + Belts.entityLength(belt) * 0.5

    local outputBelt = Belts.findBeltish(belt.surface, adjacentPosition(belt.position, belt.direction, distance))

    if outputBelt == nil then return nil end
    if outputBelt.direction == Belts.oppositeDirection(belt) then return nil end
    if not Belts.isInputType(outputBelt) then return nil end
    if Belts.isSideloaded(outputBelt) then if sideloading then return outputBelt else return nil end end
    return outputBelt
end


--- Search for a belt-like entity at the given position and return it, otherwise return nil
function Belts.findBeltish(surface, position)
    for _, type in ipairs({ "transport-belt", "underground-belt", "loader" }) do
        local beltish = surface.find_entities_filtered { position = position, type = type, }[1]
        if beltish then return beltish end
    end
    return nil
end

function Belts.entityLength(belt)
    if belt.type == "loader" then
        return 2 else return 1
    end
end

function Belts.isInputType(belt)
    if belt and (belt.type == "transport-belt" or
            (belt.type == "underground-belt" and belt.belt_to_ground_type == "input") or
            (belt.type == "loader" and belt.loader_type == "input")) then return true else return false
    end
end

return Belts
