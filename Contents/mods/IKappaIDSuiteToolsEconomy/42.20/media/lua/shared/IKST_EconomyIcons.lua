require "IKST_Shared"

IKST_EconomyIcons = IKST_EconomyIcons or {}

-- Soft UI glyph retired; keep the item/inventory icon (kiosk model assets unchanged).
IKST_EconomyIcons.SHOP_ITEM = "media/textures/Item_IKST_ShopTerminal.png"
IKST_EconomyIcons.SHOP_KIT_TYPE = "IKST.ShopTerminalKit"

function IKST_EconomyIcons.texture(path)
    if not path or type(getTexture) ~= "function" then
        return nil
    end
    return getTexture(path)
end

function IKST_EconomyIcons.shopTexture()
    return IKST_EconomyIcons.texture(IKST_EconomyIcons.SHOP_ITEM)
end

function IKST_EconomyIcons.applyContextIcon(option, path)
    -- Custom shop glyph disabled (soft when scaled); text-only context entries.
    return
end

function IKST_EconomyIcons.applyButtonIcon(btn, path)
    return
end
