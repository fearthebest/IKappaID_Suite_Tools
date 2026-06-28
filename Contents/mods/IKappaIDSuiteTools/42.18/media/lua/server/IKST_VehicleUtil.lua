-- Minimal vehicle lookup (base mod — used by World Guard claims).
if type(isClient) == "function" and isClient()
    and type(isServer) == "function" and not isServer() then
    return
end

require "IKST_Shared"
require "IKST_Utility"
require "IKST_VehicleKeys"

IKST_VehicleUtil = IKST_VehicleUtil or {}

function IKST_VehicleUtil.forEachVehicle(vehicles, visitor)
    if not vehicles or not visitor then
        return
    end
    if vehicles.iterator then
        local it = vehicles:iterator()
        if it and it.hasNext and it.next then
            while it:hasNext() do
                local vehicle = it:next()
                if vehicle then
                    visitor(vehicle)
                end
            end
        end
        return
    end
    if vehicles.size and vehicles.get then
        for i = 0, vehicles:size() - 1 do
            local vehicle = vehicles:get(i)
            if vehicle then
                visitor(vehicle)
            end
        end
    end
end

function IKST_VehicleUtil.getVehiclesFromCell(cell)
    if not cell and getCell then
        cell = getCell()
    end
    if cell and cell.getVehicles then
        return cell:getVehicles()
    end
    return nil
end

function IKST_VehicleUtil.getVehicle(id)
    if id == nil then
        return nil
    end
    id = tonumber(id)
    if id == nil then
        return nil
    end
    if getVehicleById then
        local v = getVehicleById(id)
        if v then
            return v
        end
    end
    if VehicleManager and VehicleManager.instance then
        if VehicleManager.instance.getVehicleByID then
            local v = VehicleManager.instance:getVehicleByID(id)
            if v then
                return v
            end
        end
        if VehicleManager.instance.getVehicleById then
            local v = VehicleManager.instance:getVehicleById(id)
            if v then
                return v
            end
        end
    end
    return nil
end

function IKST_VehicleUtil.listNearby(x, y, z, radius)
    local out = {}
    local vehicles = IKST_VehicleUtil.getVehiclesFromCell()
    if not vehicles then
        return out
    end
    z = tonumber(z) or 0
    IKST_VehicleUtil.forEachVehicle(vehicles, function(v)
        local dist = IKST.distance2d(x, y, v:getX(), v:getY())
        local vz = v:getZ() or 0
        if dist <= radius and math.abs(z - vz) <= 1.5 then
            local scriptName = ""
            if v.getScript and v:getScript() then
                scriptName = v:getScript():getName() or ""
            end
            local cond = 100
            if v.getVehicleEngineQuality then
                cond = v:getVehicleEngineQuality() or cond
            end
            out[#out + 1] = {
                id = v:getId(),
                script = scriptName,
                distance = math.floor(dist),
                condition = cond,
                x = v:getX(),
                y = v:getY(),
                z = v:getZ(),
            }
        end
    end)
    table.sort(out, function(a, b) return a.distance < b.distance end)
    return out
end

function IKST_VehicleUtil.nearestId(x, y, z, radius)
    local list = IKST_VehicleUtil.listNearby(x, y, z, radius or 8)
    if list[1] then
        return list[1].id, list[1]
    end
    return nil, nil
end

function IKST_VehicleUtil.playerHasVehicleKey(player, vehicle)
    if IKST_VehicleKeys and IKST_VehicleKeys.playerHasVehicleKey then
        return IKST_VehicleKeys.playerHasVehicleKey(player, vehicle)
    end
    return false
end
