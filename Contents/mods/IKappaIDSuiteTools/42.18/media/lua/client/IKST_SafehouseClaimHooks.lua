if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "IKST_Shared"
require "IKST_SafehouseClaim"
require "IKST_Access"

IKST_SafehouseClaimHooks = IKST_SafehouseClaimHooks or {}

function IKST_SafehouseClaimHooks.notifyDenied(player)
    if player then
        IKST.notify(player, IKST.text("IGUI_IKST_Claim_SafehouseDenied", "This safe area is claimed by another player."), false)
    end
end

function IKST_SafehouseClaimHooks.wrapIsValid(classTable, action)
    if not classTable or not classTable.isValid or classTable.IKST_sh_wrapped then
        return
    end
    classTable.IKST_sh_wrapped = true
    local vanilla = classTable.isValid
    classTable.isValid = function(self)
        if self and self.character and action then
            local sq = nil
            if self.square then
                sq = self.square
            elseif self.object and self.object.getSquare then
                sq = self.object:getSquare()
            elseif self.character.getCurrentSquare then
                sq = self.character:getCurrentSquare()
            end
            if sq and IKST_SafehouseClaim.canAtSquare(self.character, sq, action) == false then
                IKST_SafehouseClaimHooks.notifyDenied(self.character)
                if self.stop then
                    self:stop()
                end
                return false
            end
        end
        return vanilla(self)
    end
end

function IKST_SafehouseClaimHooks.wrapBuildActions()
    if IKST_SafehouseClaimHooks.buildWrapped then
        return
    end
    IKST_SafehouseClaimHooks.buildWrapped = true
    local buildClasses = {
        "ISBuildAction",
        "ISWoodenWall",
        "ISWoodenDoor",
        "ISWoodenStairs",
        "ISWoodenFloor",
        "ISBarricadeAction",
    }
    for _, className in ipairs(buildClasses) do
        local classTable = _G[className]
        if classTable then
            IKST_SafehouseClaimHooks.wrapIsValid(classTable, "build")
        end
    end
    local doorClasses = {
        "ISOpenCloseDoor",
        "ISOpenCloseWindow",
    }
    for _, className in ipairs(doorClasses) do
        local classTable = _G[className]
        if classTable then
            IKST_SafehouseClaimHooks.wrapIsValid(classTable, "doors")
        end
    end
end

function IKST_SafehouseClaimHooks.init()
    IKST_SafehouseClaimHooks.wrapBuildActions()
end

if Events and Events.OnGameStart then
    Events.OnGameStart.Add(IKST_SafehouseClaimHooks.init)
end
