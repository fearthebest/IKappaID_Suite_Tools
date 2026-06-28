-- Server Briefing: resolve section text (defaults + host file overrides).

if type(isClient) == "function" and isClient()
    and type(isServer) == "function" and not isServer() then
    return
end

require "IKST_Shared"
require "IKST_Briefing"

IKST_BriefingServer = IKST_BriefingServer or {}
IKST_BriefingServer._cache = IKST_BriefingServer._cache or {}

local function readHostFile(sectionId)
    if not getFileReader then
        return nil
    end
    local path = "IKST/Briefing/" .. tostring(sectionId) .. ".txt"
    local reader = getFileReader(path, true)
    if not reader then
        return nil
    end
    local lines = {}
    local line = reader:readLine()
    while line do
        lines[#lines + 1] = line
        line = reader:readLine()
    end
    reader:close()
    if #lines == 0 then
        return nil
    end
    return table.concat(lines, "\n")
end

function IKST_BriefingServer.resolveBody(sectionId)
    if not sectionId then
        return ""
    end
    sectionId = tostring(sectionId)
    local cached = IKST_BriefingServer._cache[sectionId]
    if cached ~= nil then
        return cached
    end
    local body = readHostFile(sectionId)
    if not body or body == "" then
        body = IKST_Briefing.defaultBody(sectionId)
    end
    body = IKST_Briefing.clampBody(body)
    IKST_BriefingServer._cache[sectionId] = body
    return body
end

function IKST_BriefingServer.buildPayload(sectionId)
    local catalog = IKST_Briefing.defaultCatalog()
    local sections = {}
    for _, row in ipairs(catalog) do
        sections[#sections + 1] = {
            id = row.id,
            title = row.title,
            body = IKST_BriefingServer.resolveBody(row.id),
        }
    end
    local activeId = sectionId
    if not activeId and catalog[1] then
        activeId = catalog[1].id
    end
    return {
        sections = sections,
        activeId = activeId,
        version = IKST.VERSION,
    }
end

function IKST_BriefingServer.handleFetch(player, args)
    if not IKST_Briefing.enabled() then
        if IKST_WorldOps and IKST_WorldOps.sendResult then
            IKST_WorldOps.sendResult(player, false, "briefing disabled", nil, nil, nil, IKST.CMD.briefingFetch)
        end
        return
    end
    local payload = IKST_BriefingServer.buildPayload(args and args.sectionId)
    IKST.deliverClientCommand(player, IKST.CMD.briefingResult, payload)
end

function IKST_BriefingServer.clearCache()
    IKST_BriefingServer._cache = {}
end

if Events and Events.OnGameStart then
    Events.OnGameStart.Add(function()
        IKST_BriefingServer.clearCache()
    end)
end
