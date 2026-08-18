require "IKST_Shared"

IKST_ClaimIcons = IKST_ClaimIcons or {}

-- Custom media/ui/ikst glyphs look soft when scaled small — text-only hub/UI.
IKST_ClaimIcons.HUB_UI_ICONS = false
IKST_ClaimIcons.CONTEXT_ICONS = false

IKST_ClaimIcons.DASHBOARD = "media/ui/ikst/ws_dashboard.png"
-- Source PNGs are 128x128 (2x); drawn smaller in UI for sharp downscale.
IKST_ClaimIcons.ICON_CANVAS = 128
IKST_ClaimIcons.ICON_GLYPH_MAX = 104

IKST_ClaimIcons.VEHICLE_CLAIM = "media/ui/ikst/vehicle_claim.png"
IKST_ClaimIcons.VEHICLE_UNCLAIM = "media/ui/ikst/vehicle_unclaim.png"
IKST_ClaimIcons.SAFEHOUSE_CLAIM = "media/ui/ikst/safehouse_claim.png"
IKST_ClaimIcons.SAFEHOUSE_UNCLAIM = "media/ui/ikst/safehouse_unclaim.png"
IKST_ClaimIcons.PERMS = "media/ui/vehicles/vehicle_saddlebag.png"

function IKST_ClaimIcons.texture(path)
    if not path or not getTexture then
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
    if not btn or not path or not btn.setImage then
        return
    end
    local tex = IKST_ClaimIcons.texture(path)
    if not tex then
        return
    end
    btn:setImage(tex)
    if btn.setImageRight then
        btn:setImageRight(false)
    end
    if btn.setDisplayBackground then
        btn:setDisplayBackground(true)
    end
end
