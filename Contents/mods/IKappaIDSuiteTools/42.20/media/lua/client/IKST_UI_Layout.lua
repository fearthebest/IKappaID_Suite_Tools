-- Suite Tools layout helpers — delegates generic spacing to IKappaID_UI.
if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "IKappaID_UI/IKUI_Config"
require "IKappaID_UI/IKUI_Layout"

IKST_UI_Layout = IKST_UI_Layout or {}

function IKST_UI_Layout.uiScale()
    return IKUI_Config.uiScale()
end

function IKST_UI_Layout.s(px)
    return IKUI_Config.s(px)
end

function IKST_UI_Layout.textSize(text, font)
    return IKUI_Config.textSize(text, font)
end

function IKST_UI_Layout.buttonWidth(label, font, minW)
    return IKUI_Config.buttonWidth(label, font, minW)
end

function IKST_UI_Layout.screen(margin)
    return IKUI_Layout.screen(margin)
end

function IKST_UI_Layout.center(childW, childH, rect)
    return IKUI_Layout.center(childW, childH, rect)
end

function IKST_UI_Layout.column(parent, x, y, w, children, opts)
    return IKUI_Layout.column(parent, x, y, w, children, opts)
end

function IKST_UI_Layout.row(parent, x, y, h, children, opts)
    return IKUI_Layout.row(parent, x, y, h, children, opts)
end

function IKST_UI_Layout.sidebarWidth()
    return IKUI_Config.sidebarWidth()
end

function IKST_UI_Layout.padding()
    return IKUI_Config.padding
end

function IKST_UI_Layout.gap()
    return IKUI_Config.gap
end

function IKST_UI_Layout.buttonMinH()
    return IKUI_Config.buttonMinH()
end
