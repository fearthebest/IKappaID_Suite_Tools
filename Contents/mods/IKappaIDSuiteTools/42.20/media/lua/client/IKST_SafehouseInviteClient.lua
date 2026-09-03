if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "IKST_Shared"

IKST_SafehouseInviteClient = IKST_SafehouseInviteClient or {}
IKST_SafehouseInviteClient.pending = IKST_SafehouseInviteClient.pending or {}

function IKST_SafehouseInviteClient.setPending(rows)
    IKST_SafehouseInviteClient.pending = rows or {}
    if IKST_Hub and type(IKST_Hub.refreshActive) == "function" then
        IKST_Hub.refreshActive()
    end
end

function IKST_SafehouseInviteClient.onInviteNotify(args)
    local row = args and args.invite
    if not row then
        return
    end
    local list = IKST_SafehouseInviteClient.pending
    local replaced = false
    for i = 1, #list do
        local cur = list[i]
        if cur and math.floor(tonumber(cur.x) or 0) == math.floor(tonumber(row.x) or 0)
            and math.floor(tonumber(cur.y) or 0) == math.floor(tonumber(row.y) or 0)
            and math.floor(tonumber(cur.w) or 0) == math.floor(tonumber(row.w) or 0)
            and math.floor(tonumber(cur.h) or 0) == math.floor(tonumber(row.h) or 0) then
            list[i] = row
            replaced = true
            break
        end
    end
    if not replaced then
        list[#list + 1] = row
    end
    local p = getPlayer and getPlayer() or nil
    if p then
        IKST.notify(p, IKST.text("IGUI_IKST_ClaimInvite_Received",
            "Safehouse invite received. Open Claim → Overview to Accept or Decline."), true)
    end
    if IKST_Hub and type(IKST_Hub.refreshActive) == "function" then
        IKST_Hub.refreshActive()
    end
end

function IKST_SafehouseInviteClient.requestList(player)
    if not player then
        return
    end
    IKST.dispatchCommand(player, IKST.CMD.safehouseInviteList, {})
end
