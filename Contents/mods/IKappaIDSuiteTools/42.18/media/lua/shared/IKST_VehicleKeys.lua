-- Client-safe vehicle key checks (inventory read only).

require "IKST_Shared"

IKST_VehicleKeys = IKST_VehicleKeys or {}

function IKST_VehicleKeys.playerHasVehicleKey(player, vehicle)
    if not player or not vehicle then
        return false
    end
    if vehicle.isKeysInIgnition and vehicle:isKeysInIgnition() then
        return true
    end
    local keyId = vehicle.getKeyId and vehicle:getKeyId() or -1
    if keyId == nil or keyId < 0 then
        return true
    end
    local inv = player.getInventory and player:getInventory()
    if not inv or not inv.getItemsFromCategory then
        return false
    end
    local keys = inv:getItemsFromCategory("Key")
    if not keys then
        return false
    end
    for i = 0, keys:size() - 1 do
        local item = keys:get(i)
        if item and item.getKeyId and item:getKeyId() == keyId then
            return true
        end
    end
    return false
end
