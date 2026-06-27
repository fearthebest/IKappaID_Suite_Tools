require "IKST_Shared"

IKST_Access = IKST_Access or {}

function IKST_Access.sandbox()
    return SandboxVars and SandboxVars.IKappaIDSuiteTools or nil
end

function IKST_Access.sandboxBool(key, fallback)
    local sv = IKST_Access.sandbox()
    if not sv or sv[key] == nil then
        return fallback == true
    end
    return sv[key] == true
end

function IKST_Access.sandboxInt(key, fallback, minVal, maxVal)
    local sv = IKST_Access.sandbox()
    local v = sv and sv[key]
    if v == nil then
        v = fallback
    end
    v = tonumber(v)
    if not v then
        v = fallback or 0
    end
    if minVal and v < minVal then
        v = minVal
    end
    if maxVal and v > maxVal then
        v = maxVal
    end
    return math.floor(v)
end

function IKST_Access.canUseEconomy(player)
    if not IKST.isModEnabled() then
        return false
    end
    if not IKST.Plugins or not IKST.Plugins.isActive("economy") then
        return false
    end
    player = IKST.resolvePlayer(player)
    if not player then
        return false
    end
    if not IKST_Economy or not IKST_Economy.isEnabled then
        return false
    end
    return IKST_Economy.isEnabled()
end

function IKST_Access.canUseLoot(player)
    if not IKST.isModEnabled() then
        return false
    end
    if not IKST.Plugins or not IKST.Plugins.isActive("loot") then
        return false
    end
    return IKST_Access.canUseStaffTools(player)
end

function IKST_Access.isSinglePlayer()
    if type(isMultiplayer) == "function" then
        return not isMultiplayer()
    end
    if getWorld and getWorld() and getWorld().getGameMode then
        local mode = getWorld():getGameMode()
        if mode == "Multiplayer" then
            return false
        end
    end
    return true
end

function IKST_Access.isAdmin(player)
    player = IKST.resolvePlayer(player)
    if not IKST.isModEnabled() then
        return false
    end
    if not player then
        return false
    end
    if IKST_Access.isSinglePlayer() then
        return true
    end
    if IKST.isCoopHostPlayer and IKST.isCoopHostPlayer(player) then
        return true
    end
    if isAdmin and isAdmin() then
        return true
    end
    local lvl = ""
    if player.getAccessLevel then
        lvl = string.lower(tostring(player:getAccessLevel() or ""))
    elseif getAccessLevel then
        lvl = string.lower(tostring(getAccessLevel() or ""))
    end
    return lvl == "admin"
end

function IKST_Access.canUseTools(player)
    return IKST_Access.isAdmin(player)
end

function IKST_Access.canUseStaffTools(player)
    if not IKST_Access.canUseTools(player) then
        return false
    end
    if IKST_Access.isSinglePlayer() then
        return true
    end
    if IKST.isCoopHostPlayer and IKST.isCoopHostPlayer(player) then
        return true
    end
    return IKST_Access.sandboxBool("StaffToolsEnabled", true)
end

function IKST_Access.canUseThreatTools()
    return IKST_Access.sandboxBool("EnableThreatTools", true)
end

function IKST_Access.canUseCatchJail()
    return IKST_Access.sandboxBool("EnableCatchJail", true)
end

function IKST_Access.utilitiesToggleEnabled()
    return IKST_Access.sandboxBool("EnableUtilitiesToggle", true)
end

function IKST_Access.canUseRecoveryJournal()
    return IKST_Access.sandboxBool("RecoveryJournalEnabled", true)
end

function IKST_Access.staffRemoteAdmin()
    return IKST_Access.sandboxBool("StaffRemoteAdmin", false)
end

function IKST_Access.claimListMaxSize()
    return IKST_Access.sandboxInt("ClaimListMaxSize", 200, 10, 1000)
end

function IKST_Access.canToggleUtilities(player)
    if IKST_Access.isSinglePlayer() then
        return true
    end
    if not IKST_Access.utilitiesToggleEnabled() then
        return false
    end
    player = IKST.resolvePlayer(player)
    if not player then
        return false
    end
    if IKST.isCoopHostPlayer and IKST.isCoopHostPlayer(player) then
        return true
    end
    local lvl = ""
    if player.getAccessLevel then
        lvl = string.lower(tostring(player:getAccessLevel() or ""))
    end
    return lvl == "admin" or lvl == "moderator" or lvl == "gm" or lvl == "overseer"
end

function IKST_Access.canOpenPanel(player)
    if not IKST.isModEnabled() then
        return false
    end
    player = IKST.resolvePlayer(player)
    if not player then
        return false
    end
    if IKST_Access.isAdmin(player) then
        return true
    end
    if IKST_Access.canUseEconomy(player) then
        return true
    end
    return true
end

function IKST_Access.canUseWorkspace(player, workspaceId)
    if not IKST.isModEnabled() or not workspaceId then
        return false
    end
    player = IKST.resolvePlayer(player)
    if workspaceId == IKST.VIEW.utilities then
        return IKST_Access.isAdmin(player)
    end
    if workspaceId == IKST.VIEW.tiles then
        return IKST_Access.isAdmin(player) and IKST.Plugins and IKST.Plugins.isActive("tiles")
    end
    if workspaceId == IKST.VIEW.vehicles then
        return IKST_Access.isAdmin(player) and IKST.Plugins and IKST.Plugins.isActive("vehicles")
    end
    if workspaceId == IKST.VIEW.claim or workspaceId == IKST.VIEW.everyone then
        return IKST_Access.canOpenPanel(player)
    end
    if workspaceId == IKST.VIEW.economy then
        return IKST_Access.canUseEconomy(player)
    end
    if workspaceId == IKST.VIEW.loot then
        return IKST_Access.canUseLoot(player)
    end
    return false
end
