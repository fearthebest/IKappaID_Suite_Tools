-- JobClaim: thin alias — soft Claim paint is SoftTool_Claim only.
if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "IKST_Shared"

IKST_JobClaim = IKST_JobClaim or {}

function IKST_JobClaim.build(panel)
    if IKST_SoftTool_Claim and type(IKST_SoftTool_Claim.build) == "function" then
        return IKST_SoftTool_Claim.build(panel)
    end
    return 8
end
