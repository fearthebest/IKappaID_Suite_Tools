-- Optional addon registration for IKappaID Suite Tools (base mod).

require "IKST_Shared"

IKST.Plugins = IKST.Plugins or {}
local registry = {}

function IKST.isAddonActive(modId)
    if not modId or modId == "" then
        return false
    end
    if getActivatedMods then
        local mods = getActivatedMods()
        if mods then
            if mods.contains and mods:contains(modId) then
                return true
            end
            if mods.indexOf and mods:indexOf(modId) >= 0 then
                return true
            end
            if mods.size and mods.get then
                for i = 0, mods:size() - 1 do
                    if mods:get(i) == modId then
                        return true
                    end
                end
            end
        end
    end
    return false
end

function IKST.Plugins.get(id)
    return registry[id]
end

function IKST.Plugins.all()
    return registry
end

function IKST.Plugins.isActive(id)
    local spec = registry[id]
    if not spec then
        return false
    end
    if spec.modId and not IKST.isAddonActive(spec.modId) then
        return false
    end
    if spec.isActive then
        return spec.isActive()
    end
    return true
end

function IKST.Plugins.register(id, spec)
    if not id or type(spec) ~= "table" then
        return
    end
    local row = registry[id] or {}
    for key, value in pairs(spec) do
        row[key] = value
    end
    row.id = id
    registry[id] = row
end

local function appendHubTool(out, tool, pluginId, modeId)
    if not tool or tool.mode ~= modeId then
        return
    end
    local copy = {}
    for k, v in pairs(tool) do
        copy[k] = v
    end
    copy.id = copy.id or pluginId
    table.insert(out, copy)
end

function IKST.Plugins.hubToolsForMode(modeId)
    local out = {}
    for pluginId, spec in pairs(registry) do
        if IKST.Plugins.isActive(pluginId) then
            if spec.hubTools then
                for _, tool in ipairs(spec.hubTools) do
                    appendHubTool(out, tool, pluginId, modeId)
                end
            end
            appendHubTool(out, spec.hubTool, pluginId, modeId)
        end
    end
    table.sort(out, function(a, b)
        return (tonumber(a.order) or 50) < (tonumber(b.order) or 50)
    end)
    return out
end

function IKST.Plugins.buildJobTool(panel, toolId)
    for pluginId, spec in pairs(registry) do
        if not IKST.Plugins.isActive(pluginId) then
            -- skip inactive addon
        elseif spec.jobTools and spec.buildJobTools and spec.buildJobTools[toolId] then
            return spec.buildJobTools[toolId](panel)
        elseif spec.jobTool == toolId and spec.buildJob then
            return spec.buildJob(panel)
        end
    end
    return nil
end

function IKST.Plugins.onNavEntered(panel, modeId, toolId)
    for pluginId, spec in pairs(registry) do
        if IKST.Plugins.isActive(pluginId) and spec.onNavEntered then
            spec.onNavEntered(panel, modeId, toolId)
        end
    end
end

function IKST.Plugins.onServerCommand(command, args, player)
    for pluginId, spec in pairs(registry) do
        if IKST.Plugins.isActive(pluginId) and spec.onServerCommand then
            if spec.onServerCommand(command, args, player) then
                return true
            end
        end
    end
    return false
end

function IKST.Plugins.findCommandSpec(command)
    for pluginId, spec in pairs(registry) do
        if IKST.Plugins.isActive(pluginId) then
            if spec.adminCommands and spec.adminCommands[command] then
                return pluginId, spec, "admin"
            end
            if spec.playerCommands and spec.playerCommands[command] then
                return pluginId, spec, "player"
            end
        end
    end
    return nil
end

function IKST.Plugins.handleServerCommand(command, player, args)
    args = args or {}
    local pluginId, spec = IKST.Plugins.findCommandSpec(command)
    if not pluginId then
        return false
    end
    if not spec.handleServer then
        return true, false, "addon error", spec
    end
    local isAdmin = spec.adminCommands and spec.adminCommands[command] == true
    local ok, msg = spec.handleServer(command, player, args)
    if spec.afterServer then
        spec.afterServer(command, player, args, ok, msg, isAdmin)
    end
    return true, ok, msg, spec
end
