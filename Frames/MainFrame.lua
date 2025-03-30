---@class MPLM_Private
local private = select(2, ...)

local L = private.L

---@class DungeonInfo
---@field id number
---@field index number
---@field name string
---@field image string
---@field loot number[]

---@class MPLM_DungeonHeader : Frame
---@field Image Texture
---@field Label FontString
MPLM_DungeonHeaderMixin = {}

---@param dungeonInfo DungeonInfo
function MPLM_DungeonHeaderMixin:Init(dungeonInfo)
    self.Image:SetTexture(dungeonInfo.image)
    self.Label:SetText(dungeonInfo.name)
end

function MPLM_DungeonHeaderMixin:OnSizeChanged(width, height)
    self.Image:SetWidth(height-5);
end

---@class MPLM_SlotHeader : Frame
---@field EquippedItem1Button MPLM_ItemButton
---@field EquippedItem2Button MPLM_ItemButton
MPLM_SlotHeaderMixin = {}

function MPLM_SlotHeaderMixin:Init(slot)
    self.Label:SetText(private.slotFilterToSlotName[slot])
    local slotIDs = private.slotFilterToSlotIDs[slot]

    if slotIDs[1] then
        local itemLink = GetInventoryItemLink("player", slotIDs[1])
        self.EquippedItem1Button:Init(itemLink)
    else
        self.EquippedItem1Button:Hide()
    end

    self.EquippedItem1Button:ClearAllPoints()
    if slotIDs[2] then
        local itemLink = GetInventoryItemLink("player", slotIDs[2])
        self.EquippedItem2Button:Init(itemLink)
        self.EquippedItem1Button:SetPoint("TOPRIGHT", self, "TOP", 0, -7)
    else
        self.EquippedItem2Button:Hide()
        self.EquippedItem1Button:SetPoint("TOP", 0, -7)
    end
end

---@class MPLM_SlotHeader : Frame
---@field Label FontString

---@class MPLM_MainFrame : Frame
---@field Filter Frame
---@field ResizeButton Button
---@field SetPortraitToAsset fun(self, texturePath: string)
---@field Stat1Search any
---@field Stat2Search any
---@field SlotSelect any
---@field HideOtherItems any
MPLM_MainFrameMixin = {}

function MPLM_MainFrameMixin:OnLoad()
    self:SetPortraitToAsset([[Interface\EncounterJournal\UI-EJ-PortraitIcon]]);

    self.HideOtherItems:SetLabelText(L["Hide Others"])

    self:RegisterEvent("EJ_LOOT_DATA_RECIEVED")

    self.ResizeButton:Init(self, 1100, 670, 1100*1.5, 670*1.5);

    self.dungeonHeaderPool = CreateFramePool("Frame", self, "MPLM_DungeonHeaderTemplate")
    self.slotHeaderPool = CreateFramePool("Frame", self, "MPLM_SlotHeaderTemplate")
    self.itemButtonPool = CreateFramePool("Button", self, "MPLM_ItemButtonTemplate", function(pool, button) button:Reset() end)

    ---@type table<number, EncounterJournalItemInfo>
    self.itemCache = {}

    ---@type DungeonInfo[]
    self.dungeonInfos = {}
end

function MPLM_MainFrameMixin:Init()
    -- this is required for the SpellBookItemAutoCastTemplate to be available
    PlayerSpellsFrame_LoadUI();

    self:SetupFilterDropdown()
    self:SetupStatSearchDropdown()
    self:SetupSlotsDropdown()
    self:SetupHideOtherItemsCheckbox()
end

function MPLM_MainFrameMixin:OnShow()
    if EncounterJournal and EncounterJournal:IsShown() then
        EncounterJournal:Hide()
    end

    self:DoScan()

    if not self.EncounterJournalShowHooked then
        hooksecurefunc(EncounterJournal, "Show", function()
            self:Hide()
        end)
        self.EncounterJournalShowHooked = true
    end
end

function MPLM_MainFrameMixin:OnEvent(event, ...)
    if event == "EJ_LOOT_DATA_RECIEVED" then
        if self:IsShown() and not self.RescanTimer then
            self.RescanTimer = C_Timer.NewTimer(0.2, function()
                self:DoScan()
                self.RescanTimer = nil
            end)
        end
    end
end

function MPLM_MainFrameMixin:OnSizeChanged()
    if self.matrixFrames then
        self:LayoutMatrix(self.matrixFrames)
    end
end

function MPLM_MainFrameMixin:DoScan()
    self.dungeonInfos = self:ScanDungeons()
    self:UpdateMatrix()
end

function MPLM_MainFrameMixin:UpdateMatrix()
    self.matrixFrames = self:BuildMatrix()
    self:LayoutMatrix(self.matrixFrames)
    self:UpdateSearchGlow()
end

function MPLM_MainFrameMixin:SetupFilterDropdown()
    local function GetClassFilter()
        local filterClassID, filterSpecID = EJ_GetLootFilter();
        return filterClassID;
    end

    local function GetSpecFilter()
        local filterClassID, filterSpecID = EJ_GetLootFilter();
        return filterSpecID;
    end

    local function SetClassAndSpecFilter(classID, specID)
        EJ_SetLootFilter(classID, specID);
        if EncounterJournal_OnFilterChanged then
            EncounterJournal_OnFilterChanged(EncounterJournal);
        end
        self.SlotSelect:GenerateMenu()
        self:DoScan()
    end

    ClassMenu.InitClassSpecDropdown(self.Filter, GetClassFilter, GetSpecFilter, SetClassAndSpecFilter);
end

function MPLM_MainFrameMixin:SetupStatSearchDropdown()
    local function UpdateOnSelection()
        if self.hideOtherItems then
            self:UpdateMatrix()
        else
            self:UpdateSearchGlow()
        end
    end

    do
        local function IsSelected(value)
            return private.db.char.stat1SearchValue == value
        end

        local function SetSelected(value)
            private.db.char.stat1SearchValue = value
            UpdateOnSelection()
        end

        self.Stat1Search:SetupMenu(function(dropdown, rootDescription)
            rootDescription:CreateRadio(L["All Stats"], IsSelected, SetSelected, nil);

            for key, shortName in pairs(private.statsShortened) do
                rootDescription:CreateRadio(_G[key], IsSelected, SetSelected, key);
            end
        end);
    end

    do
        local function IsSelected(value)
            return private.db.char.stat2SearchValue == value
        end

        local function SetSelected(value)
            private.db.char.stat2SearchValue = value
            UpdateOnSelection()
        end

        self.Stat2Search:SetupMenu(function(dropdown, rootDescription)
            rootDescription:CreateRadio(L["All Stats"], IsSelected, SetSelected, nil);

            for key, shortName in pairs(private.statsShortened) do
                rootDescription:CreateRadio(_G[key], IsSelected, SetSelected, key);
            end
        end);
    end
end

function MPLM_MainFrameMixin:SetupSlotsDropdown()
    local function IsSelected(slot)
        return private:IsSlotActive(slot)
    end

    local function SetSelected(slot)
        private:SetSlotActive(slot, not private:IsSlotActive(slot))
        self:UpdateMatrix()
    end

    local function SetAllSelect(value)
        private:SetAllSlotsActive(value)
        self:UpdateMatrix()
    end

    self.SlotSelect:SetupMenu(function(dropdown, rootDescription)
        rootDescription:CreateButton(L["Select All"], SetAllSelect, true)
        rootDescription:CreateButton(L["Unselect All"], SetAllSelect, false)

        rootDescription:CreateDivider()

        for filter, name in pairs(private.slotFilterToSlotName) do
            if filter ~= Enum.ItemSlotFilterType.Other then
                rootDescription:CreateCheckbox(name, IsSelected, SetSelected, filter);
            end
        end
    end);
end

function MPLM_MainFrameMixin:SetupHideOtherItemsCheckbox()
    local function HideOtherItemsToggled()
        self.hideOtherItems = not self.hideOtherItems
        self:UpdateMatrix()
    end

	self.HideOtherItems:SetControlChecked(self.hideOtherItems);
	self.HideOtherItems:SetCallback(HideOtherItemsToggled);
end

---@param itemLink string
---@return integer|true|false|nil matchResult 2 = strong match, 1 = weak match, true = all stats match, false = no match, nil = invalid item link
function MPLM_MainFrameMixin:MatchWithStatSearch(itemLink)
    if not itemLink then return nil end

    -- different behaviour if both stat search boxes are set to the same value
    -- then we have a strong match if the higher stat is the selected stat
    -- and a weak match if the lower stat is the selected stat
    if private.db.char.stat1SearchValue and private.db.char.stat1SearchValue == private.db.char.stat2SearchValue then
        local searchValue = private.db.char.stat1SearchValue
        local orderedStats = private:GetSortedStatsInfo(itemLink)
        if orderedStats[1] and orderedStats[1].statKey == searchValue then return 2 end
        if orderedStats[2] and orderedStats[2].statKey == searchValue then return 1 end
        return false
    else
        local stats = C_Item.GetItemStats(itemLink)
        local result = (stats[private.db.char.stat1SearchValue] and 1 or 0) + (stats[private.db.char.stat2SearchValue] and 1 or 0)
        return result > 0 and result or (not private.db.char.stat1SearchValue or not private.db.char.stat2SearchValue)
    end
end

function MPLM_MainFrameMixin:UpdateSearchGlow()
    for button in self.itemButtonPool:EnumerateActive() --[[@as fun(): MPLM_ItemButton]] do
        if button.itemLink then
            local matchResult = self:MatchWithStatSearch(button.itemLink)
            if matchResult == 2 then
                button:ShowStrongHighlight()
            elseif matchResult == 1 then
                button:ShowWeakHighlight()
            else
                button:HideWeakHighlight()
                button:HideStrongHighlight()
            end
        else
            button:HideStrongHighlight()
            button:HideWeakHighlight()
        end
    end
end

function MPLM_MainFrameMixin:GetLootSlotsPresent()
	local isLootSlotPresent = {};
	for i, dungeonInfo in ipairs(self.dungeonInfos) do
        for j, itemId in ipairs(dungeonInfo.loot) do
            local itemInfo = self.itemCache[itemId]
            if itemInfo then
                isLootSlotPresent[itemInfo.filterType] = true;
            end
        end
	end
	return isLootSlotPresent;
end

function MPLM_MainFrameMixin:IsItemVisible(itemInfo)
    return itemInfo
        and itemInfo.filterType
        and itemInfo.link
        and private:IsSlotActive(itemInfo.filterType)
        and (not self.hideOtherItems or self:MatchWithStatSearch(itemInfo.link))
        and true or false
end

---@param dungeonInfo DungeonInfo
function MPLM_MainFrameMixin:HasDungeonVisibleItems(dungeonInfo)
    for i, itemId in ipairs(dungeonInfo.loot) do
        if self:IsItemVisible(self.itemCache[itemId]) then
            return true
        end
    end
end

---@class MatrixFrames
---@field dungeonHeaders MPLM_DungeonHeader[]
---@field slotHeaders MPLM_SlotHeader[]
---@field itemButtons table<MPLM_DungeonHeader, table<MPLM_SlotHeader, MPLM_ItemButton[]>>

function MPLM_MainFrameMixin:BuildMatrix()
    self.dungeonHeaderPool:ReleaseAll()
    self.slotHeaderPool:ReleaseAll()
    self.itemButtonPool:ReleaseAll()

    ---@type MatrixFrames
    local matrixFrames = {
        dungeonHeaders = {},
        slotHeaders = {},
        itemButtons = {},
    }

    local dungeonToHeader = {}
    for i, dungeonInfo in ipairs(self.dungeonInfos) do
        if self:HasDungeonVisibleItems(dungeonInfo) then
            local dungeonHeader = self.dungeonHeaderPool:Acquire() --[[@as MPLM_DungeonHeader]]
            dungeonHeader:Init(dungeonInfo)

            dungeonToHeader[dungeonInfo.id] = dungeonHeader
            tinsert(matrixFrames.dungeonHeaders, dungeonHeader)
        end
    end

	local isLootSlotPresent = self:GetLootSlotsPresent();
    local slotToHeader = {}
    for filter, name in pairs(private.slotFilterToSlotName) do
        if isLootSlotPresent[filter] and private:IsSlotActive(filter) then
            local slotHeader = self.slotHeaderPool:Acquire() --[[@as MPLM_SlotHeader]]
            slotHeader:Init(filter)

            slotToHeader[filter] = slotHeader
            tinsert(matrixFrames.slotHeaders, slotHeader)
        end
    end

    for i, dungeonInfo in ipairs(self.dungeonInfos) do
        local dungeonHeader = dungeonToHeader[dungeonInfo.id]

        if dungeonHeader then
            local itemButtonsPerSlot = {}
            for j, itemId in ipairs(dungeonInfo.loot) do
                local itemInfo = self.itemCache[itemId]

                if self:IsItemVisible(itemInfo) then
                    local slotHeader = slotToHeader[itemInfo.filterType]
                    local currentButtons = itemButtonsPerSlot[slotHeader]
                    if not currentButtons then
                        currentButtons = {}
                        itemButtonsPerSlot[slotHeader] = currentButtons
                    end

                    local itemButton = self.itemButtonPool:Acquire() --[[@as MPLM_ItemButton]]
                    itemButton:Init(itemInfo)

                    tinsert(currentButtons, itemButton)
                end
            end

            matrixFrames.itemButtons[dungeonHeader] = itemButtonsPerSlot
        end
    end

    return matrixFrames
end

---@param matrixData MatrixFrames
function MPLM_MainFrameMixin:LayoutMatrix(matrixData)
    local padding = 10
    local dividerSize = 5
    local topAreaHeight = 90
    local dungeonStartY = topAreaHeight + 5 + 35
    local maxCellSize = 110

    local availableHeight = self:GetHeight() - dungeonStartY - padding;
    local dungenHeight = math.min(maxCellSize, availableHeight / #matrixData.dungeonHeaders)

    local lastDungeonHeader = nil
    for i, dungeonHeader in ipairs(matrixData.dungeonHeaders) do
        dungeonHeader:SetHeight(dungenHeight)
        if lastDungeonHeader then
            dungeonHeader:SetPoint("TOPLEFT", lastDungeonHeader, "BOTTOMLEFT", 0, 0)
        else
            dungeonHeader:SetPoint("TOPLEFT", padding, -dungeonStartY)
        end

        dungeonHeader:SetPoint("RIGHT", -padding, 0)
        dungeonHeader:Show()

        lastDungeonHeader = dungeonHeader
    end

    local slotStartX = (dungenHeight - dividerSize) + padding;
    local availableWidth = self:GetWidth() - slotStartX - padding;
    local slotWidth = math.min(maxCellSize, availableWidth / #matrixData.slotHeaders)

    local lastSlotHeader = nil
    for i, slotHeader in ipairs(matrixData.slotHeaders) do
        slotHeader:SetWidth(slotWidth)
        if lastSlotHeader then
            slotHeader:SetPoint("TOPLEFT", lastSlotHeader, "TOPRIGHT", 0, 0)
        else
            slotHeader:SetPoint("TOPLEFT", slotStartX, -topAreaHeight)
        end
        slotHeader:SetPoint("BOTTOM", 0, padding)
        slotHeader:Show()

        lastSlotHeader = slotHeader
    end

    local itemSpaceWidth = slotWidth - dividerSize;
    local itemSpaceHeight = dungenHeight - dividerSize;
    local minDimSize = math.min(itemSpaceWidth, itemSpaceHeight)
    local itemIconSize = minDimSize/2

    for dungeonHeader, itemButtonsPerDungeon in pairs(matrixData.itemButtons) do
        for slotHeader, itemButtonsPerCell in pairs(itemButtonsPerDungeon) do
            for k, itemButton in ipairs(itemButtonsPerCell) do
                itemButton:SetSize(itemIconSize, itemIconSize)

                local xOffset = ((k-1)%2 * itemIconSize) + (itemSpaceWidth-minDimSize)/2 + dividerSize
                local yOffset = -(math.floor((k-1)/2) * itemIconSize) - (itemSpaceHeight-minDimSize)/2 - dividerSize
                itemButton:SetPoint("LEFT", slotHeader, "LEFT", xOffset, 0)
                itemButton:SetPoint("TOP", dungeonHeader, "TOP", 0, yOffset)
                itemButton:Show()
            end
        end
    end
end

function MPLM_MainFrameMixin:ScanDungeons()
    -- populates EncounterJournal global
    EncounterJournal_LoadUI()

    --Select Dungeons Tab
    EncounterJournal.instanceID = nil
    EncounterJournal.encounterID = nil
    EJ_ContentTab_Select(EncounterJournal.dungeonsTab:GetID())

    --Select Current Season
    local currentSeaonTier = EJ_GetNumTiers()
    EJ_SelectTier(currentSeaonTier)

    C_EncounterJournal.ResetSlotFilter()

    ---@type DungeonInfo[]
    local dungeonInfos = {}

    local imageRelative = nil
    local instanceIdx = 0
    while true do
        instanceIdx = instanceIdx + 1
        local instanceId, instanceName, _, _, _, _, image2 = EJ_GetInstanceByIndex(instanceIdx, false)

        if not instanceId then
            break
        end

        EJ_SelectInstance(instanceId)

        EJ_SetDifficulty(DifficultyUtil.ID.DungeonChallenge)

        --private.addon:Print("Scanning instance: " .. instanceName)

        local itemIds = {}
        for i = 1, EJ_GetNumLoot() do
            local lootInfo = C_EncounterJournal.GetLootInfoByIndex(i)
            if lootInfo and lootInfo.itemID and lootInfo.filterType ~= Enum.ItemSlotFilterType.Other then
                tinsert(itemIds, lootInfo.itemID)

                if lootInfo.name then
                    --private.addon:Print("Found loot: " .. lootInfo.name)
                    self.itemCache[lootInfo.itemID] = lootInfo
                end
            end
        end

        tinsert(dungeonInfos, {
            id = instanceId,
            index = instanceIdx,
            tier = EJ_GetCurrentTier(),
            name = instanceName,
            image = image2,
            loot = itemIds,
        })
    end

    return dungeonInfos
end
