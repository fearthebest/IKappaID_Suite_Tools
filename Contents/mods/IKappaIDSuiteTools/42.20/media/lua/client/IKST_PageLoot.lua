-- Soft-shell Loot page — plugin buildJob via SoftPageHost.
if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "IKST_Shared"
require "IKST_SoftPageHost"

IKST_PageLoot = IKST_PageLoot or {}

function IKST_PageLoot.create(window, x, y, w, h)
    return IKST_SoftPageHost.create(window, x, y, w, h, IKST.VIEW.loot)
end
