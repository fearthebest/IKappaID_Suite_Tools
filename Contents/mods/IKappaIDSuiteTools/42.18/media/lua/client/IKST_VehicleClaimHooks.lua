if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "IKST_Shared"
require "IKST_ClaimPolicy"
require "IKST_VehicleClaim"
require "IKST_Access"
require "IKST_VehiclePermissions"

IKST_VehicleClaimHooks = IKST_VehicleClaimHooks or {}
IKST_VehicleClaimHooks._engineTick = 0

function IKST_VehicleClaimHooks.notifyDenied(player)
    if not player then
        return
    end
    IKST.notify(player, IKST.text("IGUI_IKST_Claim_VehicleDenied", "This vehicle is claimed by another player."), false)
end

function IKST_VehicleClaimHooks.wrapIsValid(classTable, action)
    if not classTable or not classTable.isValid or classTable.IKST_wrapped then
        return
    end
    classTable.IKST_wrapped = true
    local vanilla = classTable.isValid
    classTable.isValid = function(self)
        if self and self.character and self.vehicle and action then
            if not IKST_VehicleClaim.canUseVehicle(self.character, self.vehicle, action) then
                IKST_VehicleClaimHooks.notifyDenied(self.character)
                if self.stop then
                    self:stop()
                end
                return false
            end
        end
        if self and self.character and action then
            local vehicle = self.vehicle
            if not vehicle and self.part and self.part.getVehicle then
                vehicle = self.part:getVehicle()
            end
            if vehicle and not IKST_VehicleClaim.canUseVehicle(self.character, vehicle, action) then
                IKST_VehicleClaimHooks.notifyDenied(self.character)
                if self.stop then
                    self:stop()
                end
                return false
            end
        end
        return vanilla(self)
    end
end

function IKST_VehicleClaimHooks.wrapEnterVehicle()
    if IKST_VehicleClaimHooks.enterWrapped then
        return
    end
    if not ISEnterVehicle or not ISEnterVehicle.isValid then
        return
    end
    IKST_VehicleClaimHooks.enterWrapped = true
    IKST_VehicleClaimHooks.wrapIsValid(ISEnterVehicle, "enter")
end

function IKST_VehicleClaimHooks.wrapTransfer()
    if IKST_VehicleClaimHooks.transferWrapped then
        return
    end
    if not ISInventoryTransferAction or not ISInventoryTransferAction.isValid then
        return
    end
    IKST_VehicleClaimHooks.transferWrapped = true
    local vanilla = ISInventoryTransferAction.isValid
    ISInventoryTransferAction.isValid = function(self)
        if self and self.character and self.srcContainer and self.destContainer then
            if not IKST_VehicleClaim.transferAllowed(self.item, self.srcContainer, self.destContainer, self.character) then
                IKST_VehicleClaimHooks.notifyDenied(self.character)
                if self.stop then
                    self:stop()
                end
                return false
            end
        end
        return vanilla(self)
    end
end

function IKST_VehicleClaimHooks.wrapTimedActions()
    if IKST_VehicleClaimHooks.timedWrapped then
        return
    end
    IKST_VehicleClaimHooks.timedWrapped = true
    for className, action in pairs(IKST_VehiclePermissions.TIMED_ACTION) do
        local classTable = _G[className]
        if classTable then
            IKST_VehicleClaimHooks.wrapIsValid(classTable, action)
        end
    end
end

function IKST_VehicleClaimHooks.engineWatchdog(player)
    if not player or not player.isLocalPlayer or not player:isLocalPlayer() then
        return
    end
    if not player.getVehicle then
        return
    end
    local vehicle = player:getVehicle()
    if not vehicle then
        return
    end
    if not IKST_VehicleClaim.canUseVehicle(player, vehicle, "enter") then
        if vehicle.shutOff then
            vehicle:shutOff()
        end
        if vehicle.exit and player then
            vehicle:exit(player)
        end
        IKST_VehicleClaimHooks.notifyDenied(player)
        return
    end
    if vehicle.isEngineRunning and vehicle:isEngineRunning() then
        if not IKST_VehicleClaim.canUseVehicle(player, vehicle, "engine") then
            if vehicle.shutOff then
                vehicle:shutOff()
            end
        end
    end
end

function IKST_VehicleClaimHooks.onPlayerUpdate(player)
    IKST_VehicleClaimHooks._engineTick = IKST_VehicleClaimHooks._engineTick + 1
    if IKST_VehicleClaimHooks._engineTick % 15 ~= 0 then
        return
    end
    IKST_VehicleClaimHooks.engineWatchdog(player)
end

function IKST_VehicleClaimHooks.init()
    if not ISEnterVehicle then
        require "Vehicles/TimedActions/ISEnterVehicle"
    end
    if not ISInventoryTransferAction then
        require "TimedActions/ISInventoryTransferAction"
    end
    IKST_VehicleClaimHooks.wrapEnterVehicle()
    IKST_VehicleClaimHooks.wrapTimedActions()
end

if Events and Events.OnGameStart then
    Events.OnGameStart.Add(IKST_VehicleClaimHooks.init)
end
if Events and Events.OnPlayerUpdate then
    Events.OnPlayerUpdate.Add(IKST_VehicleClaimHooks.onPlayerUpdate)
end
