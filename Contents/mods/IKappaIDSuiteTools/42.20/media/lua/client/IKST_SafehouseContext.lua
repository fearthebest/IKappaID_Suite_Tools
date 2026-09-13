-- World context for IKST safehouse claims. Vanilla Claim/View Safehouse is
-- wrapped to IKST (same exception class as tickets). See docs/ENFORCEMENT.md.

if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "ISUI/ISWorldObjectContextMenu"
require "ISUI/UserPanel/ISSafehouseUI"
require "ISUI/UserPanel/ISUserPanelUI"
require "OptionScreens/MapSpawnSelect"
require "IKST_Shared"
require "IKST_ClaimPolicy"
require "IKST_Claim"
require "IKST_SafehouseClaim"
require "IKST_SafehouseClaimClient"
require "IKST_SafeHouse"
require "IKST_Access"
require "IKST_ClaimIcons"
require "IKST_JobGuard"
require "IKST_Hub"
require "IKST_ClaimPermissionsUI"
require "IKappaID_UI/IKUI_Shell"

IKST_SafehouseContext = IKST_SafehouseContext or {}

function IKST_SafehouseContext.mayCreateClaim(player)
    return IKST_ClaimPolicy and IKST_ClaimPolicy.mayCreateSafehouseClaim
        and IKST_ClaimPolicy.mayCreateSafehouseClaim(player)
end

function IKST_SafehouseContext.mayRequestClaim(player)
    return IKST_ClaimPolicy and IKST_ClaimPolicy.mayRequestSafehouseClaim
        and IKST_ClaimPolicy.mayRequestSafehouseClaim(player)
end

function IKST_SafehouseContext.addOption(sub, label, player, fn, iconPath)
    local opt = sub:addOption(label, player, fn)
    IKST_ClaimIcons.applyContextIcon(opt, iconPath)
    return opt
end

function IKST_SafehouseContext.openClaimWorkspace(player, safehouse)
    player = IKST.resolvePlayer(player) or (getPlayer and getPlayer())
    if not player then
        return
    end
    if IKST_Hub and type(IKST_Hub.openWorkspace) == "function" then
        IKST_Hub.openWorkspace(player, IKST.VIEW.claim, "overview")
    elseif IKST_Hub and type(IKST_Hub.open) == "function" then
        IKST_Hub.open(player)
        if type(IKST_Hub.switchWorkspace) == "function" then
            IKST_Hub.switchWorkspace(IKST.VIEW.claim, "overview")
        end
    end
    local panel = IKST_Hub and type(IKST_Hub.activeJobPanel) == "function" and IKST_Hub.activeJobPanel()
    if panel and safehouse and IKST_SafehouseClaim and type(IKST_SafehouseClaim.boundsFromSafehouse) == "function" then
        local x, y, w, h, owner = IKST_SafehouseClaim.boundsFromSafehouse(safehouse)
        if x then
            panel.guardSelectedSH = {
                x = x, y = y, w = w, h = h, owner = owner,
                id = IKST_SafeHouse and IKST_SafeHouse.onlineId and (IKST_SafeHouse.onlineId(safehouse) or IKST_SafeHouse.id(safehouse)) or nil,
            }
        end
    end
end

function IKST_SafehouseContext.redirectClaim(player)
    player = IKST.resolvePlayer(player) or (getPlayer and getPlayer())
    IKST_SafehouseContext.openClaimWorkspace(player)
    if not player then
        return
    end
    if IKST_SafehouseContext.mayCreateClaim(player) then
        IKST.notify(player, IKST.text("IGUI_IKST_Claim_VanillaRedirectStaff",
            "House claims use IKST. Use Claim here on the Safehouses tab."), true)
    else
        IKST.notify(player, IKST.text("IGUI_IKST_Claim_VanillaRedirect",
            "House claims use IKST. Request a claim on Overview; staff approve it."), true)
    end
end

function IKST_SafehouseContext.redirectView(player, safehouse)
    player = IKST.resolvePlayer(player) or (getPlayer and getPlayer())
    IKST_SafehouseContext.openClaimWorkspace(player, safehouse)
end

function IKST_SafehouseContext.stripVanillaClaimOptions(context)
    if not context then
        return
    end
    local names = {}
    local function addName(s)
        if type(s) == "string" and s ~= "" then
            names[s] = true
        end
    end
    if type(getText) == "function" then
        addName(getText("ContextMenu_TakeSafehouse"))
        addName(getText("ContextMenu_ViewSafehouse"))
        addName(getText("ContextMenu_Safehouse"))
        addName(getText("ContextMenu_ClaimSafehouse"))
        addName(getText("ContextMenu_ReleaseSafehouse"))
    end
    addName("Claim Safehouse")
    addName("Take Safehouse")
    addName("View Safehouse")
    addName("Release Safehouse")
    addName("Safehouse")
    if type(context.removeOptionByName) == "function" then
        for name in pairs(names) do
            context:removeOptionByName(name)
        end
    end
    local keep = string.lower(IKST.text("IGUI_IKST_SafehouseClaim_Menu", "Safe area"))
    local options = context.options
    if type(options) == "table" and type(context.removeOptionByName) == "function" then
        local extra = {}
        for _, opt in pairs(options) do
            local n = opt and opt.name
            if type(n) == "string" and n ~= "" then
                local lower = string.lower(n)
                if lower ~= keep and (string.find(lower, "safehouse", 1, true) or string.find(lower, "safe house", 1, true)) then
                    extra[n] = true
                end
            end
        end
        for name in pairs(extra) do
            context:removeOptionByName(name)
        end
    end
end

local function spawnRegionFromBounds(x, y, w, h)
    if x == nil or y == nil or not w or not h then
        return nil
    end
    -- Same center as vanilla MapSpawnSelect:getSafehouseSpawnRegion.
    local posX = x + (h / 2)
    local posY = y + (w / 2)
    local name = "Safehouse"
    if type(getText) == "function" then
        name = getText("UI_mapspawn_Safehouse")
    end
    return {
        {
            name = name,
            points = {
                unemployed = {
                    { posX = posX, posY = posY, posZ = 0 },
                },
            },
        },
    }
end

local function spawnUsernames()
    local names = {}
    local function add(n)
        if type(n) == "string" and n ~= "" then
            names[#names + 1] = n
        end
    end
    if type(getClientUsername) == "function" then
        add(getClientUsername())
    end
    local player = nil
    if type(getSpecificPlayer) == "function" then
        player = getSpecificPlayer(0)
    end
    if not player and type(getPlayer) == "function" then
        player = getPlayer()
    end
    if player and type(player.getUsername) == "function" then
        add(player:getUsername())
    end
    return names
end

local function nameMatches(a, b)
    if type(a) ~= "string" or type(b) ~= "string" then
        return false
    end
    if IKST_ClaimPolicy and type(IKST_ClaimPolicy.usernamesEqual) == "function" then
        return IKST_ClaimPolicy.usernamesEqual(a, b)
    end
    return a == b
end

local function javaHouseAllowsRespawn(sh, username)
    if not sh or type(username) ~= "string" then
        return false
    end
    local flagged = false
    if type(sh.isRespawnInSafehouse) == "function" then
        flagged = sh:isRespawnInSafehouse(username) == true
    end
    if not flagged and type(sh.getPlayersRespawn) == "function" then
        local list = sh:getPlayersRespawn()
        if list and type(list.contains) == "function" then
            flagged = list:contains(username) == true
        end
    end
    if not flagged then
        return false
    end
    if type(sh.getOwner) == "function" and nameMatches(sh:getOwner(), username) then
        return true
    end
    if type(sh.getPlayers) == "function" then
        local members = sh:getPlayers()
        if members and type(members.contains) == "function" and members:contains(username) then
            return true
        end
    end
    return false
end

function IKST_SafehouseContext.safehouseSpawnRegion()
    if type(isClient) == "function" and not isClient() then
        return nil
    end
    if not IKST_ClaimPolicy or type(IKST_ClaimPolicy.safehouseRespawnAllowed) ~= "function" then
        return nil
    end
    if not IKST_ClaimPolicy.safehouseRespawnAllowed() then
        return nil
    end
    local names = spawnUsernames()
    if #names < 1 then
        return nil
    end
    local found = nil
    if IKST_SafeHouse and type(IKST_SafeHouse.iter) == "function" then
        IKST_SafeHouse.iter(function(sh)
            if found then
                return
            end
            for i = 1, #names do
                if javaHouseAllowsRespawn(sh, names[i]) then
                    local x, y, w, h = IKST_SafeHouse.bounds(sh)
                    found = spawnRegionFromBounds(x, y, w, h)
                    return
                end
            end
        end)
    end
    if found then
        return found
    end
    local rows = IKST_SafehouseClaimClient and IKST_SafehouseClaimClient.safehouses
    if type(rows) == "table" then
        for i = 1, #rows do
            local row = rows[i]
            if row and row.respawnOn == true then
                local mine = row.isMine == true or row.canRespawn == true
                if not mine then
                    for n = 1, #names do
                        if nameMatches(row.owner, names[n]) then
                            mine = true
                            break
                        end
                    end
                end
                if mine then
                    return spawnRegionFromBounds(row.x, row.y, row.w, row.h)
                end
            end
        end
    end
    return nil
end

function IKST_SafehouseContext.wrapVanilla()
    if IKST_SafehouseContext.wrapped then
        return
    end
    IKST_SafehouseContext.wrapped = true
    if ISWorldObjectContextMenu and type(ISWorldObjectContextMenu.onTakeSafeHouse) == "function" then
        ISWorldObjectContextMenu.onTakeSafeHouse = function(worldobjects, square, player)
            IKST_SafehouseContext.redirectClaim(player)
        end
    end
    if ISWorldObjectContextMenu and type(ISWorldObjectContextMenu.onViewSafeHouse) == "function" then
        ISWorldObjectContextMenu.onViewSafeHouse = function(worldobjects, safehouse, player)
            IKST_SafehouseContext.redirectView(player, safehouse)
        end
    end
    if ISUserPanelUI and type(ISUserPanelUI.onOptionMouseDown) == "function" then
        local vanillaPanel = ISUserPanelUI.onOptionMouseDown
        ISUserPanelUI.onOptionMouseDown = function(self, button, x, y)
            local isSafehouse = button and (button == self.safehouseBtn or button.internal == "SAFEHOUSE")
            if isSafehouse then
                if self.close then
                    self:close()
                end
                IKST_SafehouseContext.redirectView(self.player, nil)
                return
            end
            return vanillaPanel(self, button, x, y)
        end
    end
    if ISSafehouseUI then
        ISSafehouseUI.addToUIManager = function(self)
            if ISSafehouseUI.instance == self then
                ISSafehouseUI.instance = nil
            end
            IKST_SafehouseContext.redirectView(self.player, self.safehouse)
        end
    end
    if MapSpawnSelect and type(MapSpawnSelect.getSafehouseSpawnRegion) == "function"
        and not MapSpawnSelect.__ikst_safehouse_spawn then
        MapSpawnSelect.__ikst_safehouse_spawn = true
        local origSpawn = MapSpawnSelect.getSafehouseSpawnRegion
        MapSpawnSelect.getSafehouseSpawnRegion = function(self)
            local region = origSpawn(self)
            if region then
                return region
            end
            return IKST_SafehouseContext.safehouseSpawnRegion()
        end
    end
end

function IKST_SafehouseContext.addRespawnOption(sub, player, sh, x, y, w, h, owner, uiState)
    if not IKST_ClaimPolicy or type(IKST_ClaimPolicy.safehouseRespawnAllowed) ~= "function" then
        return
    end
    if not IKST_ClaimPolicy.safehouseRespawnAllowed() then
        return
    end
    local allowed = false
    if IKST_Access.canUseTools(player) then
        allowed = true
    elseif type(sh.isOwner) == "function" and sh:isOwner(player) == true then
        allowed = true
    elseif type(sh.playerAllowed) == "function" and sh:playerAllowed(player) == true then
        allowed = true
    elseif IKST_ClaimPermissionsUI and type(IKST_ClaimPermissionsUI.rowAllowsRespawn) == "function"
        and IKST_ClaimPermissionsUI.rowAllowsRespawn(uiState) then
        allowed = true
    end
    if not allowed then
        return
    end
    local uname = nil
    if type(player.getUsername) == "function" then
        uname = player:getUsername()
    end
    local on = false
    if uname and type(sh.isRespawnInSafehouse) == "function" then
        on = sh:isRespawnInSafehouse(uname) == true
    end
    local label = on
        and IKST.text("IGUI_IKST_SH_RespawnOn", "Respawn on")
        or IKST.text("IGUI_IKST_SH_RespawnOff", "Respawn off")
    local shId = IKST_SafeHouse.onlineId(sh) or IKST_SafeHouse.id(sh)
    IKST_SafehouseContext.addOption(sub, label, player, function()
        IKST.dispatchCommand(player, IKST.CMD.safehouseSetRespawn, {
            x = x, y = y, w = w, h = h, owner = owner, id = shId, on = not on,
        })
    end, IKST_ClaimIcons.SAFEHOUSE_CLAIM)
end

function IKST_SafehouseContext.onFillWorldObjectContextMenu(playerNum, context, worldobjects, test)
    if test then
        return false
    end
    local player = IKST.resolvePlayer(playerNum)
    if not player or not context then
        return
    end
    IKST_SafehouseContext.stripVanillaClaimOptions(context)
    local sq = nil
    if type(player.getCurrentSquare) == "function" then
        sq = player:getCurrentSquare()
    end
    if not sq then
        return
    end

    local sh = IKST_SafehouseClaim.safehouseAtSquare(sq)
    if not sh and SafeHouse and type(SafeHouse.getSafeHouse) == "function" then
        sh = SafeHouse.getSafeHouse(sq)
    end
    local isAdmin = IKST_Access.canUseTools(player)

    if sh then
        local x, y, w, h, owner = IKST_SafehouseClaim.boundsFromSafehouse(sh)
        if not x then
            return
        end
        local uiState = IKST_SafehouseClaimClient and IKST_SafehouseClaimClient.uiState(x, y, w, h, player, owner)
        local canRelease = isAdmin
        local canEdit = isAdmin
        if uiState then
            canRelease = uiState.canRelease == true or isAdmin
            canEdit = IKST_ClaimPermissionsUI.rowAllowsOpen(uiState) or isAdmin
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
            IKST_SafehouseContext.addOption(sub, IKST.text("IGUI_IKST_VehicleClaim_Perms", "Permissions..."), player, function()
                if not IKST_Hub or type(IKST_Hub.openWorkspace) ~= "function" then
                    return
                end
                local claimId = (IKST and IKST.VIEW and IKST.VIEW.claim) or "claim"
                IKST_Hub.openWorkspace(player, claimId, "overview")
                local win = IKUI_Shell and IKUI_Shell.instance
                local soft = win and type(win.page) == "function" and win:page(claimId) or nil
                if not soft or not IKST_ClaimPermissionsUI then
                    return
                end
                soft.guardSelectedSH = {
                    x = x, y = y, w = w, h = h, owner = owner,
                    canEdit = true, isMine = true,
                }
                local cfg = IKST_ClaimPermissionsUI.safehouseConfig(x, y, w, h)
                IKST_ClaimPermissionsUI.beginSoft(soft, cfg)
                if type(soft.refreshJobUI) == "function" then
                    soft:refreshJobUI(true)
                end
            end, IKST_ClaimIcons.PERMS)
        end
        IKST_SafehouseContext.addRespawnOption(sub, player, sh, x, y, w, h, owner, uiState)
        sub:addOption(IKST.text("IGUI_IKST_VehicleClaim_Info", "Owner") .. ": " .. tostring(owner or "?"), nil, nil)
        return
    end

    if not IKST_SafehouseContext.mayCreateClaim(player)
        and not (IKST_ClaimPolicy and IKST_ClaimPolicy.mayShowSafehouseClaimRequest(player)) then
        return
    end

    local staff = IKST_Access.canUseTools(player)
    local building = nil
    if type(sq.getBuilding) == "function" then
        building = sq:getBuilding()
    end
    if not staff and not IKST_Claim.isResidentialBuilding(building) then
        return
    end
    local claimMode = IKST_Claim.MODE.square
    if not staff then
        claimMode = IKST_Claim.MODE.building
    end

    local px, py, pw, ph, pz = IKST_Claim.safehousePreviewRect(
        math.floor(player:getX()), math.floor(player:getY()), player:getZ() or 0,
        IKST_ClaimRadial and IKST_ClaimRadial.DEFAULT_SH_SIZE or 13,
        claimMode, nil, nil)

    local root = context:addOption(IKST.text("IGUI_IKST_SafehouseClaim_Menu", "Safe area"))
    IKST_ClaimIcons.applyContextIcon(root, IKST_ClaimIcons.SAFEHOUSE_CLAIM)
    local sub = ISContextMenu:getNew(context)
    context:addSubMenu(root, sub)
    if IKST_SafehouseContext.mayCreateClaim(player) then
        IKST_SafehouseContext.addOption(sub, IKST.text("IGUI_IKST_Guard_SH_Claim", "Claim land here"), player, function()
            IKST.dispatchCommand(player, IKST.CMD.safehouseClaim, {
                x = math.floor(player:getX()),
                y = math.floor(player:getY()),
                z = pz or 0,
                size = IKST_ClaimRadial and IKST_ClaimRadial.DEFAULT_SH_SIZE or 13,
                w = pw,
                h = ph,
                claimMode = claimMode,
            })
        end, IKST_ClaimIcons.SAFEHOUSE_CLAIM)
    end
    if IKST_ClaimPolicy and IKST_ClaimPolicy.mayShowSafehouseClaimRequest(player) then
        IKST_SafehouseContext.addOption(sub, IKST.text("IGUI_IKST_ClaimTile_RequestHouse", "Request house"), player, function()
            IKST_JobGuard.startHouseClaimRequest(player, nil)
        end, IKST_ClaimIcons.SAFEHOUSE_CLAIM)
    end
end

if Events and Events.OnFillWorldObjectContextMenu then
    Events.OnFillWorldObjectContextMenu.Add(IKST_SafehouseContext.onFillWorldObjectContextMenu)
end

if Events and Events.OnGameStart then
    Events.OnGameStart.Add(function()
        IKST_SafehouseContext.wrapVanilla()
    end)
end
