-- World Guard server operations.
if type(isClient) == "function" and isClient()
    and type(isServer) == "function" and not isServer() then
    return
end

require "IKST_Shared"
require "IKST_Access"
require "IKST_Args"
require "IKST_Grid"
require "IKST_Claim"
require "IKST_ClaimPolicy"
require "IKST_ClaimSocial"
require "IKST_Identity"
require "IKST_WorldOps"
require "IKST_StaffOps"
require "IKST_VehicleIdentity"
require "IKST_VehicleClaim"
require "IKST_VehicleUtil"
require "IKST_SafehouseClaim"
require "IKST_SafehousePermissions"
require "IKST_PhunZones"
require "IKST_SafeHouse"
require "IKST_ModDataSync"
require "IKST_GuardOps_VehicleClaim"
require "IKST_GuardOps_Catch"
require "IKST_GuardOps_Safehouse"
require "IKST_Policy"

IKST_GuardOps = IKST_GuardOps or {}

function IKST_GuardOps.claimLocationPolicyBlocked(player, x, y, z)
    if not player then
        return false, nil
    end
    if not IKST_Policy then
        require "IKST_Policy"
    end
    if not IKST_Policy.respectClaims("claim") then
        return false, nil
    end
    local allowed, reason = IKST_Policy.locationAllowedAtCoord(player, x, y, z, "claim")
    if allowed == true then
        return false, nil
    end
    return true, reason or "not_your_claim"
end

function IKST_GuardOps.worldRulesData()
    local data = ModData.getOrCreate("IKST_WorldRules")
    if not data.rules then
        data.rules = { disableDestroy = false, disablePickup = false }
    end
    if not data.spriteBlacklist then
        data.spriteBlacklist = {}
    end
    if data.showSafehouseBorders == nil then
        data.showSafehouseBorders = false
    end
    return data
end

function IKST_GuardOps.username(player)
    if not player then
        return nil
    end
    if player.getUsername then
        local name = player:getUsername()
        if name and name ~= "" then
            return name
        end
    end
    if player.getDisplayName then
        local name = player:getDisplayName()
        if name and name ~= "" then
            return name
        end
    end
    if type(player.getDescriptor) == "function" and player:getDescriptor() and player:getDescriptor().getForename then
        local desc = player:getDescriptor()
        local fore = desc:getForename() or ""
        local sur = type(desc.getSurname) == "function" and desc:getSurname() or ""
        local full = string.gsub(fore .. " " .. sur, "^%s*(.-)%s*$", "%1")
        if full ~= "" then
            return full
        end
    end
    return "Player"
end

function IKST_GuardOps.toggleCreative(player)
    if not player or not player.setBuildCheat or not player.isBuildCheat then
        return false, "unavailable"
    end
    local on = not player:isBuildCheat()
    player:setBuildCheat(on)
    return true, on and "creative ON" or "creative OFF"
end

function IKST_GuardOps.toggleUnlimitedAmmo(player)
    if not player or not player.setUnlimitedAmmo or not player.isUnlimitedAmmo then
        return false, "unavailable"
    end
    local on = not player:isUnlimitedAmmo()
    player:setUnlimitedAmmo(on)
    return true, on and "unlimited ammo ON" or "unlimited ammo OFF"
end

function IKST_GuardOps.lightbulbsInRadius(cx, cy, cz, radius)
    local squares = IKST_Grid.squaresInRadius(cx, cy, cz, radius)
    local count = 0
    for _, sq in ipairs(squares) do
        local objects = sq:getObjects()
        if objects then
            for i = 0, objects:size() - 1 do
                local obj = objects:get(i)
                if obj and obj.getSprite then
                    local sprite = obj:getSprite()
                    local name = sprite and sprite.getName and string.lower(sprite:getName() or "") or ""
                    if string.find(name, "light", 1, true) or string.find(name, "lamp", 1, true) then
                        if obj.setActivated then
                            obj:setActivated(true)
                            count = count + 1
                        end
                    end
                end
            end
        end
    end
    return true, "lights " .. count
end

function IKST_GuardOps.dumpPlayers(admin)
    local out = {}
    local list = getOnlinePlayers and getOnlinePlayers()
    if list and list.size and list.get then
        for i = 0, list:size() - 1 do
            local p = list:get(i)
            if p then
                out[#out + 1] = {
                    id = type(p.getOnlineID) == "function" and p:getOnlineID() or i,
                    name = IKST_StaffOps.playerLabel(p),
                    x = math.floor(p:getX()),
                    y = math.floor(p:getY()),
                    z = p:getZ(),
                }
            end
        end
    elseif admin then
        out[1] = {
            id = type(admin.getOnlineID) == "function" and admin:getOnlineID() or 0,
            name = IKST_StaffOps.playerLabel(admin),
            x = math.floor(admin:getX()),
            y = math.floor(admin:getY()),
            z = admin:getZ(),
        }
    end
    return out
end

function IKST_GuardOps.pageSlice(list, offset, limit)
    local maxCap = IKST_Access and IKST_Access.claimListMaxSize and IKST_Access.claimListMaxSize() or 200
    offset = math.max(0, math.floor(tonumber(offset) or 0))
    if limit == nil then
        limit = maxCap
    else
        limit = math.floor(tonumber(limit) or 50)
        if limit < 1 then
            limit = 50
        end
        if limit > maxCap then
            limit = maxCap
        end
    end
    list = list or {}
    local total = #list
    local sliced = {}
    local last = math.min(total, offset + limit)
    for i = offset + 1, last do
        sliced[#sliced + 1] = list[i]
    end
    local hasMore = (offset + #sliced) < total
    return sliced, total, hasMore, offset, limit
end

function IKST_GuardOps.sendClaimList(player, list, offset, limit)
    local sliced, total, hasMore, off, lim = IKST_GuardOps.pageSlice(list, offset, limit)
    local rows = {}
    for _, item in ipairs(sliced) do
        if item and item.canRelease ~= nil then
            rows[#rows + 1] = item
        elseif item then
            rows[#rows + 1] = IKST_GuardOps.claimRowForViewer(item, player)
        end
    end
    IKST.deliverClientCommand(player, IKST.CMD.vehicleClaimListResult, {
        claims = rows,
        total = total,
        offset = off,
        limit = lim,
        hasMore = hasMore,
    })
end

function IKST_GuardOps.sendNearbyVehicles(player, list)
    local rows = {}
    for _, row in ipairs(list or {}) do
        rows[#rows + 1] = IKST_GuardOps.enrichNearbyRow(row, player)
    end
    IKST.deliverClientCommand(player, IKST.CMD.vehicleListResult, { vehicles = rows })
end

function IKST_GuardOps.handle(command, admin, args)
    args = args or {}
    local ax = math.floor(tonumber(args.x) or (admin and admin:getX()) or 0)
    local ay = math.floor(tonumber(args.y) or (admin and admin:getY()) or 0)
    local az = tonumber(args.z) or (admin and admin:getZ()) or 0
    local radius = IKST.clampRadius(args.radius)

    if command == IKST.CMD.catchTarget or command == IKST.CMD.catchPlayer then
        local target = IKST_StaffOps.findPlayerByOnlineID(args.target)
        if not target then
            local uname = IKST_Args and IKST_Args.readUsername and IKST_Args.readUsername(args, "username")
            if uname and getPlayerFromUsername then
                target = getPlayerFromUsername(uname)
            end
        end
        if not target then
            return false, "player not found"
        end
        local maxDist = IKST_Access.sandboxInt("CatchMaxDistance", 40, 5, 200)
        if not IKST_Access.staffRemoteAdmin() then
            local tx = target:getX()
            local ty = target:getY()
            local tz = target:getZ() or 0
            if not IKST_Args.actorNearCoord(admin, tx, ty, tz, maxDist) then
                return false, "too_far"
            end
        end
        local ok, msg = IKST_GuardOps.setCaught(target, true)
        if ok and IKST_StaffHistory and type(IKST_StaffHistory.record) == "function" then
            local who = type(target.getUsername) == "function" and target:getUsername() or "?"
            IKST_StaffHistory.record(admin, "catch", tostring(who), true)
        end
        return ok, msg
    end

    if command == IKST.CMD.releaseTarget or command == IKST.CMD.releasePlayer then
        local target = IKST_StaffOps.findPlayerByOnlineID(args.target)
        if not target then
            local uname = IKST_Args and IKST_Args.readUsername and IKST_Args.readUsername(args, "username")
            if uname and getPlayerFromUsername then
                target = getPlayerFromUsername(uname)
            end
        end
        if not target then
            return false, "player not found"
        end
        return IKST_GuardOps.setCaught(target, false)
    end

    if command == IKST.CMD.toggleCreative then
        return IKST_GuardOps.toggleCreative(admin)
    end

    if command == IKST.CMD.toggleUnlimitedAmmo then
        return IKST_GuardOps.toggleUnlimitedAmmo(admin)
    end

    if command == IKST.CMD.lightbulbsArea then
        return IKST_GuardOps.lightbulbsInRadius(ax, ay, az, radius)
    end

    if command == IKST.CMD.dumpPlayers then
        local list = IKST_GuardOps.dumpPlayers(admin)
        IKST.deliverClientCommand(admin, IKST.CMD.dumpPlayersResult, { players = list })
        return true, "dumped " .. #list
    end

    if command == IKST.CMD.safehouseList then
        IKST_GuardOps.purgeExpiredSafehouses()
        local list = IKST_GuardOps.listSafehouses()
        if not IKST_GuardOps.actorIsAdmin(admin) then
            list = IKST_GuardOps.filterSafehousesForPlayer(list, admin)
        end
        IKST_GuardOps.sendSafehouseList(admin, list, args.offset, args.limit)
        return true, #list .. " safehouse(s)"
    end

    if command == IKST.CMD.safehouseClaim then
        if not IKST_GuardOps.actorIsAdmin(admin) then
            if not IKST_ClaimPolicy.playerClaimsEnabled() then
                IKST_GuardOps.notifySafehouseClaimResult(admin, false, "staff must approve claims", { x = ax, y = ay, z = az })
                return false, "staff must approve claims"
            end
            args.owner = IKST_GuardOps.username(admin)
            local dist = IKST_Access.sandboxInt("ClaimNearDistance", 8, 2, 32)
            if not IKST_Args.actorNearCoord(admin, ax, ay, az, dist) then
                IKST_GuardOps.notifySafehouseClaimResult(admin, false, "too far", { x = ax, y = ay, z = az })
                return false, "too far"
            end
        end
        local ok, msg = IKST_GuardOps.claimSafehouse(admin, ax, ay, az, args.size, args.owner, args.claimMode, args.w, args.h)
        IKST_GuardOps.notifySafehouseClaimResult(admin, ok, msg, {
            x = ax, y = ay, z = az,
            w = args.w, h = args.h,
            claimMode = args.claimMode,
        })
        if ok and IKST_StaffHistory and type(IKST_StaffHistory.record) == "function" then
            IKST_StaffHistory.record(admin, "claim", tostring(msg or "safehouse"), true)
        end
        return ok, msg
    end

    if command == IKST.CMD.safehouseRelease then
        local ok, msg = IKST_GuardOps.releaseSafehouse(args.owner, args.x, args.y, args.w, args.h, args.id, admin)
        IKST_GuardOps.notifySafehouseClaimResult(admin, ok, msg, {
            x = args.x, y = args.y, w = args.w, h = args.h, id = args.id,
        })
        return ok, msg
    end

    if command == IKST.CMD.safehouseAddMember then
        return IKST_GuardOps.addSafehouseMember(admin, args)
    end

    if command == IKST.CMD.safehouseRemoveMember then
        return IKST_GuardOps.removeSafehouseMember(admin, args)
    end

    if command == IKST.CMD.safehouseTp then
        return IKST_GuardOps.tpToSafehouse(admin, args.x, args.y, args.w, args.h, args.z)
    end

    if command == IKST.CMD.backupSafehouses then
        return IKST_GuardOps.backupSafehouses()
    end

    if command == IKST.CMD.restoreSafehouses then
        return IKST_GuardOps.restoreSafehouses(admin)
    end

    if command == IKST.CMD.toggleSafehouseBorders then
        local data = IKST_GuardOps.worldRulesData()
        data.showSafehouseBorders = not data.showSafehouseBorders
        IKST.transmitModData(IKST.ModDataKeys.WorldRules)
        IKST.deliverClientCommand(admin, IKST.CMD.safehouseBordersSync, { on = data.showSafehouseBorders })
        return true, data.showSafehouseBorders and "borders ON" or "borders OFF"
    end

    if command == IKST.CMD.vehicleClaim then
        local claimVehicle = nil
        if not IKST_GuardOps.actorIsAdmin(admin) and type(admin.getVehicle) == "function" then
            claimVehicle = admin:getVehicle()
        end
        if not claimVehicle then
            claimVehicle = IKST_GuardOps.resolveClaimVehicle(admin, args.vehicleId)
        end
        if not claimVehicle then
            return false, "no vehicle nearby — pick one in the list"
        end
        if not IKST_GuardOps.actorIsAdmin(admin) then
            if not IKST_ClaimPolicy.playerClaimsEnabled() then
                return false, "staff must approve claims"
            end
            local vz = type(claimVehicle.getZ) == "function" and claimVehicle:getZ() or 0
            if not IKST_Args.actorNearCoord(admin, claimVehicle:getX(), claimVehicle:getY(), vz, IKST.getVehicleNearRadius()) then
                return false, "too far"
            end
        end
        local ownerKey = IKST_Identity.accountKey(admin)
        if IKST_GuardOps.actorIsAdmin(admin) and args.owner and args.owner ~= "" then
            local found = IKST_Identity.findPlayerByUsername(args.owner)
            if not found then
                found = IKST_Identity.findPlayerByAccountKey(args.owner)
            end
            if found then
                ownerKey = IKST_Identity.accountKey(found)
            else
                ownerKey = IKST_Identity.resolveWhitelistKey(args.owner)
            end
        end
        if not IKST_GuardOps.actorIsAdmin(admin) then
            ownerKey = IKST_Identity.accountKey(admin)
            if IKST.vehicleClaimRequireKeys() then
                if not IKST_VehicleUtil.playerHasVehicleKey(admin, claimVehicle) then
                    return false, "need vehicle key to claim"
                end
            end
        end
        if not ownerKey or ownerKey == "" then
            return false, "no owner"
        end
        local key = IKST_VehicleClaim.ensureKey(claimVehicle)
        if not key then
            return false, "vehicle identity missing"
        end
        local meta = { label = args.label or "" }
        meta.script = IKST_VehicleIdentity.scriptName(claimVehicle)
        local x, y, z = IKST_VehicleIdentity.coords(claimVehicle)
        meta.x = x
        meta.y = y
        meta.z = z
        meta.sqlId = IKST_VehicleIdentity.sqlId(claimVehicle)
        local ok, msg = IKST_VehicleClaim.claim(key, ownerKey, meta)
        return IKST_GuardOps.finishVehicleClaimCommand(admin, ok, msg, key, ok and "set" or nil)
    end

    if command == IKST.CMD.vehicleReleaseClaim then
        local key = IKST_GuardOps.claimStoreKey(admin, args)
        if not key then
            return false, "no vehicle selected"
        end
        local entry = IKST_VehicleClaim.get(key)
        if not entry then
            return false, "not claimed"
        end
        if not IKST_GuardOps.canManageVehicleClaim(admin, entry, key) then
            return false, "not your claim"
        end
        local ok, msg = IKST_VehicleClaim.release(key)
        return IKST_GuardOps.finishVehicleClaimCommand(admin, ok, msg, key, ok and "remove" or nil)
    end

    if command == IKST.CMD.vehicleClaimTransfer then
        if not IKST_GuardOps.actorIsAdmin(admin) then
            return false, "admin only"
        end
        local key = IKST_GuardOps.claimStoreKey(admin, args)
        if not key then
            return false, "no vehicle selected"
        end
        local newOwner = args.owner
        if newOwner and newOwner ~= "" then
            local found = IKST_Identity.findPlayerByUsername(newOwner)
            if not found then
                found = IKST_Identity.findPlayerByAccountKey(newOwner)
            end
            if found then
                newOwner = IKST_Identity.accountKey(found)
            else
                newOwner = IKST_Identity.resolveWhitelistKey(newOwner)
            end
        end
        local ok, msg = IKST_VehicleClaim.transfer(key, newOwner)
        return IKST_GuardOps.finishVehicleClaimCommand(admin, ok, msg, key, ok and "set" or nil)
    end

    if command == IKST.CMD.vehicleClaimSetLabel then
        local key = IKST_GuardOps.claimStoreKey(admin, args)
        if not key then
            return false, "no vehicle selected"
        end
        local entry = IKST_VehicleClaim.get(key)
        if not entry then
            return false, "not claimed"
        end
        if not IKST_GuardOps.canManageVehicleClaim(admin, entry, key) then
            return false, "not your claim"
        end
        local ok, msg = IKST_VehicleClaim.setLabel(key, args.label)
        return IKST_GuardOps.finishVehicleClaimCommand(admin, ok, msg, key, ok and "set" or nil)
    end

    if command == IKST.CMD.vehicleClaimSetPerms then
        local key = IKST_GuardOps.claimStoreKey(admin, args)
        if not key then
            return false, "no vehicle selected"
        end
        local entry = IKST_VehicleClaim.get(key)
        if not entry then
            return false, "not claimed"
        end
        if not IKST_GuardOps.canManageVehicleClaim(admin, entry, key) then
            return false, "not your claim"
        end
        local ok, msg = IKST_VehicleClaim.setPermissions(key, args.scope, args.username, args.perms)
        return IKST_GuardOps.finishVehicleClaimCommand(admin, ok, msg, key, ok and "set" or nil)
    end

    if command == IKST.CMD.safehouseClaimSetPerms then
        local x, y, w, h = IKST_SafehouseClaim.refFromArgs(args)
        if not x and admin then
            local sq = admin:getCurrentSquare()
            local sh = sq and IKST_SafehouseClaim.safehouseAtSquare(sq) or nil
            x, y, w, h = IKST_SafehouseClaim.boundsFromSafehouse(sh)
        end
        if not x then
            return false, "no safehouse selected"
        end
        local entry = IKST_SafehouseClaim.get(x, y, w, h)
        if not entry then
            local sh = IKST_GuardOps.findSafehouseEntry({ x = x, y = y, w = w, h = h }, admin)
            if sh then
                local owner = type(sh.getOwner) == "function" and sh:getOwner() or nil
                if owner and owner ~= "" then
                    IKST_SafehouseClaim.ensureOnClaim(IKST_Identity.migrateOwnerField(owner), x, y, w, h)
                    entry = IKST_SafehouseClaim.get(x, y, w, h)
                end
            end
        end
        if not entry then
            return false, "not claimed"
        end
        if not IKST_GuardOps.actorIsAdmin(admin) and not IKST_SafehouseClaim.playerMayEdit(entry, admin) then
            return false, "not your safehouse"
        end
        local blocked, blockReason = IKST_GuardOps.claimLocationPolicyBlocked(admin, x, y, args.z or 0)
        if blocked then
            return false, blockReason or "not_your_claim"
        end
        local ok, msg = IKST_SafehouseClaim.setPermissions(x, y, w, h, args.scope, args.username, args.perms)
        return IKST_GuardOps.finishSafehouseClaimCommand(admin, ok, msg, x, y, w, h, ok and "set" or nil)
    end

    if command == IKST.CMD.safehouseSetRespawn then
        return IKST_GuardOps.setSafehouseRespawn(admin, args)
    end

    if command == IKST.CMD.vehicleClaimList then
        local list
        local showAll = args.all == true
            and (IKST_GuardOps.actorIsAdmin(admin) or IKST.vehicleShowAllClaims())
        if showAll then
            list = IKST_VehicleClaim.listAll()
        else
            list = IKST_VehicleClaim.listForOwner(IKST_Identity.accountKey(admin))
        end
        local rows = {}
        for _, entry in ipairs(list) do
            rows[#rows + 1] = IKST_GuardOps.claimRowForViewer(entry, admin)
        end
        IKST_GuardOps.sendClaimList(admin, rows, args.offset, args.limit)
        return true, #rows .. " claim(s)"
    end

    if command == IKST.CMD.vehicleClaimNearby then
        if not IKST_VehicleUtil or not IKST_VehicleUtil.listNearby then
            return false, "vehicle API missing"
        end
        -- Non-staff always scan from actor; staff may use args when near (gate already clamps).
        if not IKST_GuardOps.actorIsAdmin(admin) then
            ax = math.floor(admin:getX())
            ay = math.floor(admin:getY())
            az = admin:getZ() or 0
        end
        local list = IKST_VehicleUtil.listNearby(ax, ay, az, radius)
        for _, row in ipairs(list) do
            local v = row.id ~= nil and IKST_VehicleUtil.getVehicle(row.id) or nil
            if v and IKST_VehicleClaim and type(IKST_VehicleClaim.bindLoadedVehicle) == "function" then
                IKST_VehicleClaim.bindLoadedVehicle(v)
                row.claimKey = IKST_VehicleIdentity.readKey(v) or row.claimKey
            end
        end
        IKST_GuardOps.sendNearbyVehicles(admin, list)
        return true, #list .. " vehicle(s)"
    end

    return false, "unknown guard command"
end

if Events and Events.OnGameStart and Events.OnGameStart.Add then
    Events.OnGameStart.Add(function()
        if not IKST.runsOnServerJvm or not IKST.runsOnServerJvm() then
            return
        end
        IKST_GuardOps.iterSafehouses(function(sh)
            if IKST_SafehouseClaim and IKST_SafehouseClaim.syncFromVanilla then
                IKST_SafehouseClaim.syncFromVanilla(sh)
            end
        end)
        if IKST_GuardOps.bindLoadedVehicleClaims then
            IKST_GuardOps.bindLoadedVehicleClaims()
        end
    end)
end
