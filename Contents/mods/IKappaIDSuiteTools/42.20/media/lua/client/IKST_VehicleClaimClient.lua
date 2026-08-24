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
    local id = tonumber(row.id)
    if id then
        IKST_VehicleClaimClient.byId[id] = row
    end
    if row.claimKey and row.claimKey ~= "" then
        IKST_VehicleClaimClient.byKey[row.claimKey] = row
    elseif row.id and IKST_VehicleIdentity.isDurableKey(row.id) then
        IKST_VehicleClaimClient.byKey[tostring(row.id)] = row
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
            local claimKey = tostring(entry.id)
            local displayLabel = entry.label
            if not displayLabel or displayLabel == "" then
                displayLabel = entry.script or ("#" .. claimKey)
            end
            rows[#rows + 1] = {
                id = claimKey,
                claimKey = claimKey,
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
    local claimKey = tostring(entry.id)
    if IKST_VehicleClaim.ensureEntryShape then
        IKST_VehicleClaim.ensureEntryShape(entry)
    end
    local displayLabel = entry.label
    if not displayLabel or displayLabel == "" then
        displayLabel = entry.script or ("#" .. claimKey)
    end
    local canRelease = false
    local canEdit = false
    if player then
        canRelease = IKST_VehicleClaim.playerMayRelease(entry, player, claimKey)
        canEdit = IKST_VehicleClaim.playerMayEdit(entry, player)
    end
    return {
        id = claimKey,
        claimKey = claimKey,
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
    local matchKey = row.claimKey or tostring(row.id)
    local replaced = false
    for i, r in ipairs(IKST_VehicleClaimClient.claims or {}) do
        local rk = r.claimKey or tostring(r.id)
        if rk == matchKey then
            IKST_VehicleClaimClient.claims[i] = row
            replaced = true
            break
        end
    end
    if not replaced then
        IKST_VehicleClaimClient.claims[#IKST_VehicleClaimClient.claims + 1] = row
    end
    for i, r in ipairs(IKST_VehicleClaimClient.nearby or {}) do
        local rk = r.claimKey or tostring(r.id)
        if rk == matchKey or tonumber(r.id) == tonumber(row.id) then
            IKST_VehicleClaimClient.nearby[i] = row
            break
        end
    end
    IKST_VehicleClaimClient.reindexClaims()
end

function IKST_VehicleClaimClient.onClaimListResult(args)
    IKST_VehicleClaimClient.claims = (args and args.claims) or {}
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
    local id = tonumber(vehicleId)
    if id ~= nil then
        local row = IKST_VehicleClaimClient.byId[id]
        if row then
            return row
        end
    end
    local key = vehicleId and tostring(vehicleId) or nil
    if key and IKST_VehicleClaimClient.byKey[key] then
        return IKST_VehicleClaimClient.byKey[key]
    end
    if vehicle and IKST_VehicleIdentity and type(IKST_VehicleIdentity.readKey) == "function" then
        local stamp = IKST_VehicleIdentity.readKey(vehicle)
        if stamp and IKST_VehicleClaimClient.byKey[stamp] then
            return IKST_VehicleClaimClient.byKey[stamp]
        end
    end
    return nil
end

function IKST_VehicleClaimClient.finalizeUiState(state, player)
    if not state then
        return nil
    end
    if state.claimed == true then
        state.canClaim = false
        return state
    end
    if IKST_ClaimPolicy and type(IKST_ClaimPolicy.mayCreateVehicleClaim) == "function" then
        state.canClaim = IKST_ClaimPolicy.mayCreateVehicleClaim(player) == true
    end
    return state
end

function IKST_VehicleClaimClient.spFallbackState(vehicleId, player, vehicle)
    local claimKey = nil
    if vehicle and IKST_VehicleIdentity and type(IKST_VehicleIdentity.readKey) == "function" then
        claimKey = IKST_VehicleIdentity.readKey(vehicle)
    end
    if not claimKey and vehicleId ~= nil and IKST_VehicleIdentity.isDurableKey(vehicleId) then
        claimKey = tostring(vehicleId)
    end
    local lookupKey = claimKey or vehicleId
    local runtimeId = tonumber(vehicleId)
    local entry = lookupKey and IKST_VehicleClaim.get(lookupKey)
    if entry and not IKST_VehicleClaim.isEntryExpired(entry) then
        local displayLabel = entry.label
        if not displayLabel or displayLabel == "" then
            displayLabel = entry.script or ("#" .. tostring(lookupKey))
        end
        return {
            id = runtimeId or claimKey or vehicleId,
            claimKey = claimKey or tostring(entry.id),
            claimed = true,
            ownerLabel = IKST_Identity.labelForKey(entry.owner),
            displayLabel = displayLabel,
            canRelease = IKST_VehicleClaim.playerMayRelease(entry, player, claimKey or entry.id),
            canEdit = IKST_VehicleClaim.playerMayEdit(entry, player),
            canClaim = false,
            hoursRemainingText = IKST_ClaimPolicy.hoursRemainingLabel(entry.expiresAt),
        }
    end
    return {
        id = runtimeId or vehicleId,
        claimKey = claimKey,
        claimed = false,
        canClaim = IKST_ClaimPolicy.mayCreateVehicleClaim(player),
        canRelease = false,
        canEdit = false,
    }
end

function IKST_VehicleClaimClient.uiState(vehicleId, player, vehicle)
    local row = IKST_VehicleClaimClient.rowForVehicle(vehicleId, vehicle)
    if row and row.claimed == true then
        return IKST_VehicleClaimClient.finalizeUiState(row, player)
    end
    local claimKey = nil
    if vehicle and IKST_VehicleIdentity and type(IKST_VehicleIdentity.readKey) == "function" then
        claimKey = IKST_VehicleIdentity.readKey(vehicle)
    end
    if not claimKey and vehicleId ~= nil and IKST_VehicleIdentity.isDurableKey(vehicleId) then
        claimKey = tostring(vehicleId)
    end
    local lookupKey = claimKey or vehicleId
    local entry = lookupKey and IKST_VehicleClaim.get(lookupKey)
    if entry and not IKST_VehicleClaim.isEntryExpired(entry) then
        return IKST_VehicleClaimClient.finalizeUiState(
            IKST_VehicleClaimClient.buildRowFromEntry(entry, player), player)
    end
    if row then
        return IKST_VehicleClaimClient.finalizeUiState(row, player)
    end
    local id = tonumber(vehicleId)
    if IKST.isMultiplayerSession and IKST.isMultiplayerSession() then
        if entry and not IKST_VehicleClaim.isEntryExpired(entry) then
            return IKST_VehicleClaimClient.finalizeUiState({
                id = id or claimKey or vehicleId,
                claimKey = claimKey,
                claimed = true,
                ownerLabel = IKST_Identity.labelForKey(entry.owner),
                canRelease = false,
                canEdit = false,
                canClaim = false,
                stale = true,
            }, player)
        end
        return IKST_VehicleClaimClient.finalizeUiState({
            id = id or vehicleId,
            claimKey = claimKey,
            claimed = false,
            canRelease = false,
            canEdit = false,
            stale = true,
        }, player)
    end
    return IKST_VehicleClaimClient.finalizeUiState(
        IKST_VehicleClaimClient.spFallbackState(vehicleId, player, vehicle), player)
end

function IKST_VehicleClaimClient.applyMirror(args)
    if IKST_VehicleClaimMirror.applyMirror(args) then
        local key = args.vehicleId or (args.entry and args.entry.id)
        if key then
            key = tostring(key)
        end
        local player = getPlayer and getPlayer() or nil
        if args.action == "remove" and key then
            IKST_VehicleClaimClient.byKey[key] = nil
            local kept = {}
            for _, row in ipairs(IKST_VehicleClaimClient.claims or {}) do
                local rk = row.claimKey or tostring(row.id)
                if rk ~= key then
                    kept[#kept + 1] = row
                end
            end
            IKST_VehicleClaimClient.claims = kept
            for i, row in ipairs(IKST_VehicleClaimClient.nearby or {}) do
                local rk = row.claimKey or tostring(row.id)
                if rk == key then
                    local runtimeId = tonumber(row.id)
                    IKST_VehicleClaimClient.nearby[i] = {
                        id = runtimeId or row.id,
                        claimKey = nil,
                        claimed = false,
                        canClaim = IKST_ClaimPolicy.mayCreateVehicleClaim(player),
                        canRelease = false,
                        canEdit = false,
                    }
                    break
                end
            end
            IKST_VehicleClaimClient.reindexClaims()
        elseif args.action == "set" and key and type(args.entry) == "table" then
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
