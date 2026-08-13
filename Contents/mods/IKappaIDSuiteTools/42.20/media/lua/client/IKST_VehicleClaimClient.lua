if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "IKST_Shared"
require "IKST_ClaimPolicy"
require "IKST_VehicleClaim"
require "IKST_VehicleClaimMirror"
require "IKST_VehicleIdentity"
require "IKST_Identity"
require "IKST_Access"

IKST_VehicleClaimClient = IKST_VehicleClaimClient or {}
IKST_VehicleClaimClient.claims = IKST_VehicleClaimClient.claims or {}
IKST_VehicleClaimClient.nearby = IKST_VehicleClaimClient.nearby or {}
IKST_VehicleClaimClient.byId = IKST_VehicleClaimClient.byId or {}
IKST_VehicleClaimClient.byKey = IKST_VehicleClaimClient.byKey or {}
IKST_VehicleClaimClient.listBootstrapped = IKST_VehicleClaimClient.listBootstrapped or false

local function indexRow(row)
    if not row then
        return
    end
    if row.claimKey and row.claimKey ~= "" then
        IKST_VehicleClaimClient.byKey[tostring(row.claimKey)] = row
    end
    if row.id ~= nil then
        IKST_VehicleClaimClient.byKey[tostring(row.id)] = row
        local runtime = tonumber(row.id)
        if runtime then
            IKST_VehicleClaimClient.byId[runtime] = row
        end
    end
    if row.runtimeId ~= nil then
        local runtime = tonumber(row.runtimeId)
        if runtime then
            IKST_VehicleClaimClient.byId[runtime] = row
        end
    end
end

function IKST_VehicleClaimClient.syncFromMirroredStore()
    if not IKST_VehicleClaim or not IKST_VehicleClaim.store then
        return
    end
    local data = IKST_VehicleClaim.store()
    local rows = {}
    for _, entry in pairs(data.byId or {}) do
        if entry and entry.id and not IKST_VehicleClaim.isEntryExpired(entry) then
            local displayLabel = entry.label
            if not displayLabel or displayLabel == "" then
                displayLabel = entry.script or tostring(entry.id)
            end
            rows[#rows + 1] = {
                id = entry.id,
                claimKey = tostring(entry.id),
                owner = entry.owner,
                ownerLabel = IKST_Identity.labelForKey(entry.owner),
                displayLabel = displayLabel,
                script = entry.script,
                x = entry.x,
                y = entry.y,
                z = entry.z,
                claimed = true,
                hoursRemainingText = IKST_ClaimPolicy.hoursRemainingLabel(entry.expiresAt),
                mirrored = true,
            }
        end
    end
    IKST_VehicleClaimClient.claims = rows
    IKST_VehicleClaimClient.reindexClaims()
end

function IKST_VehicleClaimClient.onMirroredModData()
    local hasServerRows = false
    for _, row in ipairs(IKST_VehicleClaimClient.claims or {}) do
        if row.canRelease ~= nil then
            hasServerRows = true
            break
        end
    end
    if not hasServerRows then
        IKST_VehicleClaimClient.syncFromMirroredStore()
    end
    if IKST_JobsPanel and IKST_JobsPanel.instance then
        IKST_JobsPanel.instance:refreshJobUI()
    end
end

function IKST_VehicleClaimClient.bootstrap(player)
    if not player or not IKST.isMultiplayerSession or not IKST.isMultiplayerSession() then
        return
    end
    IKST_VehicleClaimClient.syncFromMirroredStore()
    local showAll = IKST_Access and IKST_Access.canUseTools(player)
    IKST.dispatchCommand(player, IKST.CMD.vehicleClaimList, { all = showAll == true })
end

function IKST_VehicleClaimClient.reindexClaims()
    IKST_VehicleClaimClient.byId = {}
    IKST_VehicleClaimClient.byKey = {}
    for _, row in ipairs(IKST_VehicleClaimClient.nearby or {}) do
        indexRow(row)
    end
    for _, row in ipairs(IKST_VehicleClaimClient.claims or {}) do
        indexRow(row)
    end
end

function IKST_VehicleClaimClient.buildRowFromEntry(entry, player)
    if not entry or not entry.id then
        return nil
    end
    local id = entry.id
    if IKST_VehicleClaim.ensureEntryShape then
        IKST_VehicleClaim.ensureEntryShape(entry)
    end
    local displayLabel = entry.label
    if not displayLabel or displayLabel == "" then
        displayLabel = entry.script or tostring(id)
    end
    local canRelease = false
    local canEdit = false
    if player then
        canRelease = IKST_VehicleClaim.playerMayRelease(entry, player, id)
        canEdit = IKST_VehicleClaim.playerMayEdit(entry, player)
    end
    return {
        id = id,
        claimKey = tostring(id),
        owner = entry.owner,
        ownerLabel = IKST_Identity.labelForKey(entry.owner),
        displayLabel = displayLabel,
        script = entry.script,
        x = entry.x,
        y = entry.y,
        z = entry.z,
        claimed = true,
        canClaim = false,
        canRelease = canRelease,
        canEdit = canEdit,
        hoursRemainingText = IKST_ClaimPolicy.hoursRemainingLabel(entry.expiresAt),
    }
end

function IKST_VehicleClaimClient.upsertClaimRow(entry, player)
    local row = IKST_VehicleClaimClient.buildRowFromEntry(entry, player)
    if not row then
        return
    end
    local id = row.id
    local replaced = false
    for i, r in ipairs(IKST_VehicleClaimClient.claims or {}) do
        if tostring(r.id) == tostring(id) or (row.claimKey and tostring(r.claimKey) == tostring(row.claimKey)) then
            IKST_VehicleClaimClient.claims[i] = row
            replaced = true
            break
        end
    end
    if not replaced then
        IKST_VehicleClaimClient.claims[#IKST_VehicleClaimClient.claims + 1] = row
    end
    for i, r in ipairs(IKST_VehicleClaimClient.nearby or {}) do
        local sameRuntime = tonumber(r.id) and tonumber(row.runtimeId) and tonumber(r.id) == tonumber(row.runtimeId)
        local sameKey = row.claimKey and tostring(r.claimKey) == tostring(row.claimKey)
        if sameRuntime or sameKey then
            IKST_VehicleClaimClient.nearby[i] = row
            break
        end
    end
    IKST_VehicleClaimClient.reindexClaims()
end

function IKST_VehicleClaimClient.onClaimListResult(args)
    local incoming = (args and args.claims) or {}
    local offset = tonumber(args and args.offset) or 0
    if offset <= 0 then
        IKST_VehicleClaimClient.claims = incoming
    else
        local list = IKST_VehicleClaimClient.claims or {}
        for i = 1, #incoming do
            list[#list + 1] = incoming[i]
        end
        IKST_VehicleClaimClient.claims = list
    end
    IKST_VehicleClaimClient.listBootstrapped = true
    IKST_VehicleClaimClient.reindexClaims()
    if IKST_JobsPanel and IKST_JobsPanel.instance then
        IKST_JobsPanel.instance:refreshJobUI()
    end
end

function IKST_VehicleClaimClient.onNearbyResult(vehicles)
    IKST_VehicleClaimClient.nearby = vehicles or {}
    IKST_VehicleClaimClient.listBootstrapped = true
    IKST_VehicleClaimClient.reindexClaims()
    if IKST_JobsPanel and IKST_JobsPanel.instance then
        IKST_JobsPanel.instance:refreshJobUI()
    end
end

function IKST_VehicleClaimClient.rowForVehicle(vehicleId, vehicle)
    if vehicle and IKST_VehicleIdentity then
        local key = IKST_VehicleIdentity.readKey(vehicle)
        if key and IKST_VehicleClaimClient.byKey[key] then
            return IKST_VehicleClaimClient.byKey[key]
        end
        local entry = IKST_VehicleClaim.getForVehicle(vehicle)
        if entry then
            return IKST_VehicleClaimClient.buildRowFromEntry(entry, getPlayer and getPlayer() or nil)
        end
    end
    if vehicleId ~= nil and IKST_VehicleClaimClient.byKey[tostring(vehicleId)] then
        return IKST_VehicleClaimClient.byKey[tostring(vehicleId)]
    end
    local id = tonumber(vehicleId)
    if id == nil then
        return nil
    end
    return IKST_VehicleClaimClient.byId[id]
end

function IKST_VehicleClaimClient.spFallbackState(vehicleId, player, vehicle)
    local entry = nil
    if vehicle then
        entry = IKST_VehicleClaim.getForVehicle(vehicle)
    end
    if not entry then
        local key = vehicleId
        if vehicle and IKST_VehicleIdentity then
            key = IKST_VehicleIdentity.readKey(vehicle) or vehicleId
        end
        entry = key and IKST_VehicleClaim.get(key) or nil
    end
    if entry and not IKST_VehicleClaim.isEntryExpired(entry) then
        return IKST_VehicleClaimClient.buildRowFromEntry(entry, player)
    end
    return {
        id = vehicleId,
        claimed = false,
        canClaim = IKST_ClaimPolicy.mayCreateClaim(player),
        canRelease = false,
        canEdit = false,
    }
end

function IKST_VehicleClaimClient.uiState(vehicleId, player, vehicle)
    local row = IKST_VehicleClaimClient.rowForVehicle(vehicleId, vehicle)
    if row and row.claimed == true then
        return row
    end
    if vehicle then
        local entry = IKST_VehicleClaim.getForVehicle(vehicle)
        if entry and not IKST_VehicleClaim.isEntryExpired(entry) then
            return IKST_VehicleClaimClient.buildRowFromEntry(entry, player)
        end
    end
    local key = vehicleId
    if vehicle and IKST_VehicleIdentity then
        key = IKST_VehicleIdentity.readKey(vehicle) or vehicleId
    end
    local entry = key and IKST_VehicleClaim.get(key) or nil
    if entry and not IKST_VehicleClaim.isEntryExpired(entry) then
        return IKST_VehicleClaimClient.buildRowFromEntry(entry, player)
    end
    if row then
        return row
    end
    if IKST.isMultiplayerSession and IKST.isMultiplayerSession() then
        return {
            id = vehicleId,
            claimed = false,
            canClaim = false,
            canRelease = false,
            canEdit = false,
            stale = true,
        }
    end
    return IKST_VehicleClaimClient.spFallbackState(vehicleId, player, vehicle)
end

function IKST_VehicleClaimClient.applyMirror(args)
    if IKST_VehicleClaimMirror.applyMirror(args) then
        local id = args.vehicleId or (args.entry and args.entry.id)
        local player = getPlayer and getPlayer() or nil
        if args.action == "remove" and id then
            local want = tostring(id)
            IKST_VehicleClaimClient.byKey[want] = nil
            local runtime = tonumber(id)
            if runtime then
                IKST_VehicleClaimClient.byId[runtime] = nil
            end
            local kept = {}
            for _, row in ipairs(IKST_VehicleClaimClient.claims or {}) do
                if tostring(row.id) ~= want and tostring(row.claimKey or "") ~= want then
                    kept[#kept + 1] = row
                end
            end
            IKST_VehicleClaimClient.claims = kept
            for i, row in ipairs(IKST_VehicleClaimClient.nearby or {}) do
                if tostring(row.claimKey or "") == want or tostring(row.id) == want then
                    IKST_VehicleClaimClient.nearby[i] = {
                        id = row.id,
                        claimed = false,
                        canClaim = IKST_ClaimPolicy.mayCreateClaim(player),
                        canRelease = false,
                        canEdit = false,
                    }
                    break
                end
            end
            IKST_VehicleClaimClient.reindexClaims()
        elseif args.action == "set" and id and type(args.entry) == "table" then
            IKST_VehicleClaimClient.upsertClaimRow(args.entry, player)
        end
    end
end

function IKST_VehicleClaimClient.forceRefresh(args)
    if args then
        IKST_VehicleClaimClient.applyMirror(args)
    end
    local player = getPlayer and getPlayer() or nil
    if player and IKST.isMultiplayerSession and IKST.isMultiplayerSession() then
        IKST.dispatchCommand(player, IKST.CMD.vehicleClaimList, {
            all = IKST_Access and IKST_Access.canUseTools(player),
        })
        if player.getX and player.getY then
            IKST.dispatchCommand(player, IKST.CMD.vehicleClaimNearby, {
                x = math.floor(player:getX()),
                y = math.floor(player:getY()),
                z = type(player.getZ) == "function" and player:getZ() or 0,
                radius = IKST.getVehicleNearRadius(),
            })
        end
    end
    if IKST_JobsPanel and IKST_JobsPanel.instance then
        IKST_JobsPanel.instance:refreshJobUI()
    end
end
