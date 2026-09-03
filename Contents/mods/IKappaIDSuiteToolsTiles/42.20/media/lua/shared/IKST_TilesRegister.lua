require "IKST_Plugins"
require "IKST_ClaimPolicy"
require "IKST_Access"

if not (type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient()) then
    require "IKST_SoftTool_Tiles"
end

local ADMIN_COMMANDS = {
    inspectSquare = true,
    cleanupObject = true,
    cleanupTile = true,
    cleanupSquare = true,
    paintRemove = true,
    cleanupRadius = true,
    cleanupCube = true,
    cleanupRoom = true,
    cleanupBuilding = true,
    cleanupVegetation = true,
    paintPlace = true,
    rewind = true,
    protectList = true,
    autoGardener = true,
    autoLumberjack = true,
    autoGravel = true,
    autoCorpseStack = true,
    autoHomeWreck = true,
    autoFarmer = true,
    autoUnloadContainers = true,
    protectSquare = true,
    unprotectSquare = true,
    protectRadius = true,
    unprotectRadius = true,
    protectVehicle = true,
    unprotectVehicle = true,
    setDropbox = true,
    setReadonly = true,
    setReadonlyRadius = true,
    setWorldRule = true,
    addSpriteBlacklist = true,
    farmRevitalize = true,
    farmHarvestAll = true,
    blueprintCopy = true,
    blueprintPaste = true,
    blueprintSave = true,
    blueprintLoad = true,
    blueprintList = true,
    blueprintDelete = true,
    createSnapshot = true,
    restoreSnapshot = true,
    lockSetPassword = true,
    lockClear = true,
    clearanceSetLock = true,
}

local PLAYER_COMMANDS = {
    lockTryUnlock = true,
    lockTryClearance = true,
    lockInstallKeypad = true,
}

local SKIP_RESULT = {
    [IKST.CMD.inspectSquare] = true,
    [IKST.CMD.protectList] = true,
}

local function tilesAfterServer(command, player, args, ok, msg)
    if SKIP_RESULT[command] then
        return
    end
    if IKST_WorldOps and IKST_WorldOps.sendResult then
        IKST_WorldOps.sendResult(player, ok, msg, args and args.x, args and args.y, args and args.z, command)
    end
end

local BUILD_TOOLS = {
    {
        mode = IKST.VIEW.tiles,
        id = "overview",
        titleKey = "IGUI_IKST_Tiles_Overview",
        title = "Overview",
        order = 5,
    },
    {
        mode = IKST.VIEW.tiles,
        id = "remove",
        titleKey = "IGUI_IKST_Job_Cleanup",
        title = "Remove",
        order = 10,
    },
    {
        mode = IKST.VIEW.tiles,
        id = "paint",
        titleKey = "IGUI_IKST_Job_Painter",
        title = "Paint tiles",
        order = 20,
    },
    {
        mode = IKST.VIEW.tiles,
        id = "inspect",
        titleKey = "IGUI_IKST_Job_Inspector",
        title = "Inspect tile",
        order = 30,
    },
    {
        mode = IKST.VIEW.tiles,
        id = "blueprints",
        titleKey = "IGUI_IKST_Gadget_blueprints",
        title = "Copy build",
        order = 40,
    },
    {
        mode = IKST.VIEW.tiles,
        id = "area",
        titleKey = "IGUI_IKST_Job_Automation",
        title = "Area jobs",
        order = 45,
    },
    {
        mode = IKST.VIEW.tiles,
        id = "protect",
        titleKey = "IGUI_IKST_Tool_Protect",
        title = "Protection",
        order = 50,
    },
}

local function buildOverview(panel)
    if IKST_SoftTool_Tiles and IKST_SoftTool_Tiles.buildOverview then
        return IKST_SoftTool_Tiles.buildOverview(panel)
    end
    return 8
end

local function buildRemove(panel)
    if IKST_SoftTool_Tiles and IKST_SoftTool_Tiles.buildRemove then
        return IKST_SoftTool_Tiles.buildRemove(panel)
    end
    return 8
end

local function buildPaint(panel)
    if IKST_SoftTool_Tiles and IKST_SoftTool_Tiles.buildPaint then
        return IKST_SoftTool_Tiles.buildPaint(panel)
    end
    return 8
end

local function buildInspect(panel)
    if IKST_SoftTool_Tiles and IKST_SoftTool_Tiles.buildInspect then
        return IKST_SoftTool_Tiles.buildInspect(panel)
    end
    return 8
end

local function buildBlueprints(panel)
    if IKST_SoftTool_Tiles and IKST_SoftTool_Tiles.buildBlueprints then
        return IKST_SoftTool_Tiles.buildBlueprints(panel)
    end
    return 8
end

local function buildArea(panel)
    if IKST_SoftTool_Tiles and IKST_SoftTool_Tiles.buildArea then
        return IKST_SoftTool_Tiles.buildArea(panel)
    end
    return 8
end

local function buildProtect(panel)
    if IKST_SoftTool_Tiles and IKST_SoftTool_Tiles.buildProtect then
        return IKST_SoftTool_Tiles.buildProtect(panel)
    end
    return 8
end

IKST.Plugins.register("tiles", {
    modId = "IKappaIDSuiteToolsTiles",
    adminCommands = ADMIN_COMMANDS,
    playerCommands = PLAYER_COMMANDS,
    canUsePlayer = function(player)
        if not player then
            return false
        end
        if not IKST_ClaimPolicy.playerClaimsEnabled() then
            return false
        end
        return true
    end,
    canUseAdmin = function(player)
        return IKST_Access.canUseStaffTools(player)
    end,
    handleServer = function(command, player, args)
        if not IKST_TilesOps or not IKST_TilesOps.handle then
            return false, "tiles server missing"
        end
        return IKST_TilesOps.handle(command, player, args)
    end,
    afterServer = tilesAfterServer,
    hubTools = BUILD_TOOLS,
    jobTools = {
        overview = true,
        remove = true,
        paint = true,
        inspect = true,
        blueprints = true,
        area = true,
        protect = true,
    },
    buildJobTools = {
        overview = buildOverview,
        remove = buildRemove,
        paint = buildPaint,
        inspect = buildInspect,
        blueprints = buildBlueprints,
        area = buildArea,
        protect = buildProtect,
    },
    onNavEntered = function(panel, modeId, toolId)
        if not panel or not panel.player then
            return
        end
        local player = panel.player
        if modeId == IKST.VIEW.tiles and toolId == "remove" and IKST_JobCleanup and IKST_JobCleanup.syncArm then
            IKST_JobCleanup.syncArm(panel)
        elseif modeId == IKST.VIEW.tiles and toolId == "protect" and IKST_JobTilesGuard then
            local st = IKST.getPlayerState(player)
            if st then
                st.guardMode = "tiles"
            end
            IKST_JobTilesGuard.requestList(player)
        end
    end,
    onServerCommand = function(command, args, player)
        if command == IKST.CMD.protectListResult then
            if IKST_JobTilesGuard and IKST_JobTilesGuard.onListResult then
                IKST_JobTilesGuard.onListResult(args)
            end
            return true
        end
        if command == IKST.CMD.blueprintListResult then
            if IKST_JobTilesGuard and IKST_JobTilesGuard.onBlueprintListResult then
                IKST_JobTilesGuard.onBlueprintListResult(args)
            end
            return true
        end
        return false
    end,
})
