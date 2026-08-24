-- Redirect vanilla "Add Ticket" to IKST Everyone (user request, Wave 2).
-- Does not replace staff See Tickets (ISAdminTicketsUI). Idempotent wrap.

if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "ISUI/UserPanel/ISTicketsUI"
require "ISUI/AdminPanel/ISAdminTicketsUI"
require "IKST_Shared"
require "IKST_Access"
require "IKST_JobsPanel"

IKST_TicketsUI = IKST_TicketsUI or {}

-- Staff inbox is vanilla ISAdminTicketsUI (F1 Admin -> See Tickets).
-- IKST does not keep a second ticket list.
function IKST_TicketsUI.openInbox(player)
    player = IKST.resolvePlayer(player) or (getPlayer and getPlayer())
    if not player then
        return
    end
    if not IKST.isMultiplayerSession or not IKST.isMultiplayerSession() then
        IKST.notify(player, IKST.text("IGUI_IKST_SeeTickets_MpOnly",
            "Tickets need multiplayer. Staff review them in F1 Admin -> See Tickets."), false)
        return
    end
    if IKST_Access and type(IKST_Access.canUseStaffTools) == "function"
        and not IKST_Access.canUseStaffTools(player) then
        IKST.notify(player, IKST.text("IGUI_IKST_SeeTickets_StaffOnly",
            "Staff tools are required to open the ticket inbox."), false)
        return
    end
    if ISAdminTicketsUI.instance and type(ISAdminTicketsUI.instance.close) == "function" then
        ISAdminTicketsUI.instance:close()
    end
    local ui = ISAdminTicketsUI:new(50, 50, 900, 600, player)
    ui:initialise()
    ui:addToUIManager()
end

function IKST_TicketsUI.openReport(player)
    player = IKST.resolvePlayer(player) or (getPlayer and getPlayer())
    if not player then
        return
    end
    if IKST_JobsPanel and type(IKST_JobsPanel.open) == "function" then
        IKST_JobsPanel.open(player)
    end
    local panel = IKST_JobsPanel and IKST_JobsPanel.instance
    if panel and type(panel.enterNav) == "function" then
        panel:enterNav(IKST.VIEW.everyone, nil)
    end
    IKST.notify(player, IKST.text("IGUI_IKST_Everyone_ReportHint",
        "Use Report player. Type who and why in the box, then send."), true)
end

function IKST_TicketsUI.wrapAddTicket()
    if IKST_TicketsUI.wrapped or not ISTicketsUI or not ISTicketsUI.onClick then
        return
    end
    IKST_TicketsUI.wrapped = true
    local vanilla = ISTicketsUI.onClick
    ISTicketsUI.onClick = function(self, button)
        if button and button.internal == "ADDTICKET" then
            if self.close then
                self:close()
            end
            IKST_TicketsUI.openReport(self.player)
            return
        end
        return vanilla(self, button)
    end
end

if Events and Events.OnGameStart then
    Events.OnGameStart.Add(function()
        IKST_TicketsUI.wrapAddTicket()
    end)
end
