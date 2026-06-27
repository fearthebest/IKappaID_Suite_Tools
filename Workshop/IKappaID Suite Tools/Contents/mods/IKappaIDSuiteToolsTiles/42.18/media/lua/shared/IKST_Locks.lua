-- Tile lock helpers (ModData IKST_Locks).

require "IKST_Shared"
require "IKST_ModDataSync"

IKST_Locks = IKST_Locks or {}

function IKST_Locks.key(x, y, z)
    return tostring(math.floor(tonumber(x) or 0)) .. ","
        .. tostring(math.floor(tonumber(y) or 0)) .. ","
        .. tostring(math.floor(tonumber(z) or 0))
end

function IKST_Locks.store()
    return ModData.getOrCreate("IKST_Locks")
end

function IKST_Locks.getPassword(x, y, z)
    local data = IKST_Locks.store()
    data.locks = data.locks or {}
    return data.locks[IKST_Locks.key(x, y, z)]
end

function IKST_Locks.setPassword(x, y, z, password)
    if IKST.isMultiplayerSession and IKST.isMultiplayerSession() then
        if not IKST.runsOnServerJvm or not IKST.runsOnServerJvm() then
            return false
        end
    end
    local data = IKST_Locks.store()
    data.locks = data.locks or {}
    local k = IKST_Locks.key(x, y, z)
    if password and password ~= "" then
        data.locks[k] = password
    else
        data.locks[k] = nil
    end
    if IKST.transmitModData then
        IKST.transmitModData(IKST.ModDataKeys.Locks)
    end
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
    local pw = IKST_Locks.getPassword(x, y, z)
    return pw ~= nil and pw ~= ""
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
