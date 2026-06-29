IKST = IKST or {}

IKST.MODULE = "IKST"
IKST.VERSION = "0.2.6.5"

IKST.STAFF_ECONOMY_GIVE_MAX = 500000

IKST.CMD = {
    inspectSquare = "inspectSquare",
    cleanupObject = "cleanupObject",
    cleanupTile = "cleanupTile",
    cleanupSquare = "cleanupSquare",
    cleanupRadius = "cleanupRadius",
    cleanupCube = "cleanupCube",
    cleanupRoom = "cleanupRoom",
    cleanupBuilding = "cleanupBuilding",
    cleanupVegetation = "cleanupVegetation",
    paintPlace = "paintPlace",
    paintRemove = "paintRemove",
    vehicleSpawn = "vehicleSpawn",
    vehicleMove = "vehicleMove",
    vehicleDelete = "vehicleDelete",
    vehicleDeleteCell = "vehicleDeleteCell",
    vehiclePrune = "vehiclePrune",
    vehicleFlip = "vehicleFlip",
    vehicleRepair = "vehicleRepair",
    vehicleKey = "vehicleKey",
    vehicleList = "vehicleList",
    threatCull = "threatCull",
    threatPopulation = "threatPopulation",
    quickSave = "quickSave",
    quickBroadcast = "quickBroadcast",
    quickWater = "quickWater",
    quickPower = "quickPower",
    healSelf = "healSelf",
    feedSelf = "feedSelf",
    cureSelf = "cureSelf",
    godSelf = "godSelf",
    invisSelf = "invisSelf",
    ghostSelf = "ghostSelf",
    tpCoords = "tpCoords",
    giveItem = "giveItem",
    giveKit = "giveKit",
    setTime = "setTime",
    setWeather = "setWeather",
    clearWeather = "clearWeather",
    clearZombies = "clearZombies",
    healTarget = "healTarget",
    bringTarget = "bringTarget",
    tpToTarget = "tpToTarget",
    giveTarget = "giveTarget",
    economyGive = "economyGive",
    economyGiveTarget = "economyGiveTarget",
    economyBalance = "economyBalance",
    economyReissueId = "economyReissueId",
    economyReissueIdTarget = "economyReissueIdTarget",
    economySnapshot = "economySnapshot",
    economySnapshotResult = "economySnapshotResult",
    economyDeposit = "economyDeposit",
    economyWithdraw = "economyWithdraw",
    economyWire = "economyWire",
    economyExchange = "economyExchange",
    economyExchangeAll = "economyExchangeAll",
    economyIdCardReissue = "economyIdCardReissue",
    economyVendEnable = "economyVendEnable",
    economyVendClaim = "economyVendClaim",
    economyShopPlace = "economyShopPlace",
    economyVendDisable = "economyVendDisable",
    economyVendSetPrice = "economyVendSetPrice",
    economyVendBuy = "economyVendBuy",
    economyVendList = "economyVendList",
    economyVendListResult = "economyVendListResult",
    economyAtmConfigure = "economyAtmConfigure",
    economyAtmPlace = "economyAtmPlace",
    staffListPlayers = "staffListPlayers",
    vehicleRepairNear = "vehicleRepairNear",
    vehicleKeyNear = "vehicleKeyNear",
    healAll = "healAll",
    feedAll = "feedAll",
    cureAll = "cureAll",
    tpAllToMe = "tpAllToMe",
    feedTarget = "feedTarget",
    cureTarget = "cureTarget",
    godTarget = "godTarget",
    saveWaypoint = "saveWaypoint",
    delWaypoint = "delWaypoint",
    tpWaypoint = "tpWaypoint",
    listWaypoints = "listWaypoints",
    lootRepopulateContainer = "lootRepopulateContainer",
    lootRepopulateZone = "lootRepopulateZone",
    autoGardener = "autoGardener",
    autoLumberjack = "autoLumberjack",
    autoGravel = "autoGravel",
    autoCorpseStack = "autoCorpseStack",
    autoHomeWreck = "autoHomeWreck",
    autoFarmer = "autoFarmer",
    autoUnloadContainers = "autoUnloadContainers",
    protectSquare = "protectSquare",
    unprotectSquare = "unprotectSquare",
    protectRadius = "protectRadius",
    unprotectRadius = "unprotectRadius",
    protectVehicle = "protectVehicle",
    unprotectVehicle = "unprotectVehicle",
    setDropbox = "setDropbox",
    setReadonly = "setReadonly",
    protectList = "protectList",
    vehicleSkinNext = "vehicleSkinNext",
    vehicleSkinPrev = "vehicleSkinPrev",
    vehicleUnlockTrunk = "vehicleUnlockTrunk",
    vehicleUnlockDoors = "vehicleUnlockDoors",
    catchTarget = "catchTarget",
    catchPlayer = "catchPlayer",
    releaseTarget = "releaseTarget",
    releasePlayer = "releasePlayer",
    toggleCreative = "toggleCreative",
    toggleUnlimitedAmmo = "toggleUnlimitedAmmo",
    lightbulbsArea = "lightbulbsArea",
    dumpPlayers = "dumpPlayers",
    dumpPlayersResult = "dumpPlayersResult",
    safehouseList = "safehouseList",
    safehouseListResult = "safehouseListResult",
    safehouseClientRefresh = "safehouseClientRefresh",
    safehouseRelease = "safehouseRelease",
    safehouseClaim = "safehouseClaim",
    safehouseTp = "safehouseTp",
    backupSafehouses = "backupSafehouses",
    restoreSafehouses = "restoreSafehouses",
    toggleSafehouseBorders = "toggleSafehouseBorders",
    vehicleClaim = "vehicleClaim",
    vehicleReleaseClaim = "vehicleReleaseClaim",
    vehicleClaimTransfer = "vehicleClaimTransfer",
    vehicleClaimSetLabel = "vehicleClaimSetLabel",
    vehicleClaimSetPerms = "vehicleClaimSetPerms",
    vehicleClaimList = "vehicleClaimList",
    vehicleClaimListResult = "vehicleClaimListResult",
    vehicleClaimNearby = "vehicleClaimNearby",
    safehouseAddMember = "safehouseAddMember",
    safehouseRemoveMember = "safehouseRemoveMember",
    safehouseClaimSetPerms = "safehouseClaimSetPerms",
    journalRecord = "journalRecord",
    journalRestore = "journalRestore",
    lockTryUnlock = "lockTryUnlock",
    lockInstallKeypad = "lockInstallKeypad",
    lockUnlockSync = "lockUnlockSync",
    setWorldRule = "setWorldRule",
    addSpriteBlacklist = "addSpriteBlacklist",
    farmRevitalize = "farmRevitalize",
    farmHarvestAll = "farmHarvestAll",
    blueprintCopy = "blueprintCopy",
    blueprintPaste = "blueprintPaste",
    createSnapshot = "createSnapshot",
    restoreSnapshot = "restoreSnapshot",
    lockSetPassword = "lockSetPassword",
    lockClear = "lockClear",
    safehouseBordersSync = "safehouseBordersSync",
    catchSync = "catchSync",
    result = "result",
    batchProgress = "batchProgress",
    vehicleListResult = "vehicleListResult",
    inspectResult = "inspectResult",
    threatResult = "threatResult",
    staffListResult = "staffListResult",
    waypointListResult = "waypointListResult",
    applyTeleport = "applyTeleport",
    applyStaffModes = "applyStaffModes",
    applyVehicleSync = "applyVehicleSync",
    protectListResult = "protectListResult",
    auditTail = "auditTail",
    auditTailResult = "auditTailResult",
    debugStatus = "debugStatus",
    debugTail = "debugTail",
    debugStatusResult = "debugStatusResult",
    debugTailResult = "debugTailResult",
    utilitySync = "utilitySync",
    rewind = "rewind",
    rewindSync = "rewindSync",
    briefingFetch = "briefingFetch",
    briefingResult = "briefingResult",
    arrivalSync = "arrivalSync",
    vehicleFieldRecovery = "vehicleFieldRecovery",
}

IKST.AUTO_COMMANDS = {
    autoGardener = true,
    autoLumberjack = true,
    autoGravel = true,
    autoCorpseStack = true,
    autoHomeWreck = true,
    autoFarmer = true,
    autoUnloadContainers = true,
}

IKST.PROTECT_COMMANDS = {
    protectSquare = true,
    unprotectSquare = true,
    protectRadius = true,
    unprotectRadius = true,
    protectVehicle = true,
    unprotectVehicle = true,
    setDropbox = true,
    setReadonly = true,
}

IKST.GUARD_COMMANDS = {
    catchTarget = true,
    catchPlayer = true,
    releaseTarget = true,
    releasePlayer = true,
    toggleCreative = true,
    toggleUnlimitedAmmo = true,
    lightbulbsArea = true,
    dumpPlayers = true,
    safehouseList = true,
    safehouseRelease = true,
    safehouseClaim = true,
    safehouseTp = true,
    backupSafehouses = true,
    restoreSafehouses = true,
    toggleSafehouseBorders = true,
    vehicleClaim = true,
    vehicleReleaseClaim = true,
    vehicleClaimTransfer = true,
    vehicleClaimSetLabel = true,
    vehicleClaimSetPerms = true,
    vehicleClaimList = true,
    vehicleClaimNearby = true,
    safehouseAddMember = true,
    safehouseRemoveMember = true,
    safehouseClaimSetPerms = true,
}

IKST.PLAYER_CLAIM_COMMANDS = {
    vehicleClaim = true,
    vehicleReleaseClaim = true,
    vehicleClaimList = true,
    vehicleClaimNearby = true,
    vehicleClaimSetLabel = true,
    vehicleClaimSetPerms = true,
    safehouseClaim = true,
    safehouseList = true,
    safehouseRelease = true,
    safehouseAddMember = true,
    safehouseRemoveMember = true,
    safehouseClaimSetPerms = true,
    journalRecord = true,
    journalRestore = true,
    lockTryUnlock = true,
    lockInstallKeypad = true,
}

IKST.JOURNAL_TYPE = "IKST.RecoveryJournal"
IKST.KEYPAD_KIT_TYPE = "IKST.KeypadKit"

IKST.STAFF_COMMANDS = {
    healSelf = true,
    feedSelf = true,
    cureSelf = true,
    godSelf = true,
    invisSelf = true,
    ghostSelf = true,
    tpCoords = true,
    giveItem = true,
    giveKit = true,
    setTime = true,
    setWeather = true,
    clearWeather = true,
    clearZombies = true,
    healTarget = true,
    bringTarget = true,
    tpToTarget = true,
    giveTarget = true,
    economyGive = true,
    economyGiveTarget = true,
    economyBalance = true,
    economyReissueId = true,
    economyReissueIdTarget = true,
    vehicleRepairNear = true,
    vehicleKeyNear = true,
    healAll = true,
    feedAll = true,
    cureAll = true,
    tpAllToMe = true,
    feedTarget = true,
    cureTarget = true,
    godTarget = true,
    saveWaypoint = true,
    delWaypoint = true,
    tpWaypoint = true,
}

IKST.VIEW = {
    favorites = "favorites",
    hub = "favorites",
    utilities = "utilities",
    claim = "claim",
    everyone = "everyone",
    tiles = "tiles",
    vehicles = "vehicles",
    build = "build",
    server = "server",
    quick = "quick",
    players = "players",
    safehouses = "safehouses",
    worldedit = "worldedit",
    rules = "rules",
    gadgets = "gadgets",
    cleanup = "cleanup",
    painter = "painter",
    vehicle = "vehicle",
    threat = "threat",
    inspector = "inspector",
    staff = "staff",
    economy = "economy",
    automation = "automation",
    loot = "loot",
    protect = "guard",
    guard = "guard",
}

IKST.CLEANUP_MODES = {
    removeObject = "removeObject",
    removeTile = "removeTile",
    clearSquare = "clearSquare",
    radius = "radius",
    room = "room",
    building = "building",
    vegetation = "vegetation",
    inspect = "inspect",
}

IKST.CLEANUP_SCOPES = {
    single = "single",
    cube = "cube",
    radius = "radius",
    room = "room",
    building = "building",
}

IKST.RADIUS_PRESETS = { S = 3, M = 7, L = 15 }
IKST.CUBE_PRESETS = { S = 1, M = 3, L = 7 }

-- Core cleanup actions shown in the UI (scope is chosen separately).
IKST.CLEANUP_ACTIONS = {
    IKST.CLEANUP_MODES.removeObject,
    IKST.CLEANUP_MODES.removeTile,
    IKST.CLEANUP_MODES.vegetation,
}

IKST.CLEANUP_SCOPE_LIST = {
    IKST.CLEANUP_SCOPES.single,
    IKST.CLEANUP_SCOPES.cube,
    IKST.CLEANUP_SCOPES.radius,
    IKST.CLEANUP_SCOPES.room,
    IKST.CLEANUP_SCOPES.building,
}

IKST.PAINTER_MODES = {
    eyedropper = "eyedropper",
    paint = "paint",
    remove = "remove",
    replace = "replace",
}

function IKST.resolvePlayer(playerOrNum)
    if playerOrNum == nil then
        return getPlayer and getPlayer() or nil
    end
    if type(playerOrNum) == "number" then
        if getSpecificPlayer then
            return getSpecificPlayer(playerOrNum)
        end
        return getPlayer and getPlayer() or nil
    end
    if playerOrNum.getModData then
        return playerOrNum
    end
    return getPlayer and getPlayer() or nil
end

function IKST.text(key, fallback)
    if not key then
        return fallback or ""
    end
    if getText and type(getText) == "function" then
        local value = getText(key)
        if value and value ~= "" and value ~= key then
            return value
        end
    end
    return fallback or key
end

function IKST.getPlayerState(player)
    player = IKST.resolvePlayer(player)
    if not player or not player.getModData then
        return nil
    end
    local md = player:getModData()
    if not md then
        return nil
    end
    if not md.IKST then
        md.IKST = {
            view = IKST.VIEW.favorites,
            job = nil,
            cleanupMode = IKST.CLEANUP_MODES.removeObject,
            cleanupAction = IKST.CLEANUP_MODES.removeObject,
            cleanupScope = IKST.CLEANUP_SCOPES.single,
            cleanupCubeHalf = IKST.CUBE_PRESETS.M,
            armed = false,
            armedJob = nil,
            log = {},
            panel = {},
            cleanupRadius = IKST.RADIUS_PRESETS.M,
            lootScope = IKST.CLEANUP_SCOPES.single,
            rewindStack = {},
            painterMode = IKST.PAINTER_MODES.eyedropper,
            vehicleMode = "list",
            worldEditMode = "remove",
            gadgetMode = "area",
            favorites = {},
            recentSprites = {},
            currentPick = nil,
            settings = {
                autoPaintAfterEyedropper = true,
            },
            lastInspect = nil,
            lastBroadcast = "",
            lastView = nil,
            lastNavMode = nil,
            lastNavTool = nil,
            navMode = nil,
            navTool = nil,
            recentViews = {},
        }
    end
    if not md.IKST.log then
        md.IKST.log = {}
    end
    if not md.IKST.panel then
        md.IKST.panel = {}
    end
    if not md.IKST.favorites then
        md.IKST.favorites = {}
    end
    if not md.IKST.recentSprites then
        md.IKST.recentSprites = {}
    end
    if not md.IKST.recentViews then
        md.IKST.recentViews = {}
    end
    if not md.IKST.settings then
        md.IKST.settings = { autoPaintAfterEyedropper = true }
    end
    IKST.normalizeCleanupState(md.IKST)
    return md.IKST
end

function IKST.pushRecentSprite(player, pick)
    if not pick or not pick.sprite then
        return
    end
    local state = IKST.getPlayerState(player)
    if not state then
        return
    end
    table.insert(state.recentSprites, 1, pick)
    while #state.recentSprites > 50 do
        table.remove(state.recentSprites)
    end
end

function IKST.normalizeCleanupState(state)
    if not state then
        return
    end
    if state.cleanupAction and state.cleanupScope then
        state.cleanupMode = state.cleanupAction
        if not state.cleanupCubeHalf then
            state.cleanupCubeHalf = IKST.CUBE_PRESETS.M
        end
        state.cleanupCubeHalf = IKST.clampCubeHalf(state.cleanupCubeHalf)
        return
    end
    local legacy = state.cleanupMode or IKST.CLEANUP_MODES.removeObject
    if legacy == IKST.CLEANUP_MODES.radius then
        state.cleanupScope = IKST.CLEANUP_SCOPES.radius
        state.cleanupAction = IKST.CLEANUP_MODES.removeObject
    elseif legacy == IKST.CLEANUP_MODES.room then
        state.cleanupScope = IKST.CLEANUP_SCOPES.room
        state.cleanupAction = IKST.CLEANUP_MODES.removeObject
    elseif legacy == IKST.CLEANUP_MODES.building then
        state.cleanupScope = IKST.CLEANUP_SCOPES.building
        state.cleanupAction = IKST.CLEANUP_MODES.removeObject
    elseif legacy == IKST.CLEANUP_MODES.vegetation then
        state.cleanupAction = IKST.CLEANUP_MODES.vegetation
        state.cleanupScope = IKST.CLEANUP_SCOPES.single
    elseif legacy == IKST.CLEANUP_MODES.clearSquare then
        state.cleanupAction = IKST.CLEANUP_MODES.removeObject
        state.cleanupScope = IKST.CLEANUP_SCOPES.single
    else
        state.cleanupAction = legacy
        state.cleanupScope = IKST.CLEANUP_SCOPES.single
    end
    state.cleanupMode = state.cleanupAction
    if not state.cleanupCubeHalf then
        state.cleanupCubeHalf = IKST.CUBE_PRESETS.M
    end
    state.cleanupCubeHalf = IKST.clampCubeHalf(state.cleanupCubeHalf)
end

function IKST.getCleanupAction(state)
    IKST.normalizeCleanupState(state)
    return state.cleanupAction
end

function IKST.getCleanupScope(state)
    IKST.normalizeCleanupState(state)
    return state.cleanupScope
end

function IKST.actionToCommand(action)
    if action == IKST.CLEANUP_MODES.removeTile then
        return IKST.CMD.cleanupTile
    end
    if action == IKST.CLEANUP_MODES.clearSquare then
        return IKST.CMD.cleanupSquare
    end
    if action == IKST.CLEANUP_MODES.inspect then
        return IKST.CMD.inspectSquare
    end
    return IKST.CMD.cleanupObject
end

function IKST.cleanupActionLabel(action)
    if action == IKST.CLEANUP_MODES.removeTile then
        return IKST.text("IGUI_IKST_Mode_RemoveTile", "Remove tile")
    end
    if action == IKST.CLEANUP_MODES.vegetation then
        return IKST.text("IGUI_IKST_Mode_Vegetation", "Remove vegetation")
    end
    return IKST.text("IGUI_IKST_Mode_RemoveObject", "Remove object")
end

function IKST.cleanupScopeLabel(scope, state)
    if scope == IKST.CLEANUP_SCOPES.cube then
        local edge = IKST.cubeEdgeLength(state and state.cleanupCubeHalf or IKST.CUBE_PRESETS.M)
        return IKST.text("IGUI_IKST_Scope_Cube", "Cube") .. " " .. edge .. "³"
    end
    if scope == IKST.CLEANUP_SCOPES.radius then
        local radius = state and state.cleanupRadius or IKST.RADIUS_PRESETS.M
        return IKST.text("IGUI_IKST_Scope_Radius", "Radius") .. " " .. tostring(radius)
    end
    if scope == IKST.CLEANUP_SCOPES.room then
        return IKST.text("IGUI_IKST_Scope_Room", "Room")
    end
    if scope == IKST.CLEANUP_SCOPES.building then
        return IKST.text("IGUI_IKST_Scope_Building", "Building")
    end
    return IKST.text("IGUI_IKST_Scope_Single", "Single")
end

function IKST.cubeEdgeLength(halfExtent)
    halfExtent = IKST.clampCubeHalf(halfExtent)
    return (halfExtent * 2) + 1
end

function IKST.pushLog(player, line)
    local state = IKST.getPlayerState(player)
    if not state then
        return
    end
    table.insert(state.log, 1, line)
    while #state.log > 20 do
        table.remove(state.log)
    end
end

function IKST.isModEnabled()
    if not SandboxVars or not SandboxVars.IKappaIDSuiteTools then
        return true
    end
    local v = SandboxVars.IKappaIDSuiteTools.EnableMod
    if v == nil then
        return true
    end
    return v == true
end

function IKST.getMaxCleanupRadius()
    local sv = SandboxVars and SandboxVars.IKappaIDSuiteToolsTiles
    if sv and sv.MaxCleanupRadius then
        return sv.MaxCleanupRadius
    end
    if SandboxVars and SandboxVars.IKappaIDSuiteTools and SandboxVars.IKappaIDSuiteTools.MaxCleanupRadius then
        return SandboxVars.IKappaIDSuiteTools.MaxCleanupRadius
    end
    return 50
end

function IKST.getMaxPaintRadius()
    local sv = SandboxVars and SandboxVars.IKappaIDSuiteToolsTiles
    if sv and sv.MaxPaintRadius then
        return sv.MaxPaintRadius
    end
    return 25
end

function IKST.vehicleShowAllClaims()
    local sv = SandboxVars and SandboxVars.IKappaIDSuiteToolsVehicles
    return sv and sv.VehicleShowAllClaims == true
end

function IKST.vehicleClaimRequireKeys()
    local sv = SandboxVars and SandboxVars.IKappaIDSuiteToolsVehicles
    return sv and sv.VehicleClaimRequireKeys == true
end

function IKST.getVehicleListRadius()
    local sv = SandboxVars and SandboxVars.IKappaIDSuiteToolsVehicles
    if sv and sv.VehicleListRadius then
        return sv.VehicleListRadius
    end
    if SandboxVars and SandboxVars.IKappaIDSuiteTools and SandboxVars.IKappaIDSuiteTools.VehicleListRadius then
        return SandboxVars.IKappaIDSuiteTools.VehicleListRadius
    end
    return 30
end

function IKST.clampRadius(r)
    r = tonumber(r) or IKST.RADIUS_PRESETS.M
    return math.max(1, math.min(math.floor(r), IKST.getMaxCleanupRadius()))
end

function IKST.clampCubeHalf(h)
    h = tonumber(h) or IKST.CUBE_PRESETS.M
    return math.max(0, math.min(math.floor(h), IKST.getMaxCleanupRadius()))
end

function IKST.getVehicleNearRadius()
    if SandboxVars and SandboxVars.IKappaIDSuiteTools and SandboxVars.IKappaIDSuiteTools.VehicleNearRadius then
        return SandboxVars.IKappaIDSuiteTools.VehicleNearRadius
    end
    return 12
end

function IKST.parseNumber(text, fallback)
    fallback = fallback or 0
    if text == nil then
        return fallback
    end
    if type(text) ~= "string" then
        text = tostring(text)
    end
    text = string.gsub(text, "^%s*(.-)%s*$", "%1")
    if text == "" then
        return fallback
    end
    local n = tonumber(text)
    if not n then
        return fallback
    end
    return n
end

-- Safe parse for UI text fields (Kahlua tonumber can throw on empty/invalid input).
function IKST.parseAmount(text)
    if text == nil then
        return 0
    end
    if type(text) ~= "string" then
        text = tostring(text)
    end
    text = string.gsub(text, "^%s*(.-)%s*$", "%1")
    if text == "" then
        return 0
    end
    text = string.gsub(text, "[$,]", "")
    local n = tonumber(text)
    if not n then
        return 0
    end
    return math.floor(n)
end

function IKST.isVegetationObject(obj, square)
    if not obj or not obj.getSprite then
        return false
    end
    local floor = square and square.getFloor and square:getFloor()
    if floor and obj == floor then
        return false
    end
    if instanceof(obj, "IsoTree") or instanceof(obj, "IsoBush") then
        return true
    end
    local sprite = obj:getSprite()
    if not sprite or not sprite.getName then
        return false
    end
    local name = string.lower(sprite:getName() or "")
    if name == "" then
        return false
    end
    if string.find(name, "floors_", 1, true) or string.find(name, "street", 1, true)
        or string.find(name, "road", 1, true) or string.find(name, "pavement", 1, true)
        or string.find(name, "asphalt", 1, true) or string.find(name, "sidewalk", 1, true)
        or string.find(name, "blends_grassoverlays", 1, true)
        or string.find(name, "blends_natural", 1, true) then
        return false
    end
    if string.find(name, "vegetation_", 1, true) then
        return true
    end
    if string.find(name, "tree", 1, true) or string.find(name, "bush", 1, true) then
        return true
    end
    if string.find(name, "grass", 1, true) and not string.find(name, "glass", 1, true) then
        return true
    end
    return false
end

function IKST.collectVegetationOnSquare(square)
    local result = {}
    local seen = {}
    if not square then
        return result
    end
    local function add(obj)
        if obj and not seen[obj] then
            seen[obj] = true
            result[#result + 1] = obj
        end
    end
    if square.getTree then
        add(square:getTree())
    end
    if square.getBush then
        add(square:getBush())
    end
    if square.getBushes then
        local bushes = square:getBushes()
        if bushes and bushes.size then
            for i = 0, bushes:size() - 1 do
                add(bushes:get(i))
            end
        end
    end
    local objects = square.getObjects and square:getObjects()
    if objects then
        for i = 0, objects:size() - 1 do
            local obj = objects:get(i)
            if IKST.isVegetationObject(obj, square) then
                add(obj)
            end
        end
    end
    return result
end

function IKST.isMultiplayerSession()
    return type(isMultiplayer) == "function" and isMultiplayer()
end

-- Remote MP client JVM only (not listen host, not integrated SP server JVM).
function IKST.isRemoteClient()
    return type(isClient) == "function" and isClient()
        and type(isServer) == "function" and not isServer()
end

-- MP listen host runs client + server JVMs; world edits must hit the server JVM.
function IKST.isListenHostClient()
    return IKST.isMultiplayerSession()
        and type(isClient) == "function" and isClient()
        and type(isServer) == "function" and isServer()
end

-- Integrated SP / listen host: server sendServerCommand may not loop to client handlers.
IKST._clientCommandHandlers = IKST._clientCommandHandlers or {}

function IKST.registerClientCommandHandler(handler)
    if type(handler) == "function" then
        IKST._clientCommandHandlers[#IKST._clientCommandHandlers + 1] = handler
    end
end

function IKST.deliverClientCommand(player, command, args)
    args = args or {}
    if not IKST_Debug then
        require "IKST_Debug"
    end
    if IKST_Debug and IKST_Debug.logNet then
        IKST_Debug.logNet("server->client", command, player, args, "")
    end
    local useDirect = not IKST.isRemoteClient() and #IKST._clientCommandHandlers > 0
    if useDirect then
        for _, handler in ipairs(IKST._clientCommandHandlers) do
            handler(IKST.MODULE, command, args)
        end
        return
    end
    if sendServerCommand and player then
        sendServerCommand(player, IKST.MODULE, command, args)
    end
end

function IKST.runsOnServerJvm()
    return type(isServer) == "function" and isServer()
end

function IKST.distance2d(x1, y1, x2, y2)
    local dx = (tonumber(x1) or 0) - (tonumber(x2) or 0)
    local dy = (tonumber(y1) or 0) - (tonumber(y2) or 0)
    return math.sqrt(dx * dx + dy * dy)
end

function IKST.runServerCommand(player, command, args)
    if IKST_Lifecycle and not IKST_Lifecycle.isWorldReady() then
        if player and IKST.notify then
            IKST.notify(player, "world loading", false)
        end
        return
    end
    if not IKST_Server then
        require "IKST_Server"
    end
    if IKST_Server and IKST_Server.handleCommand then
        IKST_Server.handleCommand(IKST.MODULE, command, player, args)
    end
end

function IKST.isCoopHostPlayer(player)
    if not isCoopHost or not isCoopHost() then
        return false
    end
    player = IKST.resolvePlayer(player)
    return player ~= nil and player.isLocalPlayer and player:isLocalPlayer()
end

function IKST.dispatchCommand(player, command, args)
    player = IKST.resolvePlayer(player)
    if not player or not command then
        return
    end
    args = args or {}
    if not IKST_Debug then
        require "IKST_Debug"
    end
    if IKST_Debug and IKST_Debug.logNet then
        IKST_Debug.logNet("client->dispatch", command, player, args, "")
    end
    -- Co-op host: client command does not loop back to the server.
    if IKST.isCoopHostPlayer(player) then
        IKST.runServerCommand(player, command, args)
        return
    end
    -- MP listen host: route through server JVM (same as remote clients).
    if IKST.isListenHostClient() then
        if IKST.enqueueClientCommand then
            IKST.enqueueClientCommand(player, command, args)
            return
        end
        if sendClientCommand and player then
            sendClientCommand(player, IKST.MODULE, command, args)
            return
        end
    end
    -- Integrated SP or dedicated server JVM: run world edits directly.
    if not IKST.isRemoteClient() then
        IKST.runServerCommand(player, command, args)
        return
    end
    if IKST.enqueueClientCommand then
        IKST.enqueueClientCommand(player, command, args)
        return
    end
    if sendClientCommand and player then
        sendClientCommand(player, IKST.MODULE, command, args)
    end
end

function IKST.shouldNotifyResult(mode)
    if not mode then
        return true
    end
    if mode == IKST.CMD.paintPlace or mode == IKST.CMD.paintRemove then
        return false
    end
    if mode == IKST.CMD.cleanupObject or mode == IKST.CMD.cleanupTile or mode == IKST.CMD.cleanupSquare then
        return false
    end
    if mode == IKST.CMD.vehicleClaimList or mode == IKST.CMD.safehouseList then
        return false
    end
    return true
end

function IKST.notify(player, message, ok)
    player = IKST.resolvePlayer(player)
    if not player or not HaloTextHelper or not HaloTextHelper.addText then
        return
    end
    local text = tostring(message)
    -- B42.19: addText(player, text, color) is invalid; use separator + RGB.
    if ok then
        HaloTextHelper.addText(player, text, "", 0, 255, 0)
    else
        HaloTextHelper.addText(player, text, "", 255, 0, 0)
    end
end
