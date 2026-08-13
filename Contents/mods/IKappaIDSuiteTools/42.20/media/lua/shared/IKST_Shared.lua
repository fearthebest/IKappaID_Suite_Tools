require "IKST_Constants"
require "IKST_Text"

function IKST.resolvePlayer(playerOrNum)
    if playerOrNum == nil then
        return getPlayer and getPlayer() or nil
    end
    if type(playerOrNum) == "number" then
        if getSpecificPlayer then
            return getSpecificPlayer(playerOrNum)
        end
        return getPlayer and getPlayer() or nil
    end
    if playerOrNum.getModData then
        return playerOrNum
    end
    return getPlayer and getPlayer() or nil
end
function IKST.getPlayerState(player)
    player = IKST.resolvePlayer(player)
    if not player or not player.getModData then
        return nil
    end
    local md = player:getModData()
    if not md then
        return nil
    end
    if not md.IKST then
        md.IKST = {
            view = IKST.VIEW.favorites,
            job = nil,
            cleanupMode = IKST.CLEANUP_MODES.removeObject,
            cleanupAction = IKST.CLEANUP_MODES.removeObject,
            cleanupScope = IKST.CLEANUP_SCOPES.single,
            cleanupCubeHalf = IKST.CUBE_PRESETS.M,
            armed = false,
            armedJob = nil,
            log = {},
            panel = {},
            cleanupRadius = IKST.RADIUS_PRESETS.M,
            lootScope = IKST.CLEANUP_SCOPES.single,
            rewindStack = {},
            painterMode = IKST.PAINTER_MODES.eyedropper,
            vehicleMode = "list",
            worldEditMode = "remove",
            gadgetMode = "area",
            favorites = {},
            recentSprites = {},
            currentPick = nil,
            settings = {
                autoPaintAfterEyedropper = true,
            },
            lastInspect = nil,
            lastBroadcast = "",
            lastView = nil,
            lastNavMode = nil,
            lastNavTool = nil,
            navMode = nil,
            navTool = nil,
            recentViews = {},
        }
    end
    if not md.IKST.log then
        md.IKST.log = {}
    end
    if not md.IKST.panel then
        md.IKST.panel = {}
    end
    if not md.IKST.favorites then
        md.IKST.favorites = {}
    end
    if not md.IKST.recentSprites then
        md.IKST.recentSprites = {}
    end
    if not md.IKST.recentViews then
        md.IKST.recentViews = {}
    end
    if not md.IKST.settings then
        md.IKST.settings = { autoPaintAfterEyedropper = true }
    end
    IKST.normalizeCleanupState(md.IKST)
    return md.IKST
end

function IKST.pushRecentSprite(player, pick)
    if not pick or not pick.sprite then
        return
    end
    local state = IKST.getPlayerState(player)
    if not state then
        return
    end
    table.insert(state.recentSprites, 1, pick)
    while #state.recentSprites > 50 do
        table.remove(state.recentSprites)
    end
end

function IKST.normalizeCleanupState(state)
    if not state then
        return
    end
    if state.cleanupAction and state.cleanupScope then
        state.cleanupMode = state.cleanupAction
        if not state.cleanupCubeHalf then
            state.cleanupCubeHalf = IKST.CUBE_PRESETS.M
        end
        state.cleanupCubeHalf = IKST.clampCubeHalf(state.cleanupCubeHalf)
        return
    end
    local legacy = state.cleanupMode or IKST.CLEANUP_MODES.removeObject
    if legacy == IKST.CLEANUP_MODES.radius then
        state.cleanupScope = IKST.CLEANUP_SCOPES.radius
        state.cleanupAction = IKST.CLEANUP_MODES.removeObject
    elseif legacy == IKST.CLEANUP_MODES.room then
        state.cleanupScope = IKST.CLEANUP_SCOPES.room
        state.cleanupAction = IKST.CLEANUP_MODES.removeObject
    elseif legacy == IKST.CLEANUP_MODES.building then
        state.cleanupScope = IKST.CLEANUP_SCOPES.building
        state.cleanupAction = IKST.CLEANUP_MODES.removeObject
    elseif legacy == IKST.CLEANUP_MODES.vegetation then
        state.cleanupAction = IKST.CLEANUP_MODES.vegetation
        state.cleanupScope = IKST.CLEANUP_SCOPES.single
    elseif legacy == IKST.CLEANUP_MODES.clearSquare then
        state.cleanupAction = IKST.CLEANUP_MODES.removeObject
        state.cleanupScope = IKST.CLEANUP_SCOPES.single
    else
        state.cleanupAction = legacy
        state.cleanupScope = IKST.CLEANUP_SCOPES.single
    end
    state.cleanupMode = state.cleanupAction
    if not state.cleanupCubeHalf then
        state.cleanupCubeHalf = IKST.CUBE_PRESETS.M
    end
    state.cleanupCubeHalf = IKST.clampCubeHalf(state.cleanupCubeHalf)
end

function IKST.getCleanupAction(state)
    IKST.normalizeCleanupState(state)
    return state.cleanupAction
end

function IKST.getCleanupScope(state)
    IKST.normalizeCleanupState(state)
    return state.cleanupScope
end

function IKST.actionToCommand(action)
    if action == IKST.CLEANUP_MODES.removeTile then
        return IKST.CMD.cleanupTile
    end
    if action == IKST.CLEANUP_MODES.clearSquare then
        return IKST.CMD.cleanupSquare
    end
    if action == IKST.CLEANUP_MODES.inspect then
        return IKST.CMD.inspectSquare
    end
    return IKST.CMD.cleanupObject
end

function IKST.cleanupActionLabel(action)
    if action == IKST.CLEANUP_MODES.removeTile then
        return IKST.text("IGUI_IKST_Mode_RemoveTile", "Remove tile")
    end
    if action == IKST.CLEANUP_MODES.vegetation then
        return IKST.text("IGUI_IKST_Mode_Vegetation", "Remove vegetation")
    end
    return IKST.text("IGUI_IKST_Mode_RemoveObject", "Remove object")
end

function IKST.cleanupScopeLabel(scope, state)
    if scope == IKST.CLEANUP_SCOPES.cube then
        local edge = IKST.cubeEdgeLength(state and state.cleanupCubeHalf or IKST.CUBE_PRESETS.M)
        return IKST.text("IGUI_IKST_Scope_Cube", "Cube") .. " " .. edge .. "³"
    end
    if scope == IKST.CLEANUP_SCOPES.radius then
        local radius = state and state.cleanupRadius or IKST.RADIUS_PRESETS.M
        return IKST.text("IGUI_IKST_Scope_Radius", "Radius") .. " " .. tostring(radius)
    end
    if scope == IKST.CLEANUP_SCOPES.room then
        return IKST.text("IGUI_IKST_Scope_Room", "Room")
    end
    if scope == IKST.CLEANUP_SCOPES.building then
        return IKST.text("IGUI_IKST_Scope_Building", "Building")
    end
    if scope == IKST.CLEANUP_SCOPES.cell then
        return IKST.text("IGUI_IKST_Scope_Cell", "Whole cell")
    end
    return IKST.text("IGUI_IKST_Scope_Single", "Single")
end

function IKST.cubeEdgeLength(halfExtent)
    halfExtent = IKST.clampCubeHalf(halfExtent)
    return (halfExtent * 2) + 1
end

function IKST.pushLog(player, line, kind)
    local state = IKST.getPlayerState(player)
    if not state then
        return
    end
    local entry = tostring(line or "")
    if kind and kind ~= "" then
        entry = { text = entry, kind = tostring(kind) }
    end
    table.insert(state.log, 1, entry)
    while #state.log > 20 do
        table.remove(state.log)
    end
    if type(isClient) == "function" and isClient()
        and IKST_ActionLogWindow and type(IKST_ActionLogWindow.refreshForPlayer) == "function" then
        IKST_ActionLogWindow.refreshForPlayer(player)
    end
end

function IKST.isModEnabled()
    if not SandboxVars or not SandboxVars.IKappaIDSuiteTools then
        return true
    end
    local v = SandboxVars.IKappaIDSuiteTools.EnableMod
    if v == nil then
        return true
    end
    return v == true
end

-- Hub dashboard requires IKappaID_UI (mod.info require=). Dedicated Mods= must include it.
function IKST.uiFrameworkLoaded()
    if type(IKUI_Config) == "table" then
        return true
    end
    if type(getActivatedMods) ~= "function" then
        return false
    end
    local mods = getActivatedMods()
    if not mods or type(mods.contains) ~= "function" then
        return false
    end
    return mods:contains("IKappaID_UI") == true or mods:contains("\\IKappaID_UI") == true
end

function IKST.getMaxCleanupRadius()
    local sv = SandboxVars and SandboxVars.IKappaIDSuiteToolsTiles
    if sv and sv.MaxCleanupRadius then
        return sv.MaxCleanupRadius
    end
    if SandboxVars and SandboxVars.IKappaIDSuiteTools and SandboxVars.IKappaIDSuiteTools.MaxCleanupRadius then
        return SandboxVars.IKappaIDSuiteTools.MaxCleanupRadius
    end
    return 50
end

function IKST.getMaxPaintRadius()
    local sv = SandboxVars and SandboxVars.IKappaIDSuiteToolsTiles
    if sv and sv.MaxPaintRadius then
        return sv.MaxPaintRadius
    end
    return 25
end

function IKST.vehicleShowAllClaims()
    local sv = SandboxVars and SandboxVars.IKappaIDSuiteToolsVehicles
    return sv and sv.VehicleShowAllClaims == true
end

function IKST.vehicleClaimRequireKeys()
    local sv = SandboxVars and SandboxVars.IKappaIDSuiteToolsVehicles
    return sv and sv.VehicleClaimRequireKeys == true
end

function IKST.getVehicleListRadius()
    local sv = SandboxVars and SandboxVars.IKappaIDSuiteToolsVehicles
    if sv and sv.VehicleListRadius then
        return sv.VehicleListRadius
    end
    if SandboxVars and SandboxVars.IKappaIDSuiteTools and SandboxVars.IKappaIDSuiteTools.VehicleListRadius then
        return SandboxVars.IKappaIDSuiteTools.VehicleListRadius
    end
    return 30
end

function IKST.clampRadius(r)
    r = tonumber(r) or IKST.RADIUS_PRESETS.M
    return math.max(1, math.min(math.floor(r), IKST.getMaxCleanupRadius()))
end

function IKST.getMaxCleanupCubeHalf()
    local sv = SandboxVars and SandboxVars.IKappaIDSuiteToolsTiles
    if sv and sv.MaxCleanupCubeHalf then
        return sv.MaxCleanupCubeHalf
    end
    return 10
end

function IKST.clampCubeHalf(h)
    h = tonumber(h) or IKST.CUBE_PRESETS.M
    return math.max(0, math.min(math.floor(h), IKST.getMaxCleanupCubeHalf()))
end

function IKST.getVehicleNearRadius()
    if SandboxVars and SandboxVars.IKappaIDSuiteTools and SandboxVars.IKappaIDSuiteTools.VehicleNearRadius then
        return SandboxVars.IKappaIDSuiteTools.VehicleNearRadius
    end
    return 12
end

function IKST.parseNumber(text, fallback)
    fallback = fallback or 0
    if text == nil then
        return fallback
    end
    if type(text) ~= "string" then
        text = tostring(text)
    end
    text = string.gsub(text, "^%s*(.-)%s*$", "%1")
    if text == "" then
        return fallback
    end
    -- Digits only — never pass free-form UI text to tonumber (Kahlua can throw).
    local matched = string.match(text, "^([%-%+]?%d+%.?%d*)")
    if not matched then
        return fallback
    end
    local n = tonumber(matched)
    if n == nil then
        return fallback
    end
    return n
end

-- Parse money/qty UI text (strip $/, keep leading number only).
function IKST.parseAmount(text)
    if text == nil then
        return 0
    end
    if type(text) ~= "string" then
        text = tostring(text)
    end
    text = string.gsub(text, "^%s*(.-)%s*$", "%1")
    if text == "" then
        return 0
    end
    text = string.gsub(text, "[$,]", "")
    local matched = string.match(text, "^([%-%+]?%d+%.?%d*)")
    if not matched then
        return 0
    end
    local n = tonumber(matched)
    if n == nil then
        return 0
    end
    return math.floor(n)
end

function IKST.isVegetationObject(obj, square)
    if not obj or not obj.getSprite then
        return false
    end
    local floor = square and type(square.getFloor) == "function" and square:getFloor()
    if floor and obj == floor then
        return false
    end
    if instanceof(obj, "IsoTree") or instanceof(obj, "IsoBush") then
        return true
    end
    local sprite = obj:getSprite()
    if not sprite or not sprite.getName then
        return false
    end
    local name = string.lower(sprite:getName() or "")
    if name == "" then
        return false
    end
    if string.find(name, "floors_", 1, true) or string.find(name, "street", 1, true)
        or string.find(name, "road", 1, true) or string.find(name, "pavement", 1, true)
        or string.find(name, "asphalt", 1, true) or string.find(name, "sidewalk", 1, true)
        or string.find(name, "blends_grassoverlays", 1, true)
        or string.find(name, "blends_natural", 1, true) then
        return false
    end
    if string.find(name, "vegetation_", 1, true) then
        return true
    end
    if string.find(name, "tree", 1, true) or string.find(name, "bush", 1, true) then
        return true
    end
    if string.find(name, "grass", 1, true) and not string.find(name, "glass", 1, true) then
        return true
    end
    return false
end

function IKST.collectVegetationOnSquare(square)
    local result = {}
    local seen = {}
    if not square then
        return result
    end
    local function add(obj)
        if obj and not seen[obj] then
            seen[obj] = true
            result[#result + 1] = obj
        end
    end
    if square.getTree then
        add(square:getTree())
    end
    if square.getBush then
        add(square:getBush())
    end
    if square.getBushes then
        local bushes = square:getBushes()
        if bushes and bushes.size then
            for i = 0, bushes:size() - 1 do
                add(bushes:get(i))
            end
        end
    end
    local objects = type(square.getObjects) == "function" and square:getObjects()
    if objects then
        for i = 0, objects:size() - 1 do
            local obj = objects:get(i)
            if IKST.isVegetationObject(obj, square) then
                add(obj)
            end
        end
    end
    return result
end

function IKST.isMultiplayerSession()
    return type(isMultiplayer) == "function" and isMultiplayer()
end

-- God / Invisible / Ghost / NoClip need engine PlayerCheats.
-- Available in MP always; in SP only when launched with -debug.
function IKST.engineStaffModesAvailable()
    if IKST.isMultiplayerSession() then
        return true
    end
    if type(getDebug) == "function" and getDebug() then
        return true
    end
    if type(isDebugEnabled) == "function" and isDebugEnabled() then
        return true
    end
    return false
end

-- Remote MP client JVM only (not listen host, not integrated SP server JVM).
function IKST.isRemoteClient()
    return type(isClient) == "function" and isClient()
        and type(isServer) == "function" and not isServer()
end

-- IKFRVP-style gate: remote MP clients execute server vehicle mirror payloads only.
function IKST.clientExecutesServerMirror()
    if IKST_Authority and IKST_Authority.usesMirrorExecuteClient then
        return IKST_Authority.usesMirrorExecuteClient()
    end
    return IKST.isRemoteClient()
end

-- MP listen host runs client + server JVMs; world edits must hit the server JVM.
function IKST.isListenHostClient()
    return IKST.isMultiplayerSession()
        and type(isClient) == "function" and isClient()
        and type(isServer) == "function" and isServer()
end

-- Integrated SP / listen host: server sendServerCommand may not loop to client handlers.
IKST._clientCommandHandlers = IKST._clientCommandHandlers or {}

function IKST.registerClientCommandHandler(handler)
    if type(handler) == "function" then
        IKST._clientCommandHandlers[#IKST._clientCommandHandlers + 1] = handler
    end
end

-- True when `player` is a local IsoPlayer on this JVM (SP or listen-host local).
function IKST.isLocalPlayerObj(player)
    if not player then
        return false
    end
    if type(getSpecificPlayer) == "function" then
        for i = 0, 3 do
            local p = getSpecificPlayer(i)
            if p == player then
                return true
            end
        end
    end
    return type(getPlayer) == "function" and getPlayer() == player
end

function IKST.deliverClientCommand(player, command, args)
    args = args or {}
    if type(IKST_Debug) == "table" and IKST_Debug.logNet then
        IKST_Debug.logNet("server->client", command, player, args, "")
    end
    local mp = IKST.isMultiplayerSession and IKST.isMultiplayerSession()
    local isLocal = (not player) or IKST.isLocalPlayerObj(player)

    -- Remote MP clients must get a real packet. Old path called local handlers for
    -- every forEachOnline target on listen host, so remotes waited on slow GameTime sync.
    if mp and player and not isLocal and type(sendServerCommand) == "function" then
        sendServerCommand(player, IKST.MODULE, command, args)
        return
    end

    if #IKST._clientCommandHandlers > 0 and not IKST.isRemoteClient() then
        for _, handler in ipairs(IKST._clientCommandHandlers) do
            handler(IKST.MODULE, command, args)
        end
        return
    end

    if type(sendServerCommand) == "function" and player then
        sendServerCommand(player, IKST.MODULE, command, args)
    end
end

function IKST.runsOnServerJvm()
    return type(isServer) == "function" and isServer()
end

-- IKFRVP trunk pattern: remote MP + listen-host client JVMs never mutate synced world state.
function IKST.mayMutateWorldState()
    if IKST_Authority and IKST_Authority.mayMutateWorldState then
        return IKST_Authority.mayMutateWorldState()
    end
    if IKST.isRemoteClient and IKST.isRemoteClient() then
        return false
    end
    if IKST.isListenHostClient and IKST.isListenHostClient() then
        return false
    end
    if IKST.isMultiplayerSession and IKST.isMultiplayerSession() then
        return IKST.runsOnServerJvm and IKST.runsOnServerJvm()
    end
    return true
end

function IKST.distance2d(x1, y1, x2, y2)
    local dx = (tonumber(x1) or 0) - (tonumber(x2) or 0)
    local dy = (tonumber(y1) or 0) - (tonumber(y2) or 0)
    return math.sqrt(dx * dx + dy * dy)
end

function IKST.runServerCommand(player, command, args)
    if IKST_Lifecycle and not IKST_Lifecycle.isWorldReady() then
        if player and IKST.notify then
            IKST.notify(player, "world loading", false)
        end
        return
    end
    if not IKST_Server then
        require "IKST_Server"
    end
    if IKST_Server and IKST_Server.handleCommand then
        IKST_Server.handleCommand(IKST.MODULE, command, player, args)
    end
end

function IKST.isCoopHostPlayer(player)
    if not isCoopHost or not isCoopHost() then
        return false
    end
    player = IKST.resolvePlayer(player)
    return player ~= nil and type(player.isLocalPlayer) == "function" and player:isLocalPlayer()
end

function IKST.dispatchCommand(player, command, args)
    player = IKST.resolvePlayer(player)
    if not player or not command then
        return
    end
    args = args or {}
    if type(IKST_Debug) == "table" and IKST_Debug.logNet then
        IKST_Debug.logNet("client->dispatch", command, player, args, "")
    end
    -- MP listen host: route through authoritative server JVM (must run before co-op shortcut).
    if IKST.isListenHostClient() then
        if IKST.enqueueClientCommand then
            IKST.enqueueClientCommand(player, command, args)
            return
        end
        if sendClientCommand and player then
            sendClientCommand(player, IKST.MODULE, command, args)
            return
        end
    end
    -- Integrated co-op host (single JVM): sendClientCommand does not loop to server handlers.
    if IKST.isCoopHostPlayer(player) then
        IKST.runServerCommand(player, command, args)
        return
    end
    -- Integrated SP or dedicated server JVM: run world edits directly.
    if not IKST.isRemoteClient() then
        IKST.runServerCommand(player, command, args)
        return
    end
    if IKST.enqueueClientCommand then
        IKST.enqueueClientCommand(player, command, args)
        return
    end
    if sendClientCommand and player then
        sendClientCommand(player, IKST.MODULE, command, args)
    end
end

function IKST.shouldNotifyResult(mode)
    if not mode then
        return true
    end
    if mode == IKST.CMD.paintPlace or mode == IKST.CMD.paintRemove then
        return false
    end
    if mode == IKST.CMD.cleanupObject or mode == IKST.CMD.cleanupTile or mode == IKST.CMD.cleanupSquare then
        return false
    end
    if mode == IKST.CMD.vehicleClaimList or mode == IKST.CMD.safehouseList then
        return false
    end
    if mode == IKST.CMD.lootRepopulateZone or mode == IKST.CMD.lootRepopulateContainer then
        return false
    end
    return true
end

function IKST.formatServerResult(message, args)
    local msg = tostring(message or "")
    if IKST_Policy and IKST_Policy.formatDenyMessage then
        local policyMsg = IKST_Policy.formatDenyMessage(msg)
        if policyMsg and policyMsg ~= "" then
            msg = policyMsg
        end
    end
    if IKST_Economy and IKST_Economy.formatResultMessage then
        msg = IKST_Economy.formatResultMessage(msg, args)
    end
    if IKST_LootOps and IKST_LootOps.formatResultMessage then
        msg = IKST_LootOps.formatResultMessage(msg, args)
    end
    if IKST_VehicleSnapshot and IKST_VehicleSnapshot.formatResultMessage then
        msg = IKST_VehicleSnapshot.formatResultMessage(msg)
    end
    return msg
end

function IKST.notify(player, message, ok)
    player = IKST.resolvePlayer(player)
    if not player or not HaloTextHelper or not HaloTextHelper.addText then
        return
    end
    local text = tostring(message)
    -- B42.19: addText(player, text, color) is invalid; use separator + RGB.
    if ok then
        HaloTextHelper.addText(player, text, "", 0, 255, 0)
    else
        HaloTextHelper.addText(player, text, "", 255, 0, 0)
    end
end

