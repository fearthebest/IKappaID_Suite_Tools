-- Latest-20 action lines for the standalone Action Log window.
-- No scrollbars, no docked JobsPanel card - just colored text rows.
if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "IKST_Shared"
require "IKappaID_UI/IKUI_Chrome"

IKST_ActionLog = IKST_ActionLog or {}
IKST_ActionLog.MAX_LINES = 20

function IKST_ActionLog.lineRgb(kind, text)
    local c = IKUI_Chrome.colors
    local k = kind
    if not k and type(text) == "string" then
        if string.find(text, "^DENIED") or string.find(text, "denied") then
            k = "deny"
        elseif string.find(text, "/") and string.find(text, "%d+/%d+") then
            k = "progress"
        end
    end
    if k == "deny" or k == "danger" or k == "error" then
        return c.danger.r, c.danger.g, c.danger.b
    end
    if k == "success" then
        return c.success.r, c.success.g, c.success.b
    end
    if k == "progress" or k == "accent" then
        return c.accent.r, c.accent.g, c.accent.b
    end
    return c.textMuted.r, c.textMuted.g, c.textMuted.b
end

-- Newest first. Caps at MAX_LINES (pushLog already trims storage).
function IKST_ActionLog.linesForPlayer(player)
    local out = {}
    local state = IKST.getPlayerState(player)
    local raw = state and state.log or nil
    if not raw then
        return out
    end
    local maxN = IKST_ActionLog.MAX_LINES
    local n = #raw
    if n > maxN then
        n = maxN
    end
    for i = 1, n do
        local line = raw[i]
        local body = line
        local kind = nil
        if type(line) == "table" then
            body = line.text or ""
            kind = line.kind
        end
        body = tostring(body or "")
        local r, g, b = IKST_ActionLog.lineRgb(kind, body)
        out[#out + 1] = { text = body, r = r, g = g, b = b }
    end
    return out
end

-- Legacy JobsPanel hook (action log is no longer docked). Safe no-op.
function IKST_ActionLog.relayout(_logPanel, _x, _y, _w, _h, _panel)
end
