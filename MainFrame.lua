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
---@field SetPortraitToAsset fun(self, texturePath: string)
---@field Stat1Search any
---@field Stat2Search any
MPLM_MainFrameMixin = {}

function MPLM_MainFrameMixin:OnLoad()
    self:SetPortraitToAsset([[Interface\EncounterJournal\UI-EJ-PortraitIcon]]);

    self:RegisterEvent("EJ_LOOT_DATA_RECIEVED")

    self.dungeonHeaderPool = CreateFramePool("Frame", self, "MPLM_DungeonHeaderTemplate")
    self.slotHeaderPool = CreateFramePool("Frame", self, "MPLM_SlotHeaderTemplate")
    self.itemButtonPool = CreateFramePool("Button", self, "MPLM_ItemButtonTemplate", function(pool, button) button:Reset() end)

    ---@type table<number, EncounterJournalItemInfo>
    self.itemCache = {}

    ---@type table<number, {index: number, instanceId: number}>
    self.unloadedItems = {}

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
        local itemID = ...;
        local unloadedItemInfo = self.unloadedItems[itemID]
        if unloadedItemInfo then
            EJ_SelectInstance(unloadedItemInfo.instanceId)
            local lootInfo = C_EncounterJournal.GetLootInfoByIndex(unloadedItemInfo.index)
            if lootInfo and lootInfo.name then
                private.addon:Print("Received loot data: " .. lootInfo.name)
                self.itemCache[lootInfo.itemID] = lootInfo
                self.unloadedItems[itemID] = nil
            end
        end
    end
end

function MPLM_MainFrameMixin:DoScan()
    self.dungeonInfos = self:ScanDungeons()
    self:BuildMatrix()
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

function MPLM_MainFrameMixin:BuildMatrix()
    self.dungeonHeaderPool:ReleaseAll()
    self.slotHeaderPool:ReleaseAll()
    self.itemButtonPool:ReleaseAll()

    local currentYOffset = -95
    local dungeonToYOffset = {}
    for i, dungeonInfo in ipairs(self.dungeonInfos) do
        local dungeonHeader = self.dungeonHeaderPool:Acquire() --[[@as MPLM_DungeonHeader]]
        dungeonHeader:SetHeight(69)
        dungeonHeader:SetPoint("TOPLEFT", self, "TOPLEFT", 10, currentYOffset)
        dungeonHeader:SetPoint("RIGHT", -10, 0)
        dungeonHeader:Init(dungeonInfo)
        dungeonHeader:Show()

        dungeonToYOffset[dungeonInfo.id] = currentYOffset - 5
        currentYOffset = currentYOffset - dungeonHeader:GetHeight()
    end

	local isLootSlotPresent = self:GetLootSlotsPresent();
    local currentXOffset = 75
    local slotToXOffset = {}
    for filter, name in pairs(SlotFilterToSlotName) do
        if isLootSlotPresent[filter] then
            local slotHeader = self.slotHeaderPool:Acquire() --[[@as MPLM_SlotHeader]]
            slotHeader.Label:SetText(name)
            slotHeader:SetWidth(69)
            slotHeader:SetPoint("TOPLEFT", currentXOffset, -90)
            slotHeader:SetPoint("BOTTOM", 0, 10)
            slotHeader:Show()

            slotToXOffset[filter] = currentXOffset + 5
            currentXOffset = currentXOffset + slotHeader:GetWidth()
        end
    end

    local itemButtons = {}
    for i, dungeonInfo in ipairs(self.dungeonInfos) do
        local dungeonYOffset = dungeonToYOffset[dungeonInfo.id]

        for j, itemId in ipairs(dungeonInfo.loot) do
            local itemInfo = self.itemCache[itemId]

            if itemInfo then
                local matrixKey = tostring(i)..','..tostring(itemInfo.filterType);
                local currentButtons = itemButtons[matrixKey]
                if not currentButtons then
                    currentButtons = {}
                    itemButtons[matrixKey] = currentButtons
                end

                local itemButton = self.itemButtonPool:Acquire() --[[@as MPLM_ItemButton]]
                itemButton:Init(itemInfo)

                local xOffset = slotToXOffset[itemInfo.filterType] + ((#currentButtons)%2 * 32)
                local yOffset = dungeonYOffset - (math.floor((#currentButtons)/2) * 32)
                itemButton:SetPoint("TOPLEFT", self, "TOPLEFT", xOffset, yOffset)
                itemButton:Show()

                tinsert(currentButtons, itemButton)
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
                else
                    --private.addon:Print("Wait for loot data: " .. lootInfo.itemID)
                    self.unloadedItems[lootInfo.itemID] = {
                        index = i,
                        instanceId = instanceId,
                    }
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
