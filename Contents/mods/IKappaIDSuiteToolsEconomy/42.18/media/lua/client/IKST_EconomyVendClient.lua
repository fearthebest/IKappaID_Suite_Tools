if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "IKST_Shared"
require "IKST_Identity"
require "IKST_Access"

IKST_EconomyVendClient = IKST_EconomyVendClient or {}
IKST_EconomyVendClient.byKey = IKST_EconomyVendClient.byKey or {}

function IKST_EconomyVendClient.keyFor(x, y, z)
    return tostring(math.floor(tonumber(x) or 0)) .. ","
        .. tostring(math.floor(tonumber(y) or 0)) .. ","
        .. tostring(math.floor(tonumber(z) or 0))
end

function IKST_EconomyVendClient.onVendListResult(args)
    if not args then
        return
    end
    local x = math.floor(tonumber(args.x) or 0)
    local y = math.floor(tonumber(args.y) or 0)
    local z = math.floor(tonumber(args.z) or 0)
    IKST_EconomyVendClient.byKey[IKST_EconomyVendClient.keyFor(x, y, z)] = {
        x = x,
        y = y,
        z = z,
        owner = args.owner,
        canManage = args.canManage == true,
        canClaim = args.canClaim == true,
        isVending = args.isVending == true,
    }
end

function IKST_EconomyVendClient.snapshotAt(x, y, z)
    if x == nil or y == nil then
        return nil
    end
    return IKST_EconomyVendClient.byKey[IKST_EconomyVendClient.keyFor(x, y, z)]
end

function IKST_EconomyVendClient.uiState(player, x, y, z, obj)
    if IKST_Authority and IKST_Authority.uiUsesServerSnapshots and IKST_Authority.uiUsesServerSnapshots() then
        local snap = IKST_EconomyVendClient.snapshotAt(x, y, z)
        if snap then
            return snap
        end
        return {
            x = x,
            y = y,
            z = z,
            isVending = false,
            canClaim = false,
            canManage = false,
            stale = true,
        }
    end
    if not obj or not obj.getModData or not IKST_Economy then
        return nil
    end
    local md = obj:getModData()
    local vending = md and md[IKST_Economy.VEND_TAG] == true
    local owner = vending and IKST_Economy.vendOwnerOfObject(obj) or nil
    local canManage = false
    if vending and player and IKST_Identity and IKST_Identity.playerOwnsKey then
        canManage = IKST_Identity.playerOwnsKey(player, owner)
    end
    if IKST_Access and IKST_Access.canUseTools(player) then
        canManage = true
    end
    return {
        x = x,
        y = y,
        z = z,
        owner = owner,
        isVending = vending == true,
        canClaim = not vending,
        canManage = canManage,
    }
end
