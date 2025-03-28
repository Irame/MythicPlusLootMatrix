---@class MPLM_Private
local private = select(2, ...)

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
---@field Label FontString

---@class MPLM_MainFrame : Frame
---@field Filter Frame
---@field ResizeButton Button
---@field SetPortraitToAsset fun(self, texturePath: string)
---@field Stat1Search any
---@field Stat2Search any
MPLM_MainFrameMixin = {}

function MPLM_MainFrameMixin:OnLoad()
    self:SetPortraitToAsset([[Interface\EncounterJournal\UI-EJ-PortraitIcon]]);

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
end

function MPLM_MainFrameMixin:OnEvent(event, ...)
    if event == "EJ_LOOT_DATA_RECIEVED" then
        if not self.RescanTimer then
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
        self:DoScan()
    end

    ClassMenu.InitClassSpecDropdown(self.Filter, GetClassFilter, GetSpecFilter, SetClassAndSpecFilter);
end

function MPLM_MainFrameMixin:SetupStatSearchDropdown()
    do
        local function IsSelected(value)
            return self.stat1SearchValue == value
        end

        local function SetSelected(value)
            self.stat1SearchValue = value
            self:UpdateSearchGlow()
        end

        self.Stat1Search:SetupMenu(function(dropdown, rootDescription)
            rootDescription:CreateRadio("None", IsSelected, SetSelected, nil);

            for key, shortName in pairs(private.statsShortened) do
                rootDescription:CreateRadio(_G[key], IsSelected, SetSelected, key);
            end
        end);
    end

    do
        local function IsSelected(value)
            return self.stat2SearchValue == value
        end

        local function SetSelected(value)
            self.stat2SearchValue = value
            self:UpdateSearchGlow()
        end

        self.Stat2Search:SetupMenu(function(dropdown, rootDescription)
            rootDescription:CreateRadio("None", IsSelected, SetSelected, nil);

            for key, shortName in pairs(private.statsShortened) do
                rootDescription:CreateRadio(_G[key], IsSelected, SetSelected, key);
            end
        end);
    end
end

function MPLM_MainFrameMixin:UpdateSearchGlow()
    for button in self.itemButtonPool:EnumerateActive() --[[@as fun(): MPLM_ItemButton]] do
        if button.itemInfo.link then
            local stats = C_Item.GetItemStats(button.itemInfo.link)
            local stat1Value = stats[self.stat1SearchValue]
            local stat2Value = stats[self.stat2SearchValue]
            if stat1Value and stat2Value then
                button:ShowStrongHighlight()
            else
                if stat1Value or stat2Value then
                    button:ShowWeakHighlight()
                else
                    button:HideWeakHighlight()
                    button:HideStrongHighlight()
                end
            end
        else
            button:HideStrongHighlight()
            button:HideWeakHighlight()
        end
    end
end

local SlotFilterToSlotName = {
	[Enum.ItemSlotFilterType.Head] = INVTYPE_HEAD,
	[Enum.ItemSlotFilterType.Neck] = INVTYPE_NECK,
	[Enum.ItemSlotFilterType.Shoulder] = INVTYPE_SHOULDER,
	[Enum.ItemSlotFilterType.Cloak] = INVTYPE_CLOAK,
	[Enum.ItemSlotFilterType.Chest] = INVTYPE_CHEST,
	[Enum.ItemSlotFilterType.Wrist] = INVTYPE_WRIST,
	[Enum.ItemSlotFilterType.Hand] = INVTYPE_HAND,
	[Enum.ItemSlotFilterType.Waist] = INVTYPE_WAIST,
	[Enum.ItemSlotFilterType.Legs] = INVTYPE_LEGS,
	[Enum.ItemSlotFilterType.Feet] = INVTYPE_FEET,
	[Enum.ItemSlotFilterType.MainHand] = INVTYPE_WEAPONMAINHAND,
	[Enum.ItemSlotFilterType.OffHand] = INVTYPE_WEAPONOFFHAND,
	[Enum.ItemSlotFilterType.Finger] = INVTYPE_FINGER,
	[Enum.ItemSlotFilterType.Trinket] = INVTYPE_TRINKET,
	[Enum.ItemSlotFilterType.Other] = EJ_LOOT_SLOT_FILTER_OTHER,
}

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
        local dungeonHeader = self.dungeonHeaderPool:Acquire() --[[@as MPLM_DungeonHeader]]
        dungeonHeader:Init(dungeonInfo)

        dungeonToHeader[dungeonInfo.id] = dungeonHeader
        tinsert(matrixFrames.dungeonHeaders, dungeonHeader)
    end

	local isLootSlotPresent = self:GetLootSlotsPresent();
    local slotToHeader = {}
    for filter, name in pairs(SlotFilterToSlotName) do
        if isLootSlotPresent[filter] then
            local slotHeader = self.slotHeaderPool:Acquire() --[[@as MPLM_SlotHeader]]
            slotHeader.Label:SetText(name)

            slotToHeader[filter] = slotHeader
            tinsert(matrixFrames.slotHeaders, slotHeader)
        end
    end

    for i, dungeonInfo in ipairs(self.dungeonInfos) do
        local dungeonHeader = dungeonToHeader[dungeonInfo.id]

        local itemButtonsPerSlot = {}
        for j, itemId in ipairs(dungeonInfo.loot) do
            local itemInfo = self.itemCache[itemId]

            if itemInfo then
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

    return matrixFrames
end

---@param matrixData MatrixFrames
function MPLM_MainFrameMixin:LayoutMatrix(matrixData)
    local availableHeight = self:GetHeight() - 95 - 10;
    local dungenHeight = availableHeight / #matrixData.dungeonHeaders

    local lastDungeonHeader = nil
    for i, dungeonHeader in ipairs(matrixData.dungeonHeaders) do
        dungeonHeader:SetHeight(dungenHeight)
        if lastDungeonHeader then
            dungeonHeader:SetPoint("TOPLEFT", lastDungeonHeader, "BOTTOMLEFT", 0, 0)
        else
            dungeonHeader:SetPoint("TOPLEFT", 10, -95)
        end

        dungeonHeader:SetPoint("RIGHT", -10, 0)
        dungeonHeader:Show()

        lastDungeonHeader = dungeonHeader
    end

    local slotStartX = (dungenHeight-5) + 10;
    local availableWidth = self:GetWidth() - slotStartX - 10;
    local slotWidth = availableWidth / #matrixData.slotHeaders

    local lastSlotHeader = nil
    for i, slotHeader in ipairs(matrixData.slotHeaders) do
        slotHeader:SetWidth(slotWidth)
        if lastSlotHeader then
            slotHeader:SetPoint("TOPLEFT", lastSlotHeader, "TOPRIGHT", 0, 0)
        else
            slotHeader:SetPoint("TOPLEFT", slotStartX, -90)
        end
        slotHeader:SetPoint("BOTTOM", 0, 10)
        slotHeader:Show()

        lastSlotHeader = slotHeader
    end

    local itemSpaceWidth = slotWidth - 5;
    local itemSpaceHeight = dungenHeight - 5;
    local minDimSize = math.min(itemSpaceWidth, itemSpaceHeight)
    local itemIconSize = minDimSize/2

    for dungeonHeader, itemButtonsPerDungeon in pairs(matrixData.itemButtons) do
        for slotHeader, itemButtonsPerCell in pairs(itemButtonsPerDungeon) do
            for k, itemButton in ipairs(itemButtonsPerCell) do
                itemButton:SetSize(itemIconSize, itemIconSize)

                local xOffset = ((k-1)%2 * itemIconSize) + (itemSpaceWidth-minDimSize)/2 + 5
                local yOffset = -(math.floor((k-1)/2) * itemIconSize) - (itemSpaceHeight-minDimSize)/2 - 5
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
