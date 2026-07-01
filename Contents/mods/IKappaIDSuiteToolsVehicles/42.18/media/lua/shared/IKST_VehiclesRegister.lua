require "IKST_Plugins"
require "IKST_Access"

local ADMIN_COMMANDS = {
    vehicleList = true,
    vehicleSpawn = true,
    vehicleMove = true,
    vehicleDelete = true,
    vehicleDeleteCell = true,
    vehicleFlip = true,
    vehicleRepair = true,
    vehicleKey = true,
    vehiclePrune = true,
    vehicleRepairNear = true,
    vehicleKeyNear = true,
    vehicleSkinNext = true,
    vehicleSkinPrev = true,
    vehicleUnlockTrunk = true,
    vehicleUnlockDoors = true,
}

local PLAYER_COMMANDS = {
    vehicleFieldRecovery = true,
}

local function vehiclesAfterServer(command, player, args, ok, msg)
    if command == IKST.CMD.vehicleList then
        return
    end
    local extra = nil
    if args and args.relocateMeta then
        extra = args.relocateMeta
    end
    if IKST_WorldOps and IKST_WorldOps.sendResult then
        IKST_WorldOps.sendResult(player, ok, msg, args and args.x, args and args.y, args and args.z, command, extra)
    end
end

local VEHICLE_TOOLS = {
    {
        mode = IKST.VIEW.vehicles,
        id = "spawn",
        titleKey = "IGUI_IKST_VehicleTool_Spawn",
        title = "Spawn / move / delete",
        order = 10,
    },
    {
        mode = IKST.VIEW.vehicles,
        id = "repair",
        titleKey = "IGUI_IKST_VehicleTool_Repair",
        title = "Repair / flip",
        order = 20,
    },
    {
        mode = IKST.VIEW.vehicles,
        id = "prune",
        titleKey = "IGUI_IKST_VehicleTool_Prune",
        title = "Prune / unlock",
        order = 30,
    },
}

local function buildVehicleJob(panel)
    if IKST_JobVehicle and IKST_JobVehicle.build then
        return IKST_JobVehicle.build(panel)
    end
    return 8
end

IKST.Plugins.register("vehicles", {
    modId = "IKappaIDSuiteToolsVehicles",
    adminCommands = ADMIN_COMMANDS,
    playerCommands = PLAYER_COMMANDS,
    canUseAdmin = function(player)
        return IKST_Access.canUseStaffTools(player)
    end,
    canUsePlayer = function(player)
        local sv = SandboxVars and SandboxVars.IKappaIDSuiteToolsVehicles
        if not sv or sv.FieldRecoveryEnabled == false then
            return false
        end
        return IKST.isModEnabled()
    end,
    handleServer = function(command, player, args)
        if not IKST_VehicleOps or not IKST_VehicleOps.handle then
            return false, "vehicles server missing"
        end
        return IKST_VehicleOps.handle(command, player, args)
    end,
    afterServer = vehiclesAfterServer,
    hubTools = VEHICLE_TOOLS,
    jobTools = {
        spawn = true,
        repair = true,
        prune = true,
    },
    buildJobTools = {
        spawn = buildVehicleJob,
        repair = buildVehicleJob,
        prune = buildVehicleJob,
    },
    onNavEntered = function(panel, modeId, toolId)
        if modeId == IKST.VIEW.vehicles and panel and panel.player and IKST_JobVehicle then
            IKST_JobVehicle.requestList(panel.player)
        end
    end,
    onServerCommand = function(command, args, player)
        if command == IKST.CMD.vehicleListResult then
            if IKST_VehicleClaimClient and IKST_VehicleClaimClient.onNearbyResult then
                IKST_VehicleClaimClient.onNearbyResult(args and args.vehicles)
            end
            if IKST_JobVehicle and IKST_JobVehicle.onListResult then
                IKST_JobVehicle.onListResult(args and args.vehicles)
            end
            return true
        end
        return false
    end,
})
