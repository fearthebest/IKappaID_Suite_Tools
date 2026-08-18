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
    if IKST.PLAYER_SELF_COMMANDS and IKST.PLAYER_SELF_COMMANDS[command] then
        return true
    end
    if IKST.PLAYER_CLAIM_COMMANDS and IKST.PLAYER_CLAIM_COMMANDS[command] then
        return true
    end
    if IKST.CORE_COMMANDS and IKST.CORE_COMMANDS[command] then
        return true
    end
    if IKST.CORE_STAFF_COMMANDS and IKST.CORE_STAFF_COMMANDS[command] then
        return true
    end
    return false
end

function IKST_ServerGate.checkRateAndArgs(player, command, args, meta)
    meta = meta or {}
    IKST_ServerGate.ensureServerModules()

    if command == IKST.CMD.giveItem or command == IKST.CMD.giveTarget then
        if not IKST_Args.readItemType(args, "type") then
            return false, "bad_item_type", meta
        end
        if args.count ~= nil and IKST_Args.readAmount(args, "count", 1, 100) == nil then
            return false, "bad_count", meta
        end
    end

    if command == IKST.CMD.economyGive or command == IKST.CMD.economyGiveTarget then
        if args.amount ~= nil and IKST_Args.readAmount(args, "amount", 1, IKST.STAFF_ECONOMY_GIVE_MAX) == nil then
            return false, "bad_amount", meta
        end
    end

    if command == IKST.CMD.tpCoords then
        local x = IKST_Args.readCoord(args, "x")
        local y = IKST_Args.readCoord(args, "y")
        if x == nil or y == nil then
            return false, "bad_coords", meta
        end
        local z = tonumber(args and args.z) or 0
        if not IKST_Args.mapSquareExists(x, y, z) then
            return false, "bad_coords", meta
        end
    end

    if command == IKST.CMD.toggleSelfCheat then
        local cheatId = IKST_Args.readCheatId(args)
        if not cheatId then
            return false, "bad_cheat", meta
        end
        if not IKST_StaffCheats then
            require "IKST_StaffCheats"
        end
        if not IKST_StaffCheats or not IKST_StaffCheats.isValidId(cheatId) then
            return false, "bad_cheat", meta
        end
    end

    if command == IKST.CMD.saveWaypoint then
        if not IKST_Waypoints then
            require "IKST_Waypoints"
        end
        local name = IKST_Waypoints and IKST_Waypoints.normalizeName(args and args.name) or nil
        if not name then
            return false, "bad_name", meta
        end
        args.name = name
    end

    if command == IKST.CMD.clearanceIssueSelf or command == IKST.CMD.clearanceIssueTarget
        or command == IKST.CMD.clearanceSetLock then
        if not IKST_Args.readZoneId(args, "zoneId") then
            return false, "bad_zone", meta
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

    if command == IKST.CMD.protectSquare or command == IKST.CMD.unprotectSquare
        or command == IKST.CMD.setDropbox or command == IKST.CMD.setReadonly then
        if IKST.runsOnServerJvm and IKST.runsOnServerJvm() then
            local x = IKST_Args.readCoord(args, "x") or (player and math.floor(player:getX()))
            local y = IKST_Args.readCoord(args, "y") or (player and math.floor(player:getY()))
            local z = tonumber(args and args.z) or (player and player:getZ()) or 0
            local dist = IKST_Access.sandboxInt("ClaimNearDistance", 8, 2, 32)
            if x == nil or y == nil or not IKST_Args.requireNearOrRemoteAdmin(player, x, y, z, dist) then
                return false, "too_far", meta
            end
        end
    end

    if command == IKST.CMD.protectVehicle or command == IKST.CMD.unprotectVehicle then
        if IKST.runsOnServerJvm and IKST.runsOnServerJvm() then
            local vid = IKST_Args.readVehicleId(args, "vehicleId")
            if not vid then
                return false, "bad_vehicle", meta
            end
            if not IKST_VehicleUtil then
                require "IKST_VehicleUtil"
            end
            local v = IKST_VehicleUtil and type(IKST_VehicleUtil.getVehicle) == "function" and IKST_VehicleUtil.getVehicle(vid)
            if not v then
                return false, "bad_vehicle", meta
            end
            local vz = (type(v.getZ) == "function" and v:getZ()) or 0
            local nearR = IKST.getVehicleNearRadius and IKST.getVehicleNearRadius() or 12
            if not IKST_Args.requireNearOrRemoteAdmin(player, v:getX(), v:getY(), vz, nearR) then
                return false, "too_far", meta
            end
        end
    end

    if command == IKST.CMD.vehicleDeleteCell or command == IKST.CMD.vehiclePrune then
        if IKST.runsOnServerJvm and IKST.runsOnServerJvm() then
            local x = IKST_Args.readCoord(args, "x") or IKST_Args.readCoord(args, "cellX")
            local y = IKST_Args.readCoord(args, "y") or IKST_Args.readCoord(args, "cellY")
            if command == IKST.CMD.vehicleDeleteCell then
                local cellX = IKST_Args.readCoord(args, "cellX")
                local cellY = IKST_Args.readCoord(args, "cellY")
                if cellX ~= nil and cellY ~= nil then
                    x = cellX * 300 + 150
                    y = cellY * 300 + 150
                end
            end
            x = x or (player and math.floor(player:getX()))
            y = y or (player and math.floor(player:getY()))
            local z = tonumber(args and args.z) or (player and player:getZ()) or 0
            local maxDist = 80
            if command == IKST.CMD.vehiclePrune then
                if IKST_Args.readBool(args and args.cell) == true then
                    x = player and math.floor(player:getX())
                    y = player and math.floor(player:getY())
                    if x ~= nil and y ~= nil then
                        local cellX = math.floor(x / 300)
                        local cellY = math.floor(y / 300)
                        x = cellX * 300 + 150
                        y = cellY * 300 + 150
                    end
                    maxDist = 80
                else
                    maxDist = IKST.clampRadius(args and args.radius) + 4
                end
            end
            if x == nil or y == nil or not IKST_Args.requireNearOrRemoteAdmin(player, x, y, z, maxDist) then
                return false, "too_far", meta
            end
        end
    end

    if command == IKST.CMD.vehicleClaimNearby then
        if IKST.runsOnServerJvm and IKST.runsOnServerJvm() and not IKST_Access.canUseTools(player) then
            -- Non-staff: always scan from actor position (ignore client coords).
            if player then
                args.x = math.floor(player:getX())
                args.y = math.floor(player:getY())
                args.z = player:getZ() or 0
            end
        elseif IKST.runsOnServerJvm and IKST.runsOnServerJvm() then
            local x = IKST_Args.readCoord(args, "x") or (player and math.floor(player:getX()))
            local y = IKST_Args.readCoord(args, "y") or (player and math.floor(player:getY()))
            local z = tonumber(args and args.z) or (player and player:getZ()) or 0
            local radius = IKST_Args.readRadius(args, "radius")
            if x == nil or y == nil or not IKST_Args.requireNearOrRemoteAdmin(player, x, y, z, radius + 4) then
                return false, "too_far", meta
            end
        end
    end

    if command == IKST.CMD.lockInstallKeypad or command == IKST.CMD.lockTryUnlock
        or command == IKST.CMD.lockTryClearance
        or command == IKST.CMD.lockSetPassword or command == IKST.CMD.lockClear
        or command == IKST.CMD.clearanceSetLock then
        local dist = IKST_Access.sandboxInt("LockInstallDistance", 3, 1, 15)
        local x = IKST_Args.readCoord(args, "x") or (player and math.floor(player:getX()))
        local y = IKST_Args.readCoord(args, "y") or (player and math.floor(player:getY()))
        local z = tonumber(args and args.z) or (player and player:getZ()) or 0
        if x == nil or y == nil or not IKST_Args.actorNearCoord(player, x, y, z, dist) then
            return false, "too_far", meta
        end
    end

    if command == IKST.CMD.lockTryUnlock or command == IKST.CMD.lockInstallKeypad
        or command == IKST.CMD.lockSetPassword then
        if args.password ~= nil and IKST_Args.readPassword(args, "password") == nil then
            return false, "bad_password", meta
        end
        if command ~= IKST.CMD.lockTryUnlock and args.password ~= nil then
            args.password = IKST_Args.readPassword(args, "password")
        end
    end

    if command == IKST.CMD.economyDeposit or command == IKST.CMD.economyWithdraw
        or command == IKST.CMD.economyWire or command == IKST.CMD.economyPayRequest then
        local maxAmt = IKST.STAFF_ECONOMY_GIVE_MAX or 500000
        if args.amount ~= nil and IKST_Args.readAmount(args, "amount", 1, maxAmt) == nil then
            return false, "bad_amount", meta
        end
    end

    if command == IKST.CMD.economySetPref then
        if args.autoAccept ~= nil and IKST_Args.readBool(args.autoAccept) == nil then
            return false, "bad_pref", meta
        end
    end

    if command == IKST.CMD.economyPayRespond then
        if args.accept ~= nil and IKST_Args.readBool(args.accept) == nil then
            return false, "bad_accept", meta
        end
    end

    if command == IKST.CMD.economyDelivery or command == IKST.CMD.economyPlayerBounty then
        local msg = args and args.message
        if msg ~= nil and type(msg) ~= "string" then
            return false, "bad_message", meta
        end
        if type(msg) == "string" and #msg > 512 then
            args.message = string.sub(msg, 1, 512)
        end
    end

    if command == IKST.CMD.economyDeposit or command == IKST.CMD.economyWithdraw
        or command == IKST.CMD.economyExchange or command == IKST.CMD.economyExchangeAll
        or command == IKST.CMD.economyIdCardReissue then
        if not IKST_Economy or type(IKST_Economy.playerNearCoord) ~= "function" then
            return false, "economy_unavailable", meta
        end
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
        if not IKST_Economy or type(IKST_Economy.playerNearCoord) ~= "function" then
            return false, "economy_unavailable", meta
        end
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
                local vz = type(v.getZ) == "function" and v:getZ() or 0
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

    if IKST.runsOnServerJvm and IKST.runsOnServerJvm() and not IKST_Access.staffRemoteAdmin() then
        local tileCmd = command == IKST.CMD.cleanupObject
            or command == IKST.CMD.cleanupTile
            or command == IKST.CMD.cleanupSquare
            or command == IKST.CMD.paintRemove
            or command == IKST.CMD.cleanupRadius
            or command == IKST.CMD.cleanupCube
            or command == IKST.CMD.cleanupRoom
            or command == IKST.CMD.cleanupBuilding
            or command == IKST.CMD.cleanupVegetation
            or command == IKST.CMD.paintPlace
        if tileCmd then
            local x = IKST_Args.readCoord(args, "x") or (player and math.floor(player:getX()))
            local y = IKST_Args.readCoord(args, "y") or (player and math.floor(player:getY()))
            local z = tonumber(args and args.z) or (player and player:getZ()) or 0
            if x == nil or y == nil then
                return false, "bad_coords", meta
            end
            local maxDist = 12
            if command == IKST.CMD.cleanupRadius or command == IKST.CMD.cleanupVegetation then
                maxDist = IKST.clampRadius(args.radius) + 2
            elseif command == IKST.CMD.cleanupCube then
                maxDist = (IKST.clampCubeHalf(args.halfExtent) * 2) + 4
            elseif command == IKST.CMD.cleanupRoom or command == IKST.CMD.cleanupBuilding then
                maxDist = IKST_Access.sandboxInt("ClaimNearDistance", 8, 2, 32)
            else
                local maxR = IKST.getMaxPaintRadius and IKST.getMaxPaintRadius() or 25
                maxDist = maxR + 2
            end
            if not IKST_Args.actorNearCoord(player, x, y, z, maxDist) then
                return false, "too_far", meta
            end
        end

        if command == IKST.CMD.lootRepopulateContainer or command == IKST.CMD.lootRepopulateZone then
            local x = IKST_Args.readCoord(args, "x") or (player and math.floor(player:getX()))
            local y = IKST_Args.readCoord(args, "y") or (player and math.floor(player:getY()))
            local z = tonumber(args and args.z) or (player and player:getZ()) or 0
            local maxDist = 12
            if command == IKST.CMD.lootRepopulateZone then
                if args.scope == IKST.CLEANUP_SCOPES.cell then
                    if player then
                        args.x = math.floor(player:getX())
                        args.y = math.floor(player:getY())
                        args.z = player:getZ() or 0
                        x = args.x
                        y = args.y
                        z = args.z
                    end
                    maxDist = 80
                elseif args.scope == IKST.CLEANUP_SCOPES.radius then
                    if IKST.clampLootRadius then
                        maxDist = IKST.clampLootRadius(args.radius) + 2
                        args.radius = IKST.clampLootRadius(args.radius)
                    else
                        maxDist = IKST.clampRadius(args.radius) + 2
                    end
                elseif args.scope == IKST.CLEANUP_SCOPES.building or args.scope == IKST.CLEANUP_SCOPES.room then
                    local maxR = type(IKST.getMaxCleanupRadius) == "function" and IKST.getMaxCleanupRadius() or 50
                    maxDist = maxR + 2
                else
                    maxDist = 12
                end
            end
            if x == nil or y == nil or not IKST_Args.actorNearCoord(player, x, y, z, maxDist) then
                return false, "too_far", meta
            end
            if args.onlyEmpty ~= nil and type(args.onlyEmpty) ~= "boolean" then
                return false, "bad_filter", meta
            end
            if args.skipLocked ~= nil and type(args.skipLocked) ~= "boolean" then
                return false, "bad_filter", meta
            end
            if args.skipClaimed ~= nil and type(args.skipClaimed) ~= "boolean" then
                return false, "bad_filter", meta
            end
            if args.preserveExisting ~= nil and type(args.preserveExisting) ~= "boolean" then
                return false, "bad_filter", meta
            end
            if args.lootTable ~= nil then
                if type(args.lootTable) ~= "string" then
                    return false, "bad_loot_table", meta
                end
                if args.lootTable ~= "residential" and args.lootTable ~= "grocery"
                    and args.lootTable ~= "medical" and args.lootTable ~= "event"
                    and args.lootTable ~= "military" then
                    return false, "bad_loot_table", meta
                end
            end
            args.onlyEmpty = args.onlyEmpty == true
            args.skipLocked = args.skipLocked == true
            args.skipClaimed = args.skipClaimed == true
            args.preserveExisting = args.preserveExisting == true
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

    IKST_ServerGate.ensureServerModules()
    if IKST.runsOnServerJvm and IKST.runsOnServerJvm() and IKST_RateLimit then
        local okRate, retryMs, code = IKST_RateLimit.check(player, command)
        if not okRate then
            return false, code or "rate_limit", { retryAfterMs = retryMs }
        end
    end

    if IKST.isMultiplayerSession and IKST.isMultiplayerSession() then
        if not IKST_Identity then
            require "IKST_Identity"
        end
        if IKST_Identity and type(IKST_Identity.steamId) == "function"
            and not IKST_Identity.steamId(player) then
            if type(IKST_Debug) == "table" and IKST_Debug.logVerbose then
                IKST_Debug.logVerbose("identity", "MP player without SteamID: " .. IKST_Debug.playerBrief(player))
            end
        end
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

    if command == IKST.CMD.vehicleClaimPing then
        if not IKST.isMultiplayerSession or not IKST.isMultiplayerSession() then
            return false, "unavailable", {}
        end
        return IKST_ServerGate.checkRateAndArgs(player, command, args, { group = "list_query" })
    end

    if command == IKST.CMD.safehouseClaimPing then
        if not IKST.isMultiplayerSession or not IKST.isMultiplayerSession() then
            return false, "unavailable", {}
        end
        return IKST_ServerGate.checkRateAndArgs(player, command, args, { group = "list_query" })
    end

    if IKST.PLAYER_SELF_COMMANDS and IKST.PLAYER_SELF_COMMANDS[command] then
        if command == IKST.CMD.helpRequest or command == IKST.CMD.reportPlayer
            or command == IKST.CMD.claimDispute then
            local msg = args and args.message
            if msg ~= nil and type(msg) ~= "string" then
                return false, "bad_message", { group = "player_self" }
            end
            local maxLen = 120
            if command == IKST.CMD.reportPlayer or command == IKST.CMD.claimDispute then
                maxLen = 512
            end
            if type(msg) == "string" and #msg > maxLen then
                args.message = string.sub(msg, 1, maxLen)
            end
        end
        if command == IKST.CMD.claimRequest then
            local keys = { "x1", "y1", "z1", "x2", "y2", "z2" }
            for _, key in ipairs(keys) do
                if IKST_Args.readCoord(args, key) == nil then
                    return false, "bad_coords", { group = "player_self" }
                end
            end
        end
        return IKST_ServerGate.checkRateAndArgs(player, command, args, { group = "player_self" })
    end

    if IKST.GUARD_COMMANDS and IKST.GUARD_COMMANDS[command] then
        if IKST.PLAYER_CLAIM_COMMANDS and IKST.PLAYER_CLAIM_COMMANDS[command] then
            local staff = IKST_Access.canUseStaffTools(player)
            if not staff then
                if IKST.PLAYER_CLAIM_CREATE and IKST.PLAYER_CLAIM_CREATE[command] then
                    if not IKST_ClaimPolicy.playerClaimsEnabled() then
                        return false, "claims_need_staff", {}
                    end
                elseif IKST.PLAYER_CLAIM_MANAGE and IKST.PLAYER_CLAIM_MANAGE[command] then
                    -- owner manage of an already-approved claim; GuardOps checks ownership
                else
                    if not IKST_ClaimPolicy.playerClaimsEnabled() then
                        return false, "claims_disabled", {}
                    end
                end
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

    if IKST.CORE_STAFF_COMMANDS and IKST.CORE_STAFF_COMMANDS[command] then
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
    local code = reason or "not_allowed"
    local msg = code
    if code == "rate_limit" and meta.retryAfterMs then
        msg = "rate limited (" .. tostring(math.ceil((meta.retryAfterMs or 0) / 1000)) .. "s)"
    elseif code == "rate_limit" then
        msg = "rate limited"
    elseif code == "staff_disabled" then
        msg = "staff tools disabled"
    elseif code == "utilities_disabled" then
        msg = "utilities disabled"
    elseif code == "threat_disabled" then
        msg = "threat tools disabled"
    elseif code == "catch_disabled" then
        msg = "catch/jail disabled"
    elseif code == "journal_disabled" then
        msg = "recovery journal disabled"
    elseif code == "briefing_disabled" then
        msg = "server briefing disabled"
    elseif code == "claims_disabled" then
        msg = "player claims disabled"
    elseif code == "claims_need_staff" then
        msg = "staff must approve claims"
    elseif code == "respawn_disabled" then
        msg = "safehouse respawn disabled"
    elseif code == "world_loading" then
        msg = "world loading"
    elseif code == "unknown_command" then
        msg = "unknown command"
    elseif code == "too_far" then
        msg = "too far"
    elseif code == "bad_item_type" then
        msg = "invalid item type"
    elseif code == "bad_count" then
        msg = "invalid count"
    elseif code == "bad_coords" then
        msg = "invalid coordinates"
    elseif code == "bad_password" then
        msg = "invalid password"
    elseif code == "bad_vehicle" then
        msg = "invalid vehicle"
    elseif code == "economy_unavailable" then
        msg = "economy module unavailable"
    elseif code == "not_allowed" or code == "admin_only" or code == "unavailable" then
        msg = "not allowed"
    elseif code == "mod_disabled" then
        msg = "mod disabled"
    elseif code == "bad_request" then
        msg = "bad request"
    end
    meta.code = code
    meta.message = msg
    if meta.plugin == nil and IKST.Plugins and IKST.Plugins.findCommandSpec then
        local pluginId = IKST.Plugins.findCommandSpec(command)
        if pluginId then
            meta.plugin = pluginId
        end
    end
    if IKST_AuditLog and IKST_AuditLog.record then
        IKST_AuditLog.record(player, command, args, false, msg)
    end
    if type(IKST_Debug) == "table" and IKST_Debug.logDeny then
        IKST_Debug.logDeny(command, player, msg, args)
    end
    return msg, meta
end
