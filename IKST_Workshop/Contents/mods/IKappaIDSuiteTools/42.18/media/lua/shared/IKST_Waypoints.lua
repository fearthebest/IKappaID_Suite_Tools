require "IKST_Shared"

IKST_Waypoints = IKST_Waypoints or {}
IKST_Waypoints.KEY = "IKST_Waypoints"

function IKST_Waypoints.normalizeName(name)
    if not name or type(name) ~= "string" then
        return nil
    end
    name = string.gsub(name, "^%s*(.-)%s*$", "%1")
    if name == "" then
        return nil
    end
    return name
end

function IKST_Waypoints.sync()
    if IKST.transmitModData then
        IKST.transmitModData(IKST.ModDataKeys and IKST.ModDataKeys.Waypoints or IKST_Waypoints.KEY)
    end
end

function IKST_Waypoints.store()
    local data = ModData.getOrCreate(IKST_Waypoints.KEY)
    data.list = data.list or {}
    return data
end

function IKST_Waypoints.list()
    return IKST_Waypoints.store().list
end

function IKST_Waypoints.find(name)
    name = IKST_Waypoints.normalizeName(name)
    if not name then
        return nil
    end
    for _, wp in ipairs(IKST_Waypoints.list()) do
        if wp.name == name then
            return wp
        end
    end
    return nil
end

function IKST_Waypoints.save(player, name)
    player = IKST.resolvePlayer(player)
    name = IKST_Waypoints.normalizeName(name)
    if not player or not name then
        return false, "enter a name"
    end
    local list = IKST_Waypoints.list()
    for i = #list, 1, -1 do
        if list[i].name == name then
            table.remove(list, i)
        end
    end
    list[#list + 1] = {
        name = name,
        x = player:getX(),
        y = player:getY(),
        z = player:getZ(),
    }
    if IKST.runsOnServerJvm and IKST.runsOnServerJvm() then
        IKST_Waypoints.sync()
    end
    return true, "Saved '" .. name .. "'"
end

function IKST_Waypoints.delete(name)
    name = IKST_Waypoints.normalizeName(name)
    if not name then
        return false, "enter a name"
    end
    local list = IKST_Waypoints.list()
    local removed = false
    for i = #list, 1, -1 do
        if list[i].name == name then
            table.remove(list, i)
            removed = true
        end
    end
    if removed then
        if IKST.runsOnServerJvm and IKST.runsOnServerJvm() then
            IKST_Waypoints.sync()
        end
        return true, "Deleted '" .. name .. "'"
    end
    return false, "no such waypoint"
end
