-- Tile lock helpers: server-only passwords, public locked flags for clients.

require "IKST_Shared"
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

function IKST_Locks.rebuildPublic()
    if not IKST_Locks.runsOnServer() then
        return
    end
    local sec = IKST_Locks.secretsStore()
    local pub = IKST_Locks.publicStore()
    pub.locked = {}
    sec.locks = sec.locks or {}
    for k, pw in pairs(sec.locks) do
        if pw and pw ~= "" then
            pub.locked[k] = true
        end
    end
end

function IKST_Locks.transmitPublic()
    if IKST.transmitModData and IKST.ModDataKeys and IKST.ModDataKeys.LocksPublic then
        IKST.transmitModData(IKST.ModDataKeys.LocksPublic)
    end
end

function IKST_Locks.getPassword(x, y, z)
    if not IKST_Locks.runsOnServer() then
        return nil
    end
    local data = IKST_Locks.secretsStore()
    data.locks = data.locks or {}
    return data.locks[IKST_Locks.key(x, y, z)]
end

function IKST_Locks.setPassword(x, y, z, password)
    if not IKST_Locks.runsOnServer() then
        return false
    end
    local data = IKST_Locks.secretsStore()
    data.locks = data.locks or {}
    local k = IKST_Locks.key(x, y, z)
    if password and password ~= "" then
        data.locks[k] = password
    else
        data.locks[k] = nil
    end
    IKST_Locks.rebuildPublic()
    IKST_Locks.transmitPublic()
    return true
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
    if not IKST_Locks.runsOnServer() then
        return false, "server only"
    end
    if not IKST_Locks.isLocked(x, y, z) then
        return true, "not locked"
    end
    local expected = IKST_Locks.getPassword(x, y, z)
    if expected and password and password == expected then
        IKST_Locks.markUnlocked(player, x, y, z)
        return true, "unlocked"
    end
    return false, "wrong password"
end

if IKST_Locks.runsOnServer() then
    IKST_Locks.rebuildPublic()
end
