---@type string
local addonName = ...

---@class MPLM_Private
local private = select(2, ...)

---@class MPLM : AceAddon, AceConsole-3.0
local addon = LibStub("AceAddon-3.0"):NewAddon(addonName, "AceConsole-3.0")
private.addon = addon

---@type MPLM_MainFrame
MPLM_MainFrame = MPLM_MainFrame

function addon:OnInitialize()
    self:RegisterChatCommand("mplm", "ChatCommandHandler");

    local dbDefaults = {
        char = {
            slotActive = {},
            stat1SearchValue = nil,
            stat2SearchValue = nil,
        }
    }

    for filter in pairs(private.slotFilterToSlotName) do
        if filter ~= Enum.ItemSlotFilterType.Other then
            dbDefaults.char.slotActive[filter] = true
        end
    end

    private.db = LibStub("AceDB-3.0"):New("MythicPlusLootMatrixDB", dbDefaults, true)
end

function addon:OnEnable()
    MPLM_MainFrame:Init()
end

function addon:ChatCommandHandler(args)
    private:ToggleMatrixFrame()
end

function MPLM_OnAddonCompartmentClick()
    private:ToggleMatrixFrame()
end

function private:ToggleMatrixFrame()
    MPLM_MainFrame:SetShown(MPLM_MainFrame:IsShown() == false)
end