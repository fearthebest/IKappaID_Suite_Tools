require "IKST_Shared"

IKST_Rewind = IKST_Rewind or {}
IKST_Rewind.MAX_STEPS = 30

function IKST_Rewind.getStack(player)
    local state = IKST.getPlayerState(player)
    if not state then
        return {}
    end
    if not state.rewindStack then
        state.rewindStack = {}
    end
    return state.rewindStack
end

function IKST_Rewind.count(player)
    return #IKST_Rewind.getStack(player)
end

function IKST_Rewind.peek(player)
    local stack = IKST_Rewind.getStack(player)
    return stack[1]
end

function IKST_Rewind.push(player, label, entries)
    if not player or not entries or #entries == 0 then
        return
    end
    local stack = IKST_Rewind.getStack(player)
    table.insert(stack, 1, {
        label = tostring(label or "cleanup"),
        entries = entries,
    })
    while #stack > IKST_Rewind.MAX_STEPS do
        table.remove(stack)
    end
end

function IKST_Rewind.recordSquare(player, label, x, y, z, sprites)
    if not sprites or #sprites == 0 then
        return
    end
    IKST_Rewind.push(player, label, {
        { x = x, y = y, z = z, sprites = sprites },
    })
end

function IKST_Rewind.pop(player)
    local stack = IKST_Rewind.getStack(player)
    if #stack == 0 then
        return nil
    end
    return table.remove(stack, 1)
end

function IKST_Rewind.clear(player)
    local state = IKST.getPlayerState(player)
    if state then
        state.rewindStack = {}
    end
end
