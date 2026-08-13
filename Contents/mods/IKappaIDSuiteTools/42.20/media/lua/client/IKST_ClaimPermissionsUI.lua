if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "ISUI/ISCollapsableWindow"
require "ISUI/ISButton"
require "ISUI/ISLabel"
require "ISUI/ISTextEntryBox"
require "IKST_Shared"
require "IKST_Chrome"
require "IKST_UI_Layout"
require "IKST_UI_Theme"
require "IKST_ClaimPolicy"

IKST_ClaimPermissionsUI = IKST_ClaimPermissionsUI or {}
IKST_ClaimPermissionsUI.instance = nil

function IKST_ClaimPermissionsUI.close()
    if IKST_ClaimPermissionsUI.instance then
        IKST_ClaimPermissionsUI.instance:onClose()
    end
end

local Panel = ISCollapsableWindow:derive("IKST_ClaimPermissionsUI")

local function mutedLabelRgb()
    return IKST_UI_Theme.rgba(IKST_UI_Theme.colors.textMuted)
end

function Panel:createChildren()
    ISCollapsableWindow.createChildren(self)
    IKST_Chrome.applyPanelColors(self)
    local cfg = self.config
    if not cfg then
        return
    end
    local pad = IKST_UI_Layout and IKST_UI_Layout.s(16) or 16
    local btnH = (IKST_UI_Layout and IKST_UI_Layout.buttonMinH and math.min(32, IKST_UI_Layout.buttonMinH())) or 28
    local top = self:titleBarHeight() + 4
    local innerW = self.width - (pad * 2)
    local y = top

    self.scopeBtns = {}
    local scopes = cfg.scopes or {}
    local scopeW = math.floor((innerW - 8) / math.max(1, #scopes))
    local sx = pad
    for _, scope in ipairs(scopes) do
        local btn = IKST_Chrome.newActionButton(sx, y, scopeW, btnH, scope.label, self, Panel.onScope, "chip")
        btn.internal = scope.id
        self:addChild(btn)
        self.scopeBtns[#self.scopeBtns + 1] = btn
        sx = sx + scopeW + 4
    end
    y = y + btnH + 12

    local mr, mg, mb, ma = IKST_UI_Theme.rgba(IKST_UI_Theme.colors.textPrimary)
    self.userLabel = ISLabel:new(pad, y, 20, IKST.text("IGUI_IKST_VehicleClaim_UserPerms", "Whitelist player:"), mr, mg, mb, ma, UIFont.Small, true)
    self.userLabel:initialise()
    self:addChild(self.userLabel)
    y = y + 18
    self.userEntry = ISTextEntryBox:new("", pad, y, math.min(180, innerW - 90), btnH)
    self.userEntry:initialise()
    self.userEntry:instantiate()
    IKST_Chrome.styleInput(self.userEntry, false)
    self:addChild(self.userEntry)
    self.userScopeBtn = IKST_Chrome.newActionButton(pad + math.min(180, innerW - 90) + 8, y, 70, btnH, IKST.text("IGUI_IKST_VehicleClaim_UserScope", "User"), self, Panel.onUserScope, "chip")
    self:addChild(self.userScopeBtn)
    y = y + btnH + 12

    local wr, wg, wb, wa = mutedLabelRgb()
    self.whitelistLabel = ISLabel:new(pad, y, 20, "", wr, wg, wb, wa, UIFont.Small, true)
    self.whitelistLabel:initialise()
    self:addChild(self.whitelistLabel)
    y = y + 18

    self.actionBtns = {}
    local actions = cfg.permissions.ACTIONS
    local cols = cfg.actionCols or 3
    local btnW = math.floor((innerW - ((cols - 1) * 4)) / cols)
    local ax = pad
    for i, action in ipairs(actions) do
        local label = cfg.actionLabel(action)
        local btn = IKST_Chrome.newActionButton(ax, y, btnW, btnH, label, self, Panel.onToggleAction, "chip")
        btn.internal = action
        self:addChild(btn)
        self.actionBtns[action] = btn
        ax = ax + btnW + 4
        if i % cols == 0 then
            ax = pad
            y = y + btnH + 6
        end
    end
    if #actions % cols ~= 0 then
        y = y + btnH + 10
    else
        y = y + 8
    end

    self.saveBtn = IKST_Chrome.newActionButton(pad, y, math.min(150, math.floor(innerW * 0.48)), btnH + 4, IKST.text("IGUI_IKST_VehicleClaim_SavePerms", "Save permissions"), self, Panel.onSave, "primary")
    self:addChild(self.saveBtn)
    self.removeUserBtn = IKST_Chrome.newActionButton(pad + math.min(150, math.floor(innerW * 0.48)) + 8, y, math.min(150, math.floor(innerW * 0.48)), btnH + 4, IKST.text("IGUI_IKST_VehicleClaim_RemoveUser", "Remove user"), self, Panel.onRemoveUser, "danger")
    self:addChild(self.removeUserBtn)
end

function Panel:onClose()
    self:setVisible(false)
    self:removeFromUIManager()
    IKST_ClaimPermissionsUI.instance = nil
end

function Panel:close()
    self:onClose()
end

function Panel:refreshPolicyUi()
    local cfg = self.config
    if not cfg then
        return
    end
    local named = IKST_ClaimPolicy.allowNamedPlayers()
    if self.userEntry then
        self.userEntry:setEditable(named)
    end
    if self.userScopeBtn then
        self.userScopeBtn:setEnable(named)
    end
    if self.removeUserBtn then
        self.removeUserBtn:setEnable(named)
    end
    local editGroups = IKST_ClaimPolicy.ownersEditGroups()
    for _, btn in ipairs(self.scopeBtns or {}) do
        btn:setEnable(editGroups)
    end
    if self.whitelistLabel and type(cfg.getEntry) == "function" then
        local lines = {}
        if IKST_ClaimPolicy.whitelistOnly() then
            lines[#lines + 1] = IKST.text("IGUI_IKST_Claim_WhitelistOnlyHint", "Whitelist mode: only owner + named players.")
        end
        local entry = cfg.getEntry(self)
        if entry and entry.users then
            local names = {}
            for name in pairs(entry.users) do
                names[#names + 1] = name
            end
            table.sort(names)
            if #names > 0 then
                lines[#lines + 1] = IKST.text("IGUI_IKST_Claim_WhitelistNames", "On list:") .. " " .. table.concat(names, ", ")
            end
        end
        self.whitelistLabel:setName(table.concat(lines, "  "))
    end
end

function Panel:refreshScopeHighlight()
    for _, btn in ipairs(self.scopeBtns) do
        IKST_Chrome.styleChipButton(btn, btn.internal == self.scope)
    end
    if self.userScopeBtn then
        IKST_Chrome.styleChipButton(self.userScopeBtn, self.scope == "user")
    end
end

function Panel:loadPermsForScope()
    local cfg = self.config
    if not cfg or type(cfg.getEntry) ~= "function" then
        return
    end
    local entry = cfg.getEntry(self)
    if not entry then
        return
    end
    local perms
    if self.scope == "user" then
        local name = self.userEntry and self.userEntry:getText() or ""
        local userPerms = IKST_ClaimPolicy.findUserPerms(entry.users, name)
        perms = userPerms or cfg.permissions.emptyPerms()
    else
        perms = entry.groups[self.scope] or cfg.permissions.emptyPerms()
    end
    self.draft = cfg.permissions.copyPerms(perms)
    self:refreshActionButtons()
end

function Panel:refreshActionButtons()
    for action, btn in pairs(self.actionBtns) do
        IKST_Chrome.styleChipButton(btn, self.draft and self.draft[action] == true)
    end
end

function Panel:onScope(button)
    if not IKST_ClaimPolicy.ownersEditGroups() then
        return
    end
    self.scope = button.internal
    self:refreshScopeHighlight()
    self:loadPermsForScope()
end

function Panel:onUserScope()
    if not IKST_ClaimPolicy.allowNamedPlayers() then
        return
    end
    self.scope = "user"
    self:refreshScopeHighlight()
    self:loadPermsForScope()
end

function Panel:onToggleAction(button)
    local cfg = self.config
    if not cfg then
        return
    end
    if not self.draft then
        self.draft = cfg.permissions.emptyPerms()
    end
    local action = button.internal
    self.draft[action] = not self.draft[action]
    self:refreshActionButtons()
end

function Panel:onSave()
    local cfg = self.config
    if not cfg or type(cfg.buildSavePayload) ~= "function" then
        return
    end
    local username = nil
    local scope = self.scope
    if scope == "user" then
        username = self.userEntry and self.userEntry:getText() or ""
        if username == "" then
            IKST.notify(self.player, IKST.text("IGUI_IKST_VehicleClaim_UserRequired", "Enter a username."), false)
            return
        end
    end
    IKST.dispatchCommand(self.player, cfg.cmd, cfg.buildSavePayload(self, scope, username, self.draft))
    IKST.notify(self.player, IKST.text("IGUI_IKST_VehicleClaim_Saved", "Permissions sent to server."), true)
end

function Panel:onRemoveUser()
    local cfg = self.config
    if not cfg or type(cfg.buildRemovePayload) ~= "function" then
        return
    end
    local username = self.userEntry and self.userEntry:getText() or ""
    if username == "" then
        return
    end
    IKST.dispatchCommand(self.player, cfg.cmd, cfg.buildRemovePayload(self, username))
end

function Panel:new(player, config)
    local pw, ph = 440, 380
    local px = (getCore():getScreenWidth() - pw) / 2
    local py = (getCore():getScreenHeight() - ph) / 2
    local o = ISCollapsableWindow:new(px, py, pw, ph)
    setmetatable(o, self)
    self.__index = self
    o.player = player
    o.config = config
    o.pin = true
    o.resizable = false
    o.scope = config.defaultScope
    o.draft = config.permissions.emptyPerms()
    IKST_Chrome.applyPanelColors(o)
    o:setTitle(config.title or IKST.text("IGUI_IKST_Claim_Perms", "Claim permissions"))
    return o
end

function IKST_ClaimPermissionsUI.open(player, config)
    IKST_ClaimPermissionsUI.close()
    local panel = Panel:new(player, config)
    if config.refX ~= nil then
        panel.refX = config.refX
        panel.refY = config.refY
        panel.refW = config.refW
        panel.refH = config.refH
    end
    if config.vehicleId ~= nil then
        panel.vehicleId = config.vehicleId
    end
    panel:initialise()
    panel:addToUIManager()
    panel:loadPermsForScope()
    panel:refreshScopeHighlight()
    panel:refreshPolicyUi()
    IKST_ClaimPermissionsUI.instance = panel
    return panel
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

function IKST_ClaimPermissionsUI.vehicleConfig(vehicleId)
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
            return {
                vehicleId = panel.vehicleId,
                claimKey = panel.vehicleId,
                scope = scope,
                username = username,
                perms = perms,
            }
        end,
        buildRemovePayload = function(panel, username)
            return {
                vehicleId = panel.vehicleId,
                claimKey = panel.vehicleId,
                scope = "remove_user",
                username = username,
            }
        end,
        vehicleId = vehicleId,
    }
end

function IKST_ClaimPermissionsUI.openSafehouse(player, x, y, w, h, defaultScope)
    local cfg = IKST_ClaimPermissionsUI.safehouseConfig(x, y, w, h)
    if defaultScope then
        cfg.defaultScope = defaultScope
    end
    IKST_ClaimPermissionsUI.open(player, cfg)
end

function IKST_ClaimPermissionsUI.openVehicle(player, vehicleId, defaultScope)
    local cfg = IKST_ClaimPermissionsUI.vehicleConfig(vehicleId)
    if defaultScope then
        cfg.defaultScope = defaultScope
    end
    IKST_ClaimPermissionsUI.open(player, cfg)
end
