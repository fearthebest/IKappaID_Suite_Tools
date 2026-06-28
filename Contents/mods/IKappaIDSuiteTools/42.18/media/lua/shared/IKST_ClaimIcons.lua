require "IKST_Shared"

IKST_ClaimIcons = IKST_ClaimIcons or {}

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

function IKST_ClaimIcons.applyContextIcon(option, path)
    if not option or not path then
        return
    end
    local tex = IKST_ClaimIcons.texture(path)
    if tex then
        option.iconTexture = tex
    end
end

function IKST_ClaimIcons.applyButtonIcon(btn, path)
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
