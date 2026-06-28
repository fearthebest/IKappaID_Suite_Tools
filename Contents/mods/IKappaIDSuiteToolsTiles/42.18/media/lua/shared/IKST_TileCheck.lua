-- Tile / object protection checks.

require "IKST_Shared"
require "IKST_TileProtect"
require "IKST_WorldRules"
require "IKST_Access"

IKST_TileCheck = IKST_TileCheck or {}

function IKST_TileCheck.spriteNameOf(object)
    if not object or not object.getSprite then
        return nil
    end
    local sprite = object:getSprite()
    if sprite and sprite.getName then
        return sprite:getName()
    end
    return nil
end

function IKST_TileCheck.squareOf(object)
    if not object then
        return nil
    end
    if object.getSquare then
        return object:getSquare()
    end
    return nil
end

function IKST_TileCheck.isProtected(object, mode, player)
    if not object then
        return false
    end
    if player and IKST_Access.canUseTools(player) then
        return false
    end

    local rules = IKST_WorldRules.getRules()
    local spriteName = IKST_TileCheck.spriteNameOf(object) or ""
    local sq = IKST_TileCheck.squareOf(object)

    if IKST_WorldRules.isSpriteBlacklisted(spriteName) then
        return true
    end

    if sq and IKST_TileProtect.isTileProtected(sq:getX(), sq:getY(), sq:getZ()) then
        return true
    end

    if mode == "pickup" and rules.disablePickup then
        return true
    end
    if mode ~= "pickup" and rules.disableDestroy then
        return true
    end

    return false
end

function IKST_TileCheck.notifyBlocked(player, messageKey, fallback)
    if player then
        IKST.notify(player, IKST.text(messageKey, fallback), false)
    end
end
