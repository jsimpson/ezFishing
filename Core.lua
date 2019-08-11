--------------------------------------------------------------------------------
-- Constants
--------------------------------------------------------------------------------

local config = {
    autoArcaneLure = true,
    autoLure       = true,
    autoLoot       = true,
    enhanceSounds  = true,
}

local fishingSkill     = GetSpellInfo(7620)
local mainHandSlot     = 16
local arcaneLureItemId = 139175

local cvarOverrides = {
    enhanceSounds = {
        Sound_MasterVolume   = 1.0,
        Sound_SFXVolume      = 1.0,
        Sound_MusicVolume    = 0.0,
        Sound_AmbienceVolume = 0.0,
    },
    always = {
        autointeract = 0,
    },
    autoLoot = {
        autoLootDefault = 1,
    },
}

local poles = {
    [  6256] = true, -- Fishing Pole
    [  6365] = true, -- Strong Fishing Pole
    [  6366] = true, -- Darkwood Fishing Pole
    [  6367] = true, -- Big Iron Fishing Pole
    [ 12225] = true, -- Blump Family Fishing Pole
    [ 19022] = true, -- Nat Pagle's Extreme Angler FC-5000
    [ 19970] = true, -- Arcanite Fishing Pole
    [ 25978] = true, -- Seth's Graphite Fishing Pole
    [ 44050] = true, -- Mastercraft Kalu'ak Fishing Pole
    [ 45858] = true, -- Nat's Lucky Fishing Pole
    [ 45991] = true, -- Bone Fishing Pole
    [ 45992] = true, -- Jeweled Fishing Pole
    [ 46337] = true, -- Staats' Fishing Pole
    [ 52678] = true, -- Jonathan's Fishing Pole
    [ 84660] = true, -- Pandaren Fishing Pole
    [ 84661] = true, -- Dragon Fishing Pole
    [116825] = true, -- Savage Fishing Pole
    [116826] = true, -- Draenic Fishing Pole
    [118381] = true, -- Ephemeral Fishing Pole
    [120163] = true, -- Thruk's Fishing Rod
    [133755] = true, -- Underlight Angler
}

local lures = {
    -- [Item Id] = { required skill, bonus, duration(m) }
    [  6529] = {   0,   3, 10 }, -- Shiny Bauble
    [  6530] = {  50,   5, 10 }, -- Nightcrawlers
    [  6532] = { 100,   7, 10 }, -- Bright Baubles
    [  6533] = { 100,   9, 10 }, -- Aquadynamic Fish Attractor
    [  6811] = {  50,   5, 10 }, -- Aquadynamic Fish Lens
    [  7307] = { 100,   7, 10 }, -- Flesh Eating Worm
    [ 33820] = {   0,   7, 10 }, -- Weather-Beaten Fishing Hat
    [ 34861] = {   1,   9, 10 }, -- Sharpened Fish Hook
    [ 46006] = {   1,   9, 60 }, -- Glow Worm
    [ 62673] = {  75,   9, 10 }, -- Feathered Lure
    [ 67404] = {   0,   2, 10 }, -- Glass Fishing Bobber
    [ 68049] = {   1,  10, 15 }, -- Heat-Treated Spinning Lure
    [ 88710] = {   0,  10, 10 }, -- Nat's Hat
    [116825] = {   0,  10, 10 }, -- Savage Fishing Pole
    [116826] = {   0,  10, 10 }, -- Draenic Fishing Pole
    [117405] = {   0,  10, 10 }, -- Nat's Drinking Hat
    [118391] = { 100,  10, 10 }, -- Worm Supreme
    [124674] = {   1,  10, 10 }, -- Day-Old Darkmoon Doughnut
}

--------------------------------------------------------------------------------
-- Lure handling
--------------------------------------------------------------------------------

function BuffSearch(target, spellName)
    for i = 1, 40 do
        local name, _, _, _, _, _ = UnitBuff(target, i);
        if name and name == spellName then return true end
    end
    return false
end

local function GetFishingSkill()
    local _, _, _, fishing, _, _ = GetProfessions()
    local name, _, rank, _, _, _, _, modifier = GetProfessionInfo(fishing)
    return (rank or 0) + (modifier or 0)
end

local function GetBestLure()
    local skill, lure
    local score = 0
    for itemId, info in pairs(lures) do
        if GetItemCount(itemId) > 0 then
            local requiredSkill, bonus, duration = unpack(info)
            local thisScore = bonus * duration
            skill = skill or GetFishingSkill()
            if skill >= requiredSkill and thisScore > score then
                lure, score = itemId, thisScore
            end
        end
    end
    return lure
end

--------------------------------------------------------------------------------
-- teh frame
--------------------------------------------------------------------------------

local frame = CreateFrame("Frame")
frame:Hide()

--------------------------------------------------------------------------------
-- Core
--------------------------------------------------------------------------------

local button = CreateFrame("Button", "ezFishingButton", UIParent, "SecureActionButtonTemplate")
button:EnableMouse(true)
button:SetFrameStrata("LOW")
button:RegisterForClicks("RightButtonUp")
button:SetPoint("TOP", UIParent, "BOTTOM", 0, -5)

button:SetScript("PreClick", function(self)
    if UnitCastingInfo("player") then return end

    if config.autoArcaneLure and not BuffSearch("player", "Arcane Lure") then
        if GetItemCount(arcaneLureItemId) > 0 then
          self:SetAttribute("type", "item")
          self:SetAttribute("item", "item:"..arcaneLureItemId)
          return
        end
    end

    if config.autoLure and not GetWeaponEnchantInfo() then
        local lure = GetBestLure()
        if lure then
            if GetItemCooldown(lure) == 0 then
                self:SetAttribute("type", "item")
                self:SetAttribute("item", "item:"..lure)
                self:SetAttribute("target-slot", INVSLOT_MAINHAND)
            end
            return
        end
    end

    local fishingMacroIndex = GetMacroIndexByName(fishingSkill)
    if fishingMacroIndex ~= 0 then
        self:SetAttribute("type", "macro")
        self:SetAttribute("macro", fishingMacroIndex)
    else
        self:SetAttribute("type", "spell")
        self:SetAttribute("spell", fishingSkill)
    end
end)

button:SetScript("PostClick", function(self)
    ClearOverrideBindings(frame)
    self:SetAttribute("type", nil)
    self:SetAttribute("item", nil)
    self:SetAttribute("target-slot", nil)
    self:SetAttribute("spell", nil)
    self:SetAttribute("macro", nil)
end)

local lastClickTime = 0
local function OnMouseDown_Hook(_, button)
    if frame:IsShown() and button == "RightButton" then
        local now = GetTime()
        local delay = now - lastClickTime
        lastClickTime = now
        if delay < 0.4 then
            SetOverrideBindingClick(frame, true, "BUTTON2", "ezFishingButton")
        end
    end
end

--------------------------------------------------------------------------------
-- Enabling/disabling fishing mode
--------------------------------------------------------------------------------

local cvarBackup = {}

local function OverrideCVars(values)
    for name, value in pairs(values) do
        local currentValue = tonumber(GetCVar(name))
        if currentValue ~= value then
            cvarBackup[name] = currentValue
            SetCVar(name, value)
        end
    end
end

frame:SetScript('OnShow', function(self)
    OverrideCVars(cvarOverrides.always)
    if config.autoLoot then
        OverrideCVars(cvarOverrides.autoLoot)
    end
    if config.enhanceSounds then
        OverrideCVars(cvarOverrides.enhanceSounds)
    end
end)

frame:SetScript('OnHide', function(self)
  ClearOverrideBindings(frame)
  for name, value in pairs(cvarBackup) do
      SetCVar(name, value)
  end
  wipe(cvarBackup)
end)

function frame:CheckActivation()
    if not InCombatLockdown() then
        local mainHandId = tonumber(GetInventoryItemID("player", INVSLOT_MAINHAND) or nil)
        if mainHandId and poles[mainHandId] then
            self:Show()
            return
        end
    end
    self:Hide()
end

--------------------------------------------------------------------------------
-- Event handling
--------------------------------------------------------------------------------

frame:SetScript('OnEvent', function(self, event, ...)
    if type(self[event]) == "function" then
        return self[event](self, event, ...)
    else
        print("ezFishing: no handler for ", event)
    end
end)

function frame:UNIT_INVENTORY_CHANGED(_, unit)
    if unit == 'player' then
        self:CheckActivation()
    end
end

function frame:ADDON_LOADED(_, addon)
    if addon:lower() ~= "ezfishing" then return end
    self:UnregisterEvent('ADDON_LOADED')
    WorldFrame:HookScript('OnMouseDown', OnMouseDown_Hook)
    self:CheckActivation()
end

frame.PLAYER_LOGOUT = frame.Hide
frame.PLAYER_REGEN_DISABLED = frame.Hide
frame.PLAYER_REGEN_ENABLED = frame.CheckActivation

frame:RegisterEvent('PLAYER_LOGOUT')
frame:RegisterEvent('PLAYER_REGEN_DISABLED')
frame:RegisterEvent('PLAYER_REGEN_ENABLED')
frame:RegisterEvent('UNIT_INVENTORY_CHANGED')
frame:RegisterEvent('ADDON_LOADED')
