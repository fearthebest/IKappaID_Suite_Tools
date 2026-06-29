-- Client enforcement for tile protection (sledge destroy, movable pickup).
-- Chains vanilla cursor/tool methods; rules live in IKST_TileCheck / IKST_SafehouseClaim.
-- Maintainer notes: docs/ENFORCEMENT.md (not shipped in Workshop tree).

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

function IKST_EnforcementTiles.wrapDestroyCursor()
    if not ISDestroyCursor or not ISDestroyCursor.canDestroy then
        return
    end
    if IKST_EnforcementTiles.alreadyWrapped(ISDestroyCursor, "canDestroy") then
        return
    end
    local vanillaCanDestroy = ISDestroyCursor.canDestroy
    ISDestroyCursor.canDestroy = function(self, object)
        if object and IKST_TileCheck and IKST_TileCheck.isProtected(object, "destroy", self and self.character) then
            IKST_TileCheck.notifyDestroyBlocked(self.character, object)
            return false
        end
        local sq = object and object.getSquare and object:getSquare() or nil
        if sq and IKST_EnforcementTiles.safehouseBlocked(self and self.character, sq, "destroy") then
            return false
        end
        return vanillaCanDestroy(self, object)
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
        if obj and IKST_TileCheck and IKST_TileCheck.isProtected(obj, "pickup", self and self.character) then
            IKST_TileCheck.notifyBlocked(self.character, "IGUI_IKST_Guard_PickupProtected", "Pickup blocked.")
            return false
        end
        local sq = obj and obj.getSquare and obj:getSquare() or nil
        if sq and IKST_EnforcementTiles.safehouseBlocked(self and self.character, sq, "loot") then
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
                if self and self.item and IKST_TileCheck and IKST_TileCheck.isProtected(self.item, "destroy", self.character) then
                    IKST_TileCheck.notifyDestroyBlocked(self.character, self.item)
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
                if self and self.thumpable and IKST_TileCheck and IKST_TileCheck.isProtected(self.thumpable, "destroy", self.character) then
                    IKST_TileCheck.notifyDestroyBlocked(self.character, self.thumpable)
                    return false
                end
                return vanillaDismantleValid(self)
            end
        end
    end
end

function IKST_EnforcementTiles.init()
    if type(isClient) == "function" and not isClient() then
        return
    end
    if not IKST_SafehouseClaim then
        require "IKST_SafehouseClaim"
    end
    IKST_EnforcementTiles.wrapDestroyCursor()
    IKST_EnforcementTiles.wrapDestroyTimedActions()
    IKST_EnforcementTiles.wrapMovablePickup()
end

if Events and Events.OnGameBoot then
    Events.OnGameBoot.Add(IKST_EnforcementTiles.init)
end
if Events and Events.OnGameStart then
    Events.OnGameStart.Add(IKST_EnforcementTiles.init)
end
