-- Delegates to IKappaID_UI scroll host (keeps IKST call sites stable).
if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "IKappaID_UI_Framework/IKUI_Widgets"

IKST_ScrollArea = IKUI_ScrollHost

function IKST_ScrollArea.wrap(parent, x, y, w, h)
    local area = IKUI_ScrollHost:new(x, y, w, h)
    if parent and type(parent.addJobWidget) == "function" then
        parent:addJobWidget(area)
    elseif parent and type(parent.addChild) == "function" then
        parent:addChild(area)
    end
    return area
end
