-- Soft-shell Everyone page — hosts JobEveryone via SoftPageHost.
if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "IKST_Shared"
require "IKST_SoftPageHost"

IKST_PageEveryone = IKST_PageEveryone or {}

function IKST_PageEveryone.create(window, x, y, w, h)
    return IKST_SoftPageHost.create(window, x, y, w, h, IKST.VIEW.everyone)
end
