if type(isServer) == "function" and isServer() and type(isClient) == "function" and not isClient() then
    return
end

require "ISUI/ISCollapsableWindow"
require "ISUI/ISScrollingListBox"
require "ISUI/ISRichTextPanel"
require "ISUI/ISButton"
require "IKST_Shared"
require "IKST_Briefing"
require "IKST_Chrome"

IKST_BriefingUI = ISCollapsableWindow:derive("IKST_BriefingUI")
IKST_BriefingUI.instance = nil
IKST_BriefingUI._cache = IKST_BriefingUI._cache or nil

function IKST_BriefingUI:new(x, y, w, h)
    w = w or 640
    h = h or 480
    local o = ISCollapsableWindow:new(x, y, w, h)
    setmetatable(o, self)
    self.__index = self
    o.player = nil
    o.activeId = nil
    o.pin = true
    o.resizable = true
    IKST_Chrome.applyPanelColors(o)
    return o
end

function IKST_BriefingUI:doDrawItem(y, item, alt)
    if not item or not item.item then
        return y
    end
    local c = IKST_Chrome.colors
    if self.selected == item.index then
        self:drawRect(0, y, self:getWidth(), self.itemheight, 0.35, c.accentDim.r, c.accentDim.g, c.accentDim.b)
    end
    self:drawText(item.item.title or "?", 8, y + 4, c.textPrimary.r, c.textPrimary.g, c.textPrimary.b, 1, UIFont.Small)
    return y + self.itemheight
end

function IKST_BriefingUI:createChildren()
    ISCollapsableWindow.createChildren(self)
    local top = self:titleBarHeight()
    local listW = 180
    local listH = self.height - top - 36

    self.listBox = ISScrollingListBox:new(0, top, listW, listH)
    self.listBox:initialise()
    self.listBox.itemheight = getTextManager():getFontHeight(UIFont.Small) + 6
    self.listBox.font = UIFont.Small
    self.listBox.doDrawItem = IKST_BriefingUI.doDrawItem
    self.listBox:setOnMouseDownFunction(self, IKST_BriefingUI.onSelectSection)
    self:addChild(self.listBox)

    self.body = ISRichTextPanel:new(listW, top, self.width - listW, listH)
    self.body:initialise()
    self.body.autosetheight = false
    self.body.clip = true
    self.body.backgroundColor = { r = 0, g = 0, b = 0, a = 0.35 }
    self.body:paginate()
    self:addChild(self.body)
    self.body:addScrollBars()

    self.closeBtn = ISButton:new(self.width - 100, self.height - 30, 90, 22,
        IKST.text("UI_btn_close", "Close"), self, IKST_BriefingUI.onClose)
    self.closeBtn:initialise()
    IKST_Chrome.styleSecondaryButton(self.closeBtn)
    self:addChild(self.closeBtn)
end

function IKST_BriefingUI:onSelectSection(section)
    if not section or not section.id then
        return
    end
    self.activeId = section.id
    self:showSection(section.id)
end

function IKST_BriefingUI:showSection(sectionId)
    if not self.body or not IKST_BriefingUI._cache then
        return
    end
    for _, row in ipairs(IKST_BriefingUI._cache.sections or {}) do
        if row.id == sectionId then
            self.body.text = row.body or ""
            self.body:paginate()
            return
        end
    end
end

function IKST_BriefingUI:refreshList()
    if not self.listBox then
        return
    end
    self.listBox:clear()
    local cache = IKST_BriefingUI._cache
    if not cache or not cache.sections then
        return
    end
    for _, row in ipairs(cache.sections) do
        self.listBox:addItem(row.title or row.id, row)
    end
    local activeId = self.activeId or cache.activeId
    for i = 0, self.listBox:size() - 1 do
        local item = self.listBox.items[i + 1]
        if item and item.item and item.item.id == activeId then
            self.listBox.selected = i + 1
            break
        end
    end
    if activeId then
        self:showSection(activeId)
    end
end

function IKST_BriefingUI:onClose()
    self:setVisible(false)
    self:removeFromUIManager()
    IKST_BriefingUI.instance = nil
end

function IKST_BriefingUI:initialise()
    ISCollapsableWindow.initialise(self)
    self:setTitle(IKST.text("IGUI_IKST_Briefing_Title", "Server Briefing"))
end

function IKST_BriefingUI:open(player)
    if not IKST_Briefing.enabled() then
        return
    end
    player = IKST.resolvePlayer(player)
    if not player then
        return
    end
    if IKST_BriefingUI.instance then
        IKST_BriefingUI.instance:setVisible(true)
        IKST_BriefingUI.instance:addToUIManager()
        return
    end
    local sw = getCore():getScreenWidth()
    local sh = getCore():getScreenHeight()
    local ui = IKST_BriefingUI:new((sw - 640) / 2, (sh - 480) / 2, 640, 480)
    ui.player = player
    ui:initialise()
    ui:addToUIManager()
    IKST_BriefingUI.instance = ui
    if IKST_BriefingUI._cache then
        ui:refreshList()
    else
        IKST.dispatchCommand(player, IKST.CMD.briefingFetch, {})
    end
end

function IKST_BriefingUI.onResult(args)
    if not args or not args.sections then
        return
    end
    IKST_BriefingUI._cache = args
    if IKST_BriefingUI.instance then
        IKST_BriefingUI.instance.activeId = args.activeId
        IKST_BriefingUI.instance:refreshList()
    end
end
