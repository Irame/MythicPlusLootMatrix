---@class MPLM_Private
local private = select(2, ...)

private.ctor = {}

-- const tables

private.statsShortened = {
    ITEM_MOD_CRIT_RATING_SHORT = "Crit.",
    ITEM_MOD_HASTE_RATING_SHORT = "Haste",
    ITEM_MOD_MASTERY_RATING_SHORT = "Mast.",
    ITEM_MOD_VERSATILITY = "Vers.",
}

---@type table<integer, string>
private.dungeonShorthands = {
    [1272] = "BREW",
    [1210] = "DFC",
    [1267] = "PSF",
    [1268] = "ROOK",
    [1298] = "FLOOD",
    [1187] = "TOP",
    [1178] = "WORK",
    [1012] = "ML",
}

---@type table<Enum.ItemSlotFilterType, integer[]>
private.slotFilterToSlotIDs = {
    [Enum.ItemSlotFilterType.Head] = {1},
    [Enum.ItemSlotFilterType.Neck] = {2},
    [Enum.ItemSlotFilterType.Shoulder] = {3},
    [Enum.ItemSlotFilterType.Chest] = {5},
    [Enum.ItemSlotFilterType.Waist] = {6},
    [Enum.ItemSlotFilterType.Legs] = {7},
    [Enum.ItemSlotFilterType.Feet] = {8},
    [Enum.ItemSlotFilterType.Wrist] = {9},
    [Enum.ItemSlotFilterType.Hand] = {10},
    [Enum.ItemSlotFilterType.Finger] = {11, 12},
    [Enum.ItemSlotFilterType.Trinket] = {13, 14},
    [Enum.ItemSlotFilterType.Cloak] = {15},
    [Enum.ItemSlotFilterType.MainHand] = {16},
    [Enum.ItemSlotFilterType.OffHand] = {17},
}

private.slotFilterToSlotName = {
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

private.slotFilterOrdered = {
    Enum.ItemSlotFilterType.Head,
    Enum.ItemSlotFilterType.Neck,
    Enum.ItemSlotFilterType.Shoulder,
    Enum.ItemSlotFilterType.Cloak,
    Enum.ItemSlotFilterType.Chest,
    Enum.ItemSlotFilterType.Wrist,
    Enum.ItemSlotFilterType.Hand,
    Enum.ItemSlotFilterType.Waist,
    Enum.ItemSlotFilterType.Legs,
    Enum.ItemSlotFilterType.Feet,
    Enum.ItemSlotFilterType.Finger,
    Enum.ItemSlotFilterType.Trinket,
    Enum.ItemSlotFilterType.MainHand,
    Enum.ItemSlotFilterType.OffHand,
}

-- db utils

local function GetDefaults()
    local dbDefaults = {
        char = {
            slotsActivePerClassSpec = {
                ["*"] = {}
            },
            stat1SearchValue = nil,
            stat2SearchValue = nil,
        },
        global = {
            useShortDungeonNames = false,
        },
    }

    for i, filter in ipairs(private.slotFilterOrdered) do
        dbDefaults.char.slotsActivePerClassSpec["*"][filter] = true
    end

    return dbDefaults
end

function private:IntiializeDatabase()
    self.db = LibStub("AceDB-3.0"):New("MythicPlusLootMatrixDB", GetDefaults(), true)
end

local function GetActiveSlotKey(classId, specId)
    local _, playerClassId = UnitClassBase("player")
    if playerClassId == classId then
        return tostring(classId).."-"..tostring(specId)
    else
        return "other"
    end
end

function private:IsSlotActive(slot)
    local key = GetActiveSlotKey(EJ_GetLootFilter())
    return self.db.char.slotsActivePerClassSpec[key][slot]
end

function private:SetSlotActive(slot, value)
    local key = GetActiveSlotKey(EJ_GetLootFilter())
    self.db.char.slotsActivePerClassSpec[key][slot] = value
end

function private:SetAllSlotsActive(value)
    local key = GetActiveSlotKey(EJ_GetLootFilter())
    for i, filter in ipairs(private.slotFilterOrdered) do
        self.db.char.slotsActivePerClassSpec[key][filter] = value
    end
end

--- other utils

---@class StatInfo
---@field statKey string
---@field statName string
---@field value number

---@param itemLink any
---@return StatInfo[]
function private:GetSortedStatsInfo(itemLink)
    local stats = C_Item.GetItemStats(itemLink)

    if not stats then
        return {}
    end

    local statInfo = {}
    for stat, value in pairs(stats) do
        local statName = private.statsShortened[stat]
        if statName then
            tinsert(statInfo, {
                statKey = stat,
                statName = statName,
                value = value,
            })
        end
    end

    table.sort(statInfo, function(a, b) return a.value > b.value end)

    return statInfo
end
