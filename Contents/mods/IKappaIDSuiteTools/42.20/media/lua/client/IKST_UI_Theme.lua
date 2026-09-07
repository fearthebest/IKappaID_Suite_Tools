-- Compatibility shim - palette lives in IKappaID_UI/IKUI_Chrome.
if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "IKappaID_UI_Framework/IKUI_Chrome"
require "IKappaID_UI_Framework/IKUI_Config"

IKST_UI_Theme = IKST_UI_Theme or {}
IKST_UI_Theme.colors = IKUI_Chrome.colors
IKST_UI_Theme.space = {
    cornerRadius = IKUI_Config.cornerRadius,
    padding = IKUI_Config.padding,
    gap = IKUI_Config.gap,
    sidebarWidth = IKUI_Config.hubSidebarW,
    screenMargin = IKUI_Config.edgeMargin,
    buttonMinH = IKUI_Config.buttonMinH(),
    buttonPadX = 24,
    cardShadow = IKUI_Config.cardShadow,
    navItemH = IKUI_Config.navItemH,
    statusChipH = IKUI_Config.statusChipH,
}
IKST_UI_Theme.fonts = {
    h1 = UIFont.Large,
    h2 = UIFont.Medium,
    body = UIFont.Small,
    caption = UIFont.Small,
}

function IKST_UI_Theme.rgba(c, alpha)
    return IKUI_Chrome.rgba(c, alpha)
end
