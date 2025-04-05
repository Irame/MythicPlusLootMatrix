---@class MPLM_Private
local private = select(2, ...)

---@class ItemButtonContainer
---@field buttons MPLM_ItemButton[]
local ItemButtonContainer = {}

---@param maxCols integer
---@param maxRows integer
---@param parent Frame
---@param dungeonHeader MPLM_DungeonHeader
---@param slotHeader MPLM_SlotHeader
function ItemButtonContainer:Init(maxCols, maxRows, parent, dungeonHeader, slotHeader)
    self.maxCols = maxCols
    self.maxRows = maxRows

    self.parent = parent
    self.dungeonHeader = dungeonHeader
    self.slotHeader = slotHeader
end

function ItemButtonContainer:AddButton(button)
    if not button then return end

    button:SetParent(self.parent)

    button:ClearAllPoints()
    button:Show()

    tinsert(self.buttons, button)
end

function ItemButtonContainer:RemoveButton(button)
    if #self.buttons == 0 then return end

    button:SetParent(nil)

    for i, b in ipairs(self.buttons) do
        if b == button then
            tremove(self.buttons, i)
            break
        end
    end
end

function ItemButtonContainer:Reset()
    for _, button in ipairs(self.buttons) do
        button:SetParent(nil)
    end

    wipe(self.buttons)
end

function ItemButtonContainer:DoLayout()
    if not self.parent or not self.dungeonHeader or not self.slotHeader then return end

    local parentLeft, parentBottom, parentWidth, parentHeight = self.parent:GetRect()
    local dungeonHeaderLeft, dungeonHeaderBottom, dungeonHeaderWidth, dungeonHeaderHeight = self.dungeonHeader:GetRect()
    local slotHeaderLeft, slotHeaderBottom, slotHeaderWidth, slotHeaderHeight = self.slotHeader:GetRect()

    local width, height = slotHeaderWidth - 5, dungeonHeaderHeight - 5
    local itemIconSize = math.min(width/self.maxCols, height/self.maxRows)
    local centerX = slotHeaderLeft + 5 + width / 2 - parentLeft
    local centerY = dungeonHeaderBottom + height / 2 - parentBottom

    local buttonCount = #self.buttons
    local cols = math.min(math.ceil(math.sqrt(buttonCount)), self.maxCols)
    local rows = math.min(math.ceil(buttonCount / cols), self.maxRows)

    local startX = centerX - ((cols - 1) * itemIconSize) / 2
    local startY = centerY + ((rows - 1) * itemIconSize) / 2

    for i, button in ipairs(self.buttons) do
        button:SetSize(itemIconSize, itemIconSize)

        local col = (i - 1) % cols
        local row = math.floor((i - 1) / cols)

        local x = startX + col * itemIconSize
        local y = startY - row * itemIconSize

        button:SetPoint("CENTER", self.parent, "BOTTOMLEFT", x, y)
    end
end

private.ctor.ItemButtonContainer = function()
    return setmetatable({
        buttons = {},
        maxCols = 0,
        maxRows = 0,
    }, { __index = ItemButtonContainer }) --[[@as ItemButtonContainer]]
end
