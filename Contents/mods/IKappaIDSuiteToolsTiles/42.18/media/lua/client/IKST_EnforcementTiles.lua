-- Client enforcement for tile protection (vanilla destroy / move / pickup paths).
-- Server sets protect/readonly rules; clients block vanilla UI actions only.

if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "IKST_Shared"
require "IKST_Access"
require "IKST_TileCheck"

IKST_EnforcementTiles = IKST_EnforcementTiles or {}

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
        return
    end
    if ISDestroyCursor.canDestroy and not IKST_EnforcementTiles.alreadyWrapped(ISDestroyCursor, "canDestroy") then
        local vanillaCanDestroy = ISDestroyCursor.canDestroy
        ISDestroyCursor.canDestroy = function(self, object)
            if IKST_EnforcementTiles.objectBlocked(self and self.character, object, "destroy") then
                return false
            end
            return vanillaCanDestroy(self, object)
        end
    end
    if ISDestroyCursor.isValid and not IKST_EnforcementTiles.alreadyWrapped(ISDestroyCursor, "isValid") then
        local vanillaIsValid = ISDestroyCursor.isValid
        ISDestroyCursor.isValid = function(self, square)
            local object = self and self.currentObject or nil
            if object and IKST_EnforcementTiles.objectBlocked(self.character, object, "destroy") then
                return false
            end
            return vanillaIsValid(self, square)
        end
    end
end

function IKST_EnforcementTiles.wrapMoveableCursor()
    if not ISMoveableCursor or not ISMoveableCursor.isValid then
        return
    end
    if IKST_EnforcementTiles.alreadyWrapped(ISMoveableCursor, "isValid") then
        return
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
end

function IKST_EnforcementTiles.wrapMoveablesAction()
    if not ISMoveablesAction or not ISMoveablesAction.isValid then
        return
    end
    if IKST_EnforcementTiles.alreadyWrapped(ISMoveablesAction, "isValid") then
        return
    end
    local vanillaIsValid = ISMoveablesAction.isValid
    ISMoveablesAction.isValid = function(self)
        local object = self and self.moveProps and self.moveProps.object or nil
        if object and IKST_EnforcementTiles.objectBlocked(self.character, object, "pickup") then
            return false
        end
        return vanillaIsValid(self)
    end
end

function IKST_EnforcementTiles.wrapMovablePickup()
    if not ISMoveableSpriteTool or not ISMoveableSpriteTool.walkTo then
        return
    end
    if IKST_EnforcementTiles.alreadyWrapped(ISMoveableSpriteTool, "walkTo") then
        return
    end
    local vanillaWalkTo = ISMoveableSpriteTool.walkTo
    ISMoveableSpriteTool.walkTo = function(self, obj, ...)
        if IKST_EnforcementTiles.objectBlocked(self and self.character, obj, "pickup") then
            return false
        end
        return vanillaWalkTo(self, obj, ...)
    end
end

function IKST_EnforcementTiles.wrapDestroyTimedActions()
    if ISDestroyStuffAction and ISDestroyStuffAction.isValid then
        if not IKST_EnforcementTiles.alreadyWrapped(ISDestroyStuffAction, "isValid") then
            local vanillaDestroyValid = ISDestroyStuffAction.isValid
            ISDestroyStuffAction.isValid = function(self)
                if self and self.item and IKST_EnforcementTiles.objectBlocked(self.character, self.item, "destroy") then
                    return false
                end
                return vanillaDestroyValid(self)
            end
        end
    end
    if ISDismantleAction and ISDismantleAction.isValid then
        if not IKST_EnforcementTiles.alreadyWrapped(ISDismantleAction, "isValid") then
            local vanillaDismantleValid = ISDismantleAction.isValid
            ISDismantleAction.isValid = function(self)
                if self and self.thumpable and IKST_EnforcementTiles.objectBlocked(self.character, self.thumpable, "destroy") then
                    return false
                end
                return vanillaDismantleValid(self)
            end
        end
    end
end

function IKST_EnforcementTiles.loadVanillaClasses()
    if not ISDestroyCursor then
        require "BuildingObjects/ISDestroyCursor"
    end
    if not ISMoveableCursor then
        require "BuildingObjects/ISMoveableCursor"
    end
    if not ISMoveablesAction then
        require "Moveables/ISMoveablesAction"
    end
end

function IKST_EnforcementTiles.init()
    if type(isClient) == "function" and not isClient() then
        return
    end
    if not IKST_SafehouseClaim then
        require "IKST_SafehouseClaim"
    end
    IKST_EnforcementTiles.loadVanillaClasses()
    IKST_EnforcementTiles.wrapDestroyCursor()
    IKST_EnforcementTiles.wrapMoveableCursor()
    IKST_EnforcementTiles.wrapMoveablesAction()
    IKST_EnforcementTiles.wrapDestroyTimedActions()
    IKST_EnforcementTiles.wrapMovablePickup()
end

if Events and Events.OnGameStart then
    Events.OnGameStart.Add(IKST_EnforcementTiles.init)
end
