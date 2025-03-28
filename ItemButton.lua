---@class MPLM_Private
local private = select(2, ...)

---@class MPLM_ItemButton : Button
---@field itemInfo EncounterJournalItemInfo
---@field Icon Texture
---@field Border Texture
---@field Stat1 FontString
---@field Stat2 FontString
---@field AutoCastOverlay any
---@field SpellActivationAlert? Frame
MPLM_ItemButtonMixin = {}

---@param itemInfo EncounterJournalItemInfo
function MPLM_ItemButtonMixin:Init(itemInfo)
    self.itemInfo = itemInfo
    self.Icon:SetTexture(itemInfo.icon)

    self:UpdateStats()
    self:UpdateBorder()
    self:CheckItemButtonTooltip();
end

function MPLM_ItemButtonMixin:Reset()
    self.itemInfo = nil
    self:HideStrongHighlight()
    self:HideWeakHighlight()
end

function MPLM_ItemButtonMixin:ShowStrongHighlight()
    self:HideWeakHighlight()
    if not self.SpellActivationAlert then
		ActionButton_SetupOverlayGlow(self)
        local width, height = self:GetSize()
        self.SpellActivationAlert.ProcStartFlipbook:SetSize(width*3.5, height*3.5)
	end

    ActionButton_ShowOverlayGlow(self)
end

function MPLM_ItemButtonMixin:HideStrongHighlight()
    ActionButton_HideOverlayGlow(self)
end

function MPLM_ItemButtonMixin:ShowWeakHighlight()
    self:HideStrongHighlight()
    self.AutoCastOverlay:SetShown(true);
    self.AutoCastOverlay:ShowAutoCastEnabled(true);
end

function MPLM_ItemButtonMixin:HideWeakHighlight()
    self.AutoCastOverlay:ShowAutoCastEnabled(false);
    self.AutoCastOverlay:SetShown(false);
end

function MPLM_ItemButtonMixin:UpdateStats()
    if self.itemInfo.link then
        local stats = C_Item.GetItemStats(self.itemInfo.link)

        local statInfo = {}
        for stat, value in pairs(stats) do
            local statName = private.statsShortened[stat]
            if statName then
                tinsert(statInfo, {statName = statName, value = value})
            end
        end

        table.sort(statInfo, function(a, b) return a.value < b.value end)

        if statInfo[1] then
            self.Stat1:SetText(statInfo[1].statName)
        else
            self.Stat1:SetText("")
        end

        if statInfo[2] then
            self.Stat2:SetText(statInfo[2].statName)
        else
            self.Stat2:SetText("")
        end
    else
        self.Stat1:SetText("")
        self.Stat2:SetText("")
    end
end

function MPLM_ItemButtonMixin:UpdateBorder()
    local _, _, itemQuality = C_Item.GetItemInfo(self.itemInfo.link or self.itemInfo.itemID);
    itemQuality = itemQuality or Enum.ItemQuality.Epic;
    if ( itemQuality == Enum.ItemQuality.Uncommon ) then
        self.Border:SetAtlas("loottab-set-itemborder-green", true);
    elseif ( itemQuality == Enum.ItemQuality.Rare ) then
        self.Border:SetAtlas("loottab-set-itemborder-blue", true);
    elseif ( itemQuality == Enum.ItemQuality.Epic ) then
        self.Border:SetAtlas("loottab-set-itemborder-purple", true);
    end
end

function MPLM_ItemButtonMixin:CheckItemButtonTooltip()
	if GameTooltip:GetOwner() == self and self.itemInfo.link and not self.tooltipHasLink then
		self:ShowItemTooltip();
	end
end

function MPLM_ItemButtonMixin:GetPreviewClassAndSpec()
    local classID, specID = EJ_GetLootFilter();
    if specID == 0 then
        local spec = GetSpecialization();
        if spec and classID == select(3, UnitClass("player")) then
            specID = GetSpecializationInfo(spec, nil, nil, nil, UnitSex("player"));
        else
            specID = -1;
        end
    end
    return classID, specID;
end

function MPLM_ItemButtonMixin:OnUpdate()
    if GameTooltip:IsOwned(self) then
        if IsModifiedClick("DRESSUP") then
            ShowInspectCursor();
        else
            ResetCursor();
        end
    end
end

function MPLM_ItemButtonMixin:ShowItemTooltip()
    if not self.itemInfo then return end

    GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
    -- itemLink may not be available until after a GET_ITEM_INFO_RECEIVED event
    if self.itemInfo.link then
        local classID, specID = self:GetPreviewClassAndSpec();
        GameTooltip:SetHyperlink(self.itemInfo.link, classID, specID);
        self.tooltipHasLink = true
    else
        GameTooltip:SetItemByID(self.itemInfo.itemID);
    end
    GameTooltip_ShowCompareItem();
end

function MPLM_ItemButtonMixin:OnEnter()
    self:ShowItemTooltip()
    self:SetScript("OnUpdate", self.OnUpdate);
end

function MPLM_ItemButtonMixin:OnLeave()
    GameTooltip:Hide();
    self:SetScript("OnUpdate", nil);
    ResetCursor();
end

function MPLM_ItemButtonMixin:OnClick()
    HandleModifiedItemClick(self.itemInfo and self.itemInfo.link);
end

function MPLM_ItemButtonMixin:OnSizeChanged(width, height)
    local minDimSize = math.min(width, height)
    self.Border:SetScale(minDimSize/32)
    self.Icon:SetScale(minDimSize/32)

    if self.SpellActivationAlert then
        self.SpellActivationAlert:SetSize(width * 1.4, height * 1.4)
        self.SpellActivationAlert.ProcStartFlipbook:SetSize(width*3.5, height*3.5)
    end
end
