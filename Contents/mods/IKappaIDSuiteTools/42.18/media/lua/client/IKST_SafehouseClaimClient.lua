if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "IKST_Shared"
require "IKST_ClaimPolicy"
require "IKST_SafehouseClaim"
require "IKST_SafehouseClaimMirror"
require "IKST_Identity"
require "IKST_Access"

IKST_SafehouseClaimClient = IKST_SafehouseClaimClient or {}
IKST_SafehouseClaimClient.safehouses = IKST_SafehouseClaimClient.safehouses or {}
IKST_SafehouseClaimClient.byKey = IKST_SafehouseClaimClient.byKey or {}
IKST_SafehouseClaimClient.listBootstrapped = IKST_SafehouseClaimClient.listBootstrapped or false

function IKST_SafehouseClaimClient.boundsKey(x, y, w, h)
    return tostring(math.floor(tonumber(x) or 0)) .. "_"
        .. tostring(math.floor(tonumber(y) or 0)) .. "_"
        .. tostring(math.floor(tonumber(w) or 0)) .. "_"
        .. tostring(math.floor(tonumber(h) or 0))
end

local function indexRow(row)
    if not row or row.x == nil or row.y == nil or not row.w or not row.h then
        return
    end
    IKST_SafehouseClaimClient.byKey[IKST_SafehouseClaimClient.boundsKey(row.x, row.y, row.w, row.h)] = row
end

function IKST_SafehouseClaimClient.reindexSafehouses()
    IKST_SafehouseClaimClient.byKey = {}
    for _, row in ipairs(IKST_SafehouseClaimClient.safehouses or {}) do
        indexRow(row)
    end
end

function IKST_SafehouseClaimClient.syncFromMirroredStore()
    if not IKST_SafehouseClaim or not IKST_SafehouseClaim.store then
        return
    end
    local data = IKST_SafehouseClaim.store()
    local rows = {}
    for _, entry in pairs(data.byKey or {}) do
        if entry and entry.x and entry.y and entry.w and entry.h
            and not IKST_SafehouseClaim.isEntryExpired(entry) then
            rows[#rows + 1] = {
                x = entry.x,
                y = entry.y,
                w = entry.w,
                h = entry.h,
                owner = entry.owner,
                ownerLabel = IKST_Identity.labelForKey(entry.owner),
                claimed = true,
                hoursRemainingText = IKST_ClaimPolicy.hoursRemainingLabel(entry.expiresAt),
                mirrored = true,
            }
        end
    end
    IKST_SafehouseClaimClient.safehouses = rows
    IKST_SafehouseClaimClient.reindexSafehouses()
end

function IKST_SafehouseClaimClient.onMirroredModData()
    local hasServerRows = false
    for _, row in ipairs(IKST_SafehouseClaimClient.safehouses or {}) do
        if row.canRelease ~= nil then
            hasServerRows = true
            break
        end
    end
    if not hasServerRows then
        IKST_SafehouseClaimClient.syncFromMirroredStore()
    end
    if IKST_JobsPanel and IKST_JobsPanel.instance then
        IKST_JobsPanel.instance:refreshJobUI()
    end
end

function IKST_SafehouseClaimClient.bootstrap(player)
    if not player or not IKST.isMultiplayerSession or not IKST.isMultiplayerSession() then
        return
    end
    IKST_SafehouseClaimClient.syncFromMirroredStore()
    IKST.dispatchCommand(player, IKST.CMD.safehouseList, {})
end

function IKST_SafehouseClaimClient.onSafehouseListResult(args)
    IKST_SafehouseClaimClient.safehouses = (args and args.safehouses) or {}
    IKST_SafehouseClaimClient.listBootstrapped = true
    IKST_SafehouseClaimClient.reindexSafehouses()
end

function IKST_SafehouseClaimClient.rowForBounds(x, y, w, h)
    if x == nil or y == nil or not w or not h then
        return nil
    end
    return IKST_SafehouseClaimClient.byKey[IKST_SafehouseClaimClient.boundsKey(x, y, w, h)]
end

function IKST_SafehouseClaimClient.spFallbackState(x, y, w, h, player, owner)
    local entry = IKST_SafehouseClaim.get(x, y, w, h)
    if entry and not IKST_SafehouseClaim.isEntryExpired(entry) then
        return {
            x = x, y = y, w = w, h = h,
            owner = entry.owner or owner,
            claimed = true,
            isMine = IKST_SafehouseClaim.isOwner(entry, player),
            canRelease = IKST_SafehouseClaim.isOwner(entry, player)
                or (IKST_Access and IKST_Access.canUseTools(player)),
            canEdit = IKST_SafehouseClaim.playerMayEdit(entry, player),
            hoursRemainingText = IKST_ClaimPolicy.hoursRemainingLabel(entry.expiresAt),
        }
    end
    local username = IKST_SafehouseClaim.playerUsername(player)
    local isOwner = owner and IKST_ClaimPolicy.usernamesEqual(owner, username)
    return {
        x = x, y = y, w = w, h = h,
        owner = owner,
        claimed = false,
        isMine = isOwner == true,
        canRelease = isOwner == true or (IKST_Access and IKST_Access.canUseTools(player)),
        canEdit = isOwner == true,
    }
end

function IKST_SafehouseClaimClient.uiState(x, y, w, h, player, owner)
    local row = IKST_SafehouseClaimClient.rowForBounds(x, y, w, h)
    if row then
        return row
    end
    if x == nil or y == nil or not w or not h then
        return nil
    end
    if IKST.isMultiplayerSession and IKST.isMultiplayerSession() then
        local entry = IKST_SafehouseClaim.get(x, y, w, h)
        if entry and not IKST_SafehouseClaim.isEntryExpired(entry) then
            return {
                x = x, y = y, w = w, h = h,
                owner = entry.owner or owner,
                claimed = true,
                canRelease = false,
                canEdit = false,
                stale = true,
            }
        end
        return {
            x = x, y = y, w = w, h = h,
            owner = owner,
            claimed = false,
            canRelease = false,
            canEdit = false,
            stale = true,
        }
    end
    return IKST_SafehouseClaimClient.spFallbackState(x, y, w, h, player, owner)
end

function IKST_SafehouseClaimClient.applyMirror(args)
    if IKST_SafehouseClaimMirror.applyMirror(args) then
        local x = tonumber(args.x)
        local y = tonumber(args.y)
        local w = tonumber(args.w)
        local h = tonumber(args.h)
        if args.action == "remove" and x and y and w and h then
            local bkey = IKST_SafehouseClaimClient.boundsKey(x, y, w, h)
            IKST_SafehouseClaimClient.byKey[bkey] = nil
            local kept = {}
            for _, row in ipairs(IKST_SafehouseClaimClient.safehouses or {}) do
                if IKST_SafehouseClaimClient.boundsKey(row.x, row.y, row.w, row.h) ~= bkey then
                    kept[#kept + 1] = row
                end
            end
            IKST_SafehouseClaimClient.safehouses = kept
        end
    end
end

function IKST_SafehouseClaimClient.forceRefresh(args)
    if args then
        IKST_SafehouseClaimClient.applyMirror(args)
    end
    local player = getPlayer and getPlayer() or nil
    if player and IKST.isMultiplayerSession and IKST.isMultiplayerSession() then
        IKST.dispatchCommand(player, IKST.CMD.safehouseList, {})
    end
    if IKST_JobsPanel and IKST_JobsPanel.instance then
        IKST_JobsPanel.instance:refreshJobUI()
    end
end
