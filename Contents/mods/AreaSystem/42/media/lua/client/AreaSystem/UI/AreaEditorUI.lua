require "ISUI/ISPanel"
require "ISUI/ISButton"
require "ISUI/ISTextEntryBox"
require "AreaSystem/Definitions"

ISAreaEditor = ISPanel:derive("ISAreaEditor")

function ISAreaEditor:initialise()
    ISPanel.initialise(self)
    self:createChildren()
end

function ISAreaEditor:createChildren()
    self.title = self.area and "Edit Area" or "New Area"
    
    -- Background
    self:drawRect(0, 0, self.width, self.height, 0.8, 0, 0, 0)
    self:drawRectBorder(0, 0, self.width, self.height, 0.5, 1, 1, 1)
    
    -- Name Label
    local lblName = ISLabel:new(10, 30, 20, "Name:", 1, 1, 1, 1, UIFont.NewSmall, true)
    self:addChild(lblName)
    
    -- Name Entry
    self.nameEntry = ISTextEntryBox:new(self.area and self.area.name or "New Area", 60, 28, 200, 20)
    self.nameEntry:initialise()
    self.nameEntry:instantiate()
    -- Autosave hook
    self.nameEntry.onCommandEntered = self.onNameChanged
    -- onOtherKey causes lag in text retrieval (gets text before keyprocess), removed to fix "one letter late" issue
    self.nameEntry.onTextChangeFunction = self.onNameChanged
    self.nameEntry.target = self
    self:addChild(self.nameEntry)
    
    self.selectedColor = self.area and self.area.color or {r=0, g=1, b=0, a=0.3}

    -- Custom Color Palette
    local palette = {
        -- Greyscale
        {r=0, g=0, b=0}, {r=0.2, g=0.2, b=0.2}, {r=0.4, g=0.4, b=0.4}, {r=0.6, g=0.6, b=0.6}, {r=0.8, g=0.8, b=0.8}, {r=1, g=1, b=1},
        
        -- Reds
        {r=0.5, g=0, b=0}, {r=0.75, g=0, b=0}, {r=1, g=0, b=0}, {r=1, g=0.25, b=0.25}, {r=1, g=0.5, b=0.5}, {r=1, g=0.75, b=0.75},
        
        -- Oranges / Browns
        {r=0.4, g=0.2, b=0}, {r=0.6, g=0.3, b=0}, {r=0.8, g=0.4, b=0}, {r=1, g=0.5, b=0}, {r=1, g=0.65, b=0}, {r=1, g=0.8, b=0.4},

        -- Yellows
        {r=0.5, g=0.5, b=0}, {r=0.75, g=0.75, b=0}, {r=1, g=1, b=0}, {r=1, g=1, b=0.25}, {r=1, g=1, b=0.5}, {r=1, g=1, b=0.75},

        -- Greens
        {r=0, g=0.5, b=0}, {r=0, g=0.75, b=0}, {r=0, g=1, b=0}, {r=0.25, g=1, b=0.25}, {r=0.5, g=1, b=0.5}, {r=0.75, g=1, b=0.75},
        
        -- Cyans
        {r=0, g=0.5, b=0.5}, {r=0, g=0.75, b=0.75}, {r=0, g=1, b=1}, {r=0.25, g=1, b=1}, {r=0.5, g=1, b=1}, {r=0.75, g=1, b=1},

        -- Blues
        {r=0, g=0, b=0.5}, {r=0, g=0, b=0.75}, {r=0, g=0, b=1}, {r=0.25, g=0.25, b=1}, {r=0.5, g=0.5, b=1}, {r=0.75, g=0.75, b=1},

        -- Purples / Pinks
        {r=0.5, g=0, b=0.5}, {r=0.75, g=0, b=0.75}, {r=1, g=0, b=1}, {r=1, g=0.25, b=1}, {r=1, g=0.5, b=1}, {r=1, g=0.75, b=1}
    }
    
    local x = 10
    local y = 60
    local boxSize = 20 -- Smaller box to fit more
    local gap = 4
    local cols = 12
    
    for i, col in ipairs(palette) do
        local btn = ISButton:new(x, y, boxSize, boxSize, "", self, self.onPresetColorClicked)
        btn:initialise()
        btn:instantiate()
        btn.backgroundColor = {r=col.r, g=col.g, b=col.b, a=1}
        btn.borderColor = {r=1, g=1, b=1, a=0.5}
        btn.targetColor = col 
        self:addChild(btn)
        
        x = x + boxSize + gap
        if i % cols == 0 then
            x = 10
            y = y + boxSize + gap
        end
    end
end

function ISAreaEditor:onNameChanged()
    -- Resolve context: 'self' can be the editor or the text entry box depending on who calls it
    local editor = self
    if not editor.nameEntry then
        if self.target then 
            editor = self.target 
        elseif self.parent then 
            editor = self.parent 
        end
    end
    
    if not editor or not editor.nameEntry then return end

    local name = editor.nameEntry:getText()
    if not name or name == "" then return end
    
    if editor.area then
        if editor.area.name ~= name then
            editor.area.name = name
            AreaSystem.Client.UpdateArea(editor.area)
        end
    end
end

function ISAreaEditor:onPresetColorClicked(button)
    local col = button.targetColor
    if not col then return end
    
    self.selectedColor = {r=col.r, g=col.g, b=col.b, a = self.selectedColor.a or 0.3}
    
    if self.area then
        self.area.color = self.selectedColor
        AreaSystem.Client.UpdateArea(self.area)
    end
end

function ISAreaEditor:render()
    ISPanel.render(self)
    -- Visualize selected color
    self:drawRect(self.width - 40, 10, 30, 30, 1, self.selectedColor.r, self.selectedColor.g, self.selectedColor.b)
    self:drawRectBorder(self.width - 40, 10, 30, 30, 1, 1, 1, 1)
end

function ISAreaEditor:onClose()
    if ISAreaEditor.instance == self then
        ISAreaEditor.instance = nil
    end
    self:setVisible(false)
    self:removeFromUIManager()
end

function AreaSystem.OpenAreaEditor(area)
    if ISAreaEditor.instance then
        ISAreaEditor.instance:close()
    end
    
    if ISShapeEditor.instance and ISShapeEditor.instance:isVisible() then
        ISShapeEditor.instance:onClose()
    end

    local x = getPlayerScreenLeft(0) + 150
    local y = 150
    
    -- Snap to Area Manager
    if ISAreaManager.instance and ISAreaManager.instance:isVisible() then
        x = ISAreaManager.instance:getX() + ISAreaManager.instance:getWidth()
        y = ISAreaManager.instance:getY()
    end

    local ui = ISAreaEditor:new(x, y, 400, 300)
    ui.area = area
    ui:initialise()
    ui:setAlwaysOnTop(true)
    ui:addToUIManager()
    ISAreaEditor.instance = ui
end

function ISAreaEditor:new(x, y, width, height)
    local o = {}
    o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o.variable = nil
    o.name = nil
    o.backgroundColor = {r=0, g=0, b=0, a=0.9}
    o.borderColor = {r=1, g=1, b=1, a=0.5}
    o.width = width
    o.height = height
    return o
end
