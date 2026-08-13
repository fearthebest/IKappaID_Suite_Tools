require "IKST_Shared"
require "IKST_Authority"

IKST_Rewind = IKST_Rewind or {}
IKST_Rewind.MAX_STEPS = 30
IKST_Rewind.MOD_DATA_KEY = "IKST_RewindStacks"

function IKST_Rewind.playerKey(player)
    player = IKST.resolvePlayer(player)
    if not player then
        return nil
    end
    if not IKST_Identity then
        require "IKST_Identity"
    end
    if IKST_Identity and IKST_Identity.accountKey then
        return IKST_Identity.accountKey(player)
    end
    if player.getOnlineID then
        return "oid:" .. tostring(player:getOnlineID())
    end
    return nil
end

function IKST_Rewind.usesServerStack()
    return IKST.runsOnServerJvm and IKST.runsOnServerJvm()
        and IKST.isMultiplayerSession and IKST.isMultiplayerSession()
end

function IKST_Rewind.serverRoot()
    if not ModData or not ModData.getOrCreate then
        return nil
    end
    return ModData.getOrCreate(IKST_Rewind.MOD_DATA_KEY)
end

function IKST_Rewind.getStack(player)
    if IKST_Rewind.usesServerStack() then
        local key = IKST_Rewind.playerKey(player)
        if not key then
            return {}
        end
        local root = IKST_Rewind.serverRoot()
        if not root then
            return {}
        end
        if not root[key] then
            root[key] = {}
        end
        return root[key]
    end
    local state = IKST.getPlayerState(player)
    if not state then
        return {}
    end
    if not state.rewindStack then
        state.rewindStack = {}
    end
    return state.rewindStack
end

function IKST_Rewind.setClientCount(player, count)
    player = IKST.resolvePlayer(player)
    if not player then
        return
    end
    count = math.max(0, math.floor(tonumber(count) or 0))
    local state = IKST.getPlayerState(player)
    if state then
        state.rewindCount = count
    end
end

function IKST_Rewind.count(player)
    if IKST.isRemoteClient and IKST.isRemoteClient() then
        local state = IKST.getPlayerState(player)
        if state and state.rewindCount ~= nil then
            return state.rewindCount
        end
        return 0
    end
    return #IKST_Rewind.getStack(player)
end

function IKST_Rewind.syncCountToClient(player)
    if not player or not IKST.deliverClientCommand then
        return
    end
    if not IKST_Rewind.usesServerStack() then
        return
    end
    local count = #IKST_Rewind.getStack(player)
    IKST.deliverClientCommand(player, IKST.CMD.rewindSync, { count = count })
end

function IKST_Rewind.peek(player)
    local stack = IKST_Rewind.getStack(player)
    return stack[1]
end

function IKST_Rewind.push(player, label, entries, mode)
    if IKST_Rewind.usesServerStack() and IKST_Authority and not IKST_Authority.guardServerMutate() then
        return
    end
    if not player or not entries or #entries == 0 then
        return
    end
    local stack = IKST_Rewind.getStack(player)
    table.insert(stack, 1, {
        label = tostring(label or "cleanup"),
        entries = entries,
        mode = mode,
    })
    while #stack > IKST_Rewind.MAX_STEPS do
        table.remove(stack)
    end
    IKST_Rewind.syncCountToClient(player)
end

function IKST_Rewind.recordSquare(player, label, x, y, z, sprites, mode)
    if not sprites or #sprites == 0 then
        return
    end
    IKST_Rewind.push(player, label, {
        { x = x, y = y, z = z, sprites = sprites },
    }, mode)
end

function IKST_Rewind.pop(player)
    if IKST_Rewind.usesServerStack() and IKST_Authority and not IKST_Authority.guardServerMutate() then
        return nil
    end
    local stack = IKST_Rewind.getStack(player)
    if #stack == 0 then
        return nil
    end
    local step = table.remove(stack, 1)
    IKST_Rewind.syncCountToClient(player)
    return step
end

function IKST_Rewind.clear(player)
    if IKST_Rewind.usesServerStack() and IKST_Authority and not IKST_Authority.guardServerMutate() then
        return
    end
    if IKST_Rewind.usesServerStack() then
        local key = IKST_Rewind.playerKey(player)
        local root = IKST_Rewind.serverRoot()
        if key and root then
            root[key] = {}
        end
    else
        local state = IKST.getPlayerState(player)
        if state then
            state.rewindStack = {}
        end
    end
    IKST_Rewind.syncCountToClient(player)
end
