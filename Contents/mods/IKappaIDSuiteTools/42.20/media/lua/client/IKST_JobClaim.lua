-- JobClaim: claim workspace builds the unified Guard tabs (safehouses / vehicles / protect / catch).

if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "IKST_Shared"
require "IKST_JobGuard"

IKST_JobClaim = IKST_JobClaim or {}

function IKST_JobClaim.build(panel)
    if not IKST_JobGuard then
        return 8
    end
    return IKST_JobGuard.build(panel)
end
