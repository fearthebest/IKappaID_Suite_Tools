if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "IKST_Shared"
require "IKST_ClaimPolicy"
require "IKST_Claim"
require "IKST_SafehouseClaim"
require "IKST_SafehouseClaimClient"
require "IKST_SafeHouse"
require "IKST_Access"
require "IKST_ClaimIcons"

IKST_SafehouseContext = IKST_SafehouseContext or {}

function IKST_SafehouseContext.mayUseClaims(player)
    if IKST_Access.canUseTools(player) then
        return true
    end
    return IKST_ClaimPolicy and IKST_ClaimPolicy.playerClaimsEnabled()
end

function IKST_SafehouseContext.addOption(sub, label, player, fn, iconPath)
    local opt = sub:addOption(label, player, fn)
    IKST_ClaimIcons.applyContextIcon(opt, iconPath)
    return opt
end

function IKST_SafehouseContext.onFillWorldObjectContextMenu(playerNum, context, worldobjects, test)
    if test then
        return false
    end
    local player = IKST.resolvePlayer(playerNum)
    if not player or not context then
        return
    end
    if not IKST_SafehouseContext.mayUseClaims(player) then
        return
    end
    local sq = player.getCurrentSquare and player:getCurrentSquare() or nil
    if not sq then
        return
    end

    local sh = IKST_SafehouseClaim.safehouseAtSquare(sq)
    local isAdmin = IKST_Access.canUseTools(player)

    if sh then
        local x, y, w, h, owner = IKST_SafehouseClaim.boundsFromSafehouse(sh)
        if not x then
            return
        end
        local uiState = IKST_SafehouseClaimClient and IKST_SafehouseClaimClient.uiState(x, y, w, h, player, owner)
        local isAdmin = IKST_Access.canUseTools(player)
        local canRelease = isAdmin
        local canEdit = isAdmin
        if uiState then
            canRelease = uiState.canRelease == true or isAdmin
            canEdit = uiState.canEdit == true or isAdmin
        end

        local root = context:addOption(IKST.text("IGUI_IKST_SafehouseClaim_Menu", "Safe area"))
        IKST_ClaimIcons.applyContextIcon(root, IKST_ClaimIcons.SAFEHOUSE_CLAIM)
        local sub = ISContextMenu:getNew(context)
        context:addSubMenu(root, sub)

        if canRelease then
            local shId = IKST_SafeHouse.onlineId(sh) or IKST_SafeHouse.id(sh)
            IKST_SafehouseContext.addOption(sub, IKST.text("IGUI_IKST_Guard_SH_Release", "Remove safe area"), player, function()
                IKST.dispatchCommand(player, IKST.CMD.safehouseRelease, {
                    x = x, y = y, w = w, h = h, owner = owner, id = shId,
                })
            end, IKST_ClaimIcons.SAFEHOUSE_UNCLAIM)
        end
        if canEdit then
            IKST_SafehouseContext.addOption(sub, IKST.text("IGUI_IKST_VehicleClaim_Perms", "Permissions…"), player, function()
                if IKST_SafehouseClaimUI and IKST_SafehouseClaimUI.open then
                    IKST_SafehouseClaimUI.open(player, x, y, w, h)
                end
            end, IKST_ClaimIcons.PERMS)
        end
        sub:addOption(IKST.text("IGUI_IKST_VehicleClaim_Info", "Owner") .. ": " .. tostring(owner or "?"), nil, nil)
        return
    end

    if SafeHouse and SafeHouse.getSafeHouse and SafeHouse.getSafeHouse(sq) then
        return
    end

    local px, py, pw, ph, pz = IKST_Claim.safehousePreviewRect(
        math.floor(player:getX()), math.floor(player:getY()), player:getZ() or 0,
        IKST_ClaimRadial and IKST_ClaimRadial.DEFAULT_SH_SIZE or 13,
        IKST_Claim.MODE.square, nil, nil)

    local root = context:addOption(IKST.text("IGUI_IKST_SafehouseClaim_Menu", "Safe area"))
    IKST_ClaimIcons.applyContextIcon(root, IKST_ClaimIcons.SAFEHOUSE_CLAIM)
    local sub = ISContextMenu:getNew(context)
    context:addSubMenu(root, sub)
    IKST_SafehouseContext.addOption(sub, IKST.text("IGUI_IKST_Guard_SH_Claim", "Claim land here"), player, function()
        IKST.dispatchCommand(player, IKST.CMD.safehouseClaim, {
            x = math.floor(player:getX()),
            y = math.floor(player:getY()),
            z = pz or 0,
            size = IKST_ClaimRadial and IKST_ClaimRadial.DEFAULT_SH_SIZE or 13,
            w = pw,
            h = ph,
            claimMode = IKST_Claim.MODE.square,
        })
    end, IKST_ClaimIcons.SAFEHOUSE_CLAIM)
end

if Events and Events.OnFillWorldObjectContextMenu then
    Events.OnFillWorldObjectContextMenu.Add(IKST_SafehouseContext.onFillWorldObjectContextMenu)
end
