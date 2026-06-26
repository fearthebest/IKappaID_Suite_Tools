if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "ISUI/ISPanel"
require "ISUI/ISTextEntryBox"
require "IKST_Shared"
require "IKST_Chrome"
require "IKST_VehicleClaim"
require "IKST_VehiclePermissions"
require "IKST_ClaimPolicy"

IKST_VehicleClaimUI = IKST_VehicleClaimUI or {}

IKST_VehicleClaimUI.instance = nil

function IKST_VehicleClaimUI.close()
    if IKST_VehicleClaimUI.instance then
        IKST_VehicleClaimUI.instance:removeFromUIManager()
        IKST_VehicleClaimUI.instance = nil
    end
end

local Panel = ISPanel:derive("IKST_VehicleClaimUI")

function Panel:createChildren()
    ISPanel.createChildren(self)
    local pad = 12
    local innerW = self.width - (pad * 2)
    self.closeBtn = ISButton:new(self.width - pad - 70, pad, 70, 22, IKST.text("IGUI_IKST_Close", "Close"), self, Panel.onClose)
    self.closeBtn:initialise()
    self:addChild(self.closeBtn)

    local y = 40
    self.scopeBtns = {}
    local scopes = {
        { id = IKST_VehiclePermissions.GROUP_EVERYONE, label = IKST.text("IGUI_IKST_VehicleClaim_GroupEveryone", "Everyone") },
        { id = IKST_VehiclePermissions.GROUP_SAFEHOUSE, label = IKST.text("IGUI_IKST_VehicleClaim_GroupSafehouse", "Safehouse") },
        { id = IKST_VehiclePermissions.GROUP_FACTION, label = IKST.text("IGUI_IKST_VehicleClaim_GroupFaction", "Faction") },
    }
    local scopeW = math.floor((innerW - 8) / #scopes)
    local sx = pad
    for _, scope in ipairs(scopes) do
        local btn = ISButton:new(sx, y, scopeW, 22, scope.label, self, Panel.onScope)
        btn.internal = scope.id
        btn:initialise()
        self:addChild(btn)
        self.scopeBtns[#self.scopeBtns + 1] = btn
        sx = sx + scopeW + 4
    end
    y = y + 30

    self.userLabel = ISLabel:new(pad, y, 20, IKST.text("IGUI_IKST_VehicleClaim_UserPerms", "Whitelist player:"), 1, 1, 1, 1, UIFont.Small, true)
    self.userLabel:initialise()
    self:addChild(self.userLabel)
    y = y + 18
    self.userEntry = ISTextEntryBox:new("", pad, y, math.min(180, innerW - 90), 22)
    self.userEntry:initialise()
    self.userEntry:instantiate()
    self:addChild(self.userEntry)
    self.userScopeBtn = ISButton:new(pad + math.min(180, innerW - 90) + 8, y, 70, 22, IKST.text("IGUI_IKST_VehicleClaim_UserScope", "User"), self, Panel.onUserScope)
    self.userScopeBtn:initialise()
    self:addChild(self.userScopeBtn)
    y = y + 30

    self.whitelistLabel = ISLabel:new(pad, y, 20, "", 0.7, 0.7, 0.7, 1, UIFont.Small, true)
    self.whitelistLabel:initialise()
    self:addChild(self.whitelistLabel)
    y = y + 18

    self.actionBtns = {}
    local actions = IKST_VehiclePermissions.ACTIONS
    local cols = 4
    local btnW = math.floor((innerW - ((cols - 1) * 4)) / cols)
    local ax = pad
    local row = 0
    for i, action in ipairs(actions) do
        local btn = ISButton:new(ax, y, btnW, 22, action, self, Panel.onToggleAction)
        btn.internal = action
        btn:initialise()
        self:addChild(btn)
        self.actionBtns[action] = btn
        ax = ax + btnW + 4
        if i % cols == 0 then
            ax = pad
            y = y + 26
            row = row + 1
        end
    end
    if #actions % cols ~= 0 then
        y = y + 30
    else
        y = y + 8
    end

    self.saveBtn = ISButton:new(pad, y, math.min(150, math.floor(innerW * 0.48)), 24, IKST.text("IGUI_IKST_VehicleClaim_SavePerms", "Save permissions"), self, Panel.onSave)
    self.saveBtn:initialise()
    self:addChild(self.saveBtn)
    self.removeUserBtn = ISButton:new(pad + math.min(150, math.floor(innerW * 0.48)) + 8, y, math.min(150, math.floor(innerW * 0.48)), 24, IKST.text("IGUI_IKST_VehicleClaim_RemoveUser", "Remove user"), self, Panel.onRemoveUser)
    self.removeUserBtn:initialise()
    self:addChild(self.removeUserBtn)
end

function Panel:onClose()
    IKST_VehicleClaimUI.close()
end

function Panel:refreshPolicyUi()
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
    if self.whitelistLabel then
        local lines = {}
        if IKST_ClaimPolicy.whitelistOnly() then
            lines[#lines + 1] = IKST.text("IGUI_IKST_Claim_WhitelistOnlyHint", "Whitelist mode: only owner + named players.")
        end
        local entry = IKST_VehicleClaim.get(self.vehicleId)
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
    local entry = IKST_VehicleClaim.get(self.vehicleId)
    if not entry then
        return
    end
    IKST_VehicleClaim.ensureEntryShape(entry)
    local perms
    if self.scope == "user" then
        local name = self.userEntry and self.userEntry:getText() or ""
        local userPerms = IKST_ClaimPolicy.findUserPerms(entry.users, name)
        perms = userPerms or IKST_VehiclePermissions.emptyPerms()
    else
        perms = entry.groups[self.scope] or IKST_VehiclePermissions.emptyPerms()
    end
    self.draft = IKST_VehiclePermissions.copyPerms(perms)
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
    if not self.draft then
        self.draft = IKST_VehiclePermissions.emptyPerms()
    end
    local action = button.internal
    self.draft[action] = not self.draft[action]
    self:refreshActionButtons()
end

function Panel:onSave()
    local username = nil
    local scope = self.scope
    if scope == "user" then
        username = self.userEntry and self.userEntry:getText() or ""
        if username == "" then
            IKST.notify(self.player, IKST.text("IGUI_IKST_VehicleClaim_UserRequired", "Enter a username."), false)
            return
        end
    end
    IKST.dispatchCommand(self.player, IKST.CMD.vehicleClaimSetPerms, {
        vehicleId = self.vehicleId,
        scope = scope,
        username = username,
        perms = self.draft,
    })
    IKST.notify(self.player, IKST.text("IGUI_IKST_VehicleClaim_Saved", "Permissions sent to server."), true)
end

function Panel:onRemoveUser()
    local username = self.userEntry and self.userEntry:getText() or ""
    if username == "" then
        return
    end
    IKST.dispatchCommand(self.player, IKST.CMD.vehicleClaimSetPerms, {
        vehicleId = self.vehicleId,
        scope = "remove_user",
        username = username,
    })
end

function Panel:new(player, vehicleId)
    local w, h = 380, 300
    local x = (getCore():getScreenWidth() - w) / 2
    local y = (getCore():getScreenHeight() - h) / 2
    local o = ISPanel:new(x, y, w, h)
    setmetatable(o, self)
    self.__index = self
    o.player = player
    o.vehicleId = vehicleId
    o.scope = IKST_VehiclePermissions.GROUP_EVERYONE
    o.draft = IKST_VehiclePermissions.emptyPerms()
    IKST_Chrome.applyPanelColors(o)
    return o
end

function IKST_VehicleClaimUI.open(player, vehicleId)
    IKST_VehicleClaimUI.close()
    local panel = Panel:new(player, vehicleId)
    panel:initialise()
    panel:createChildren()
    panel:addToUIManager()
    panel:loadPermsForScope()
    panel:refreshScopeHighlight()
    panel:refreshPolicyUi()
    IKST_VehicleClaimUI.instance = panel
end
