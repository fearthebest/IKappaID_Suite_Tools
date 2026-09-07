-- SoftTool helpers for Home workspace (PageHome stays custom; SoftBody/IKUI for cards).
-- SoftBody = frontend layout; SoftTool_Home = Home feature helpers only.
if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "IKappaID_UI_Framework/IKUI_SoftBody"
require "IKappaID_UI_Framework/IKUI_Controls"

IKST_SoftTool_Home = IKST_SoftTool_Home or {}

IKST_SoftTool_Home.PAD = IKUI_SoftBody.CONTENT_PAD or 16
IKST_SoftTool_Home.GAP = IKUI_SoftBody.BTN_GAP or 6
IKST_SoftTool_Home.CARD_H = 72
IKST_SoftTool_Home.COLS = 2

-- SoftBody content rect for a home panel (uses _softContentRect when host sets it).
function IKST_SoftTool_Home.contentRect(panel)
    return IKUI_SoftBody.contentRect(panel)
end

-- Place one workspace nav card (ghost IKUI_Button) at absolute coords.
function IKST_SoftTool_Home.placeNavCard(panel, x, y, w, h, title, desc, onClick)
    if not panel or type(IKUI_Button) ~= "table" then
        return nil
    end
    local btn = IKUI_Button:new(x, y, w, h, title or "", panel, onClick)
    btn.style = "ghost"
    btn.radius = 12
    btn._wsDesc = desc or ""
    btn._ikuiAccentLeft = true
    btn._ikstHubSatellite = true
    if type(panel.addHomeWidget) == "function" then
        panel:addHomeWidget(btn)
    elseif type(IKUI_Button.mount) == "function" then
        IKUI_Button:mount(btn, panel)
    elseif type(panel.addChild) == "function" then
        panel:addChild(btn)
    end
    return btn
end
