if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "IKST_Shared"
require "IKST_RestoreOps"

IKST_RestoreJournal = IKST_RestoreJournal or {}

function IKST_RestoreJournal.resolveItem(items)
    if ISInventoryPane and ISInventoryPane.getActualItems then
        local actual = ISInventoryPane.getActualItems(items)
        if actual and actual[1] then
            return actual[1]
        end
    end
    return items and items[1] or nil
end

function IKST_RestoreJournal.onInventoryMenu(playerNum, context, items)
    if not IKST_RestoreOps.journalEnabled() then
        return
    end
    local player = IKST.resolvePlayer(playerNum)
    if not player or not context then
        return
    end
    local item = IKST_RestoreJournal.resolveItem(items)
    if not IKST_RestoreOps.isJournalItem(item) then
        return
    end
    local snap = IKST_RestoreOps.snapshotFromItem(item)
    context:addOption(IKST.text("IGUI_IKST_Journal_Record", "Record character"), player, function()
        if not item or not item.getID then
            return
        end
        IKST.dispatchCommand(player, IKST.CMD.journalRecord, { itemId = item:getID() })
    end)
    if snap then
        local label = IKST.text("IGUI_IKST_Journal_Restore", "Restore from journal")
        if snap.username then
            label = label .. " (" .. tostring(snap.username) .. ")"
        end
        context:addOption(label, player, function()
            if not item or not item.getID then
                return
            end
            IKST.dispatchCommand(player, IKST.CMD.journalRestore, { itemId = item:getID() })
        end)
    end
end

if Events and Events.OnFillInventoryObjectContextMenu then
    Events.OnFillInventoryObjectContextMenu.Add(IKST_RestoreJournal.onInventoryMenu)
end
