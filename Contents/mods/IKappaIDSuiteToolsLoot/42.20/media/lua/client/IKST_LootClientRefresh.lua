-- MP client display only: refresh loot container overlay after server repop (no world mutation).

if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "IKST_Shared"
require "IKST_LootOps"

IKST_LootClientRefresh = IKST_LootClientRefresh or {}

function IKST_LootClientRefresh.pullContainerContents(container)
    if not container then
        return
    end
    if container.requestServerItemsForContainer and type(container.requestServerItemsForContainer) == "function" then
        container:requestServerItemsForContainer()
        return
    end
    if container.requestSync and type(container.requestSync) == "function" then
        container:requestSync()
    end
end

function IKST_LootClientRefresh.refreshLootUi(container)
    local player = getPlayer and getPlayer() or nil
    if not player or not container or not getPlayerLoot then
        return
    end
    local lootPage = getPlayerLoot(player:getPlayerNum())
    if not lootPage or lootPage.inventory ~= container then
        return
    end
    if lootPage.refreshBackpacks then
        lootPage:refreshBackpacks()
    end
    if lootPage.inventoryPane and lootPage.inventoryPane.refreshContainer then
        lootPage.inventoryPane:refreshContainer()
    end
end

function IKST_LootClientRefresh.applyOne(entry)
    if not entry then
        return
    end
    if not IKST.isMultiplayerSession or not IKST.isMultiplayerSession() then
        return
    end
    local parent, container = IKST_LootOps.resolveLootTarget(
        entry.x, entry.y, entry.z, entry.objectIndex, entry.containerIndex)
    if not parent or not container then
        return
    end
    IKST_LootClientRefresh.pullContainerContents(container)
    if ItemPicker and ItemPicker.updateOverlaySprite then
        ItemPicker.updateOverlaySprite(parent)
    end
    if parent.setDrawDirty then
        parent:setDrawDirty(true)
    end
    IKST_LootClientRefresh.refreshLootUi(container)
end

function IKST_LootClientRefresh.applyRefresh(args)
    if not args then
        return
    end
    local entries = args.entries
    if type(entries) == "table" and #entries > 0 then
        for i = 1, #entries do
            IKST_LootClientRefresh.applyOne(entries[i])
        end
        return
    end
    IKST_LootClientRefresh.applyOne(args)
end
