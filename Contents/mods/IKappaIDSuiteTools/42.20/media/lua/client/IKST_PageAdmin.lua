-- Soft-shell Admin page — plugin buildJob via SoftPageHost.
if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "IKST_Shared"
require "IKST_SoftPageHost"

IKST_PageAdmin = IKST_PageAdmin or {}

function IKST_PageAdmin.create(window, x, y, w, h)
    return IKST_SoftPageHost.create(window, x, y, w, h, IKST.VIEW.admin)
end
