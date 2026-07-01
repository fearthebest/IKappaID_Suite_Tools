if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "IKST_Shared"
require "IKST_ClaimPolicy"
require "IKST_VehicleClaim"
require "IKST_VehicleClaimMirror"
require "IKST_Identity"
require "IKST_Access"

IKST_VehicleClaimClient = IKST_VehicleClaimClient or {}
IKST_VehicleClaimClient.claims = IKST_VehicleClaimClient.claims or {}
IKST_VehicleClaimClient.nearby = IKST_VehicleClaimClient.nearby or {}
IKST_VehicleClaimClient.byId = IKST_VehicleClaimClient.byId or {}
IKST_VehicleClaimClient.listBootstrapped = IKST_VehicleClaimClient.listBootstrapped or false

local function indexRow(row)
    if not row then
        return
    end
    local id = tonumber(row.id)
    if id then
        IKST_VehicleClaimClient.byId[id] = row
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
                displayLabel = entry.script or ("#" .. tostring(entry.id))
            end
            rows[#rows + 1] = {
                id = entry.id,
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
    for _, row in ipairs(IKST_VehicleClaimClient.claims or {}) do
        indexRow(row)
    end
    for _, row in ipairs(IKST_VehicleClaimClient.nearby or {}) do
        indexRow(row)
    end
end

function IKST_VehicleClaimClient.onClaimListResult(args)
    IKST_VehicleClaimClient.claims = (args and args.claims) or {}
    IKST_VehicleClaimClient.listBootstrapped = true
    IKST_VehicleClaimClient.reindexClaims()
end

function IKST_VehicleClaimClient.onNearbyResult(vehicles)
    IKST_VehicleClaimClient.nearby = vehicles or {}
    IKST_VehicleClaimClient.listBootstrapped = true
    IKST_VehicleClaimClient.reindexClaims()
end

function IKST_VehicleClaimClient.rowForVehicle(vehicleId)
    local id = tonumber(vehicleId)
    if id == nil then
        return nil
    end
    return IKST_VehicleClaimClient.byId[id]
end

function IKST_VehicleClaimClient.spFallbackState(vehicleId, player)
    local id = tonumber(vehicleId)
    if id == nil then
        return nil
    end
    local entry = IKST_VehicleClaim.get(id)
    if entry and not IKST_VehicleClaim.isEntryExpired(entry) then
        local displayLabel = entry.label
        if not displayLabel or displayLabel == "" then
            displayLabel = entry.script or ("#" .. tostring(id))
        end
        return {
            id = id,
            claimed = true,
            ownerLabel = IKST_Identity.labelForKey(entry.owner),
            displayLabel = displayLabel,
            canRelease = IKST_VehicleClaim.playerMayRelease(entry, player, id),
            canEdit = IKST_VehicleClaim.playerMayEdit(entry, player),
            canClaim = false,
            hoursRemainingText = IKST_ClaimPolicy.hoursRemainingLabel(entry.expiresAt),
        }
    end
    return {
        id = id,
        claimed = false,
        canClaim = true,
        canRelease = false,
        canEdit = false,
    }
end

function IKST_VehicleClaimClient.uiState(vehicleId, player)
    local row = IKST_VehicleClaimClient.rowForVehicle(vehicleId)
    if row then
        return row
    end
    local id = tonumber(vehicleId)
    if id == nil then
        return nil
    end
    if IKST.isMultiplayerSession and IKST.isMultiplayerSession() then
        local entry = IKST_VehicleClaim.get(id)
        if entry and not IKST_VehicleClaim.isEntryExpired(entry) then
            return {
                id = id,
                claimed = true,
                ownerLabel = IKST_Identity.labelForKey(entry.owner),
                canRelease = false,
                canEdit = false,
                canClaim = false,
                stale = true,
            }
        end
        return {
            id = id,
            claimed = false,
            canClaim = false,
            canRelease = false,
            canEdit = false,
            stale = true,
        }
    end
    return IKST_VehicleClaimClient.spFallbackState(id, player)
end

function IKST_VehicleClaimClient.applyMirror(args)
    if IKST_VehicleClaimMirror.applyMirror(args) then
        local id = tonumber(args.vehicleId or (args.entry and args.entry.id))
        if args.action == "remove" and id then
            IKST_VehicleClaimClient.byId[id] = nil
            local kept = {}
            for _, row in ipairs(IKST_VehicleClaimClient.claims or {}) do
                if tonumber(row.id) ~= id then
                    kept[#kept + 1] = row
                end
            end
            IKST_VehicleClaimClient.claims = kept
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
    end
    if IKST_JobsPanel and IKST_JobsPanel.instance then
        IKST_JobsPanel.instance:refreshJobUI()
    end
end
