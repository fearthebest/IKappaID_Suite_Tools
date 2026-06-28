require "IKST_Shared"
require "IKST_Access"
require "IKST_Args"
require "IKST_ClaimPolicy"

IKST_ServerGate = IKST_ServerGate or {}

local CATCH_COMMANDS = {
    catchTarget = true,
    catchPlayer = true,
    releaseTarget = true,
    releasePlayer = true,
}

local BASE_STAFF_MISC = {
    quickSave = true,
    quickBroadcast = true,
    staffListPlayers = true,
    listWaypoints = true,
    auditTail = true,
}

function IKST_ServerGate.ensureServerModules()
    if IKST.runsOnServerJvm and IKST.runsOnServerJvm() then
        if not IKST_RateLimit then
            require "IKST_RateLimit"
        end
        if not IKST_AuditLog then
            require "IKST_AuditLog"
        end
    end
end

function IKST_ServerGate.commandExists(command)
    if not command then
        return false
    end
    if IKST.Plugins and IKST.Plugins.findCommandSpec then
        local pluginId = IKST.Plugins.findCommandSpec(command)
        if pluginId then
            return true
        end
    end
    if IKST.STAFF_COMMANDS and IKST.STAFF_COMMANDS[command] then
        return true
    end
    if IKST.GUARD_COMMANDS and IKST.GUARD_COMMANDS[command] then
        return true
    end
    if command == IKST.CMD.threatCull or command == IKST.CMD.threatPopulation then
        return true
    end
    if command == IKST.CMD.quickWater or command == IKST.CMD.quickPower then
        return true
    end
    if command == IKST.CMD.journalRecord or command == IKST.CMD.journalRestore then
        return true
    end
    if command == IKST.CMD.briefingFetch then
        return true
    end
    if BASE_STAFF_MISC[command] then
        return true
    end
    return false
end

function IKST_ServerGate.checkRateAndArgs(player, command, args, meta)
    meta = meta or {}
    IKST_ServerGate.ensureServerModules()
    if IKST.runsOnServerJvm and IKST.runsOnServerJvm() and IKST_RateLimit then
        local okRate, retryMs, code = IKST_RateLimit.check(player, command)
        if not okRate then
            meta.retryAfterMs = retryMs
            return false, code or "rate_limit", meta
        end
    end

    if command == IKST.CMD.giveItem or command == IKST.CMD.giveTarget then
        if args.type and not IKST_Args.readItemType(args, "type") then
            return false, "bad_item_type", meta
        end
        if args.count ~= nil and IKST_Args.readAmount(args, "count", 1, 100) == nil then
            return false, "bad_count", meta
        end
    end

    if command == IKST.CMD.tpCoords then
        local x = IKST_Args.readCoord(args, "x")
        local y = IKST_Args.readCoord(args, "y")
        if x == nil or y == nil then
            return false, "bad_coords", meta
        end
    end

    if command == IKST.CMD.protectRadius or command == IKST.CMD.unprotectRadius then
        if IKST.runsOnServerJvm and IKST.runsOnServerJvm() and not IKST_Access.staffRemoteAdmin() then
            local x = IKST_Args.readCoord(args, "x") or (player and math.floor(player:getX()))
            local y = IKST_Args.readCoord(args, "y") or (player and math.floor(player:getY()))
            local z = tonumber(args and args.z) or (player and player:getZ()) or 0
            local radius = IKST_Args.readRadius(args, "radius")
            if x and y and not IKST_Args.actorNearCoord(player, x, y, z, radius + 2) then
                return false, "too_far", meta
            end
        end
    end

    if command == IKST.CMD.lockInstallKeypad then
        local dist = IKST_Access.sandboxInt("LockInstallDistance", 3, 1, 15)
        local x = IKST_Args.readCoord(args, "x") or (player and math.floor(player:getX()))
        local y = IKST_Args.readCoord(args, "y") or (player and math.floor(player:getY()))
        local z = tonumber(args and args.z) or (player and player:getZ()) or 0
        if x == nil or y == nil or not IKST_Args.actorNearCoord(player, x, y, z, dist) then
            return false, "too_far", meta
        end
    end

    if command == IKST.CMD.lockTryUnlock then
        local dist = IKST_Access.sandboxInt("LockInstallDistance", 3, 1, 15)
        local x = IKST_Args.readCoord(args, "x") or (player and math.floor(player:getX()))
        local y = IKST_Args.readCoord(args, "y") or (player and math.floor(player:getY()))
        local z = tonumber(args and args.z) or (player and player:getZ()) or 0
        if x == nil or y == nil or not IKST_Args.actorNearCoord(player, x, y, z, dist) then
            return false, "too_far", meta
        end
        if args.password ~= nil and IKST_Args.readPassword(args, "password") == nil then
            return false, "bad_password", meta
        end
    end

    if command == IKST.CMD.economyDeposit or command == IKST.CMD.economyWithdraw
        or command == IKST.CMD.economyExchange or command == IKST.CMD.economyExchangeAll
        or command == IKST.CMD.economyIdCardReissue then
        local x = IKST_Args.readCoord(args, "x") or (player and math.floor(player:getX()))
        local y = IKST_Args.readCoord(args, "y") or (player and math.floor(player:getY()))
        local z = tonumber(args and args.z) or (player and player:getZ()) or 0
        local maxDist = 6
        if IKST_Economy and IKST_Economy.shopMaxDistance then
            maxDist = IKST_Economy.shopMaxDistance() + 2
        end
        if x == nil or y == nil or not IKST_Economy.playerNearCoord(player, x, y, z, maxDist) then
            return false, "too_far", meta
        end
    end

    if command == IKST.CMD.economyVendSetPrice or command == IKST.CMD.economyVendDisable
        or command == IKST.CMD.economyVendBuy or command == IKST.CMD.economyVendClaim then
        local x = IKST_Args.readCoord(args, "x") or (player and math.floor(player:getX()))
        local y = IKST_Args.readCoord(args, "y") or (player and math.floor(player:getY()))
        local z = tonumber(args and args.z) or (player and player:getZ()) or 0
        local maxDist = 6
        if IKST_Economy and IKST_Economy.shopMaxDistance then
            maxDist = IKST_Economy.shopMaxDistance() + 2
        end
        if x == nil or y == nil or not IKST_Economy.playerNearCoord(player, x, y, z, maxDist) then
            return false, "too_far", meta
        end
    end

    if IKST.runsOnServerJvm and IKST.runsOnServerJvm() then
        if command == IKST.CMD.vehicleClaim and not IKST_Access.canUseTools(player) then
            local vid = IKST_Args.readVehicleId(args, "vehicleId")
            if vid then
                if not IKST_VehicleUtil then
                    require "IKST_VehicleUtil"
                end
                local v = IKST_VehicleUtil and IKST_VehicleUtil.getVehicle(vid)
                if not v then
                    return false, "bad_vehicle", meta
                end
                local vz = v.getZ and v:getZ() or 0
                if not IKST_Args.actorNearCoord(player, v:getX(), v:getY(), vz, IKST.getVehicleNearRadius()) then
                    return false, "too_far", meta
                end
            end
        end

        if command == IKST.CMD.safehouseClaim and not IKST_Access.canUseTools(player) then
            local x = IKST_Args.readCoord(args, "x") or (player and math.floor(player:getX()))
            local y = IKST_Args.readCoord(args, "y") or (player and math.floor(player:getY()))
            local z = tonumber(args and args.z) or (player and player:getZ()) or 0
            local dist = IKST_Access.sandboxInt("ClaimNearDistance", 8, 2, 32)
            if x == nil or y == nil or not IKST_Args.actorNearCoord(player, x, y, z, dist) then
                return false, "too_far", meta
            end
        end
    end

    return true, "ok", meta
end

function IKST_ServerGate.authorize(player, command, args)
    args = args or {}
    if not IKST.isModEnabled() then
        return false, "mod_disabled", {}
    end
    if not player or not command then
        return false, "bad_request", {}
    end

    local pluginId, spec, tier = nil, nil, nil
    if IKST.Plugins and IKST.Plugins.findCommandSpec then
        pluginId, spec, tier = IKST.Plugins.findCommandSpec(command)
    end

    if pluginId then
        local meta = { plugin = pluginId, tier = tier }
        if tier == "admin" then
            if not IKST_Access.canUseStaffTools(player) then
                return false, "staff_disabled", meta
            end
            if spec.canUseAdmin and not spec.canUseAdmin(player) then
                return false, "admin_only", meta
            end
        else
            if spec.canUsePlayer and not spec.canUsePlayer(player) then
                return false, "unavailable", meta
            end
        end
        if tier == "admin" and (pluginId == "tiles" or pluginId == "loot")
            and IKST_Lifecycle and not IKST_Lifecycle.isWorldReady() then
            return false, "world_loading", meta
        end
        return IKST_ServerGate.checkRateAndArgs(player, command, args, meta)
    end

    if command == IKST.CMD.quickWater or command == IKST.CMD.quickPower then
        if not IKST_Access.canToggleUtilities(player) then
            return false, "not_allowed", {}
        end
        if not IKST_Access.utilitiesToggleEnabled() then
            return false, "utilities_disabled", {}
        end
        return IKST_ServerGate.checkRateAndArgs(player, command, args, { group = "utility" })
    end

    if command == IKST.CMD.threatCull or command == IKST.CMD.threatPopulation then
        if not IKST_Access.canUseStaffTools(player) then
            return false, "staff_disabled", {}
        end
        if not IKST_Access.canUseThreatTools() then
            return false, "threat_disabled", {}
        end
        return IKST_ServerGate.checkRateAndArgs(player, command, args, { group = "threat" })
    end

    if IKST.STAFF_COMMANDS and IKST.STAFF_COMMANDS[command] then
        if not IKST_Access.canUseStaffTools(player) then
            return false, "staff_disabled", {}
        end
        return IKST_ServerGate.checkRateAndArgs(player, command, args, { group = "staff" })
    end

    if command == IKST.CMD.journalRecord or command == IKST.CMD.journalRestore then
        if not IKST_Access.canUseRecoveryJournal() then
            return false, "journal_disabled", {}
        end
        if not IKST_ClaimPolicy.playerClaimsEnabled() then
            return false, "claims_disabled", {}
        end
        return IKST_ServerGate.checkRateAndArgs(player, command, args, { group = "journal" })
    end

    if command == IKST.CMD.briefingFetch then
        if not IKST_Briefing or not IKST_Briefing.enabled() then
            return false, "briefing_disabled", {}
        end
        return IKST_ServerGate.checkRateAndArgs(player, command, args, { group = "list_query" })
    end

    if IKST.GUARD_COMMANDS and IKST.GUARD_COMMANDS[command] then
        if IKST.PLAYER_CLAIM_COMMANDS and IKST.PLAYER_CLAIM_COMMANDS[command] then
            if not IKST_ClaimPolicy.playerClaimsEnabled() then
                return false, "claims_disabled", {}
            end
            return IKST_ServerGate.checkRateAndArgs(player, command, args, { group = "claim" })
        end
        if not IKST_Access.canUseStaffTools(player) then
            return false, "staff_disabled", {}
        end
        if CATCH_COMMANDS[command] and not IKST_Access.canUseCatchJail() then
            return false, "catch_disabled", {}
        end
        return IKST_ServerGate.checkRateAndArgs(player, command, args, { group = "guard" })
    end

    if BASE_STAFF_MISC[command] then
        if not IKST_Access.canUseStaffTools(player) then
            return false, "staff_disabled", {}
        end
        return IKST_ServerGate.checkRateAndArgs(player, command, args, { group = "staff_misc" })
    end

    return false, "unknown_command", {}
end

function IKST_ServerGate.deny(player, command, args, reason, meta)
    IKST_ServerGate.ensureServerModules()
    meta = meta or {}
    local msg = reason or "not allowed"
    if msg == "rate_limit" and meta.retryAfterMs then
        msg = "rate limited (" .. tostring(math.ceil((meta.retryAfterMs or 0) / 1000)) .. "s)"
    elseif msg == "rate_limit" then
        msg = "rate limited"
    elseif msg == "staff_disabled" then
        msg = "staff tools disabled"
    elseif msg == "utilities_disabled" then
        msg = "utilities disabled"
    elseif msg == "threat_disabled" then
        msg = "threat tools disabled"
    elseif msg == "catch_disabled" then
        msg = "catch/jail disabled"
    elseif msg == "journal_disabled" then
        msg = "recovery journal disabled"
    elseif msg == "briefing_disabled" then
        msg = "server briefing disabled"
    elseif msg == "claims_disabled" then
        msg = "player claims disabled"
    elseif msg == "world_loading" then
        msg = "world loading"
    elseif msg == "unknown_command" then
        msg = "unknown command"
    elseif msg == "too_far" then
        msg = "too far"
    elseif msg == "bad_item_type" then
        msg = "invalid item type"
    elseif msg == "bad_count" then
        msg = "invalid count"
    elseif msg == "bad_coords" then
        msg = "invalid coordinates"
    elseif msg == "bad_password" then
        msg = "invalid password"
    elseif msg == "bad_vehicle" then
        msg = "invalid vehicle"
    end
    if IKST_AuditLog and IKST_AuditLog.record then
        IKST_AuditLog.record(player, command, args, false, msg)
    end
    return msg
end
