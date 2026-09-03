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

local function eachStoredClaimEntry(callback)
    if not callback then
        return
    end
    if IKST_SafehouseClaimMirror and type(IKST_SafehouseClaimMirror.usesMirror) == "function"
        and IKST_SafehouseClaimMirror.usesMirror() then
        for _, entry in pairs(IKST_SafehouseClaimMirror.byKey or {}) do
            callback(entry)
        end
        return
    end
    if IKST_SafehouseClaim and type(IKST_SafehouseClaim.store) == "function" then
        local data = IKST_SafehouseClaim.store()
        for _, entry in pairs(data and data.byKey or {}) do
            callback(entry)
        end
    end
end

function IKST_SafehouseClaimClient.rowFromMirrorEntry(entry, player)
    if not entry or entry.x == nil or entry.y == nil or not entry.w or not entry.h then
        return nil
    end
    if IKST_SafehouseClaim and IKST_SafehouseClaim.isEntryExpired(entry) then
        return nil
    end
    local row = {
        x = entry.x,
        y = entry.y,
        w = entry.w,
        h = entry.h,
        owner = entry.owner,
        ownerLabel = IKST_Identity and IKST_Identity.labelForKey and IKST_Identity.labelForKey(entry.owner) or entry.owner,
        claimed = true,
        hoursRemainingText = IKST_ClaimPolicy.hoursRemainingLabel(entry.expiresAt),
        mirrored = true,
    }
    return IKST_SafehouseClaimClient.finalizeUiState(row, player, entry.owner)
end

function IKST_SafehouseClaimClient.mergeMissingOwnedRows(player)
    player = IKST.resolvePlayer(player)
    if not player then
        return
    end
    local added = false
    eachStoredClaimEntry(function(entry)
        if IKST_SafehouseClaimClient.rowForBounds(entry.x, entry.y, entry.w, entry.h) then
            return
        end
        local row = IKST_SafehouseClaimClient.rowFromMirrorEntry(entry, player)
        if not row or row.isMine ~= true then
            return
        end
        IKST_SafehouseClaimClient.safehouses[#IKST_SafehouseClaimClient.safehouses + 1] = row
        added = true
    end)
    if added then
        IKST_SafehouseClaimClient.reindexSafehouses()
    end
end

function IKST_SafehouseClaimClient.syncFromMirroredStore()
    local player = getPlayer and getPlayer() or nil
    local rows = {}
    eachStoredClaimEntry(function(entry)
        local row = IKST_SafehouseClaimClient.rowFromMirrorEntry(entry, player)
        if row then
            rows[#rows + 1] = row
        end
    end)
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
    local player = getPlayer and getPlayer() or nil
    if player and type(IKST_SafehouseClaimClient.mergeMissingOwnedRows) == "function" then
        IKST_SafehouseClaimClient.mergeMissingOwnedRows(player)
    end
    if IKST_Hub and type(IKST_Hub.refreshActive) == "function" then
        IKST_Hub.refreshActive()
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
    local player = getPlayer and getPlayer() or nil
    IKST_SafehouseClaimClient.mergeMissingOwnedRows(player)
    if #IKST_SafehouseClaimClient.safehouses == 0 then
        IKST_SafehouseClaimClient.syncFromMirroredStore()
    end
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

function IKST_SafehouseClaimClient.finalizeUiState(state, player, owner)
    if not state then
        return nil
    end
    if state.claimed == true then
        local entry = nil
        if state.x ~= nil and state.y ~= nil and state.w and state.h then
            entry = IKST_SafehouseClaim.get(state.x, state.y, state.w, state.h)
        end
        local isAdmin = IKST_Access and type(IKST_Access.canUseTools) == "function"
            and IKST_Access.canUseTools(player)
        if entry and not IKST_SafehouseClaim.isEntryExpired(entry) then
            state.isMine = IKST_SafehouseClaim.isOwner(entry, player)
            state.canRelease = IKST_SafehouseClaim.isOwner(entry, player) or isAdmin
            state.canEdit = IKST_SafehouseClaim.playerMayEdit(entry, player) or isAdmin
        elseif isAdmin then
            state.canRelease = true
            state.canEdit = true
        end
        return state
    end
    state.canRelease = false
    state.canEdit = false
    return state
end

function IKST_SafehouseClaimClient.uiState(x, y, w, h, player, owner)
    local row = IKST_SafehouseClaimClient.rowForBounds(x, y, w, h)
    if row then
        return IKST_SafehouseClaimClient.finalizeUiState(row, player, owner)
    end
    if x == nil or y == nil or not w or not h then
        return nil
    end
    if IKST.isMultiplayerSession and IKST.isMultiplayerSession() then
        local entry = IKST_SafehouseClaim.get(x, y, w, h)
        if entry and not IKST_SafehouseClaim.isEntryExpired(entry) then
            return IKST_SafehouseClaimClient.finalizeUiState({
                x = x, y = y, w = w, h = h,
                owner = entry.owner or owner,
                claimed = true,
                canRelease = false,
                canEdit = false,
                stale = true,
            }, player, owner)
        end
        return IKST_SafehouseClaimClient.finalizeUiState({
            x = x, y = y, w = w, h = h,
            owner = owner,
            claimed = false,
            canRelease = false,
            canEdit = false,
            stale = true,
        }, player, owner)
    end
    return IKST_SafehouseClaimClient.finalizeUiState(
        IKST_SafehouseClaimClient.spFallbackState(x, y, w, h, player, owner), player, owner)
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
    local mirrorReady = IKST_SafehouseClaimMirror and IKST_SafehouseClaimMirror.usesMirror
        and IKST_SafehouseClaimMirror.usesMirror() and IKST_SafehouseClaimMirror.isReady()
    if player and not mirrorReady and IKST.isMultiplayerSession and IKST.isMultiplayerSession() then
        IKST.dispatchCommand(player, IKST.CMD.safehouseList, {})
    end
    if IKST_Hub and type(IKST_Hub.refreshActive) == "function" then
        IKST_Hub.refreshActive()
    end
end
