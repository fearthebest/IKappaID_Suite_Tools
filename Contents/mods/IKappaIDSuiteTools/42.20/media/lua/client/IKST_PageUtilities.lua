-- Soft-shell Utilities page — hosts JobUtilities via SoftPageHost.
if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "IKST_Shared"
require "IKST_SoftPageHost"

IKST_PageUtilities = IKST_PageUtilities or {}

function IKST_PageUtilities.create(window, x, y, w, h)
    return IKST_SoftPageHost.create(window, x, y, w, h, IKST.VIEW.utilities)
end
