local _, NeP = ...

NeP.OM = {
	Enemy    = {},
	Friendly = {},
	Dead     = {},
	Objects  = {},
	Roster   = {},
	max_distance = 100
}

local OM_c = {
	Enemy    = NeP.OM.Enemy,
	Friendly = NeP.OM.Friendly,
	Dead     = NeP.OM.Dead,
	Objects  = NeP.OM.Objects,
	Roster   = NeP.OM.Roster
}
local clean = {}

-- This cleans/updates the tables and then returns it
-- Due to Generic OM, a unit can still exist (target) but no longer be the same unit,
-- To counter this we compare GUID's.

local function MergeTable_Insert(table, Obj, GUID)
	if not table[GUID]
	and UnitExists(Obj.key)
	and UnitInPhase(Obj.key)
	and GUID == UnitGUID(Obj.key) then
		table[GUID] = Obj
		Obj.distance = NeP.Protected.Distance('player', Obj.key)
	end
end

local function MergeTable(ref)
	local temp = {}
	for GUID, Obj in pairs(NeP.Protected.nPlates[ref]) do
		MergeTable_Insert(temp, Obj, GUID)
	end
	for GUID, Obj in pairs(OM_c[ref]) do
		MergeTable_Insert(temp, Obj, GUID)
	end
	return temp
end

function clean.Objects()
	for GUID, Obj in pairs(OM_c["Objects"]) do
		if Obj.distance > NeP.OM.max_distance
		or not UnitExists(Obj.key)
		or GUID ~= UnitGUID(Obj.key) then
			OM_c["Objects"][GUID] = nil
		end
	end
end

function clean.Dead()
	for GUID, Obj in pairs(OM_c["Dead"]) do
		-- remove invalid units
		if Obj.distance > NeP.OM.max_distance
		or not UnitExists(Obj.key)
		or not UnitInPhase(Obj.key)
		or GUID ~= UnitGUID(Obj.key)
		or not UnitIsDeadOrGhost(Obj.key) then
			OM_c["Dead"][GUID] = nil
		end
	end
end

function clean.Others(ref)
	for GUID, Obj in pairs(OM_c[ref]) do
		-- remove invalid units
		if Obj.distance > NeP.OM.max_distance
		or not UnitExists(Obj.key)
		or not UnitInPhase(Obj.key)
		or GUID ~= UnitGUID(Obj.key)
		or UnitIsDeadOrGhost(Obj.key) then
			OM_c[ref][GUID] = nil
		end
	end
end

function NeP.OM.Get(_, ref, want_plates)
	if want_plates
	and NeP.Protected.nPlates
	and NeP.Protected.nPlates[ref] then
		return MergeTable(ref)
	end
	return OM_c[ref]
end

function NeP.OM.Insert(_, ref, Obj, GUID)
	local distance = NeP.Protected.Distance('player', Obj) or 999
	if distance <= NeP.OM.max_distance then
		local ObjID = select(6, strsplit('-', GUID))
		OM_c[ref][GUID] = {
			key = Obj,
			name = UnitName(Obj),
			distance = distance,
			id = tonumber(ObjID or 0),
			guid = GUID,
			isdummy = NeP.DSL:Get('isdummy')(Obj)
		}
	end
end

function NeP.OM.Add(_, Obj, isObject)
	if not UnitExists(Obj) then return end
	local GUID = UnitGUID(Obj) or '0'
	-- Units
	if UnitInPhase(Obj) then
		if UnitIsDeadOrGhost(Obj) then
			NeP.OM:Insert('Dead', Obj, GUID)
		elseif UnitIsFriend('player', Obj) then
			NeP.OM:Insert('Friendly', Obj, GUID)
		elseif UnitCanAttack('player', Obj) then
			NeP.OM:Insert('Enemy', Obj, GUID)
		end
	-- Objects
	elseif isObject then
		NeP.OM:Insert('Objects', Obj, GUID)
	end
end

local function CleanStart()
	if NeP.DSL:Get("toggle")(nil, "mastertoggle") then
		clean.Objects()
		clean.Dead()
		clean.Others("Friendly")
		clean.Others("Enemy")
		clean.Others("Roster")
	else
		for _, v in pairs(OM_c) do
			wipe(v)
		end
	end
end

local function MakerStart()
	if NeP.DSL:Get("toggle")(nil, "mastertoggle") then
		NeP.Protected:OM_Maker()
	end
end

NeP.Debug:Add("OM_Clean", CleanStart, true)
NeP.Debug:Add("OM_Maker", MakerStart, true)

C_Timer.NewTicker(1, CleanStart)
C_Timer.NewTicker(1, MakerStart)

-- Gobals
NeP.Globals.OM = {
	Add = NeP.OM.Add,
	Get = NeP.OM.Get,
	clean = clean
}
