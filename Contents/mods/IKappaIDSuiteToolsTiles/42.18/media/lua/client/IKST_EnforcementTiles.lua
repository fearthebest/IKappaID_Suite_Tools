-- Client enforcement for tile protection (vanilla destroy / move / pickup paths).
-- Server sets protect/readonly rules; clients block vanilla UI actions only.
--
-- B42.20: ISDestroyCursor / ISMoveableCursor live under media/lua/server/BuildingObjects.
-- Client require of those paths can throw — never require them. Wrap only if globals exist.

if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "IKST_Shared"
require "IKST_Access"
require "IKST_TileCheck"

IKST_EnforcementTiles = IKST_EnforcementTiles or {}

local RETRY_MAX = 40
local RETRY_INTERVAL_MS = 500

function IKST_EnforcementTiles.alreadyWrapped(table, key)
    if not table then
        return true
    end
    local flag = "IKST_enforcement_tiles_" .. key
    if table[flag] then
        return true
    end
    table[flag] = true
    return false
end

function IKST_EnforcementTiles.notifySafehouseDenied(player)
    if not player then
        return
    end
    IKST.notify(player, IKST.text("IGUI_IKST_Claim_SafehouseDenied", "This safe area is claimed by another player."), false)
end

function IKST_EnforcementTiles.safehouseBlocked(character, square, action)
    if not character or not square or not action then
        return false
    end
    if IKST_Access and IKST_Access.canUseTools and IKST_Access.canUseTools(character) then
        return false
    end
    if not IKST_SafehouseClaim or not IKST_SafehouseClaim.canAtSquare then
        return false
    end
    if IKST_SafehouseClaim.canAtSquare(character, square, action) == false then
        IKST_EnforcementTiles.notifySafehouseDenied(character)
        return true
    end
    return false
end

function IKST_EnforcementTiles.objectBlocked(character, object, mode)
    if not object then
        return false
    end
    if IKST_TileCheck and IKST_TileCheck.blocksVanillaWorldEdit(object, mode, character) then
        if mode == "pickup" then
            IKST_TileCheck.notifyBlocked(character, "IGUI_IKST_Guard_PickupProtected", "Pickup blocked.")
        else
            IKST_TileCheck.notifyDestroyBlocked(character, object)
        end
        return true
    end
    local sq = object.getSquare and object:getSquare() or nil
    local claimAction = mode == "pickup" and "loot" or "destroy"
    if sq and IKST_EnforcementTiles.safehouseBlocked(character, sq, claimAction) then
        return true
    end
    return false
end

function IKST_EnforcementTiles.wrapDestroyCursor()
    if not ISDestroyCursor then
        return false
    end
    local wrapped = false
    if type(ISDestroyCursor.canDestroy) == "function" and not IKST_EnforcementTiles.alreadyWrapped(ISDestroyCursor, "canDestroy") then
        local vanillaCanDestroy = ISDestroyCursor.canDestroy
        ISDestroyCursor.canDestroy = function(self, object)
            if IKST_EnforcementTiles.objectBlocked(self and self.character, object, "destroy") then
                return false
            end
            return vanillaCanDestroy(self, object)
        end
        wrapped = true
    end
    if type(ISDestroyCursor.isValid) == "function" and not IKST_EnforcementTiles.alreadyWrapped(ISDestroyCursor, "isValid") then
        local vanillaIsValid = ISDestroyCursor.isValid
        ISDestroyCursor.isValid = function(self, square)
            local object = self and self.currentObject or nil
            if object and IKST_EnforcementTiles.objectBlocked(self.character, object, "destroy") then
                return false
            end
            return vanillaIsValid(self, square)
        end
        wrapped = true
    end
    return wrapped or (ISDestroyCursor.IKST_enforcement_tiles_canDestroy == true)
end

function IKST_EnforcementTiles.wrapMoveableCursor()
    if not ISMoveableCursor or type(ISMoveableCursor.isValid) ~= "function" then
        return false
    end
    if IKST_EnforcementTiles.alreadyWrapped(ISMoveableCursor, "isValid") then
        return true
    end
    local vanillaIsValid = ISMoveableCursor.isValid
    ISMoveableCursor.isValid = function(self, square)
        local object = self and self.cacheObject or nil
        if object and IKST_EnforcementTiles.objectBlocked(self.character, object, "pickup") then
            if self.colorMod then
                self.colorMod = { r = 1, g = 0, b = 0 }
            end
            return false
        end
        return vanillaIsValid(self, square)
    end
    return true
end

function IKST_EnforcementTiles.wrapMoveablesAction()
    if not ISMoveablesAction or type(ISMoveablesAction.isValid) ~= "function" then
        return false
    end
    if IKST_EnforcementTiles.alreadyWrapped(ISMoveablesAction, "isValid") then
        return true
    end
    local vanillaIsValid = ISMoveablesAction.isValid
    ISMoveablesAction.isValid = function(self)
        local object = self and self.moveProps and self.moveProps.object or nil
        if object and IKST_EnforcementTiles.objectBlocked(self.character, object, "pickup") then
            return false
        end
        return vanillaIsValid(self)
    end
    return true
end

function IKST_EnforcementTiles.wrapMovablePickup()
    if not ISMoveableSpriteTool or type(ISMoveableSpriteTool.walkTo) ~= "function" then
        return false
    end
    if IKST_EnforcementTiles.alreadyWrapped(ISMoveableSpriteTool, "walkTo") then
        return true
    end
    local vanillaWalkTo = ISMoveableSpriteTool.walkTo
    ISMoveableSpriteTool.walkTo = function(self, obj, ...)
        if IKST_EnforcementTiles.objectBlocked(self and self.character, obj, "pickup") then
            return false
        end
        return vanillaWalkTo(self, obj, ...)
    end
    return true
end

function IKST_EnforcementTiles.wrapDestroyTimedActions()
    local wrapped = false
    if ISDestroyStuffAction and type(ISDestroyStuffAction.isValid) == "function" then
        if not IKST_EnforcementTiles.alreadyWrapped(ISDestroyStuffAction, "isValid") then
            local vanillaDestroyValid = ISDestroyStuffAction.isValid
            ISDestroyStuffAction.isValid = function(self)
                if self and self.item and IKST_EnforcementTiles.objectBlocked(self.character, self.item, "destroy") then
                    return false
                end
                return vanillaDestroyValid(self)
            end
            wrapped = true
        else
            wrapped = true
        end
    end
    if ISDismantleAction and type(ISDismantleAction.isValid) == "function" then
        if not IKST_EnforcementTiles.alreadyWrapped(ISDismantleAction, "isValid") then
            local vanillaDismantleValid = ISDismantleAction.isValid
            ISDismantleAction.isValid = function(self)
                if self and self.thumpable and IKST_EnforcementTiles.objectBlocked(self.character, self.thumpable, "destroy") then
                    return false
                end
                return vanillaDismantleValid(self)
            end
            wrapped = true
        else
            wrapped = true
        end
    end
    return wrapped
end

-- Prefer shared Moveables path only (safe on client). Never require server BuildingObjects.
function IKST_EnforcementTiles.loadSafeSharedClasses()
    if not ISMoveablesAction then
        require "Moveables/ISMoveablesAction"
    end
end

function IKST_EnforcementTiles.applyWraps()
    IKST_EnforcementTiles.loadSafeSharedClasses()
    local destroyOk = IKST_EnforcementTiles.wrapDestroyCursor()
    local moveOk = IKST_EnforcementTiles.wrapMoveableCursor()
    IKST_EnforcementTiles.wrapMoveablesAction()
    IKST_EnforcementTiles.wrapDestroyTimedActions()
    IKST_EnforcementTiles.wrapMovablePickup()
    return destroyOk, moveOk
end

function IKST_EnforcementTiles.init()
    if type(isClient) == "function" and not isClient() then
        return
    end
    if not IKST_SafehouseClaim then
        require "IKST_SafehouseClaim"
    end
    local destroyOk, moveOk = IKST_EnforcementTiles.applyWraps()
    if destroyOk and moveOk then
        IKST_EnforcementTiles._wrapsReady = true
        return
    end
    -- Cursor globals may load later on B42.20 — retry briefly without hard-requiring server Lua.
    if IKST_EnforcementTiles._retryStarted then
        return
    end
    IKST_EnforcementTiles._retryStarted = true
    IKST_EnforcementTiles._retryCount = 0
    IKST_EnforcementTiles._retryNextMs = 0
    if Events and Events.OnTick then
        Events.OnTick.Add(IKST_EnforcementTiles.onRetryTick)
    end
end

function IKST_EnforcementTiles.onRetryTick()
    if IKST_EnforcementTiles._wrapsReady then
        if Events and Events.OnTick then
            Events.OnTick.Remove(IKST_EnforcementTiles.onRetryTick)
        end
        return
    end
    local now = getTimestampMs and getTimestampMs() or 0
    if now < (IKST_EnforcementTiles._retryNextMs or 0) then
        return
    end
    IKST_EnforcementTiles._retryNextMs = now + RETRY_INTERVAL_MS
    IKST_EnforcementTiles._retryCount = (IKST_EnforcementTiles._retryCount or 0) + 1

    local destroyOk, moveOk = IKST_EnforcementTiles.applyWraps()
    if destroyOk and moveOk then
        IKST_EnforcementTiles._wrapsReady = true
        if Events and Events.OnTick then
            Events.OnTick.Remove(IKST_EnforcementTiles.onRetryTick)
        end
        return
    end

    if (IKST_EnforcementTiles._retryCount or 0) >= RETRY_MAX then
        if Events and Events.OnTick then
            Events.OnTick.Remove(IKST_EnforcementTiles.onRetryTick)
        end
        print("[IKST] EnforcementTiles: cursor wraps incomplete after retries (destroy="
            .. tostring(ISDestroyCursor ~= nil) .. " moveable=" .. tostring(ISMoveableCursor ~= nil)
            .. "). Tile protect still uses server authority; client UI block may be partial.")
    end
end

if Events and Events.OnGameStart then
    Events.OnGameStart.Add(IKST_EnforcementTiles.init)
end
if Events and Events.OnCreatePlayer then
    Events.OnCreatePlayer.Add(function()
        if not IKST_EnforcementTiles._wrapsReady then
            IKST_EnforcementTiles.init()
        end
    end)
end
