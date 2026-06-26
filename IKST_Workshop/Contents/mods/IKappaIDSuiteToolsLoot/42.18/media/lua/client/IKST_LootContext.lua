if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "IKST_Shared"
require "IKST_Access"
require "IKST_LootOps"

IKST_LootContext = IKST_LootContext or {}

function IKST_LootContext.onFillWorldObjectContextMenu(playerNum, context, worldobjects, test)
    if test then
        return
    end
    if not IKST.Plugins or not IKST.Plugins.isActive("loot") then
        return
    end
    local player = getSpecificPlayer and getSpecificPlayer(playerNum) or nil
    if not player or not IKST_Access.canUseLoot(player) then
        return
    end
    local targets = IKST_LootOps.resolveTargetsFromWorldObjects(worldobjects)
    if #targets == 0 then
        return
    end

    local rootLabel = IKST.text("IGUI_IKST_Loot_Context", "Repopulate loot")
    local option = context:addOption(rootLabel, worldobjects, nil)
    local sub = ISContextMenu:getNew(context)
    context:addSubMenu(option, sub)

    for i = 1, #targets do
        local target = targets[i]
        sub:addOption(target.label, player, function()
            IKST.dispatchCommand(player, IKST.CMD.lootRepopulateContainer, {
                x = target.x,
                y = target.y,
                z = target.z,
                objectIndex = target.objectIndex,
                containerIndex = target.containerIndex,
            })
        end)
    end

    if #targets > 1 then
        sub:addOption(IKST.text("IGUI_IKST_Loot_Context_All", "All on this square"), player, function()
            local first = targets[1]
            IKST.dispatchCommand(player, IKST.CMD.lootRepopulateZone, {
                x = first.x,
                y = first.y,
                z = first.z,
                scope = IKST.CLEANUP_SCOPES.single,
            })
        end)
    end
end

if Events and Events.OnFillWorldObjectContextMenu then
    Events.OnFillWorldObjectContextMenu.Add(IKST_LootContext.onFillWorldObjectContextMenu)
end
