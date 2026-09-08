-- Soft-shell Claim page — hosts JobClaim / JobGuard via SoftPageHost.
if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "IKST_Shared"
require "IKST_SoftPageHost"

IKST_PageClaim = IKST_PageClaim or {}

function IKST_PageClaim.create(window, x, y, w, h)
    return IKST_SoftPageHost.create(window, x, y, w, h, IKST.VIEW.claim)
end
