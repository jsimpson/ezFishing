--------------------------------------------------------------------------------
-- Constants
--------------------------------------------------------------------------------

local defaults = { profile = {
	autoLure = true,
	autoLoot = true,
	enhanceSounds = true,
}}

local fishingSkill = GetSpellInfo(7620)

local mainHandSlot = 16

local cvarOverrides = {
	enhanceSounds = {
		--Sound_MasterVolume = 1.0,
		Sound_SFXVolume = 1.0,
		Sound_MusicVolume = 0.0,
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
    [ 6256] = true, -- Fishing Pole
    [ 6365] = true, -- Strong Fishing Pole
    [ 6366] = true, -- Darkwood Fishing Pole
    [ 6367] = true, -- Big Iron Fishing Pole',quality:1,icon:'INV_Fishingpole_01'};_
    [12225] = true, -- Blump Family Fishing Pole
    [19022] = true, -- Nat Pagle's Extreme Angler FC-5000
    [19970] = true, -- Arcanite Fishing Pole
    [25978] = true, -- Seth's Graphite Fishing Pole
    [44050] = true, -- Mastercraft Kalu'ak Fishing Pole
    [45858] = true, -- Nat's Lucky Fishing Pole
    [45991] = true, -- Bone Fishing Pole
    [45992] = true, -- Jeweled Fishing Pole
}

local lures = {
    -- [Item Id] = { required skill, bonus, duration(m) }
    [ 6529] = {   0,  25, 10 }, -- Shiny Bauble
    [ 6530] = {  50,  50, 10 }, -- Nightcrawlers
    [ 6532] = { 100,  75, 10 }, -- Bright Baubles
    [ 6533] = { 100, 100, 10 }, -- Aquadynamic Fish Attractor
    [ 6811] = {  50,  50, 10 }, -- Aquadynamic Fish Lens
    [ 7307] = { 100,  75, 10 }, -- Flesh Eating Worm
    [34861] = { 100, 100, 10 }, -- Sharpened Fish Hook
    [46006] = { 100, 100, 60 }, -- Glow Worm
}

local db

--------------------------------------------------------------------------------
-- Lure handling
--------------------------------------------------------------------------------

--[[ GetNumSkillLines() and GetSkillLineInfo() both REMOVED in Patch 4.0.1 ]]
local function GetFishingSkill()
    local _, _, _, fishing, _, _ = GetProfessions();
    local name, _, rank, _, _, _, _, modifier = GetProfessionInfo(fishing)
    if (not modifier) then
        return rank
    else
        return rank + modifier
    end
    return 0
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
button:RegisterForClicks("RightButtonUp")
button:SetPoint("TOP", UIParent, "BOTTOM", 0, -5)

button:SetScript("PreClick", function(self)
	if UnitCastingInfo("player") then
		return 
	end
	if db.profile.autoLure and not GetWeaponEnchantInfo() then
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
	if db.profile.autoLoot then
		OverrideCVars(cvarOverrides.autoLoot)
	end
	if db.profile.enhanceSounds then
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
-- Option handling
--------------------------------------------------------------------------------

local options
function GetOptions()
	if not options then	
		options = {
			name = 'ezFishing',
			type = 'group',
			set = function(info, value)
				local shown = frame:IsShown()
				if shown then 
					frame:Hide() 
				end
				db.profile[info[#info]] = value
				if shown then 
					frame:Show() 
				end				
			end,
			get = function(info)
				return db.profile[info[#info]]
			end,
			args = {
				autoLure = {
					name = 'Apply lure',
					desc = 'Automatically apply a lure when need be.',
					type = 'toggle',
				},
				autoLoot = {
					name = 'Autoloot',
					desc = 'Enable autolooting when a fishing pole is equipped.',
					type = 'toggle',
				},
				enhanceSounds = {
					name = 'Enhanced sounds',
					desc = 'Change sound settings to ease fishing when a fishing pole is equipped.',
					type = 'toggle',
				},
			}
		}
	end	
	return options
end	

--------------------------------------------------------------------------------
-- Event handling
--------------------------------------------------------------------------------

frame:SetScript('OnEvent', function(self, event, ...)
	if type(self[event]) == "function" then
		return self[event](self, event, ...)
--@debug@
	else
		print("ezFishing: no handler for ", event)
--@end-debug@
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
	if LibStub and LibStub("AceDB-3.0", true) and LibStub("AceConfigDialog-3.0", true) then
		db = LibStub('AceDB-3.0'):New('ezFishingDB', defaults, true)
		LibStub("AceConfig-3.0"):RegisterOptionsTable('ezFishing', GetOptions)
		LibStub("AceConfigDialog-3.0"):AddToBlizOptions('ezFishing', 'ezFishing')
	else
		db = defaults
	end
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

