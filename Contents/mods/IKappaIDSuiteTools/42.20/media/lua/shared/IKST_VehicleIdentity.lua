-- Durable vehicle identity for claims.
-- BaseVehicle:getId() is a session short and is reused after restart — never persist it.
-- https://projectzomboid.com/modding/zombie/vehicles/BaseVehicle.html (getId vs getSqlId)
-- Vehicle object modData is saved with the vehicle. MP: server writes, then transmitModData.
-- https://pzwiki.net/wiki/Mod_data

IKST_VehicleIdentity = IKST_VehicleIdentity or {}

IKST_VehicleIdentity.KEY_FIELD = "IKST_vkey"
IKST_VehicleIdentity.SQL_FIELD = "IKST_vsql"
IKST_VehicleIdentity.KEY_PREFIX = "ikst:"

local function mayWrite()
    if type(isClient) == "function" and isClient()
        and type(isServer) == "function" and not isServer() then
        return false
    end
    return true
end

local function modDataFor(vehicle)
    if not vehicle or type(vehicle.getModData) ~= "function" then
        return nil
    end
    return vehicle:getModData()
end

function IKST_VehicleIdentity.isDurableKey(value)
    if value == nil then
        return false
    end
    local s = tostring(value)
    return string.sub(s, 1, 5) == IKST_VehicleIdentity.KEY_PREFIX
end

function IKST_VehicleIdentity.isLegacyRuntimeKey(value)
    if value == nil or IKST_VehicleIdentity.isDurableKey(value) then
        return false
    end
    local n = tonumber(value)
    if n == nil then
        return false
    end
    n = math.floor(n)
    return n >= 0
end

function IKST_VehicleIdentity.runtimeId(vehicle)
    if not vehicle or type(vehicle.getId) ~= "function" then
        return nil
    end
    return vehicle:getId()
end

function IKST_VehicleIdentity.liveSqlId(vehicle)
    if not vehicle or type(vehicle.getSqlId) ~= "function" then
        return nil
    end
    local n = tonumber(vehicle:getSqlId())
    if n == nil or n <= 0 then
        return nil
    end
    return tostring(math.floor(n))
end

function IKST_VehicleIdentity.readKey(vehicle)
    local data = modDataFor(vehicle)
    if not data then
        return nil
    end
    local key = data[IKST_VehicleIdentity.KEY_FIELD]
    if not IKST_VehicleIdentity.isDurableKey(key) then
        return nil
    end
    return tostring(key)
end

function IKST_VehicleIdentity.readStoredSqlId(vehicle)
    local data = modDataFor(vehicle)
    if not data then
        return nil
    end
    local n = tonumber(data[IKST_VehicleIdentity.SQL_FIELD])
    if n == nil or n <= 0 then
        return nil
    end
    return tostring(math.floor(n))
end

function IKST_VehicleIdentity.sqlId(vehicle)
    return IKST_VehicleIdentity.liveSqlId(vehicle) or IKST_VehicleIdentity.readStoredSqlId(vehicle)
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

function IKST_VehicleIdentity.transmit(vehicle)
    if not vehicle or type(vehicle.transmitModData) ~= "function" then
        return
    end
    vehicle:transmitModData()
end

function IKST_VehicleIdentity.stampWith(vehicle, key)
    if not mayWrite() or not vehicle or not IKST_VehicleIdentity.isDurableKey(key) then
        return false
    end
    local data = modDataFor(vehicle)
    if not data then
        return false
    end
    local want = tostring(key)
    local sqlId = IKST_VehicleIdentity.liveSqlId(vehicle)
    local changed = data[IKST_VehicleIdentity.KEY_FIELD] ~= want
    data[IKST_VehicleIdentity.KEY_FIELD] = want
    if sqlId and data[IKST_VehicleIdentity.SQL_FIELD] ~= sqlId then
        data[IKST_VehicleIdentity.SQL_FIELD] = sqlId
        changed = true
    end
    if changed then
        IKST_VehicleIdentity.transmit(vehicle)
    end
    return true
end
