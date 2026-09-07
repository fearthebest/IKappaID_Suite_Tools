-- Soft-shell Home page — dashboard stats + workspace grid.
if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "ISUI/ISPanel"
require "IKST_Shared"
require "IKST_Access"
require "IKST_HubNav"
require "IKST_Dashboard"
require "IKST_DashboardUI"
require "IKappaID_UI_Framework/IKUI_Chrome"
require "IKappaID_UI_Framework/IKUI_Controls"
require "IKappaID_UI_Framework/IKUI_Prefs"
require "IKappaID_UI_Framework/IKUI_SoftBody"
require "IKST_SoftTool_Home"

IKST_PageHome = IKST_PageHome or {}

local PREFS_STATS_COLLAPSED = "ikst.home.statsCollapsed"

local function loadStatsCollapsed()
    if IKUI_Prefs and type(IKUI_Prefs.getNumber) == "function" then
        local v = IKUI_Prefs.getNumber(PREFS_STATS_COLLAPSED)
        if v ~= nil then
            return v == 1
        end
    end
    return false
end

local function saveStatsCollapsed(collapsed)
    if IKUI_Prefs and type(IKUI_Prefs.set) == "function" then
        IKUI_Prefs.set(PREFS_STATS_COLLAPSED, collapsed and 1 or 0)
    end
end

function IKST_PageHome.create(window, x, y, w, h)
    local panel = ISPanel:new(x, y, w, h)
    panel.backgroundColor = { r = 0, g = 0, b = 0, a = 0 }
    panel.borderColor = { r = 0, g = 0, b = 0, a = 0 }
    panel.window = window
    panel.player = window and window.player or nil
    panel._homeWidgets = {}
    panel._staffAlertWidgets = {}
    panel._rebuilding = false
    panel._homeStatsCollapsed = loadStatsCollapsed()

    function panel:titleBarHeight()
        return 0
    end

    function panel:clearHomeWidgets()
        local lists = { self._homeWidgets, self._staffAlertWidgets }
        for li = 1, #lists do
            local list = lists[li]
            for i = 1, #(list or {}) do
                local child = list[i]
                if child and type(self.removeChild) == "function" then
                    self:removeChild(child)
                end
            end
            if li == 1 then
                self._homeWidgets = {}
            else
                self._staffAlertWidgets = {}
            end
        end
    end

    function panel:addHomeWidget(widget)
        if not widget then
            return
        end
        widget._ikstHubSatellite = true
        self:addChild(widget)
        self._homeWidgets[#self._homeWidgets + 1] = widget
    end

    function panel:enterNav(workspaceId, toolId)
        if IKST_Hub and type(IKST_Hub.switchWorkspace) == "function" then
            IKST_Hub.switchWorkspace(workspaceId, toolId)
        end
    end

    function panel:toggleStatsCollapsed()
        self._homeStatsCollapsed = not self._homeStatsCollapsed
        saveStatsCollapsed(self._homeStatsCollapsed)
        self:rebuild()
    end

    function panel:buildStaffAlerts()
        local player = IKST.resolvePlayer(self.player or (self.window and self.window.player))
        self.player = player
        local snap = IKST_Dashboard and IKST_Dashboard.snapshot
        if not player or not snap or snap.staffView ~= true then
            return 0
        end
        local helpN = tonumber(snap.pendingHelp) or 0
        local claimN = tonumber(snap.pendingClaimRequests) or 0
        if helpN < 1 and claimN < 1 then
            return 0
        end

        local pad = IKST_DashboardUI.PAD or 20
        local gap = IKST_SoftTool_Home.GAP or 12
        local alertH = 40
        local y0 = pad
        local innerW = math.max(120, self.width - pad * 2)
        local pills = {}
        if helpN > 0 then
            pills[#pills + 1] = {
                label = tostring(helpN) .. " "
                    .. IKST.text("IGUI_IKST_Home_OpenHelp", "Open help queue"),
                primary = true,
                onClick = function()
                    panel:enterNav("everyone", "help")
                end,
            }
        end
        if claimN > 0 then
            pills[#pills + 1] = {
                label = tostring(claimN) .. " "
                    .. IKST.text("IGUI_IKST_Home_OpenClaims", "Open claim queue"),
                onClick = function()
                    panel:enterNav("claim", "requests")
                end,
            }
        end
        local host = ISPanel:new(pad, y0, innerW, alertH)
        host.backgroundColor = { r = 0, g = 0, b = 0, a = 0 }
        host.borderColor = { r = 0, g = 0, b = 0, a = 0 }
        host:initialise()
        self:addChild(host)
        self._staffAlertWidgets[#self._staffAlertWidgets + 1] = host
        IKUI_SoftBody.pillRow(self, host, 0, 4, innerW, alertH - 8, pills)
        return alertH + gap
    end

    function panel:rebuild()
        if self._rebuilding then
            return
        end
        self._rebuilding = true
        self.player = IKST.resolvePlayer(self.player or (self.window and self.window.player))
        self:clearHomeWidgets()

        local alertOffset = self:buildStaffAlerts()
        if IKST_DashboardUI and type(IKST_DashboardUI.build) == "function" then
            self._homeAlertOffset = alertOffset
            IKST_DashboardUI.build(self)
        end

        self._rebuilding = false
    end

    function panel:onShow()
        self:rebuild()
        local player = self.window and self.window.player
        player = IKST.resolvePlayer(player)
        self.player = player
        if player and IKST_Dashboard and type(IKST_Dashboard.request) == "function" then
            IKST_Dashboard.request(player)
        end
    end

    function panel:refreshFromSnapshot()
        self:rebuild()
    end

    function panel:refreshJobUI()
        self:rebuild()
    end

    function panel:prerender()
        if type(ISPanel.prerender) == "function" then
            ISPanel.prerender(self)
        end
        if IKST_HubNav and type(IKST_HubNav.drawDashboard) == "function" then
            IKST_HubNav.drawDashboard(self, 0)
        end
    end

    return panel
end
