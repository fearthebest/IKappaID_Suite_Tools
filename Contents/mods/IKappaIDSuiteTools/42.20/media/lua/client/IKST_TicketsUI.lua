-- Redirect vanilla "Add Ticket" to Everyone Help (report). Staff inbox stays F1 Admin.

if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "ISUI/UserPanel/ISTicketsUI"
require "IKST_Shared"
require "IKST_Access"

IKST_TicketsUI = IKST_TicketsUI or {}

-- Staff inbox stays vanilla F1 Admin -> See Tickets. Hub never opens that window.
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
    IKST.notify(player, IKST.text("IGUI_IKST_SeeTickets_UseF1",
        "Open tickets from F1 Admin -> See Tickets."), true)
end

function IKST_TicketsUI.openReport(player)
    player = IKST.resolvePlayer(player) or (getPlayer and getPlayer())
    if not player then
        return
    end
    if IKST_Hub and type(IKST_Hub.openWorkspace) == "function" then
        IKST_Hub.openWorkspace(player, IKST.VIEW.everyone, nil)
    elseif IKST_Hub and type(IKST_Hub.open) == "function" then
        IKST_Hub.open(player)
        if type(IKST_Hub.switchWorkspace) == "function" then
            IKST_Hub.switchWorkspace(IKST.VIEW.everyone, nil)
        end
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
