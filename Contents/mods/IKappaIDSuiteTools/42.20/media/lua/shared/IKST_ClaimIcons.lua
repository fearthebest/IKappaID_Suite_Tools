require "IKST_Shared"

IKST_ClaimIcons = IKST_ClaimIcons or {}

-- IKappaID chrome glyphs under media/ui/ikst (64x64 transparent).
IKST_ClaimIcons.HUB_UI_ICONS = true
IKST_ClaimIcons.CONTEXT_ICONS = true

IKST_ClaimIcons.DASHBOARD = "media/ui/ikst/ws_dashboard.png"
IKST_ClaimIcons.ICON_CANVAS = 64
IKST_ClaimIcons.ICON_GLYPH_MAX = 52

IKST_ClaimIcons.VEHICLE_CLAIM = "media/ui/ikst/vehicle_claim.png"
IKST_ClaimIcons.VEHICLE_UNCLAIM = "media/ui/ikst/vehicle_unclaim.png"
IKST_ClaimIcons.SAFEHOUSE_CLAIM = "media/ui/ikst/safehouse_claim.png"
IKST_ClaimIcons.SAFEHOUSE_UNCLAIM = "media/ui/ikst/safehouse_unclaim.png"
IKST_ClaimIcons.PERMS = "media/ui/ikst/perms.png"

IKST_ClaimIcons.WS = {
    favorites = "media/ui/ikst/ws_dashboard.png",
    utilities = "media/ui/ikst/ws_utilities.png",
    admin = "media/ui/ikst/ws_admin.png",
    claim = "media/ui/ikst/ws_claim.png",
    tiles = "media/ui/ikst/ws_world.png",
    vehicles = "media/ui/ikst/ws_vehicles.png",
    everyone = "media/ui/ikst/ws_everyone.png",
    economy = "media/ui/ikst/ws_economy.png",
    loot = "media/ui/ikst/ws_loot.png",
}

IKST_ClaimIcons.TOOL = {
    ["vehicles:overview"] = "media/ui/ikst/tool_vehicles_overview.png",
    ["vehicles:spawn"] = "media/ui/ikst/tool_vehicle_spawn.png",
    ["vehicles:repair"] = "media/ui/ikst/tool_vehicle_repair.png",
    ["vehicles:prune"] = "media/ui/ikst/tool_vehicle_prune.png",
    ["claim:vehicleclaim"] = "media/ui/ikst/vehicle_claim.png",
    ["claim:safehouses"] = "media/ui/ikst/safehouse_claim.png",
    ["claim:overview"] = "media/ui/ikst/tool_claim_overview.png",
    ["claim:catch"] = "media/ui/ikst/tool_catch.png",
    ["utilities:self"] = "media/ui/ikst/tool_self.png",
    ["utilities:items"] = "media/ui/ikst/tool_items.png",
    ["utilities:players"] = "media/ui/ikst/tool_players.png",
    ["utilities:zombies"] = "media/ui/ikst/tool_zombies.png",
    ["utilities:servertools"] = "media/ui/ikst/tool_servertools.png",
    ["utilities:teleport"] = "media/ui/ikst/tool_teleport.png",
    ["tiles:overview"] = "media/ui/ikst/tool_tiles_overview.png",
    ["tiles:remove"] = "media/ui/ikst/tool_remove.png",
    ["tiles:paint"] = "media/ui/ikst/tool_paint.png",
    ["tiles:inspect"] = "media/ui/ikst/tool_inspect.png",
    ["tiles:blueprints"] = "media/ui/ikst/tool_blueprint.png",
    ["tiles:protect"] = "media/ui/ikst/tool_protect.png",
}

function IKST_ClaimIcons.pathForTool(modeId, toolId)
    if not modeId then
        return nil
    end
    if toolId and toolId ~= "" then
        local key = tostring(modeId) .. ":" .. tostring(toolId)
        local path = IKST_ClaimIcons.TOOL[key]
        if path then
            return path
        end
    end
    return IKST_ClaimIcons.WS[modeId]
end

function IKST_ClaimIcons.texture(path)
    if type(path) ~= "string" or path == "" then
        return nil
    end
    if type(getTexture) ~= "function" then
        return nil
    end
    return getTexture(path)
end

function IKST_ClaimIcons.drawIcon(panel, path, x, y, size, alpha)
    if IKST_ClaimIcons.HUB_UI_ICONS == false then
        return false
    end
    if not panel or not path or not size or size < 1 then
        return false
    end
    if type(panel.drawTextureScaled) ~= "function" then
        return false
    end
    local tex = IKST_ClaimIcons.texture(path)
    if not tex then
        return false
    end
    local a = alpha or 1
    size = math.floor(size)
    panel:drawTextureScaled(tex, math.floor(x), math.floor(y), size, size, a, 1, 1, 1)
    return true
end

function IKST_ClaimIcons.applyContextIcon(option, path)
    if IKST_ClaimIcons.CONTEXT_ICONS == false then
        return
    end
    if not option or not path then
        return
    end
    local tex = IKST_ClaimIcons.texture(path)
    if tex then
        option.iconTexture = tex
    end
end

function IKST_ClaimIcons.applyButtonIcon(btn, path)
    if IKST_ClaimIcons.HUB_UI_ICONS == false then
        return
    end
    if not btn or not path then
        return
    end
    if type(btn.setImage) ~= "function" then
        return
    end
    local tex = IKST_ClaimIcons.texture(path)
    if not tex then
        return
    end
    btn:setImage(tex)
    if type(btn.setImageRight) == "function" then
        btn:setImageRight(false)
    end
    if type(btn.setDisplayBackground) == "function" then
        btn:setDisplayBackground(true)
    end
end
