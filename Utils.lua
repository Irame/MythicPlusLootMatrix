---@class MPLM_Private
local private = select(2, ...)

-- const tables

private.statsShortened = {
    ITEM_MOD_CRIT_RATING_SHORT = "Crit.",
    ITEM_MOD_HASTE_RATING_SHORT = "Haste",
    ITEM_MOD_MASTERY_RATING_SHORT = "Mast.",
    ITEM_MOD_VERSATILITY = "Vers.",
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

-- db utils

local function GetDefaults()
    local dbDefaults = {
        char = {
            slotsActivePerClassSpec = {
                ["*"] = {}
            },
            stat1SearchValue = nil,
            stat2SearchValue = nil,
        }
    }

    for slot in pairs(private.slotFilterToSlotName) do
        if slot ~= Enum.ItemSlotFilterType.Other then
            dbDefaults.char.slotsActivePerClassSpec["*"][slot] = true
        end
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
    local slotsActive = self.db.char.slotsActivePerClassSpec[key]
    for index in pairs(slotsActive) do
        slotsActive[index] = value
    end
end
