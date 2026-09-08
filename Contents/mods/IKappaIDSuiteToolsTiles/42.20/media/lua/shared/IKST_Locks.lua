-- Tile lock helpers: server-only passwords, public locked flags for clients.

require "IKST_Shared"
require "IKST_Authority"
require "IKST_ModDataSync"

IKST_Locks = IKST_Locks or {}

IKST_Locks.SECRETS_KEY = "IKST_Locks"
IKST_Locks.PUBLIC_KEY = "IKST_LocksPublic"

function IKST_Locks.key(x, y, z)
    return tostring(math.floor(tonumber(x) or 0)) .. ","
        .. tostring(math.floor(tonumber(y) or 0)) .. ","
        .. tostring(math.floor(tonumber(z) or 0))
end

function IKST_Locks.runsOnServer()
    if not IKST.isMultiplayerSession or not IKST.isMultiplayerSession() then
        return true
    end
    return IKST.runsOnServerJvm and IKST.runsOnServerJvm()
end

function IKST_Locks.secretsStore()
    return ModData.getOrCreate(IKST_Locks.SECRETS_KEY)
end

function IKST_Locks.publicStore()
    return ModData.getOrCreate(IKST_Locks.PUBLIC_KEY)
end

function IKST_Locks.requireServerMutate()
    if IKST_Authority and IKST_Authority.guardServerMutate then
        return IKST_Authority.guardServerMutate()
    end
    return IKST_Locks.runsOnServer()
end

function IKST_Locks.isHashedRecord(stored)
    return type(stored) == "table" and type(stored.s) == "string" and stored.s ~= ""
        and type(stored.h) == "string" and stored.h ~= ""
end

function IKST_Locks.isPlaintextRecord(stored)
    return type(stored) == "string" and stored ~= ""
end

function IKST_Locks.recordIsSet(stored)
    return IKST_Locks.isHashedRecord(stored) or IKST_Locks.isPlaintextRecord(stored)
end

function IKST_Locks.makeSalt()
    local parts = {}
    for i = 1, 4 do
        local n = 0
        if ZombRand then
            n = ZombRand(0, 2147483646)
        elseif getTimestampMs then
            n = getTimestampMs() + i
        else
            n = i * 7919
        end
        parts[i] = string.format("%08x", n)
    end
    return table.concat(parts, "")
end

function IKST_Locks.digest(text)
    text = tostring(text or "")
    local hash = 5381
    for i = 1, #text do
        hash = ((hash * 33) + string.byte(text, i)) % 2147483647
    end
    local hash2 = 2166136261
    for i = 1, #text do
        hash2 = (hash2 + string.byte(text, i) * 16777619) % 2147483647
    end
    return string.format("%08x%08x", hash, hash2)
end

function IKST_Locks.hashPassword(password, salt)
    if not password or password == "" then
        return nil
    end
    salt = salt or IKST_Locks.makeSalt()
    return {
        s = salt,
        h = IKST_Locks.digest(salt .. password),
    }
end

function IKST_Locks.passwordMatches(stored, password)
    if not password or password == "" or not stored then
        return false
    end
    if IKST_Locks.isHashedRecord(stored) then
        return IKST_Locks.digest(stored.s .. password) == stored.h
    end
    if IKST_Locks.isPlaintextRecord(stored) then
        return password == stored
    end
    return false
end

function IKST_Locks.migratePlaintextRecord(data, k, password)
    if not data or not k or not password or password == "" then
        return false
    end
    data.locks = data.locks or {}
    local hashed = IKST_Locks.hashPassword(password)
    if not hashed then
        return false
    end
    data.locks[k] = hashed
    return true
end

function IKST_Locks.rebuildPublic()
    if not IKST_Locks.requireServerMutate() then
        return
    end
    local sec = IKST_Locks.secretsStore()
    local pub = IKST_Locks.publicStore()
    pub.locked = {}
    sec.locks = sec.locks or {}
    for k, pw in pairs(sec.locks) do
        if IKST_Locks.recordIsSet(pw) then
            pub.locked[k] = true
        end
    end
    sec.clearance = sec.clearance or {}
    for k, zoneId in pairs(sec.clearance) do
        if zoneId and zoneId ~= "" then
            pub.locked[k] = true
        end
    end
end

function IKST_Locks.transmitPublic()
    if IKST.transmitModData and IKST.ModDataKeys and IKST.ModDataKeys.LocksPublic then
        IKST.transmitModData(IKST.ModDataKeys.LocksPublic)
    end
end

function IKST_Locks.getStoredRecord(x, y, z)
    if not IKST_Locks.runsOnServer() then
        return nil
    end
    local data = IKST_Locks.secretsStore()
    data.locks = data.locks or {}
    return data.locks[IKST_Locks.key(x, y, z)]
end

function IKST_Locks.setPassword(x, y, z, password)
    if not IKST_Locks.requireServerMutate() then
        return false
    end
    local data = IKST_Locks.secretsStore()
    data.locks = data.locks or {}
    local k = IKST_Locks.key(x, y, z)
    if password and password ~= "" then
        data.locks[k] = IKST_Locks.hashPassword(password)
    else
        data.locks[k] = nil
    end
    IKST_Locks.rebuildPublic()
    IKST_Locks.transmitPublic()
    return true
end

function IKST_Locks.getClearanceZone(x, y, z)
    if not IKST_Locks.runsOnServer() then
        return nil
    end
    local data = IKST_Locks.secretsStore()
    data.clearance = data.clearance or {}
    return data.clearance[IKST_Locks.key(x, y, z)]
end

function IKST_Locks.setClearanceZone(x, y, z, zoneId)
    if not IKST_Locks.requireServerMutate() then
        return false
    end
    local data = IKST_Locks.secretsStore()
    data.clearance = data.clearance or {}
    data.locks = data.locks or {}
    local k = IKST_Locks.key(x, y, z)
    if zoneId and zoneId ~= "" then
        data.clearance[k] = zoneId
        data.locks[k] = nil
    else
        data.clearance[k] = nil
    end
    IKST_Locks.rebuildPublic()
    IKST_Locks.transmitPublic()
    return true
end

function IKST_Locks.isClearanceLock(x, y, z)
    local zoneId = IKST_Locks.getClearanceZone(x, y, z)
    return zoneId ~= nil and zoneId ~= ""
end

function IKST_Locks.playerUnlocked(player, x, y, z)
    if not player or not player.getModData then
        return false
    end
    local md = player:getModData()
    md.IKST_unlocked = md.IKST_unlocked or {}
    return md.IKST_unlocked[IKST_Locks.key(x, y, z)] == true
end

function IKST_Locks.markUnlocked(player, x, y, z)
    if not player or not player.getModData then
        return
    end
    local md = player:getModData()
    md.IKST_unlocked = md.IKST_unlocked or {}
    md.IKST_unlocked[IKST_Locks.key(x, y, z)] = true
end

function IKST_Locks.isLocked(x, y, z)
    local k = IKST_Locks.key(x, y, z)
    local pub = IKST_Locks.publicStore()
    pub.locked = pub.locked or {}
    return pub.locked[k] == true
end

function IKST_Locks.mayAccess(player, x, y, z)
    if not IKST_Locks.isLocked(x, y, z) then
        return true
    end
    if IKST_Access and IKST_Access.canUseTools and IKST_Access.canUseTools(player) then
        return true
    end
    return IKST_Locks.playerUnlocked(player, x, y, z)
end

function IKST_Locks.tryUnlock(player, x, y, z, password)
    if not IKST_Locks.requireServerMutate() then
        return false, "server only"
    end
    if not IKST_Locks.isLocked(x, y, z) then
        return true, "not locked"
    end
    if IKST_Locks.isClearanceLock(x, y, z) then
        return false, "clearance required"
    end
    local data = IKST_Locks.secretsStore()
    data.locks = data.locks or {}
    local k = IKST_Locks.key(x, y, z)
    local stored = data.locks[k]
    if IKST_Locks.passwordMatches(stored, password) then
        if IKST_Locks.isPlaintextRecord(stored) then
            IKST_Locks.migratePlaintextRecord(data, k, password)
            IKST_Locks.rebuildPublic()
            IKST_Locks.transmitPublic()
        end
        IKST_Locks.markUnlocked(player, x, y, z)
        return true, "unlocked"
    end
    return false, "wrong password"
end

function IKST_Locks.tryClearanceUnlock(player, x, y, z)
    if not IKST_Locks.requireServerMutate() then
        return false, "server only"
    end
    if not IKST_Locks.isLocked(x, y, z) then
        return true, "not locked"
    end
    local zoneId = IKST_Locks.getClearanceZone(x, y, z)
    if not zoneId or zoneId == "" then
        return false, "not clearance lock"
    end
    if not IKST_Clearance then
        require "IKST_Clearance"
    end
    if not IKST_Clearance or not IKST_Clearance.findValidCardForZone then
        return false, "clearance unavailable"
    end
    local card = IKST_Clearance.findValidCardForZone(player, zoneId)
    if not card then
        return false, "no valid clearance tag"
    end
    IKST_Locks.markUnlocked(player, x, y, z)
    return true, "unlocked"
end

if IKST_Locks.runsOnServer() then
    IKST_Locks.rebuildPublic()
end
