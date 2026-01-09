require "ISUI/ISPanel"
require "ISUI/ISComboBox"
require "ISUI/ISModalDialog"
require "AreaSystem/Definitions"

ISShapeEditor = ISPanel:derive("ISShapeEditor")

function ISShapeEditor:initialise()
    ISPanel.initialise(self)
    self:createChildren()
end

function ISShapeEditor:createChildren()
    self.title = "Shape Editor"
    
    -- Close
    self.closeButton = ISButton:new(self.width - 20, 5, 15, 15, "X", self, self.onClose)
    self.closeButton:initialise()
    self.closeButton.borderColor = {r=0, g=0, b=0, a=0}
    self:addChild(self.closeButton)

    -- Info
    self.infoLabel = ISLabel:new(10, 32, 20, "Area:", 1, 1, 1, 1, UIFont.NewSmall, true)
    self:addChild(self.infoLabel)
    
    self.areaCombo = ISComboBox:new(10, 50, self.width - 20, 20, self, self.onSelectArea)
    self.areaCombo:initialise()
    self:addChild(self.areaCombo)

    local areas = AreaSystem.Client.Data.Areas
    local sortedAreas = {}
    for id, area in pairs(areas) do
        table.insert(sortedAreas, area)
    end
    table.sort(sortedAreas, function(a,b) return a.name < b.name end)

    for _, area in ipairs(sortedAreas) do
        self.areaCombo:addOptionWithData(area.name, area.id)
    end
    
    if self.shape then
        self.areaCombo:selectData(self.shape.areaId)
    end

    -- Actions
    self.deleteBtn = ISButton:new(10, self.height - 35, 80, 25, "Delete", self, self.onDelete)
    self.deleteBtn:initialise()
    self:addChild(self.deleteBtn)
end

function ISShapeEditor:onSelectArea()
    local areaId = self.areaCombo:getOptionData(self.areaCombo.selected)
    if self.shape and areaId then
        self.shape.areaId = areaId
        AreaSystem.Client.UpdateShape(self.shape)
    end
end

function ISShapeEditor:onDelete()
    if self.shape then
        local modal = ISModalDialog:new(0, 0, 250, 150, "Are you sure you want to delete this shape?", true, self, self.onConfirmDelete)
        modal:initialise()
        modal:setAlwaysOnTop(true)
        modal:addToUIManager()
    end
end

function ISShapeEditor:onConfirmDelete(button)
    if button.internal == "YES" then
        if self.shape then
            AreaSystem.Client.RemoveShape(self.shape.id)
            self:onClose()
        end
    end
end

function ISShapeEditor:onClose()
    self:setVisible(false)
    self:removeFromUIManager()
end

function ISShapeEditor:prerender()
    self:drawRect(0, 0, self.width, self.height, self.backgroundColor.a, self.backgroundColor.r, self.backgroundColor.g, self.backgroundColor.b)
    self:drawRectBorder(0, 0, self.width, self.height, self.borderColor.a, self.borderColor.r, self.borderColor.g, self.borderColor.b)
    self:drawText(self.title, self.width / 2 - (getTextManager():MeasureStringX(UIFont.Medium, self.title) / 2), 10, 1, 1, 1, 1, UIFont.Medium)

    if self.shape then
        local x = math.floor(self.shape.x)
        local y = math.floor(self.shape.y)
        local w = math.floor(self.shape.x2 - x)
        local h = math.floor(self.shape.y2 - y)
        
        local txtX = "X: " .. tostring(x)
        local txtY = "Y: " .. tostring(y)
        local txtW = "Width: " .. tostring(w)
        local txtH = "Height: " .. tostring(h)
        
        self:drawText(txtX, 10, 80, 1, 1, 1, 1, UIFont.NewSmall)
        self:drawText(txtY, 120, 80, 1, 1, 1, 1, UIFont.NewSmall)
        self:drawText(txtW, 10, 100, 1, 1, 1, 1, UIFont.NewSmall)
        self:drawText(txtH, 120, 100, 1, 1, 1, 1, UIFont.NewSmall)
    end
end

function ISShapeEditor:new(x, y, width, height, shape)
    local o = {}
    o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o.backgroundColor = {r=0, g=0, b=0, a=0.9}
    o.borderColor = {r=1, g=1, b=1, a=0.5}
    o.shape = shape
    return o
end

-- Static Opener
function AreaSystem.OpenShapeEditor(shape)
    if not shape then return end
    
    if ISAreaEditor.instance and ISAreaEditor.instance:isVisible() then
        ISAreaEditor.instance:onClose()
    end
    
    if ISShapeEditor.instance then
        if ISShapeEditor.instance.onClose then
            ISShapeEditor.instance:onClose()
        else
            ISShapeEditor.instance:setVisible(false)
            ISShapeEditor.instance:removeFromUIManager()
        end
    end
    
    local x = getPlayerScreenLeft(0) + 200
    local y = 200
    
    -- Snap to Area Manager
    if ISAreaManager.instance and ISAreaManager.instance:isVisible() then
        x = ISAreaManager.instance:getX() + ISAreaManager.instance:getWidth()
        y = ISAreaManager.instance:getY()
    end
    
    local ui = ISShapeEditor:new(x, y, 350, 250, shape)
    ui:initialise()
    ui:setAlwaysOnTop(true)
    ui:addToUIManager()
    ISShapeEditor.instance = ui
end
