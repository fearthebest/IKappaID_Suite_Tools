if type(isClient) == "function" and isClient()
    and type(isServer) == "function" and not isServer() then
    return
end
require "IKST_Shared"
require "IKST_RestoreOps"
require "IKST_ClaimPolicy"
require "IKST_StaffOps"
require "IKST_WorldOps"

IKST_RestoreServer = IKST_RestoreServer or {}

function IKST_RestoreServer.handle(command, player, args)
    args = args or {}

    if command == IKST.CMD.journalRecord then
        if not IKST_RestoreOps.journalEnabled() then
            return false, "recovery journal disabled"
        end
        local item = IKST_RestoreOps.findItemById(player, args.itemId)
        if not IKST_RestoreOps.isJournalItem(item) then
            return false, "journal not found"
        end
        local snap = IKST_RestoreOps.capturePlayer(player)
        if not snap then
            return false, "capture failed"
        end
        IKST_RestoreOps.snapshotOnItem(item, snap)
        return true, "character recorded in journal"
    end

    if command == IKST.CMD.journalRestore then
        if not IKST_RestoreOps.journalEnabled() then
            return false, "recovery journal disabled"
        end
        local item = IKST_RestoreOps.findItemById(player, args.itemId)
        if not IKST_RestoreOps.isJournalItem(item) then
            return false, "journal not found"
        end
        local snap = IKST_RestoreOps.snapshotFromItem(item)
        if not snap then
            return false, "journal is empty"
        end
        local username = IKST_RestoreOps.username(player)
        if snap.username and username and not IKST_ClaimPolicy.usernamesEqual(snap.username, username) then
            return false, "journal belongs to another player"
        end
        return IKST_RestoreOps.applySnapshot(player, snap)
    end

    return nil
end
