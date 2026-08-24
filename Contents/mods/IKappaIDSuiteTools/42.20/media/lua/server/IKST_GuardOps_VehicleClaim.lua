-- Vehicle claim list/enrichment helpers (split from IKST_GuardOps).
if type(isClient) == "function" and isClient()
    and type(isServer) == "function" and not isServer() then
    return
end

require "IKST_Shared"
require "IKST_Access"
require "IKST_ClaimPolicy"
require "IKST_Identity"
require "IKST_VehicleClaim"
require "IKST_VehicleIdentity"
require "IKST_VehicleUtil"

IKST_GuardOps = IKST_GuardOps or {}

function IKST_GuardOps.claimRowForViewer(entry, viewer)
    if not entry then
        return nil
    end
    local row = IKST_VehicleClaim.copyEntryPlain(entry)
    row.claimKey = tostring(entry.id)
    row.ownerLabel = IKST_Identity.labelForKey(entry.owner)
    row.isMine = IKST_VehicleClaim.isOwner(entry, viewer)
        or IKST_VehicleClaim.playerListedClaim(viewer, entry.id)
    row.claimed = true
    row.canClaim = false
    row.canRelease = IKST_GuardOps.canManageVehicleClaim(viewer, entry, entry.id)
    row.canEdit = row.canRelease
        and (IKST_VehicleClaim.playerMayEdit(entry, viewer) or IKST_GuardOps.actorIsAdmin(viewer))
    row.hoursRemaining = IKST_ClaimPolicy.hoursRemaining(entry.expiresAt)
    row.hoursRemainingText = IKST_ClaimPolicy.hoursRemainingLabel(entry.expiresAt)
    if entry.label and entry.label ~= "" then
        row.displayLabel = entry.label
    elseif entry.script and entry.script ~= "" then
        row.displayLabel = entry.script
    else
        row.displayLabel = "#" .. tostring(entry.id)
    end
    return row
end

function IKST_GuardOps.enrichNearbyRow(row, viewer)
    if not row or row.id == nil then
        return row
    end
    local entry = nil
    if row.claimKey and row.claimKey ~= "" then
        entry = IKST_VehicleClaim.get(row.claimKey)
    end
    if not entry and row.id ~= nil and IKST_VehicleUtil and type(IKST_VehicleUtil.getVehicle) == "function" then
        local live = IKST_VehicleUtil.getVehicle(row.id)
        if live then
            entry = select(1, IKST_VehicleClaim.getForVehicle(live))
        end
    end
    if not entry then
        entry = IKST_VehicleClaim.get(row.id)
    end
    if entry and not IKST_VehicleClaim.isEntryExpired(entry) then
        local claimRow = IKST_GuardOps.claimRowForViewer(entry, viewer)
        row.claimed = true
        row.ownerLabel = claimRow.ownerLabel
        row.isMine = claimRow.isMine
        row.canClaim = false
        row.canRelease = claimRow.canRelease
        row.canEdit = claimRow.canEdit
        row.hoursRemainingText = claimRow.hoursRemainingText
        row.displayLabel = claimRow.displayLabel
        row.claimKey = claimRow.claimKey
        if entry.label and entry.label ~= "" then
            row.claimNote = entry.label
        end
    else
        row.claimed = false
        row.canClaim = IKST_ClaimPolicy.mayCreateVehicleClaim(viewer)
        row.canRelease = false
        row.canEdit = false
        row.isMine = false
        row.ownerLabel = nil
    end
    return row
end

function IKST_GuardOps.notifyVehicleClaimResult(player, ok, message, extra)
    if not player or not IKST.deliverClientCommand then
        return
    end
    local text = tostring(message or "")
    if IKST_ClaimPolicy and IKST_ClaimPolicy.friendlyMessage then
        text = IKST_ClaimPolicy.friendlyMessage(text)
    end
    local payload = {
        ok = ok == true,
        message = text,
    }
    if extra then
        for key, value in pairs(extra) do
            payload[key] = value
        end
    end
    IKST.deliverClientCommand(player, IKST.CMD.vehicleClaimResult, payload)
end

function IKST_GuardOps.afterVehicleClaimMutation(actor, action, vehicleId)
    if not action or not vehicleId then
        return
    end
    local mirrorArgs = {
        action = action,
        vehicleId = vehicleId,
    }
    if action == "set" then
        local entry = IKST_VehicleClaim.get(vehicleId)
        if entry then
            mirrorArgs.entry = IKST_VehicleClaim.copyEntryPlain(entry)
        end
    end
    IKST_GuardOps.broadcastVehicleClaimChange(actor, mirrorArgs)
end

function IKST_GuardOps.broadcastVehicleClaimChange(actor, mirrorArgs)
    if not IKST.isMultiplayerSession or not IKST.isMultiplayerSession() then
        return
    end
    if not IKST.runsOnServerJvm or not IKST.runsOnServerJvm() then
        return
    end
    if not IKST_StaffOps or not IKST_StaffOps.forEachOnline then
        return
    end
    IKST_VehicleClaim.purgeExpired()
    IKST_StaffOps.forEachOnline(function(p)
        local rawList
        if IKST_GuardOps.actorIsAdmin(p) then
            rawList = IKST_VehicleClaim.listAll()
        else
            rawList = IKST_VehicleClaim.listForOwner(IKST_Identity.accountKey(p))
        end
        local rows = {}
        for _, entry in ipairs(rawList) do
            rows[#rows + 1] = IKST_GuardOps.claimRowForViewer(entry, p)
        end
        IKST_GuardOps.sendClaimList(p, rows)
        IKST.deliverClientCommand(p, IKST.CMD.vehicleClaimMirror, mirrorArgs or {})
    end)
end

function IKST_GuardOps.finishVehicleClaimCommand(actor, ok, msg, vehicleId, action)
    if ok and vehicleId and action then
        IKST_GuardOps.afterVehicleClaimMutation(actor, action, vehicleId)
    end
    IKST_GuardOps.notifyVehicleClaimResult(actor, ok, msg, { vehicleId = vehicleId })
    return ok, msg
end

function IKST_GuardOps.enforceVehicleClaim(player)
    if not player then
        return
    end
    if not player.getVehicle then
        return
    end
    local vehicle = player:getVehicle()
    if not vehicle or not IKST_VehicleClaim or not IKST_VehicleClaim.canUseVehicle then
        return
    end
    if not IKST_VehicleClaim.canUseVehicle(player, vehicle, "enter") then
        if type(vehicle.shutOff) == "function" then
            vehicle:shutOff()
        end
        if type(vehicle.exit) == "function" then
            vehicle:exit(player)
        end
        local seat = 0
        if type(vehicle.getSeat) == "function" then
            seat = vehicle:getSeat(player) or 0
        end
        if type(vehicle.setCharacterPosition) == "function" then
            vehicle:setCharacterPosition(player, seat, "outside")
        end
        if not IKST_Debug then
            require "IKST_Debug"
        end
        if IKST_Debug and IKST_Debug.logEffect then
            IKST_Debug.logEffect("vehicle", "claim-eject", "vid=" .. tostring(type(vehicle.getId) == "function" and vehicle:getId() or "?"), player)
        end
        return
    end
    if type(vehicle.isEngineRunning) == "function" and vehicle:isEngineRunning() then
        if not IKST_VehicleClaim.canUseVehicle(player, vehicle, "engine") then
            if type(vehicle.shutOff) == "function" then
                vehicle:shutOff()
            end
            if IKST_Debug and IKST_Debug.logVerbose then
                IKST_Debug.logVerbose("vehicle", "claim engine shutoff vid=" .. tostring(type(vehicle.getId) == "function" and vehicle:getId() or "?"))
            end
        end
    end
end

function IKST_GuardOps.actorIsAdmin(actor)
    return IKST_Access and IKST_Access.canUseTools and IKST_Access.canUseTools(actor)
end

function IKST_GuardOps.normalizeVehicleId(raw)
    if IKST_VehicleIdentity and IKST_VehicleIdentity.isDurableKey(raw) then
        return tostring(raw)
    end
    local vidNum = tonumber(raw)
    if not vidNum then
        return nil
    end
    return vidNum
end

function IKST_GuardOps.resolveClaimVehicle(actor, rawId)
    if IKST_VehicleIdentity and IKST_VehicleIdentity.isDurableKey(rawId) then
        return nil, tostring(rawId)
    end
    local runtime = tonumber(rawId)
    if runtime == nil and actor and IKST_VehicleUtil and type(IKST_VehicleUtil.nearestId) == "function" then
        runtime = IKST_VehicleUtil.nearestId(actor:getX(), actor:getY(), actor:getZ(), IKST.getVehicleNearRadius())
    end
    if runtime == nil then
        return nil, nil
    end
    local vehicle = IKST_VehicleUtil and type(IKST_VehicleUtil.getVehicle) == "function" and IKST_VehicleUtil.getVehicle(runtime)
    return vehicle, nil
end

function IKST_GuardOps.claimStoreKey(actor, args)
    args = args or {}
    local listed = args.claimKey
    if listed == nil or listed == "" then
        listed = nil
    end
    if listed and IKST_VehicleIdentity.isDurableKey(listed) then
        return tostring(listed)
    end
    if listed and IKST_VehicleClaim.get(listed) then
        return tostring(listed)
    end
    local vehicle = IKST_GuardOps.resolveClaimVehicle(actor, args.vehicleId)
    if vehicle then
        local key = IKST_VehicleIdentity.readKey(vehicle)
        if key then
            return key
        end
        return nil
    end
    local raw = args.vehicleId
    if raw ~= nil and IKST_VehicleIdentity.isDurableKey(raw) then
        return tostring(raw)
    end
    if raw ~= nil and IKST_VehicleClaim.get(raw) then
        return tostring(raw)
    end
    return nil
end

function IKST_GuardOps.canManageVehicleClaim(actor, entry, vehicleId)
    if IKST_GuardOps.actorIsAdmin(actor) then
        return true
    end
    return IKST_VehicleClaim.playerMayRelease(entry, actor, vehicleId)
end

-- Keep inactivity clocks fresh for online owners (vehicles + safehouses). Also clears pending vehicle stamps.
function IKST_GuardOps.touchOnlineClaimActivity()
    if IKST_ClaimPolicy.inactivityHours() <= 0 then
        return
    end
    if type(getOnlinePlayers) ~= "function" then
        return
    end
    local list = getOnlinePlayers()
    if not list or type(list.size) ~= "function" then
        return
    end
    for i = 0, list:size() - 1 do
        local player = list:get(i)
        if player then
            local vehicle = type(player.getVehicle) == "function" and player:getVehicle() or nil
            if vehicle then
                IKST_VehicleClaim.applyPendingClear(vehicle)
                IKST_VehicleClaim.touchOwnerVehicle(player, vehicle)
            end
            if SafeHouse and type(SafeHouse.getSafeHouse) == "function" then
                local square = type(player.getCurrentSquare) == "function" and player:getCurrentSquare() or nil
                local sh = square and SafeHouse.getSafeHouse(square) or nil
                if sh and type(sh.getX) == "function" then
                    local x, y = sh:getX(), sh:getY()
                    local w = type(sh.getW) == "function" and sh:getW() or 1
                    local h = type(sh.getH) == "function" and sh:getH() or 1
                    local entry = IKST_SafehouseClaim.get(x, y, w, h)
                    local meta = IKST_ClaimPolicy.getSafehouseMeta(x, y, w, h)
                    local ownerName = type(sh.getOwner) == "function" and sh:getOwner() or nil
                    local isOwner = false
                    if entry and IKST_SafehouseClaim.isOwner then
                        isOwner = IKST_SafehouseClaim.isOwner(entry, player)
                    elseif meta and IKST_Identity and IKST_Identity.playerOwnsKey then
                        isOwner = IKST_Identity.playerOwnsKey(player, meta.owner)
                    elseif ownerName and IKST_ClaimPolicy.usernamesEqual then
                        local uname = type(player.getUsername) == "function" and player:getUsername() or ""
                        isOwner = IKST_ClaimPolicy.usernamesEqual(ownerName, uname)
                    end
                    if isOwner then
                        if entry and IKST_ClaimPolicy.touchActivity(entry) then
                            IKST_SafehouseClaim.transmit("set", entry.key or IKST_SafehouseClaim.keyFor(x, y, w, h), entry)
                        end
                        if meta and IKST_ClaimPolicy.touchActivity(meta) then
                            if IKST.transmitModData and IKST.ModDataKeys then
                                IKST.transmitModData(IKST.ModDataKeys.WorldRules)
                            end
                        end
                    end
                end
            end
        end
    end
end
