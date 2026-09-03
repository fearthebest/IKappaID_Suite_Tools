-- Soft-shell Vehicles page — plugin buildJob via SoftPageHost.
if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "IKST_Shared"
require "IKST_SoftPageHost"

IKST_PageVehicles = IKST_PageVehicles or {}

function IKST_PageVehicles.create(window, x, y, w, h)
    return IKST_SoftPageHost.create(window, x, y, w, h, IKST.VIEW.vehicles)
end
