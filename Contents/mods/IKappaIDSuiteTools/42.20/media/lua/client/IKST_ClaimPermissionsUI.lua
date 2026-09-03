if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "ISUI/ISLabel"
require "ISUI/ISTextEntryBox"
require "IKST_Shared"
require "IKappaID_UI/IKUI_Chrome"
require "IKST_ClaimPolicy"

IKST_ClaimPermissionsUI = IKST_ClaimPermissionsUI or {}
IKST_ClaimPermissionsUI.instance = nil

function IKST_ClaimPermissionsUI.close()
    IKST_ClaimPermissionsUI.instance = nil
end

function IKST_ClaimPermissionsUI.openInHub(player, config, toolId)
    player = IKST.resolvePlayer(player)
    if not player or not config then
        return
    end
    IKST_ClaimPermissionsUI.close()
    local tool = toolId
    if not tool then
        if config.vehicleId ~= nil then
            tool = "vehicleclaim"
        else
            tool = "overview"
        end
    end
    if IKST_Hub and type(IKST_Hub.openWorkspace) == "function" then
        IKST_Hub.openWorkspace(player, IKST.VIEW.claim, tool)
    end
    local hub = IKST_Hub and type(IKST_Hub.activeJobPanel) == "function" and IKST_Hub.activeJobPanel()
    if not hub then
        return
    end
    IKST_ClaimPermissionsUI.beginSoft(hub, config)
    if type(hub.refreshJobUI) == "function" then
        hub:refreshJobUI(true)
    end
end

function IKST_ClaimPermissionsUI.open(player, config)
    IKST_ClaimPermissionsUI.openInHub(player, config)
end

function IKST_ClaimPermissionsUI.safehouseConfig(x, y, w, h)
    require "IKST_SafehouseClaim"
    require "IKST_SafehousePermissions"
    return {
        title = IKST.text("IGUI_IKST_SafehouseClaim_PermsTitle", "Safehouse permissions"),
        permissions = IKST_SafehousePermissions,
        defaultScope = IKST_SafehousePermissions.GROUP_EVERYONE,
        actionCols = 3,
        scopes = {
            { id = IKST_SafehousePermissions.GROUP_EVERYONE, label = IKST.text("IGUI_IKST_VehicleClaim_GroupEveryone", "Everyone") },
            { id = IKST_SafehousePermissions.GROUP_MEMBER, label = IKST.text("IGUI_IKST_SafehouseClaim_GroupMember", "Members") },
            { id = IKST_SafehousePermissions.GROUP_FACTION, label = IKST.text("IGUI_IKST_VehicleClaim_GroupFaction", "Faction") },
        },
        actionLabel = function(action)
            return IKST.text("IGUI_IKST_SafehouseClaim_Action_" .. action, action)
        end,
        getEntry = function(panel)
            return IKST_SafehouseClaim.entryForDisplay(panel.refX, panel.refY, panel.refW, panel.refH)
        end,
        cmd = IKST.CMD.safehouseClaimSetPerms,
        buildSavePayload = function(panel, scope, username, perms)
            return {
                x = panel.refX, y = panel.refY, w = panel.refW, h = panel.refH,
                scope = scope,
                username = username,
                perms = perms,
            }
        end,
        buildRemovePayload = function(panel, username)
            return {
                x = panel.refX, y = panel.refY, w = panel.refW, h = panel.refH,
                scope = "remove_user",
                username = username,
            }
        end,
        refX = x,
        refY = y,
        refW = w,
        refH = h,
    }
end

function IKST_ClaimPermissionsUI.vehicleConfig(vehicleId, claimKey)
    require "IKST_VehicleClaim"
    require "IKST_VehiclePermissions"
    return {
        title = IKST.text("IGUI_IKST_VehicleClaim_PermsTitle", "Vehicle permissions"),
        permissions = IKST_VehiclePermissions,
        defaultScope = IKST_VehiclePermissions.GROUP_EVERYONE,
        actionCols = 4,
        scopes = {
            { id = IKST_VehiclePermissions.GROUP_EVERYONE, label = IKST.text("IGUI_IKST_VehicleClaim_GroupEveryone", "Everyone") },
            { id = IKST_VehiclePermissions.GROUP_SAFEHOUSE, label = IKST.text("IGUI_IKST_VehicleClaim_GroupSafehouse", "Safehouse") },
            { id = IKST_VehiclePermissions.GROUP_FACTION, label = IKST.text("IGUI_IKST_VehicleClaim_GroupFaction", "Faction") },
        },
        actionLabel = function(action)
            return IKST.text("IGUI_IKST_VehicleClaim_Action_" .. action, action)
        end,
        getEntry = function(panel)
            return IKST_VehicleClaim.entryForDisplay(panel.vehicleId)
        end,
        cmd = IKST.CMD.vehicleClaimSetPerms,
        buildSavePayload = function(panel, scope, username, perms)
            local payload = {
                vehicleId = panel.vehicleId,
                scope = scope,
                username = username,
                perms = perms,
            }
            if panel.claimKey and panel.claimKey ~= "" then
                payload.claimKey = panel.claimKey
            elseif IKST_VehicleClaimClient and type(IKST_VehicleClaimClient.rowForVehicle) == "function" then
                local row = IKST_VehicleClaimClient.rowForVehicle(panel.vehicleId)
                if row and row.claimKey and row.claimKey ~= "" then
                    payload.claimKey = row.claimKey
                end
            end
            return payload
        end,
        buildRemovePayload = function(panel, username)
            local payload = {
                vehicleId = panel.vehicleId,
                scope = "remove_user",
                username = username,
            }
            if panel.claimKey and panel.claimKey ~= "" then
                payload.claimKey = panel.claimKey
            elseif IKST_VehicleClaimClient and type(IKST_VehicleClaimClient.rowForVehicle) == "function" then
                local row = IKST_VehicleClaimClient.rowForVehicle(panel.vehicleId)
                if row and row.claimKey and row.claimKey ~= "" then
                    payload.claimKey = row.claimKey
                end
            end
            return payload
        end,
        vehicleId = vehicleId,
        claimKey = claimKey,
    }
end

function IKST_ClaimPermissionsUI.openSafehouse(player, x, y, w, h, defaultScope)
    local cfg = IKST_ClaimPermissionsUI.safehouseConfig(x, y, w, h)
    if defaultScope then
        cfg.defaultScope = defaultScope
    end
    IKST_ClaimPermissionsUI.open(player, cfg)
end

function IKST_ClaimPermissionsUI.openVehicle(player, vehicleId, defaultScope, claimKey)
    local cfg = IKST_ClaimPermissionsUI.vehicleConfig(vehicleId, claimKey)
    if defaultScope then
        cfg.defaultScope = defaultScope
    end
    IKST_ClaimPermissionsUI.open(player, cfg)
end

-- Soft hub only: permissions live in SoftPageHost detail — not a second window.
function IKST_ClaimPermissionsUI.beginSoft(hub, config)
    if not hub or not config then
        return
    end
    hub._ikstSoftPermsCfg = config
    hub._ikstSoftPerms = {
        scope = config.defaultScope,
        draft = nil,
        user = "",
        key = tostring(config.refX or "") .. ":" .. tostring(config.refY or "") .. ":"
            .. tostring(config.refW or "") .. ":" .. tostring(config.refH or "") .. ":"
            .. tostring(config.vehicleId or "") .. ":" .. tostring(config.claimKey or ""),
    }
end

function IKST_ClaimPermissionsUI.clearSoft(hub)
    if not hub then
        return
    end
    hub._ikstSoftPermsCfg = nil
    hub._ikstSoftPerms = nil
end

function IKST_ClaimPermissionsUI.hasSoft(hub)
    return hub and hub._ikstSoftPermsCfg ~= nil
end

function IKST_ClaimPermissionsUI.placeSoft(hub, parent, ax, ay, aw, ah, player)
    if not hub or not parent or not player then
        return
    end
    local cfg = hub._ikstSoftPermsCfg
    local state = hub._ikstSoftPerms
    if not cfg or not state or not cfg.permissions then
        return
    end
    require "IKST_JobLayout"
    local btnH = IKST_JobLayout.STANDARD_BTN_H or 28
    local gap = 6
    local y = ay

    local proxy = {
        refX = cfg.refX,
        refY = cfg.refY,
        refW = cfg.refW,
        refH = cfg.refH,
        vehicleId = cfg.vehicleId,
        claimKey = cfg.claimKey,
    }

    if state.draft == nil and type(cfg.getEntry) == "function" then
        local entry = cfg.getEntry(proxy)
        local perms
        if state.scope == "user" then
            perms = cfg.permissions.emptyPerms()
        elseif entry and entry.groups then
            perms = entry.groups[state.scope] or cfg.permissions.emptyPerms()
        else
            perms = cfg.permissions.emptyPerms()
        end
        state.draft = cfg.permissions.copyPerms(perms)
    end
    if not state.draft then
        state.draft = cfg.permissions.emptyPerms()
    end

    local backItems = {
        {
            label = IKST.text("IGUI_IKST_Back", "Back"),
            onClick = function()
                IKST_ClaimPermissionsUI.clearSoft(hub)
                if hub.refreshJobUI then
                    hub:refreshJobUI(true)
                end
            end,
        },
    }
    IKST_JobLayout.placePillGroup(hub, parent, ax, y, aw, btnH, backItems)
    y = y + btnH + gap

    local title = ISLabel:new(ax, y, 16, tostring(cfg.title or "Permissions"), 1, 1, 1, 1, UIFont.Small, true)
    title:initialise()
    parent:addChild(title)
    y = y + 18

    local scopeItems = {}
    for _, scope in ipairs(cfg.scopes or {}) do
        local sid = scope.id
        scopeItems[#scopeItems + 1] = {
            label = scope.label,
            primary = state.scope == sid,
            onClick = function()
                if not IKST_ClaimPolicy.ownersEditGroups() then
                    return
                end
                state.scope = sid
                state.draft = nil
                if hub.refreshJobUI then
                    hub:refreshJobUI(true)
                end
            end,
        }
    end
    if IKST_ClaimPolicy.allowNamedPlayers() then
        scopeItems[#scopeItems + 1] = {
            label = IKST.text("IGUI_IKST_VehicleClaim_UserScope", "User"),
            primary = state.scope == "user",
            onClick = function()
                state.scope = "user"
                state.draft = nil
                if hub.refreshJobUI then
                    hub:refreshJobUI(true)
                end
            end,
        }
    end
    local scopeH = IKST_JobLayout.compactPillBandH and IKST_JobLayout.compactPillBandH(1) or btnH
    IKST_JobLayout.placePillGroup(hub, parent, ax, y, aw, scopeH, scopeItems)
    y = y + scopeH + gap

    if state.scope == "user" and IKST_ClaimPolicy.allowNamedPlayers() then
        local userLab = ISLabel:new(ax, y, 16,
            IKST.text("IGUI_IKST_VehicleClaim_UserPerms", "Whitelist player:"),
            1, 1, 1, 1, UIFont.Small, true)
        userLab:initialise()
        parent:addChild(userLab)
        y = y + 16
        local entryW = math.min(220, math.max(80, aw - 8))
        local userEntry = ISTextEntryBox:new(state.user or "", ax, y, entryW, btnH)
        userEntry:initialise()
        userEntry:instantiate()
        if IKUI_Chrome and type(IKUI_Chrome.styleInput) == "function" then
            IKUI_Chrome.styleInput(userEntry, false)
        end
        parent:addChild(userEntry)
        hub._ikstSoftPermsUserEntry = userEntry
        y = y + btnH + gap
    else
        hub._ikstSoftPermsUserEntry = nil
    end

    local actionItems = {}
    local actions = cfg.permissions.ACTIONS or {}
    for _, action in ipairs(actions) do
        local a = action
        local label = type(cfg.actionLabel) == "function" and cfg.actionLabel(a) or tostring(a)
        actionItems[#actionItems + 1] = {
            label = label,
            primary = state.draft and state.draft[a] == true,
            onClick = function()
                if not state.draft then
                    state.draft = cfg.permissions.emptyPerms()
                end
                state.draft[a] = not state.draft[a]
                if hub.refreshJobUI then
                    hub:refreshJobUI(true)
                end
            end,
        }
    end
    local actRows = math.max(1, math.ceil(#actionItems / 3))
    local actH = (IKST_JobLayout.compactPillBandH and IKST_JobLayout.compactPillBandH(actRows)) or (btnH * actRows)
    if y + actH > ay + ah then
        actH = math.max(btnH, (ay + ah) - y - btnH - gap)
    end
    IKST_JobLayout.placePillGroup(hub, parent, ax, y, aw, actH, actionItems)
    y = y + actH + gap

    local foot = {
        {
            label = IKST.text("IGUI_IKST_VehicleClaim_Save", "Save"),
            primary = true,
            onClick = function()
                if type(cfg.buildSavePayload) ~= "function" then
                    return
                end
                local username = nil
                local scope = state.scope
                if scope == "user" then
                    local box = hub._ikstSoftPermsUserEntry
                    username = (box and type(box.getText) == "function" and box:getText()) or (state.user or "")
                    if username == "" then
                        IKST.notify(player, IKST.text("IGUI_IKST_VehicleClaim_UserRequired", "Enter a username."), false)
                        return
                    end
                    state.user = username
                end
                IKST.dispatchCommand(player, cfg.cmd, cfg.buildSavePayload(proxy, scope, username, state.draft))
                IKST.notify(player, IKST.text("IGUI_IKST_VehicleClaim_Saved", "Permissions sent to server."), true)
            end,
        },
    }
    if state.scope == "user" and IKST_ClaimPolicy.allowNamedPlayers() and type(cfg.buildRemovePayload) == "function" then
        foot[#foot + 1] = {
            label = IKST.text("IGUI_IKST_VehicleClaim_RemoveUser", "Remove user"),
            onClick = function()
                local box = hub._ikstSoftPermsUserEntry
                local username = (box and type(box.getText) == "function" and box:getText()) or (state.user or "")
                if username == "" then
                    return
                end
                IKST.dispatchCommand(player, cfg.cmd, cfg.buildRemovePayload(proxy, username))
            end,
        }
    end
    if y + btnH <= ay + ah then
        IKST_JobLayout.placePillGroup(hub, parent, ax, y, aw, btnH, foot)
    end
end
