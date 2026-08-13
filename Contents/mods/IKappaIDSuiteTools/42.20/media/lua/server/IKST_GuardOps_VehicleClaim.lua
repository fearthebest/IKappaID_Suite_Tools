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

IKST_GuardOps = IKST_GuardOps or {}

function IKST_GuardOps.claimRowForViewer(entry, viewer)
    if not entry then
        return nil
    end
    local row = IKST_VehicleClaim.copyEntryPlain(entry)
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
    local entry = IKST_VehicleClaim.get(row.id)
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
        if entry.label and entry.label ~= "" then
            row.claimNote = entry.label
        end
    else
        row.claimed = false
        row.canClaim = IKST_ClaimPolicy.mayCreateClaim(viewer)
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
    local payload = {
        ok = ok == true,
        message = tostring(message or ""),
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
    local vidNum = tonumber(raw)
    if not vidNum then
        return nil
    end
    return vidNum
end

function IKST_GuardOps.canManageVehicleClaim(actor, entry, vehicleId)
    if IKST_GuardOps.actorIsAdmin(actor) then
        return true
    end
    return IKST_VehicleClaim.playerMayRelease(entry, actor, vehicleId)
end
