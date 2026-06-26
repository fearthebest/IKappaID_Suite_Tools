if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "IKST_Shared"
require "IKST_ClaimPolicy"
require "IKST_Claim"
require "IKST_VehicleClaim"
require "IKST_SafehouseClaim"
require "IKST_Access"
require "IKST_PhunZones"
require "IKST_SafeHouse"
require "IKST_ClaimIcons"

IKST_ClaimRadial = IKST_ClaimRadial or {}

IKST_ClaimRadial.DEFAULT_SH_SIZE = 13

function IKST_ClaimRadial.mayUseClaims(player)
    if IKST_Access.canUseTools(player) then
        return true
    end
    return IKST_ClaimPolicy and IKST_ClaimPolicy.playerClaimsEnabled()
end

function IKST_ClaimRadial.playerMenu(playerObj)
    if not playerObj or not playerObj.getPlayerNum then
        return nil
    end
    if not getPlayerRadialMenu then
        return nil
    end
    return getPlayerRadialMenu(playerObj:getPlayerNum())
end

function IKST_ClaimRadial.texture(path)
    if IKST_ClaimIcons and IKST_ClaimIcons.texture then
        return IKST_ClaimIcons.texture(path)
    end
    if not path or not getTexture then
        return nil
    end
    return getTexture(path)
end

function IKST_ClaimRadial.nearVehicle(playerObj)
    if not playerObj then
        return nil
    end
    if playerObj.getVehicle then
        local inside = playerObj:getVehicle()
        if inside then
            return inside
        end
    end
    if ISVehicleMenu and ISVehicleMenu.getVehicleToInteractWith then
        local viaMenu = ISVehicleMenu.getVehicleToInteractWith(playerObj)
        if viaMenu then
            return viaMenu
        end
    end
    local sq = playerObj.getCurrentSquare and playerObj:getCurrentSquare() or nil
    if sq and sq.getVehicleContainer then
        return sq:getVehicleContainer()
    end
    return nil
end

function IKST_ClaimRadial.resetSliceKeys(menu)
    if menu then
        menu._ikstSliceKeys = nil
    end
end

function IKST_ClaimRadial.addSliceOnce(menu, key, text, texture, fn, arg1, arg2, arg3, arg4, arg5, arg6)
    if not menu or not menu.addSlice or not key then
        return false
    end
    menu._ikstSliceKeys = menu._ikstSliceKeys or {}
    if menu._ikstSliceKeys[key] then
        return false
    end
    menu._ikstSliceKeys[key] = true
    menu:addSlice(text, texture, fn, arg1, arg2, arg3, arg4, arg5, arg6)
    return true
end

function IKST_ClaimRadial.addVehicleSlices(playerObj)
    if not IKST_ClaimRadial.mayUseClaims(playerObj) then
        return
    end
    local vehicle = IKST_ClaimRadial.nearVehicle(playerObj)
    if not vehicle or not vehicle.getId then
        return
    end
    local vid = vehicle:getId()
    if vid == nil then
        return
    end
    local menu = IKST_ClaimRadial.playerMenu(playerObj)
    if not menu then
        return
    end
    local entry = IKST_VehicleClaim.get(vid)
    local username = IKST_VehicleClaim.playerUsername(playerObj)
    local isAdmin = IKST_Access.canUseTools(playerObj)
    local isOwner = entry and IKST_VehicleClaim.isOwner(entry, username)
    local canEdit = entry and IKST_VehicleClaim.playerMayEdit(entry, playerObj)
    local vidKey = tostring(vid)

    if not entry or IKST_VehicleClaim.isEntryExpired(entry) then
        IKST_ClaimRadial.addSliceOnce(
            menu, "vehicle_claim_" .. vidKey,
            IKST.text("IGUI_IKST_Guard_Claim", "Claim vehicle"),
            IKST_ClaimRadial.texture(IKST_ClaimIcons.VEHICLE_CLAIM),
            function()
                IKST.dispatchCommand(playerObj, IKST.CMD.vehicleClaim, { vehicleId = vid })
            end
        )
        return
    end

    if isOwner or isAdmin then
        IKST_ClaimRadial.addSliceOnce(
            menu, "vehicle_release_" .. vidKey,
            IKST.text("IGUI_IKST_Guard_ReleaseClaim", "Release claim"),
            IKST_ClaimRadial.texture(IKST_ClaimIcons.VEHICLE_UNCLAIM),
            function()
                IKST.dispatchCommand(playerObj, IKST.CMD.vehicleReleaseClaim, { vehicleId = vid })
            end
        )
    end

    if canEdit and IKST_VehicleClaimUI and IKST_VehicleClaimUI.open then
        IKST_ClaimRadial.addSliceOnce(
            menu, "vehicle_perms_" .. vidKey,
            IKST.text("IGUI_IKST_VehicleClaim_Perms", "Permissions…"),
            IKST_ClaimRadial.texture(IKST_ClaimIcons.PERMS),
            function()
                IKST_VehicleClaimUI.open(playerObj, vid)
            end
        )
    end
end

function IKST_ClaimRadial.safehouseContext(playerObj)
    if not playerObj or not playerObj.getCurrentSquare then
        return nil, nil
    end
    local sq = playerObj:getCurrentSquare()
    if not sq then
        return nil, nil
    end
    local sh = IKST_SafehouseClaim.safehouseAtSquare(sq)
    if sh then
        return sh, nil
    end
    if not IKST_ClaimRadial.mayUseClaims(playerObj) then
        return nil, nil
    end
    if SafeHouse and SafeHouse.getSafeHouse and SafeHouse.getSafeHouse(sq) then
        return nil, nil
    end
    local x = math.floor(playerObj:getX())
    local y = math.floor(playerObj:getY())
    local z = playerObj.getZ and playerObj:getZ() or 0
    local px, py, pw, ph = IKST_Claim.safehousePreviewRect(x, y, z, IKST_ClaimRadial.DEFAULT_SH_SIZE, IKST_Claim.MODE.square, nil, nil)
    return nil, { x = px, y = py, w = pw, h = ph, z = z }
end

function IKST_ClaimRadial.addSafehouseSlices(playerObj)
    if not IKST_ClaimRadial.mayUseClaims(playerObj) then
        return
    end
    if IKST_ClaimRadial.nearVehicle(playerObj) then
        return
    end
    local sh, claimPreview = IKST_ClaimRadial.safehouseContext(playerObj)
    if not sh and not claimPreview then
        return
    end
    local menu = IKST_ClaimRadial.playerMenu(playerObj)
    if not menu then
        return
    end

    if sh then
        local x, y, w, h, owner = IKST_SafehouseClaim.boundsFromSafehouse(sh)
        if not x then
            return
        end
        local areaKey = tostring(x) .. "_" .. tostring(y) .. "_" .. tostring(w) .. "_" .. tostring(h)
        local entry = IKST_SafehouseClaim.get(x, y, w, h)
        local username = IKST_SafehouseClaim.playerUsername(playerObj)
        local isAdmin = IKST_Access.canUseTools(playerObj)
        local isOwner = entry and IKST_SafehouseClaim.isOwner(entry, username)
        if not isOwner and owner and IKST_ClaimPolicy.usernamesEqual(owner, username) then
            isOwner = true
        end
        local canEdit = entry and IKST_SafehouseClaim.playerMayEdit(entry, playerObj)
        if not canEdit and isOwner then
            canEdit = true
        end

        if isOwner or isAdmin then
            local shId = IKST_SafeHouse and IKST_SafeHouse.id(sh) or (sh.getId and sh:getId() or nil)
            IKST_ClaimRadial.addSliceOnce(
                menu, "safehouse_release_" .. areaKey,
                IKST.text("IGUI_IKST_Guard_SH_Release", "Remove safe area"),
                IKST_ClaimRadial.texture(IKST_ClaimIcons.SAFEHOUSE_UNCLAIM),
                function()
                    IKST.dispatchCommand(playerObj, IKST.CMD.safehouseRelease, {
                        x = x, y = y, w = w, h = h, owner = owner, id = shId,
                    })
                end
            )
        end

        if canEdit and IKST_SafehouseClaimUI and IKST_SafehouseClaimUI.open then
            IKST_ClaimRadial.addSliceOnce(
                menu, "safehouse_perms_" .. areaKey,
                IKST.text("IGUI_IKST_VehicleClaim_Perms", "Permissions…"),
                IKST_ClaimRadial.texture(IKST_ClaimIcons.PERMS),
                function()
                    IKST_SafehouseClaimUI.open(playerObj, x, y, w, h)
                end
            )
        end
        return
    end

    if claimPreview then
        if IKST_PhunZones.rectBlocksSafehouse(claimPreview.x, claimPreview.y, claimPreview.w, claimPreview.h) then
            return
        end
        local areaKey = tostring(claimPreview.x) .. "_" .. tostring(claimPreview.y)
        IKST_ClaimRadial.addSliceOnce(
            menu, "safehouse_claim_" .. areaKey,
            IKST.text("IGUI_IKST_Guard_SH_Claim", "Claim land here"),
            IKST_ClaimRadial.texture(IKST_ClaimIcons.SAFEHOUSE_CLAIM),
            function()
                IKST.dispatchCommand(playerObj, IKST.CMD.safehouseClaim, {
                    x = math.floor(playerObj:getX()),
                    y = math.floor(playerObj:getY()),
                    z = claimPreview.z or 0,
                    size = IKST_ClaimRadial.DEFAULT_SH_SIZE,
                    w = claimPreview.w,
                    h = claimPreview.h,
                    claimMode = IKST_Claim.MODE.square,
                })
            end
        )
    end
end

function IKST_ClaimRadial.afterVehicleRadial(playerObj)
    if not playerObj then
        return
    end
    IKST_ClaimRadial.addVehicleSlices(playerObj)
end

function IKST_ClaimRadial.prepareMenu(playerObj)
    IKST_ClaimRadial.resetSliceKeys(IKST_ClaimRadial.playerMenu(playerObj))
end

function IKST_ClaimRadial.openSafehouseRadial(playerObj)
    if not playerObj or IKST_ClaimRadial.nearVehicle(playerObj) then
        return
    end
    local sh, claimPreview = IKST_ClaimRadial.safehouseContext(playerObj)
    if not sh and not claimPreview then
        return
    end
    local menu = IKST_ClaimRadial.playerMenu(playerObj)
    if not menu then
        return
    end
    if menu.clear then
        menu:clear()
    end
    IKST_ClaimRadial.resetSliceKeys(menu)
    IKST_ClaimRadial.addSafehouseSlices(playerObj)
    if menu.isEmpty and menu:isEmpty() then
        return
    end
    if menu.center then
        menu:center()
    end
    if menu.display then
        menu:display()
    end
end

function IKST_ClaimRadial.onVehicleKeyPressed(key, playerObj)
    if not playerObj then
        return
    end
    if IKST_ClaimRadial.nearVehicle(playerObj) then
        return
    end
    IKST_ClaimRadial.openSafehouseRadial(playerObj)
end

function IKST_ClaimRadial.hookVehicleMenu()
    if IKST_ClaimRadial._patched or not ISVehicleMenu then
        return
    end
    IKST_ClaimRadial._patched = true

    if ISVehicleMenu.showRadialMenu then
        IKST_ClaimRadial._vanillaInside = ISVehicleMenu.showRadialMenu
        function ISVehicleMenu.showRadialMenu(playerObj)
            IKST_ClaimRadial.prepareMenu(playerObj)
            IKST_ClaimRadial._vanillaInside(playerObj)
            IKST_ClaimRadial.afterVehicleRadial(playerObj)
        end
    end

    if ISVehicleMenu.showRadialMenuOutside then
        IKST_ClaimRadial._vanillaOutside = ISVehicleMenu.showRadialMenuOutside
        function ISVehicleMenu.showRadialMenuOutside(playerObj)
            IKST_ClaimRadial.prepareMenu(playerObj)
            IKST_ClaimRadial._vanillaOutside(playerObj)
            IKST_ClaimRadial.afterVehicleRadial(playerObj)
        end
    end

    if ISVehicleMenu.onKeyPressed then
        IKST_ClaimRadial._vanillaKey = ISVehicleMenu.onKeyPressed
        function ISVehicleMenu.onKeyPressed(key)
            if IKST_ClaimRadial._vanillaKey then
                IKST_ClaimRadial._vanillaKey(key)
            end
            local player = getPlayer and getPlayer() or nil
            if not player and getSpecificPlayer then
                player = getSpecificPlayer(0)
            end
            if player then
                IKST_ClaimRadial.onVehicleKeyPressed(key, player)
            end
        end
    end
end

if Events and Events.OnGameStart then
    Events.OnGameStart.Add(IKST_ClaimRadial.hookVehicleMenu)
end
