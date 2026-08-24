-- Player claim-request queue (server ModData). Staff approve/deny here - not vanilla tickets.

if type(isClient) == "function" and isClient()
    and type(isServer) == "function" and not isServer() then
    return
end

require "IKST_Shared"
require "IKST_Authority"
require "IKST_Args"
require "IKST_Access"
require "IKST_Identity"
require "IKST_Claim"
require "IKST_ClaimPolicy"
require "IKST_GuardOps"
require "IKST_VehicleClaim"
require "IKST_VehicleIdentity"
require "IKST_VehicleUtil"
require "IKST_WorldOps"
require "IKST_PhunZones"

IKST_ClaimRequestQueue = IKST_ClaimRequestQueue or {}
IKST_ClaimRequestQueue.KEY = "IKST_ClaimRequestQueue"
IKST_ClaimRequestQueue.MAX = 40
IKST_ClaimRequestQueue.REASON_MAX = 120

local COORD_ABS_MAX = 100000

local function coordInRange(n)
    return n ~= nil and n > -COORD_ABS_MAX and n < COORD_ABS_MAX
end

local function nowMs()
    if type(getTimestampMs) == "function" then
        return getTimestampMs()
    end
    if type(getTimeInMillis) == "function" then
        return getTimeInMillis()
    end
    return 0
end

local function notifyUser(username, ok, message, mode)
    if not username or username == "" then
        return
    end
    local target = nil
    if IKST_Identity and type(IKST_Identity.findPlayerByUsername) == "function" then
        target = IKST_Identity.findPlayerByUsername(username)
    end
    if not target or not IKST_WorldOps or type(IKST_WorldOps.sendResult) ~= "function" then
        return
    end
    IKST_WorldOps.sendResult(target, ok == true, message or "", nil, nil, nil, mode or "claimRequest")
end

local function requestUsername(player)
    local user = nil
    if IKST_Identity and type(IKST_Identity.username) == "function" then
        user = IKST_Identity.username(player)
    end
    if not user or user == "" then
        if player and type(player.getUsername) == "function" then
            user = player:getUsername()
        end
    end
    return user
end

local function removePendingForUser(user, kind)
    local data = IKST_ClaimRequestQueue.store()
    for i = #data.pending, 1, -1 do
        local row = data.pending[i]
        if row and row.user == user then
            local rowKind = row.kind or "safehouse"
            if rowKind == kind then
                table.remove(data.pending, i)
            end
        end
    end
end

function IKST_ClaimRequestQueue.store()
    local data = ModData.getOrCreate(IKST_ClaimRequestQueue.KEY)
    data.pending = data.pending or {}
    return data
end

function IKST_ClaimRequestQueue.list()
    return IKST_ClaimRequestQueue.store().pending or {}
end

function IKST_ClaimRequestQueue.find(requestId)
    requestId = tostring(requestId or "")
    if requestId == "" then
        return nil, nil
    end
    local pending = IKST_ClaimRequestQueue.store().pending or {}
    for i = 1, #pending do
        if pending[i].id == requestId then
            return pending[i], i
        end
    end
    return nil, nil
end

function IKST_ClaimRequestQueue.removeAt(index)
    local data = IKST_ClaimRequestQueue.store()
    if not index or index < 1 or index > #(data.pending or {}) then
        return nil
    end
    return table.remove(data.pending, index)
end

local function validateVehicleSelfClaimRules(player, vehicle)
    if not player or not vehicle then
        return false, "no vehicle nearby - pick one in the list"
    end
    local vz = type(vehicle.getZ) == "function" and vehicle:getZ() or 0
    if not IKST_Args.actorNearCoord(player, vehicle:getX(), vehicle:getY(), vz, IKST.getVehicleNearRadius()) then
        return false, "too far"
    end
    if IKST_ClaimPolicy.vehicleRequireSeat() then
        local seated = type(player.getVehicle) == "function" and player:getVehicle() or nil
        if seated ~= vehicle then
            return false, "sit in the vehicle to claim it"
        end
    end
    if IKST_ClaimPolicy.vehicleRequireEngine() then
        if type(vehicle.isEngineRunning) ~= "function" or not vehicle:isEngineRunning() then
            return false, "start the engine to claim"
        end
    end
    if IKST_ClaimPolicy.vehicleRequireKeys() then
        if not IKST_VehicleUtil or type(IKST_VehicleUtil.playerHasVehicleKey) ~= "function"
            or not IKST_VehicleUtil.playerHasVehicleKey(player, vehicle) then
            return false, "need vehicle key to claim"
        end
    end
    return true, nil
end

local function validateSafehouseRequestRect(player, x, y, z, w, h)
    if x == nil or y == nil or not w or not h or z == nil then
        return false, "invalid zone"
    end
    local probeX = x + math.floor(w / 2)
    local probeY = y + math.floor(h / 2)
    local square = nil
    if IKST_WorldOps and type(IKST_WorldOps.getSquare) == "function" then
        square = IKST_WorldOps.getSquare(probeX, probeY, z)
        if not square then
            square = IKST_WorldOps.getSquare(x, y, z)
        end
    end
    if not square then
        return false, "invalid square"
    end
    if IKST_Access and type(IKST_Access.canUseTools) == "function" and not IKST_Access.canUseTools(player) then
        local building = nil
        if type(square.getBuilding) == "function" then
            building = square:getBuilding()
        end
        if not IKST_Claim.isResidentialBuilding(building) then
            return false, "residential buildings only"
        end
    end
    if IKST_PhunZones and type(IKST_PhunZones.claimAllowed) == "function" then
        local allowed, blockMsg = IKST_PhunZones.claimAllowed(x, y, z, w, h, square)
        if not allowed then
            return false, blockMsg or "claim blocked"
        end
    end
    if SafeHouse and type(SafeHouse.getSafeHouse) == "function" then
        local existing = SafeHouse.getSafeHouse(square)
        if existing then
            return false, "safehouse already here"
        end
    end
    if IKST_GuardOps and type(IKST_GuardOps.safehouseAt) == "function" then
        local existing = IKST_GuardOps.safehouseAt(x, y, z, w, h)
        if existing then
            return false, "safehouse already here"
        end
    end
    return true, nil
end

-- Walk-draw corners -> pending staff review. Does not create a safehouse.
function IKST_ClaimRequestQueue.submit(player, args)
    if IKST_Authority and not IKST_Authority.guardServerMutate() then
        return false, "server only"
    end
    if not IKST.isMultiplayerSession or not IKST.isMultiplayerSession() then
        return false, "multiplayer only"
    end
    if not player then
        return false, "no player"
    end
    if not IKST_ClaimPolicy.mayRequestSafehouseClaim(player) then
        return false, "house claim requests disabled"
    end
    local x1 = IKST_Args.readCoord(args, "x1")
    local y1 = IKST_Args.readCoord(args, "y1")
    local z1 = IKST_Args.readCoord(args, "z1")
    local x2 = IKST_Args.readCoord(args, "x2")
    local y2 = IKST_Args.readCoord(args, "y2")
    local z2 = IKST_Args.readCoord(args, "z2")
    if not coordInRange(x1) or not coordInRange(y1) or z1 == nil
        or not coordInRange(x2) or not coordInRange(y2) or z2 == nil then
        return false, "need both corners"
    end
    if z1 < -1 or z1 > 32 or z2 < -1 or z2 > 32 then
        return false, "need both corners"
    end
    local dist = 8
    if IKST_Access and type(IKST_Access.sandboxInt) == "function" then
        dist = IKST_Access.sandboxInt("ClaimNearDistance", 8, 2, 32)
    end
    if not IKST_Args.actorNearCoord(player, x2, y2, z2, dist) then
        return false, "stand at the end corner"
    end
    local ok, err, x, y, w, h = IKST_Claim.walkDrawRect(x1, y1, z1, x2, y2, z2)
    if not ok then
        return false, err or "invalid zone"
    end
    local user = requestUsername(player)
    if not user or user == "" then
        return false, "no username"
    end
    if IKST_GuardOps and type(IKST_GuardOps.atMaxSafehouseClaims) == "function"
        and IKST_GuardOps.atMaxSafehouseClaims(user) then
        return false, "max safehouse claims"
    end
    local z = math.floor(z1)
    local rectOk, rectErr = validateSafehouseRequestRect(player, x, y, z, w, h)
    if not rectOk then
        return false, rectErr or "invalid zone"
    end
    local data = IKST_ClaimRequestQueue.store()
    removePendingForUser(user, "safehouse")
    data.pending[#data.pending + 1] = {
        id = tostring(nowMs()) .. ":" .. user .. ":house",
        kind = "safehouse",
        user = user,
        x = x,
        y = y,
        z = z,
        w = w,
        h = h,
        x1 = x1,
        y1 = y1,
        z1 = z1,
        x2 = x2,
        y2 = y2,
        z2 = z2,
        t = nowMs(),
    }
    while #data.pending > IKST_ClaimRequestQueue.MAX do
        table.remove(data.pending, 1)
    end
    if IKST_StaffHistory and type(IKST_StaffHistory.record) == "function" then
        IKST_StaffHistory.record(player, "claim-request",
            string.format("%dx%d @ %d,%d", w, h, x, y), true)
    end
    return true, "house claim request sent - staff will review it under Claim requests"
end

function IKST_ClaimRequestQueue.submitVehicle(player, args)
    if IKST_Authority and not IKST_Authority.guardServerMutate() then
        return false, "server only"
    end
    if not IKST.isMultiplayerSession or not IKST.isMultiplayerSession() then
        return false, "multiplayer only"
    end
    if not player then
        return false, "no player"
    end
    if not IKST_ClaimPolicy.mayRequestVehicleClaim(player) then
        return false, "vehicle claim requests disabled"
    end
    local vehicle = nil
    if type(player.getVehicle) == "function" then
        vehicle = player:getVehicle()
    end
    if not vehicle and IKST_GuardOps and type(IKST_GuardOps.resolveClaimVehicle) == "function" then
        vehicle = IKST_GuardOps.resolveClaimVehicle(player, args and args.vehicleId)
    end
    if not vehicle then
        return false, "no vehicle nearby - pick one in the list"
    end
    local runtimeId = nil
    if type(vehicle.getId) == "function" then
        runtimeId = vehicle:getId()
    end
    if runtimeId == nil then
        return false, "vehicle identity missing"
    end
    if IKST_VehicleClaim.isVehicleClaimed(vehicle) then
        return false, "already claimed"
    end
    local vz = type(vehicle.getZ) == "function" and vehicle:getZ() or 0
    if not IKST_Args.actorNearCoord(player, vehicle:getX(), vehicle:getY(), vz, IKST.getVehicleNearRadius()) then
        return false, "too far"
    end
    local rulesOk, rulesMsg = validateVehicleSelfClaimRules(player, vehicle)
    if not rulesOk then
        return false, rulesMsg
    end
    local user = requestUsername(player)
    if not user or user == "" then
        return false, "no username"
    end
    local ownerKey = IKST_Identity.accountKey(player)
    if ownerKey and IKST_VehicleClaim.atMaxClaims(ownerKey) then
        return false, "max vehicle claims"
    end
    local claimKey = IKST_VehicleClaim.ensureKey(vehicle)
    if not claimKey then
        return false, "vehicle identity missing"
    end
    local script = IKST_VehicleIdentity.scriptName(vehicle)
    local x, y, z = IKST_VehicleIdentity.coords(vehicle)
    local data = IKST_ClaimRequestQueue.store()
    removePendingForUser(user, "vehicle")
    data.pending[#data.pending + 1] = {
        id = tostring(nowMs()) .. ":" .. user .. ":vehicle",
        kind = "vehicle",
        user = user,
        vehicleRuntimeId = runtimeId,
        claimKey = claimKey,
        script = script,
        x = x,
        y = y,
        z = z,
        t = nowMs(),
    }
    while #data.pending > IKST_ClaimRequestQueue.MAX do
        table.remove(data.pending, 1)
    end
    if IKST_StaffHistory and type(IKST_StaffHistory.record) == "function" then
        IKST_StaffHistory.record(player, "vehicle-claim-request",
            tostring(script or "vehicle") .. " @" .. tostring(math.floor(x or 0)) .. "," .. tostring(math.floor(y or 0)), true)
    end
    return true, "vehicle claim request sent - staff will review it under Claim requests"
end

function IKST_ClaimRequestQueue.approveVehicle(staff, entry, index)
    local vehicle = nil
    if entry.vehicleRuntimeId ~= nil and IKST_GuardOps.resolveClaimVehicle then
        vehicle = IKST_GuardOps.resolveClaimVehicle(staff, entry.vehicleRuntimeId)
    end
    if not vehicle and entry.claimKey and IKST_VehicleClaim.findVehicleByKey then
        vehicle = IKST_VehicleClaim.findVehicleByKey(entry.claimKey)
    end
    if not vehicle then
        return false, "vehicle not found"
    end
    if IKST_VehicleClaim.isVehicleClaimed(vehicle) then
        return false, "already claimed"
    end
    local ownerPlayer = IKST_Identity.findPlayerByUsername(entry.user)
    if ownerPlayer then
        local rulesOk, rulesMsg = validateVehicleSelfClaimRules(ownerPlayer, vehicle)
        if not rulesOk then
            return false, rulesMsg
        end
    end
    local ownerKey = entry.user
    if ownerPlayer then
        ownerKey = IKST_Identity.accountKey(ownerPlayer)
    else
        ownerKey = IKST_Identity.resolveWhitelistKey(entry.user)
    end
    if not ownerKey or ownerKey == "" then
        return false, "no owner"
    end
    local key = IKST_VehicleClaim.ensureKey(vehicle)
    if not key then
        return false, "vehicle identity missing"
    end
    local meta = {
        label = "",
        script = IKST_VehicleIdentity.scriptName(vehicle),
        x = entry.x,
        y = entry.y,
        z = entry.z,
    }
    local ok, msg = IKST_VehicleClaim.claim(key, ownerKey, meta)
    if not ok then
        return false, msg or "claim failed"
    end
    IKST_ClaimRequestQueue.removeAt(index)
    if IKST_GuardOps.afterVehicleClaimMutation then
        IKST_GuardOps.afterVehicleClaimMutation(staff, "set", key)
    end
    if IKST_StaffHistory and type(IKST_StaffHistory.record) == "function" then
        IKST_StaffHistory.record(staff, "vehicle-claim-approve",
            tostring(entry.user) .. " " .. tostring(msg or ""), true)
    end
    notifyUser(entry.user, true, "Your vehicle claim was approved: " .. tostring(msg or "claimed"),
        "claimRequestApprove")
    return true, "approved vehicle for " .. tostring(entry.user)
end

function IKST_ClaimRequestQueue.approve(staff, requestId)
    if IKST_Authority and not IKST_Authority.guardServerMutate() then
        return false, "server only"
    end
    if not staff then
        return false, "no player"
    end
    local entry, index = IKST_ClaimRequestQueue.find(requestId)
    if not entry then
        return false, "request not found"
    end
    local kind = entry.kind or "safehouse"
    if kind == "vehicle" then
        return IKST_ClaimRequestQueue.approveVehicle(staff, entry, index)
    end
    local ok, msg = IKST_GuardOps.claimSafehouse(
        staff,
        entry.x,
        entry.y,
        entry.z or 0,
        nil,
        entry.user,
        IKST_Claim.MODE.square,
        entry.w,
        entry.h,
        true
    )
    if not ok then
        return false, msg or "claim failed"
    end
    IKST_ClaimRequestQueue.removeAt(index)
    if IKST_StaffHistory and type(IKST_StaffHistory.record) == "function" then
        IKST_StaffHistory.record(staff, "claim-approve",
            tostring(entry.user) .. " " .. tostring(msg or ""), true)
    end
    notifyUser(entry.user, true, "Your claim was approved: " .. tostring(msg or "safehouse claimed"),
        "claimRequestApprove")
    return true, "approved for " .. tostring(entry.user)
end

function IKST_ClaimRequestQueue.deny(staff, requestId, reason)
    if IKST_Authority and not IKST_Authority.guardServerMutate() then
        return false, "server only"
    end
    if not staff then
        return false, "no player"
    end
    local entry, index = IKST_ClaimRequestQueue.find(requestId)
    if not entry then
        return false, "request not found"
    end
    reason = tostring(reason or "")
    reason = string.gsub(reason, "^%s*(.-)%s*$", "%1")
    if #reason > IKST_ClaimRequestQueue.REASON_MAX then
        reason = string.sub(reason, 1, IKST_ClaimRequestQueue.REASON_MAX)
    end
    IKST_ClaimRequestQueue.removeAt(index)
    if IKST_StaffHistory and type(IKST_StaffHistory.record) == "function" then
        IKST_StaffHistory.record(staff, "claim-deny",
            tostring(entry.user) .. (reason ~= "" and (": " .. reason) or ""), true)
    end
    local playerMsg = "Your claim request was refused"
    if entry.kind == "vehicle" then
        playerMsg = "Your vehicle claim request was refused"
    end
    if reason ~= "" then
        playerMsg = playerMsg .. ": " .. reason
    end
    notifyUser(entry.user, false, playerMsg, "claimRequestDeny")
    return true, "denied " .. tostring(entry.user)
end
