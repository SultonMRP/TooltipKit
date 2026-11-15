-- TooltipKit-1.0
-- One place for tooltip kind, secret values, and a second tip under a host.
-- Does not replace GameTooltip:AddLine. Does not call GameTooltip:Show().
-- Does not store fields on the host tooltip.

local MAJOR, MINOR = "TooltipKit-1.0", 1
local Kit = LibStub:NewLibrary(MAJOR, MINOR)
if not Kit then
	return
end

_G.TooltipKit = Kit

local companions = setmetatable({}, { __mode = "k" })
local companionFrames = setmetatable({}, { __mode = "k" })
local listeners = {
	item = {},
	spell = {},
	unit = {},
	aura = {},
	object = {},
	corpse = {},
}
local installed = {}

local ENUM_KEY = {
	item = "Item",
	spell = "Spell",
	unit = "Unit",
	aura = "UnitAura",
	object = "Object",
	corpse = "Corpse",
}

local SCRIPT = {
	item = "OnTooltipSetItem",
	spell = "OnTooltipSetSpell",
	unit = "OnTooltipSetUnit",
}

function Kit:IsSecret(value)
	return issecretvalue ~= nil and issecretvalue(value)
end

function Kit:Text(value)
	if self:IsSecret(value) or type(value) ~= "string" or value == "" then
		return nil
	end
	return value
end

function Kit:DataType(data)
	if type(data) ~= "table" or self:IsSecret(data) then
		return nil
	end
	local ok, value = pcall(function()
		return data.type
	end)
	if not ok or self:IsSecret(value) then
		return nil
	end
	return value
end

local function EnumType(key)
	local name = ENUM_KEY[key]
	local types = Enum and Enum.TooltipDataType
	return types and name and types[name]
end

function Kit:Primary(tip, data)
	if type(data) == "table" then
		return data
	end
	if tip and tip.GetPrimaryTooltipData then
		local ok, primary = pcall(tip.GetPrimaryTooltipData, tip)
		if ok and type(primary) == "table" then
			return primary
		end
	end
end

local function SameType(tip, data, key)
	local want = EnumType(key)
	if not want then
		return false
	end
	local primary = Kit:Primary(tip, data)
	return Kit:DataType(primary) == want
end

function Kit:ItemLink(tip)
	if not tip or not tip.GetItem then
		return nil
	end
	local ok, _, link = pcall(tip.GetItem, tip)
	if not ok then
		return nil
	end
	if self:IsSecret(link) then
		return nil
	end
	if type(link) == "string" and link:find("item:", 1, true) then
		return link
	end
end

function Kit:IsItem(tip, data)
	if SameType(tip, data, "item") then
		return true
	end
	if not tip or not tip.GetItem then
		return false
	end
	local ok, _, link = pcall(tip.GetItem, tip)
	if not ok then
		return false
	end
	if self:IsSecret(link) then
		return true
	end
	return type(link) == "string" and link:find("item:", 1, true) ~= nil
end

function Kit:IsSpell(tip, data)
	return SameType(tip, data, "spell")
end

function Kit:IsAura(tip, data)
	return SameType(tip, data, "aura")
end

function Kit:IsUnit(tip, data)
	return SameType(tip, data, "unit")
end

function Kit:IsObject(tip, data)
	return SameType(tip, data, "object")
end

function Kit:IsMinimap(tip, data)
	local kind = self:DataType(self:Primary(tip, data))
	local types = Enum and Enum.TooltipDataType
	if not types or not kind then
		return false
	end
	return kind == types.MinimapMouseover or kind == types.Minimap
end

function Kit:IsForbidden(tip)
	return not tip or (tip.IsForbidden and tip:IsForbidden())
end

function Kit:IsXLootRow(tip)
	if self:IsForbidden(tip) or tip ~= GameTooltip or not tip.GetOwner then
		return false
	end
	local loaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
	if not loaded or not loaded("XLoot") then
		return false
	end
	local ok, owner = pcall(tip.GetOwner, tip)
	if not ok or not owner or not owner.GetName then
		return false
	end
	local nameOk, name = pcall(owner.GetName, owner)
	if not nameOk or self:IsSecret(name) or type(name) ~= "string" then
		return false
	end
	return name:find("^XLootFrameButton%d") ~= nil
end

function Kit:IsCompanion(tip)
	return companionFrames[tip] == true
end

function Kit:Kind(tip, data)
	if self:IsCompanion(tip) then
		return "companion"
	end
	if self:IsXLootRow(tip) then
		return "xloot"
	end
	if self:IsMinimap(tip, data) then
		return "minimap"
	end
	if self:IsItem(tip, data) then
		return "item"
	end
	if self:IsAura(tip, data) then
		return "aura"
	end
	if self:IsSpell(tip, data) then
		return "spell"
	end
	if self:IsUnit(tip, data) then
		return "unit"
	end
	if self:IsObject(tip, data) then
		return "object"
	end
	return "unknown"
end

-- True only while lines added now will be inside the backdrop the client is about to show.
-- A line added from OnShow or a timer lands outside that backdrop.
function Kit:CanAdd(tip)
	if self:IsForbidden(tip) or self:IsCompanion(tip) then
		return false
	end
	if tip.IsShown and tip:IsShown() then
		return false
	end
	return true
end

local function Dispatch(kind, tip, data)
	if Kit:IsForbidden(tip) or Kit:IsCompanion(tip) then
		return
	end
	local list = listeners[kind]
	for i = 1, #list do
		pcall(list[i], tip, data)
	end
end

local function Install(kind)
	if installed[kind] then
		return
	end
	local enumType = EnumType(kind)
	local script = SCRIPT[kind]
	local hasScript = script and GameTooltip and GameTooltip.HasScript and GameTooltip:HasScript(script)
	if hasScript then
		local function fire(tip)
			Dispatch(kind, tip)
		end
		GameTooltip:HookScript(script, fire)
		if ItemRefTooltip and ItemRefTooltip.HasScript and ItemRefTooltip:HasScript(script) then
			ItemRefTooltip:HookScript(script, fire)
		end
		installed[kind] = "script"
		return
	end
	if TooltipDataProcessor and enumType then
		TooltipDataProcessor.AddTooltipPostCall(enumType, function(tip, data)
			Dispatch(kind, tip, data)
		end)
		installed[kind] = "processor"
	end
end

function Kit:On(kind, callback)
	local list = listeners[kind]
	if not list or type(callback) ~= "function" then
		return
	end
	list[#list + 1] = callback
	Install(kind)
end

local function Slot(host)
	local slot = companions[host]
	if not slot then
		slot = { frames = {} }
		companions[host] = slot
	end
	return slot
end

function Kit:CompanionFrame(host, key)
	local slot = companions[host]
	return slot and slot.frames[key or "default"]
end

function Kit:Companion(host, key)
	if self:IsForbidden(host) then
		return nil
	end
	key = key or "default"
	local slot = Slot(host)
	local extra = slot.frames[key]
	if not extra then
		local hostName = host.GetName and host:GetName()
		if self:IsSecret(hostName) or type(hostName) ~= "string" then
			hostName = "Tip"
		end
		extra = CreateFrame("GameTooltip", "TooltipKit" .. key .. hostName, UIParent, "GameTooltipTemplate")
		extra:SetFrameStrata("TOOLTIP")
		extra:SetClampedToScreen(true)
		extra.tkCompanion = true
		extra.ttidsHooked = true
		extra.ttidsXLootCompanion = true
		slot.frames[key] = extra
		companionFrames[extra] = true
	end
	if not slot.open then
		extra:SetOwner(UIParent, "ANCHOR_NONE")
		extra:ClearLines()
		local hostScale = host.GetEffectiveScale and host:GetEffectiveScale() or 1
		local parentScale = UIParent:GetEffectiveScale()
		if parentScale and parentScale > 0 then
			extra:SetScale(hostScale / parentScale)
		end
		extra:SetFrameLevel((host.GetFrameLevel and host:GetFrameLevel() or 1) + 2)
		extra:ClearAllPoints()
		extra:SetPoint("TOPLEFT", host, "BOTTOMLEFT", 0, -1)
		slot.open = true
	end
	return extra
end

function Kit:HideCompanion(host, key)
	local slot = companions[host]
	if not slot then
		return
	end
	slot.open = nil
	if key then
		local extra = slot.frames[key]
		if extra then
			extra:Hide()
		end
		return
	end
	for _, extra in pairs(slot.frames) do
		extra:Hide()
	end
end

function Kit:AddLine(tip, text, r, g, b)
	text = self:Text(text)
	if not text or self:IsForbidden(tip) then
		return false
	end
	if self:IsXLootRow(tip) then
		local extra = self:Companion(tip, "default")
		if not extra then
			return false
		end
		extra:AddLine(text, r, g, b, true)
		if extra:NumLines() > 0 then
			extra:Show()
		end
		return true
	end
	if not self:CanAdd(tip) then
		return false
	end
	tip:AddLine(text, r, g, b, true)
	return true
end
