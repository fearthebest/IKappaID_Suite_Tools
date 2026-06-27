if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then return end

require "ISUI/ISModalDialog"
require "IKST_Shared"
require "IKST_Chrome"

IKST_Confirm = IKST_Confirm or {}

function IKST_Confirm.show(text, onYes, onNo, destructive)
    local modal = ISModalDialog:new(0, 0, 360, 140, text, true, nil, function(_, button)
        if not button or not button.internal then
            return
        end
        if button.internal == "YES" then
            if onYes then
                onYes()
            end
        elseif button.internal == "NO" then
            if onNo then
                onNo()
            end
        end
    end)
    modal:initialise()
    modal:addToUIManager()
    if destructive and modal.yes then
        modal.yes.backgroundColor = IKST_Chrome.colors.danger
    end
    return modal
end

function IKST_Confirm.showDestructive(text, onYes, onNo)
    IKST_Confirm.show(text, onYes, onNo, true)
end
