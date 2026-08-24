-- Durable vehicle identity for claims.
-- BaseVehicle:getId() is a session short id and is reused after restart - never persist it.
-- https://projectzomboid.com/modding/zombie/vehicles/BaseVehicle.html

IKST_VehicleIdentity = IKST_VehicleIdentity or {}

IKST_VehicleIdentity.KEY_FIELD = "IKST_vkey"
IKST_VehicleIdentity.KEY_PREFIX = "ikst:"

local function mayWrite()
    if type(isClient) == "function" and isClient()
        and type(isServer) == "function" and not isServer() then
        return false
    end
    return true
end

function IKST_VehicleIdentity.isDurableKey(value)
    if value == nil then
        return false
    end
    return string.sub(tostring(value), 1, #IKST_VehicleIdentity.KEY_PREFIX) == IKST_VehicleIdentity.KEY_PREFIX
end

function IKST_VehicleIdentity.readKey(vehicle)
    if not vehicle or type(vehicle.getModData) ~= "function" then
        return nil
    end
    local data = vehicle:getModData()
    if not data then
        return nil
    end
    local key = data[IKST_VehicleIdentity.KEY_FIELD]
    if IKST_VehicleIdentity.isDurableKey(key) then
        return tostring(key)
    end
    return nil
end

function IKST_VehicleIdentity.scriptName(vehicle)
    if not vehicle then
        return ""
    end
    if type(vehicle.getScriptName) == "function" then
        local name = vehicle:getScriptName()
        if name and name ~= "" then
            return tostring(name)
        end
    end
    if type(vehicle.getScript) == "function" then
        local script = vehicle:getScript()
        if script and type(script.getName) == "function" then
            return tostring(script:getName() or "")
        end
    end
    return ""
end

function IKST_VehicleIdentity.coords(vehicle)
    if not vehicle then
        return 0, 0, 0
    end
    local x = 0
    local y = 0
    local z = 0
    if type(vehicle.getX) == "function" then
        x = math.floor(tonumber(vehicle:getX()) or 0)
    end
    if type(vehicle.getY) == "function" then
        y = math.floor(tonumber(vehicle:getY()) or 0)
    end
    if type(vehicle.getZ) == "function" then
        z = tonumber(vehicle:getZ()) or 0
    end
    return x, y, z
end

function IKST_VehicleIdentity.stampWith(vehicle, key)
    if not mayWrite() or not vehicle or not IKST_VehicleIdentity.isDurableKey(key) then
        return false
    end
    if type(vehicle.getModData) ~= "function" then
        return false
    end
    local data = vehicle:getModData()
    if not data then
        return false
    end
    local want = tostring(key)
    local changed = data[IKST_VehicleIdentity.KEY_FIELD] ~= want
    data[IKST_VehicleIdentity.KEY_FIELD] = want
    if changed and type(vehicle.transmitModData) == "function" then
        vehicle:transmitModData()
    end
    return true
end

function IKST_VehicleIdentity.clearKey(vehicle)
    if not mayWrite() or not vehicle or type(vehicle.getModData) ~= "function" then
        return false
    end
    local data = vehicle:getModData()
    if not data or data[IKST_VehicleIdentity.KEY_FIELD] == nil then
        return false
    end
    data[IKST_VehicleIdentity.KEY_FIELD] = nil
    if type(vehicle.transmitModData) == "function" then
        vehicle:transmitModData()
    end
    return true
end
