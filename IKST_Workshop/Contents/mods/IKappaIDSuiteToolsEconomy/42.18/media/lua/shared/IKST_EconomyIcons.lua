require "IKST_Shared"

IKST_EconomyIcons = IKST_EconomyIcons or {}

IKST_EconomyIcons.SHOP = "media/ui/ikst/shop_terminal.png"
IKST_EconomyIcons.SHOP_ITEM = "media/textures/Item_IKST_ShopTerminal.png"
IKST_EconomyIcons.SHOP_KIT_TYPE = "IKST.ShopTerminalKit"

function IKST_EconomyIcons.texture(path)
    if not path or not getTexture then
        return nil
    end
    return getTexture(path)
end

function IKST_EconomyIcons.shopTexture()
    local tex = IKST_EconomyIcons.texture(IKST_EconomyIcons.SHOP)
    if tex then
        return tex
    end
    return IKST_EconomyIcons.texture(IKST_EconomyIcons.SHOP_ITEM)
end

function IKST_EconomyIcons.applyContextIcon(option, path)
    if not option then
        return
    end
    local tex = IKST_EconomyIcons.texture(path or IKST_EconomyIcons.SHOP)
    if tex then
        option.iconTexture = tex
    end
end

function IKST_EconomyIcons.applyButtonIcon(btn, path)
    if not btn or not btn.setImage then
        return
    end
    local tex = IKST_EconomyIcons.texture(path or IKST_EconomyIcons.SHOP)
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
