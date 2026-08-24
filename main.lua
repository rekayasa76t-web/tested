-- v3.1-super-dig-esp3000-safe-loot
-- Single-session guard:
-- This script creates several long-lived Roblox connections. Running the same
-- script repeatedly without disconnecting the old session accumulates those
-- connections and eventually hits the executor's connection limit.
local __NXROTEnv = (type(getgenv)=="function" and getgenv()) or _G
if __NXROTEnv.__NXROTMineMountainActive then
	return
end
__NXROTEnv.__NXROTMineMountainActive=true

-- NXROT: MINE A MOUNTAIN — v3.1 (Super Dig + ESP 3000 + Safe Boulder Loot)
-- ============================================================
-- [1] SERVICES
local S = {
	Players           = game:GetService("Players"),
	CoreGui           = game:GetService("CoreGui"),
	RunService        = game:GetService("RunService"),
	Workspace         = game:GetService("Workspace"),
	ReplicatedStorage = game:GetService("ReplicatedStorage"),
	UserInputService  = game:GetService("UserInputService"),
	TweenService      = game:GetService("TweenService"),
	HttpService       = game:GetService("HttpService"),
	TeleportService   = game:GetService("TeleportService"),
	GuiService        = game:GetService("GuiService"),
	VirtualUser       = game:GetService("VirtualUser"),
	Lighting          = game:GetService("Lighting"),
}
local LocalPlayer = S.Players.LocalPlayer
local Mouse       = LocalPlayer:GetMouse()

-- ============================================================
-- STARTUP KEY GATE
-- DEV_MODE = true  -> bypass key validation for testing
-- DEV_MODE = false -> valid getgenv().key is required
-- ============================================================
local DEV_MODE = (rawget(_G, "__dhub_dev") ~= nil) or false

-- [2] CONFIG LOAD
local CONFIG_PATH = "NXROT/MineAMountainV4.json"
pcall(function() if isfolder and not isfolder("NXROT") then makefolder("NXROT") end end)
local LoadedCfg   = {}
pcall(function()
	local content = readfile(CONFIG_PATH)
	if type(content) == "string" and content ~= "" then
		LoadedCfg = S.HttpService:JSONDecode(content)
	end
end)
if type(LoadedCfg) ~= "table" then LoadedCfg = {} end

-- [3] AFK
local afkConns   = {}
local afkRunning = true
do
	local function silenceIdle()
		local ok, list = pcall(function() return getconnections(LocalPlayer.Idled) end)
		if not ok or type(list) ~= "table" then return end
		for _, c in ipairs(list) do pcall(function() c:Disable() end) end
	end
	local function nudge()
		pcall(function()
			S.VirtualUser:CaptureController()
			S.VirtualUser:ClickButton2(Vector3.new())
		end)
	end
	silenceIdle()
	afkConns[#afkConns+1] = LocalPlayer.Idled:Connect(nudge)
	task.spawn(function()
		while afkRunning do
			task.wait(60)
			if not afkRunning or not LocalPlayer.Parent then break end
			silenceIdle(); nudge()
		end
	end)
end

-- [4] GUI ROOT
function resolveGuiRoot()
	local ok, h = pcall(function() return gethui() end)
	if ok and typeof(h) == "Instance" then return h end
	local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if pg then return pg end
	return LocalPlayer:WaitForChild("PlayerGui", 10) or S.CoreGui
end
local GuiRoot = resolveGuiRoot()
for _, container in ipairs({GuiRoot, S.CoreGui}) do
	for _, name in ipairs({"UniverseESPGui","UniverseCrystalEsp","DScriptsPF"}) do
		pcall(function()
			local e = container:FindFirstChild(name)
			if e then e:Destroy() end
		end)
	end
end

-- [5] REMOTE DISCOVERY
local _remoteFolder
function getRemoteFolder()
	if _remoteFolder and _remoteFolder.Parent then return _remoteFolder end
	_remoteFolder = S.ReplicatedStorage:FindFirstChild("Remotes")
		or S.ReplicatedStorage:WaitForChild("Remotes", 10)
	return _remoteFolder
end
function findRemote(name)
	local folder = getRemoteFolder()
	if not folder then return nil end
	return folder:FindFirstChild(name) or folder:WaitForChild(name, 5)
end
local RMT = {}
RMT.SellRequest    = findRemote("SellRequest")
RMT.GoHome         = findRemote("GoHome")
RMT.HoldComplete   = findRemote("CrystalHoldComplete")
RMT.ToggleFavorite = findRemote("ToggleFavorite")
RMT.ReviveBase     = findRemote("ReviveBase")
RMT.ReviveShow     = findRemote("ReviveShow")
RMT.BombActivate   = findRemote("BombActivate")
RMT.BombOpen       = findRemote("BombOpen")
RMT.BombBuyRequest = findRemote("BombBuyRequest")
RMT.Notify         = findRemote("Notify")
RMT.DigRequest     = findRemote("DigRequest")
RMT.ShopBuy        = findRemote("ShopBuy")
RMT.ShopEquip      = findRemote("ShopEquip")
RMT.UpgradeBuy     = findRemote("UpgradeBuy")
RMT.UpgradePrices  = findRemote("UpgradePrices")
RMT.RadarBuy       = findRemote("RadarBuy")
RMT.RadarBuyRequest = findRemote("RadarBuyRequest")
RMT.RadarShopQuery  = findRemote("RadarShopQuery")

-- [6] DATA TABLES
local BOMB_MATERIALS = {
	[Enum.Material.Pavement]   = {bombId="ClassicBomb",  tier=1, matName="Gunpowder Stone"},
	[Enum.Material.Salt]       = {bombId="WindBomb",     tier=2, matName="Skyglass"},
	[Enum.Material.Ice]        = {bombId="IceBomb",      tier=3, matName="Cryostone"},
	[Enum.Material.LeafyGrass] = {bombId="FireBomb",     tier=4, matName="Cinderforge Plate"},
	[Enum.Material.Asphalt]    = {bombId="ThunderBomb",  tier=5, matName="Stormsteel"},
	[Enum.Material.Concrete]   = {bombId="PoisonBomb",   tier=6, matName="Venomite"},
	[Enum.Material.Cobblestone]= {bombId="TimeBomb",     tier=7, matName="Chronoshard"},
	[Enum.Material.Brick]      = {bombId="AgonyBomb",    tier=8, matName="Dreadstone"},
}
local BOMB_TIER = {
	ClassicBomb=1, WindBomb=2, IceBomb=3, FireBomb=4,
	ThunderBomb=5, PoisonBomb=6, TimeBomb=7, AgonyBomb=8, NukeBomb=9,
}
local BOMB_CONFIG = {
	ClassicBomb  = {displayName="Classic Bomb",  fuse=2.5, cashPrice=50000},
	WindBomb     = {displayName="Wind Bomb",     fuse=2.5, cashPrice=400000},
	IceBomb      = {displayName="Ice Bomb",      fuse=2.5, cashPrice=2000000},
	FireBomb     = {displayName="Fire Bomb",     fuse=2.5, cashPrice=5000000},
	ThunderBomb  = {displayName="Thunder Bomb",  fuse=2.5, cashPrice=15000000},
	PoisonBomb   = {displayName="Poison Bomb",   fuse=2.5, cashPrice=40000000},
	TimeBomb     = {displayName="Time Bomb",     fuse=4.0, cashPrice=175000000},
	AgonyBomb    = {displayName="Agony Bomb",    fuse=3.6, cashPrice=600000000},
}
local PICKAXE_SHOP = {
	{id="RustyScrapper",   displayName="Rusty Scrapper",    cashPrice=0},
	{id="WeatheredWood",   displayName="Weathered Wood",    cashPrice=50},
	{id="ChippedStone",    displayName="Chipped Stone",     cashPrice=200},
	{id="HardenedIron",    displayName="Hardened Iron",     cashPrice=600},
	{id="CopperPick",      displayName="Copper Pick",       cashPrice=1500},
	{id="ReinforcedSteel", displayName="Reinforced Steel",  cashPrice=4000},
	{id="TitaniumSpike",   displayName="Titanium Spike",    cashPrice=10000},
	{id="FrostbitePick",   displayName="Frostbite Pick",    cashPrice=25000},
	{id="EmeraldCarver",   displayName="Emerald Carver",    cashPrice=60000},
	{id="VolcanoBasalt",   displayName="Volcano Basalt",    cashPrice=15000},
	{id="ObsidianEdge",    displayName="Obsidian Edge",     cashPrice=400000},
	{id="TempestPick",     displayName="Tempest Pick",      cashPrice=1000000},
	{id="CelestialApex",   displayName="Celestial Apex",    cashPrice=2500000},
	{id="AstralRend",      displayName="Astral Rend",       cashPrice=6000000},
	{id="EclipseFang",     displayName="Eclipse Fang",      cashPrice=15000000},
	{id="NebularThrone",   displayName="Nebular Throne",    cashPrice=35000000},
	{id="Voidreign",       displayName="Voidreign",         cashPrice=80000000},
	{id="Singularity",     displayName="Singularity",       cashPrice=180000000},
	{id="TheTerminus",     displayName="The Terminus",      cashPrice=400000000},
}
local RADAR_SHOP = {
	{id="CrystalRadar",     displayName="Crystal Radar",     cashPrice=0},
	{id="CaveRadar",        displayName="Cave Radar",        cashPrice=0},
	{id="LavaRadar",        displayName="Lava Radar",        cashPrice=0},
	{id="AetherstoneRadar", displayName="Aetherstone Radar", cashPrice=0},
	{id="BombveinsRadar",   displayName="Bombveins Radar",   cashPrice=0},
	{id="BoulderRadar",     displayName="Boulder Radar",     cashPrice=0},
}
do
	local mod=game:GetService("ReplicatedStorage"):FindFirstChild("ShopCatalog",true)
	if mod and mod:IsA("ModuleScript") then
		local ok,data=pcall(require,mod)
		if ok and type(data)=="table" and type(data.Pickaxes)=="table" then
			table.clear(PICKAXE_SHOP)
			for _,entry in pairs(data.Pickaxes) do
				if type(entry)=="table" and type(entry.id)=="string" then
					PICKAXE_SHOP[#PICKAXE_SHOP+1]={id=entry.id,displayName=entry.toolName or entry.name or entry.id,cashPrice=tonumber(entry.price) or 0}
				end
			end
		end
	end
end
do
	local mod=game:GetService("ReplicatedStorage"):FindFirstChild("RadarShopConfig",true)
	if mod and mod:IsA("ModuleScript") then
		local ok,data=pcall(require,mod)
		local radars=ok and type(data)=="table" and data.RADARS or nil
		if type(radars)=="table" then
			table.clear(RADAR_SHOP)
			for id,entry in pairs(radars) do
				if type(entry)=="table" then
					RADAR_SHOP[#RADAR_SHOP+1]={id=tostring(id),displayName=entry.displayName or entry.name or tostring(id),cashPrice=tonumber(entry.cashPrice) or 0,rarity=entry.rarity}
				end
			end
			table.sort(RADAR_SHOP,function(a,b) return a.id<b.id end)
		end
	end
end
local BOMB_SHOP_ORDER = {"ClassicBomb","WindBomb","IceBomb","FireBomb","ThunderBomb","PoisonBomb","TimeBomb","AgonyBomb"}
local RARITY_LIST = {"Default","Common","Uncommon","Rare","Epic","Legendary","Mythic","Empyrean","Pulsar","Quasar"}
function isBombMaterial(mat) return BOMB_MATERIALS[mat] ~= nil end
-- NXROT exact Vein engine material map
local DIG_MATERIALS = {
  [Enum.Material.WoodPlanks] = {matName="Prismarite", color=Color3.fromRGB(200,120,255)},
  [Enum.Material.Limestone]  = {matName="Aetherstone", color=Color3.fromRGB(80,220,255)},
  [Enum.Material.CrackedLava]= {matName="Cracked Lava", color=Color3.fromRGB(255,80,30)},
}
function isDigMaterial(mat) return DIG_MATERIALS[mat]~=nil end

function sampleTerrainMaterial(position)
	local VOXEL = 4; local half = Vector3.new(VOXEL*0.5, VOXEL*0.5, VOXEL*0.5)
	local region = Region3.new(position - half, position + half)
	local ok, mats = pcall(workspace.Terrain.ReadVoxels, workspace.Terrain, region, VOXEL)
	if not ok or not mats then return nil end
	local sz = mats.Size
	if sz.X >= 1 and sz.Y >= 1 and sz.Z >= 1 then
		local m = mats[1][1][1]; if m ~= Enum.Material.Air then return m end
	end
	return nil
end

-- [7] CFG CONSTANTS
local CFG = {
	ESP = {
		font   = Enum.Font.GothamMedium,
		sweep  = 0.5,
		budget = 0.005,
		offset = Vector3.new(0, 3, 0),
		width  = 250,
		height = 66,
		text   = 16,
		ttl    = 5,
		crystalDistance = math.clamp(tonumber(LoadedCfg.crystalEspDistance) or 3000, 50, 3000),
		veinDistance = math.clamp(tonumber(LoadedCfg.veinEspDistance) or 3000, 50, 3000),
		prismariteDistance = math.clamp(tonumber(LoadedCfg.prismariteEspDistance) or 3000, 50, 3000),
		boulderDistance = math.clamp(tonumber(LoadedCfg.boulderEspDistance) or 3000, 50, 3000),
	},
	PLAYER = {offset=Vector3.new(0,-8,0), width=220, height=44, text=15, distance=math.clamp(tonumber(LoadedCfg.playerEspDistance) or 3000, 50, 3000)},
	PACE   = {boost=35, normal=16, stats=0.25, distance=0.05},
	TP = {
		offset = Vector3.new(0, 4.5, 0),
		hold   = 0.35,
		clear  = {
			Vector3.new(0,0,0), Vector3.new(0,3,0), Vector3.new(0,7,0),
			Vector3.new(5,3,0), Vector3.new(-5,3,0), Vector3.new(0,3,5),
			Vector3.new(0,3,-5), Vector3.new(0,12,0), Vector3.new(9,6,0),
			Vector3.new(-9,6,0), Vector3.new(0,6,9), Vector3.new(0,6,-9),
			Vector3.new(0,20,0),
		},
	},
	PICK = {
		aimRange=5000, aimDot=0.995, range=13, cooldown=0.04,
		restore=0.2, burst=8, retry=0.15, forget=5, pad=4,
		instantRadius=60, instantTick=0.25,
	},
	COLORS = {
		money=Color3.fromRGB(60,255,90), default=Color3.fromRGB(0,225,255),
		extra=Color3.fromRGB(255,255,255), player=Color3.fromRGB(255,40,140),
		stroke=Color3.fromRGB(0,0,0), hexDistance="00E5FF", hexLuck="FFC400",
		vein=Color3.fromRGB(255,170,0),
	},
	TIER_NAMES   = {"Common","Uncommon","Rare","Epic","Legendary","Mythic","Empyrean","Pulsar","Quasar"},
	LUCK         = {rarity={1,1.6,2.6,4.2,7,12}, base=0.00045, exponent=0.5, cap=500, bomb=3, blood=4},
	MUTATION_LUCK = {
		Verdant=15, Voltaic=20, Gilded=18, Onyx=28, Terminus=40,
		Frost=1.4, Fire=1.4, Thunder=1.5, Starfall=1.3,
		Aurora=2.2, Radioactive=2, Poison=1.5, Wet=1,
	},
	WATCHED_ATTRIBUTES = {
		"Value","Collected","WeightKg","Tier","TierName","CrystalName","Mutation","ExtraMutations",
	},
	SUFFIXES          = {"","k","M","B","T","Qa"},
	PARSE_MULTIPLIERS = {k=1e3, m=1e6, b=1e9, t=1e12, qa=1e15},
	CONTAINER_NAMES   = {"DroppedCrystals","Crystals"},
}

-- [8] ESP HOLDER
local EspHolder    = Instance.new("Folder")
EspHolder.Name     = "UniverseCrystalEsp"
EspHolder.Parent   = GuiRoot

-- [9] TOGGLES + CACHE + STATE
local saveConfig
local Toggles = {
	CrystalEsp       = LoadedCfg.CrystalEsp == true,
	PlayerEsp        = LoadedCfg.PlayerEsp == true,
	BoulderEsp       = LoadedCfg.BoulderEsp == true,
	VeinEsp          = LoadedCfg.VeinEsp == true,
	PrismariteEsp    = LoadedCfg.PrismariteEsp == true,
	PlayerLines      = LoadedCfg.PlayerLines == true,
	CrystalLines     = LoadedCfg.CrystalLines == true,
	BoulderLines     = LoadedCfg.BoulderLines == true,
	VeinLines        = LoadedCfg.VeinLines == true,
	AimTeleport      = LoadedCfg.AimTeleport == true,
	AutoPickup       = LoadedCfg.AutoPickup == true,
	InstantPrompt    = LoadedCfg.InstantPrompt == true,
	AutoRunePickup   = LoadedCfg.AutoRunePickup == true,
	AutoFavoriteItem = LoadedCfg.AutoFavoriteItem == true,
	AutoDig          = LoadedCfg.AutoDig == true,
	AutoFarmMoney    = LoadedCfg.AutoFarmMoney == true,
	AutoFarmBoulders = LoadedCfg.AutoFarmBoulders == true,
	MoneyAutoSell    = LoadedCfg.MoneyAutoSell == true,
	AutoWeightUpgrade= LoadedCfg.AutoWeightUpgrade == true,
	AutoAirUpgrade   = LoadedCfg.AutoAirUpgrade == true,
	AutoBuyPick      = LoadedCfg.AutoBuyPick == true,
	AutoBomb         = LoadedCfg.AutoBomb == true,
	AutoBuyBombs     = LoadedCfg.AutoBuyBombs == true,
	AutoBuyRadar     = LoadedCfg.AutoBuyRadar == true,
	SpeedBoost       = LoadedCfg.SpeedBoost == true,
	Noclip           = LoadedCfg.Noclip == true,
	InfJump          = LoadedCfg.InfJump == true,
	Fly              = LoadedCfg.Fly == true,
	AutoRevive       = LoadedCfg.autoRevive == true,
	FpsBoost         = LoadedCfg.fpsBoost == true,
	UltraFps         = LoadedCfg.ultraFps == true or LoadedCfg.fpsBoost == true,
	AutoHop          = LoadedCfg.autoHop == true,
}
local ToggleSetFn = {}
local Cache = {
	registry={}, candidates={}, dirty={}, espCache={},
	playerCache={}, containerConns={}, claimed={}, instantPatched={},
	promptRestores={}, pendingActions={}, pickupFound={}, pickupSeen={},
	boulderFarmFilter={}, veinCache={},
}

-- NXROT exact Vein engine state — load dari config
Toggles.AutoFarmDigVein  = LoadedCfg.AutoFarmDigVein  == true
Toggles.AutoFarmBombVein = LoadedCfg.AutoFarmBombVein == true
Cache.digVeinFilter  = Cache.digVeinFilter  or {}
Cache.bombVeinFilter = Cache.bombVeinFilter or {}
-- Restore vein material filter dari saved config
if type(LoadedCfg.digVeinFilter) == "table" then
	for _,v in ipairs(LoadedCfg.digVeinFilter) do
		if type(v)=="string" then Cache.digVeinFilter[v]=true end
	end
end
if type(LoadedCfg.bombVeinFilter) == "table" then
	for _,v in ipairs(LoadedCfg.bombVeinFilter) do
		if type(v)=="string" then Cache.bombVeinFilter[v]=true end
	end
end

local registryCount       = 0
local espCount            = 0
local espActive           = Toggles.CrystalEsp
local playerEspActive     = Toggles.PlayerEsp
local veinEspActive       = Toggles.VeinEsp
local prismariteEspActive = Toggles.PrismariteEsp
local aimTpEnabled        = Toggles.AimTeleport
local aimTeleport
local speedActive         = Toggles.SpeedBoost
local autoPickupActive    = Toggles.AutoPickup
local instantPromptActive = Toggles.InstantPrompt
local autoReviveActive    = Toggles.AutoRevive
Toggles.FpsBoost = Toggles.FpsBoost or Toggles.UltraFps
local fpsBoostActive      = Toggles.FpsBoost
local autoHopActive       = Toggles.AutoHop
local autoBombActive      = Toggles.AutoBomb
local minValue            = LoadedCfg.minValue or 0
local boulderMinLuck      = tonumber(LoadedCfg.boulderMinLuck) or 0
local valueFilter         = minValue > 0
local espScale            = (LoadedCfg.espScale or 70) / 100
local playerScale         = (LoadedCfg.playerScale or 60) / 100
local boulderScale        = (LoadedCfg.boulderScale or 60) / 100
-- Boulder Dig Speed: OFF keeps the current/default V9 burst timing exactly.
-- v3.1 Super Dig: 100..10000 maps to an aggressive local swing/animation multiplier; server throttling still applies.
local boulderFastDig      = LoadedCfg.boulderFastDig == true
local boulderDigSpeed     = math.clamp(tonumber(LoadedCfg.boulderDigSpeed) or 10000,100,10000)
local autoHopMinutes      = LoadedCfg.autoHopMinutes or 30
local lootRadiusBoulder = math.clamp(tonumber(LoadedCfg.lootRadiusBoulder) or 12, 8, 80)
local lootRadiusVein    = math.clamp(tonumber(LoadedCfg.lootRadiusVein)    or 25, 8, 80)

local selectedPickaxeToBuy = LoadedCfg.selectedPickaxeToBuy or ""
local selectedBombToBuy = {}
do
	local raw = LoadedCfg.selectedBombToBuy
	if type(raw) == "table" then
		for _, id in ipairs(raw) do
			if type(id) == "string" and BOMB_CONFIG[id] then selectedBombToBuy[id] = true end
		end
	elseif type(raw) == "string" and raw ~= "" and BOMB_CONFIG[raw] then
		selectedBombToBuy[raw] = true
	end
end
local selectedRadarToBuy   = LoadedCfg.selectedRadarToBuy or ""
local autoBuyBombsActive   = Toggles.AutoBuyBombs
local autoBuyRadarActive   = Toggles.AutoBuyRadar

local crystalFilter = {}
do
	local raw = LoadedCfg.crystalFilter
	if type(raw) == "table" then for _, v in ipairs(raw) do if type(v)=="string" then crystalFilter[v]=true end end end
end
local rarityPickupFilter = {}
do
	local raw = LoadedCfg.rarityPickupFilter
	if type(raw) == "table" then
		for _, v in ipairs(raw) do
			if type(v)=="string" and v~="Default" and v~="" then rarityPickupFilter[v]=true end
		end
	end
end
local crystalEspFilter = {}
do
	local raw = LoadedCfg.crystalEspFilter
	if type(raw) == "table" then for _, v in ipairs(raw) do if type(v)=="string" then crystalEspFilter[v]=true end end end
end
local boulderEspFilter = {}
do
	local raw = LoadedCfg.boulderEspFilter
	if type(raw) == "table" then for _, v in ipairs(raw) do if type(v)=="string" then boulderEspFilter[v]=true end end end
end
local veinEspFilter = {}
do
	local raw = LoadedCfg.veinEspFilter
	if type(raw) == "table" then for _, v in ipairs(raw) do if type(v)=="string" then veinEspFilter[v]=true end end end
end
local farmCrystalFilter = {}
do
	local raw = LoadedCfg.farmCrystalFilter
	if type(raw) == "table" then for _, v in ipairs(raw) do if type(v)=="string" then farmCrystalFilter[v]=true end end end
end
local farmRarityFilter = {}
do
	local raw = LoadedCfg.farmRarityFilter
	if type(raw) == "table" then
		for _, v in ipairs(raw) do
			if type(v)=="string" and v~="Default" and v~="" then farmRarityFilter[v]=true end
		end
	end
end

if type(LoadedCfg.boulderFarmFilter)=="table" then
	for _,v in ipairs(LoadedCfg.boulderFarmFilter) do
		if type(v)=="string" then Cache.boulderFarmFilter[v]=true end
	end
end

local Runtime = {
	PrismariteFarmActive = false,
	speedHooked = nil,
	speedConn = nil,
	rootPart = nil,
	tpState = nil,
	lastReport = 0,
	sweepAccumulator = math.huge,
	statsDirty = true,
	statsAccumulator = 0,
	distanceAccumulator = math.huge,
	lastPickup = 0,
	lastBagWarn = 0,
	instantAccumulator = math.huge,
	autoHopStartClock = 0,
	autoHopConn = nil,
	savedParticleState = {},
	savedCastShadow = {},
	savedPostFx = {},
	savedLightState = {},
	fpsBoostDescConn = nil,
	ultraDescConn = nil,
	fpsPassId = 0,
	ultraPassId = 0,	savedWaterWaveSpeed = nil,
	ultraPlayerAccumulator = 0, ultraBackpackAccumulator = 0,
	StatsLabel=nil, BackpackLabel=nil, sellClock=0, lastGlobalAutoSell=0, configSaveClock=0, aimParams=nil, aimFDown=false,
	savedWaterReflectance = nil,
	BoulderVeinBlocked = false,
	BoulderVeinSerial = 0,
	_pickupStepRunning = false,
	prismariteCache = {},
	favoriteSentAt = setmetatable({}, {__mode="k"}),
	farmMethod = (LoadedCfg.farmMethod == "Random Server") and "Random Server" or "Current Server",
	farmReturnJobId = nil,
	autoDigAccumulator = 0,
	autoDigLastFire = 0,
	AutoDigButton = nil, AutoDigSet = nil,
	FarmMethodButton = nil, FarmMethodGet = nil, FarmMethodSet = nil,
}

-- ============================================================
-- STARTUP KEY VALIDATION
-- The old Premium tab/gated features are removed. The key is now
-- checked once before the main script/UI is initialized.
-- ============================================================
function validateStartupKey()
    if DEV_MODE == true then
        return true
    end

    local env = (type(getgenv) == "function" and getgenv()) or _G
    local key = nil

    pcall(function()
        key = env.key
    end)

    if key == nil then
        pcall(function()
            key = _G.key
        end)
    end

    key = tostring(key or ""):match("^%s*(.-)%s*$") or ""

    -- Key disimpan langsung di script, tidak menggunakan Firebase
    local VALID_KEY = "NXROT"

    return key == VALID_KEY
end

-- Boulder/Vein coordination: a bomb-required notification blocks the current Boulder.
-- Auto Bomb clears this flag only after the vein is verified gone.
function isBombRequirementNotification(text)
	if type(text) ~= "string" then return false end
	local lower=text:lower()
	for _,name in ipairs({"Agony Bomb","Time Bomb","Poison Bomb","Thunder Bomb","Fire Bomb","Ice Bomb","Wind Bomb","Classic Bomb"}) do
		if lower:find(name:lower(),1,true) then return true end
	end
	return false
end
if RMT.Notify and RMT.Notify:IsA("RemoteEvent") then
	RMT.Notify.OnClientEvent:Connect(function(_,text)
		if isBombRequirementNotification(text) then
			Runtime.BoulderVeinBlocked=true
			Runtime.BoulderVeinSerial=(Runtime.BoulderVeinSerial or 0)+1
		end
	end)
end

-- [10] NOTIFY
function Notify(text, duration)
	pcall(function()
		game:GetService("StarterGui"):SetCore("SendNotification",{
			Title="D-Hub", Text=tostring(text), Duration=duration or 3
		})
	end)
end

-- ============================================================
-- STARTUP LICENSE GATE
-- No UI/farming features are initialized until the key is valid.
-- ============================================================
if not validateStartupKey() then
	pcall(function()
		game:GetService("StarterGui"):SetCore("SendNotification",{
			Title="D-Hub", Text="Wrong Key", Duration=2
		})
	end)
	task.wait(1)
	pcall(function() LocalPlayer:Kick("D-Hub | Wrong Key") end)
	return
end

-- [11] UTILITIES
function reportError(context, err)
	-- Silent by default; set Runtime.DebugLogs=true while testing.
	if Runtime.DebugLogs ~= true then return end
	local now=os.clock()
	if now-Runtime.lastReport<5 then return end
	Runtime.lastReport=now
	warn(string.format("[MaM] %s: %s",context,tostring(err)))
end
function formatShort(n, prefix)
	n = tonumber(n) or 0; prefix = prefix or ""
	local sign = n<0 and "-" or ""; n=math.abs(n)
	if n<1000 then return string.format("%s%s%d",sign,prefix,math.floor(n+0.5)) end
	local index=0
	while n>=1000 and index<#CFG.SUFFIXES-1 do n=n/1000; index=index+1 end
	return string.format("%s%s%.2f%s",sign,prefix,n,CFG.SUFFIXES[index+1])
end
function formatWeight(kg)
	kg=tonumber(kg) or 0
	if kg>=1000 then return formatShort(kg).."kg" end
	return string.format("%.1fkg",kg)
end
function formatDistance(studs)
	studs=tonumber(studs) or 0
	if studs>=1000 then return string.format("%.1fkm",studs/1000) end
	return string.format("%dm",math.floor(studs+0.5))
end
function formatLuck(score)
	local pct=(tonumber(score) or 0)*100
	if pct<=0 then return "+0%" end
	if pct<1  then return string.format("+%.2f%%",pct) end
	if pct<10 then return string.format("+%.1f%%",pct) end
	return string.format("+%.0f%%",pct)
end
function parseValue(text)
	if type(text)~="string" then return nil end
	local cleaned=text:lower():gsub("[%s,%$_]","")
	if cleaned=="" then return 0 end
	local number,suffix=cleaned:match("^(%d*%.?%d+)(%a*)$")
	if not number then return nil end
	local base=tonumber(number); if not base then return nil end
	if suffix=="" then return base end
	local mult=CFG.PARSE_MULTIPLIERS[suffix]; if not mult then return nil end
	return base*mult
end
function fireRemote(remote,...)
	if not remote then return false end
	local args=table.pack(...)
	return pcall(function() remote:FireServer(table.unpack(args,1,args.n)) end)
end
function schedule(delay, fn)
	Cache.pendingActions[#Cache.pendingActions+1]={at=os.clock()+delay, fn=fn}
end

-- [12] CHARACTER
function bindCharacter(character)
	if not character then Runtime.rootPart=nil; return end
	Runtime.rootPart=character:FindFirstChild("HumanoidRootPart")
end
bindCharacter(LocalPlayer.Character)
local characterConn=LocalPlayer.CharacterAdded:Connect(function(character)
	Runtime.rootPart=nil; Runtime.tpState=nil
	if Runtime.favoriteWatchCharacter then Runtime.favoriteWatchCharacter(character) end
	local waiter
	waiter=character.ChildAdded:Connect(function(child)
		if child.Name=="HumanoidRootPart" then
			Runtime.rootPart=child; waiter:Disconnect()
		end
	end)
	bindCharacter(character)
	if Runtime.rootPart then waiter:Disconnect() end
end)
function getRoot()
	if Runtime.rootPart and Runtime.rootPart.Parent then return Runtime.rootPart end
	bindCharacter(LocalPlayer.Character)
	return Runtime.rootPart
end

-- [13] ATTRIBUTE HELPERS
function getAttr(inst,name)
	local ok,value=pcall(inst.GetAttribute,inst,name)
	return ok and value or nil
end
function crystalValue(inst)  return tonumber(getAttr(inst,"Value")) or 0 end
function crystalWeight(inst) return tonumber(getAttr(inst,"WeightKg")) or 0 end
function crystalTier(inst)   return tonumber(getAttr(inst,"Tier")) or 0 end
function crystalRarity(inst)
	local name=getAttr(inst,"TierName")
	if type(name)=="string" and name~="" then return name end
	return CFG.TIER_NAMES[crystalTier(inst)] or "Unknown"
end
function crystalName(inst)
	local name=getAttr(inst,"CrystalName")
	if type(name)=="string" and name~="" then return name end
	return inst.Name
end
function crystalColor(inst)
	local r=tonumber(getAttr(inst,"TierColorR"))
	local g=tonumber(getAttr(inst,"TierColorG"))
	local b=tonumber(getAttr(inst,"TierColorB"))
	if r and g and b then return Color3.fromRGB(r,g,b) end
	return CFG.COLORS.default
end
function mutationLuck(name)
	if type(name)~="string" or name=="" then return 1 end
	return CFG.MUTATION_LUCK[name] or 1
end
function combinedLuckMult(inst)
	local mutation=getAttr(inst,"Mutation")
	local roll=tonumber(getAttr(inst,"MutationLuckRoll"))
	local mult=(roll and roll>0) and roll or mutationLuck(mutation)
	local extra=getAttr(inst,"ExtraMutations")
	if type(extra)=="string" and extra~="" then
		for n in string.gmatch(extra,"[^,]+") do
			if n~="" then mult=mult*mutationLuck(n) end
		end
	end
	if getAttr(inst,"IsBloodCrystal")==true then mult=mult*CFG.LUCK.blood end
	if getAttr(inst,"AdminMutation")=="Radioactive" and mutation~="Radioactive" then
		local has=type(extra)=="string" and extra:find("Radioactive",1,true)~=nil
		if not has then mult=mult*mutationLuck("Radioactive") end
	end
	return mult
end
function computeLuck(inst)
	local tier=crystalTier(inst); if tier<=0 then return 0 end
	local weight=math.max(0,crystalWeight(inst))
	local base=(CFG.LUCK.rarity[tier] or CFG.LUCK.rarity[1])
		*math.min(weight,CFG.LUCK.cap)^CFG.LUCK.exponent*CFG.LUCK.base
	if getAttr(inst,"BombCrystal")==true then base=base*CFG.LUCK.bomb end
	return base*combinedLuckMult(inst)
end
function luckLabel(inst)
	local hover=inst:FindFirstChild("CrystalHover"); if not hover then return nil end
	local label=hover:FindFirstChild("LuckBoost")
	if not label or not label:IsA("TextLabel") then return nil end
	return label
end
function luckLabelText(inst)
	local label=luckLabel(inst); return label and label.Text or nil
end
function crystalLuck(inst)
	local text=luckLabelText(inst)

	if type(text)=="string" then
		-- Support 1000%, 1,000%, 10,000%, dst.
		local normalized=text:gsub(",","")
		local pct=tonumber(normalized:match("([%d%.]+)%s*%%"))
		if pct and pct>0 then return pct/100 end
	end

	-- Dropped crystals may temporarily lose their hover Billboard.
	-- Fall back to the engine calculation instead of treating them as 0 luck.
	return computeLuck(inst)
end

-- ============================================================
-- ============================================================
-- STANDALONE AUTO FAVORITE ITEM
-- Uses the exact inventory path/remote captured from manual Favorite.
-- Does not depend on any farming, pickup, rune, rarity, or value logic.
-- ============================================================
Runtime.favoriteMinLuck = tonumber(LoadedCfg.favoriteMinLuck)
if Runtime.favoriteMinLuck == nil or Runtime.favoriteMinLuck < 0 then Runtime.favoriteMinLuck = 10 end
Runtime.favoriteMinLuck = math.clamp(Runtime.favoriteMinLuck,0,100000)
Runtime.favoritePending = Runtime.favoritePending or setmetatable({}, {__mode="k"})

Runtime.autoFavoriteInventoryStep = function()
	if Toggles.AutoFavoriteItem ~= true then return end
	local threshold = tonumber(Runtime.favoriteMinLuck)
	if threshold == nil or threshold < 0 then threshold = 10 end
	local player = LocalPlayer
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then return end
	local remotes = S.ReplicatedStorage:FindFirstChild("Remotes")
	local event = remotes and remotes:FindFirstChild("ToggleFavorite")
	if not event or not event:IsA("RemoteEvent") then return end

	local function readLuck(tool)
	if not tool or not tool:IsA("Tool") then
		return nil
	end

	local handle = tool:FindFirstChild("Handle")
	local billboard = handle and handle:FindFirstChild("CrystalToolBillboard")
	local label = billboard and billboard:FindFirstChild("LuckBoost")

	if not label or not label:IsA("TextLabel") then
		return nil
	end

	local text = tostring(label.Text or "")
	if text == "" then
		return nil
	end

	-- Normalisasi format angka.
	-- Contoh yang didukung:
	-- Luck: +1000%
	-- Luck: 1000%
	-- +1000%
	-- 1000 %
	-- 1,000%
	-- 1.000%
	local cleaned = text

	-- Buang tulisan "Luck:" dan whitespace.
	cleaned = cleaned:gsub("[Ll]uck%s*:%s*", "")
	cleaned = cleaned:gsub("%s+", "")

	-- Ambil bagian angka + optional decimal.
	local numberText = cleaned:match("([%d][%d%.,]*)")

	if not numberText then
		return nil
	end

	-- Tentukan separator.
	-- Kalau ada koma DAN titik:
	-- anggap separator terakhir sebagai decimal separator
	-- hanya jika ada digit setelahnya.
	if numberText:find(",") and numberText:find("%.") then
		local lastComma = numberText:match(".*(),")
		local lastDot = numberText:match(".*()%.")
		
		if lastComma and lastDot then
			if lastComma > lastDot then
				numberText = numberText:gsub("%.", "")
				numberText = numberText:gsub(",", ".")
			else
				numberText = numberText:gsub(",", "")
			end
		end
	elseif numberText:find(",") then
		-- Untuk format 1,000 / 10,000 / 100,000
		local after = numberText:match(",(%d+)$")

		if after and #after == 3 then
			numberText = numberText:gsub(",", "")
		else
			numberText = numberText:gsub(",", ".")
		end
	elseif numberText:find("%.") then
		-- 1.000 biasanya thousand separator.
		-- 1.5 biasanya decimal.
		local after = numberText:match("%.(%d+)$")

		if after and #after == 3 then
			numberText = numberText:gsub("%.", "")
		end
	end

	local luck = tonumber(numberText)

	if luck == nil then
		return nil
	end

	return luck
end

	local function tryFavorite(tool,target)
		if not tool or not tool:IsA("Tool") then return end
		local handle=tool:FindFirstChild("Handle")
		local billboard=handle and handle:FindFirstChild("CrystalToolBillboard")
		local luckLabel=billboard and billboard:FindFirstChild("LuckBoost")
		if not billboard or not luckLabel or not luckLabel:IsA("TextLabel") then return end
		if tool:GetAttribute("Favorited")==true or tool:GetAttribute("Favorite")==true then return end
		local luck=readLuck(tool)
		if luck==nil or luck < threshold then return end
		local serverTool=target or backpack:FindFirstChild(tool.Name)
		if not serverTool then return end
		local pendingAt=Runtime.favoritePending[serverTool]
		if pendingAt and (os.clock()-pendingAt)<2 then return end
		Runtime.favoritePending[serverTool]=os.clock()
		local ok=pcall(function() event:FireServer(serverTool,true) end)
		if not ok then Runtime.favoritePending[serverTool]=nil end
	end

	for _,tool in ipairs(backpack:GetChildren()) do
		if tool:IsA("Tool") then tryFavorite(tool,backpack:FindFirstChild(tool.Name)) end
	end
	local character=player.Character
	if character then
		for _,tool in ipairs(character:GetChildren()) do
			if tool:IsA("Tool") then tryFavorite(tool,tool) end
		end
	end
end

Runtime.unfavoriteAllCrystalItems = function()
	local player=LocalPlayer
	local remotes=S.ReplicatedStorage:FindFirstChild("Remotes")
	local event=remotes and remotes:FindFirstChild("ToggleFavorite")
	if not event or not event:IsA("RemoteEvent") then return end
	local function process(container)
		if not container then return end
		for _,tool in ipairs(container:GetChildren()) do
			if tool:IsA("Tool") then
				local handle=tool:FindFirstChild("Handle")
				local billboard=handle and handle:FindFirstChild("CrystalToolBillboard")
				if billboard and (tool:GetAttribute("Favorited")==true or tool:GetAttribute("Favorite")==true) then
					pcall(function() event:FireServer(tool,false) end)
				end
				Runtime.favoritePending[tool]=nil
			end
		end
	end
	process(player:FindFirstChildOfClass("Backpack")); process(player.Character)
end

Runtime.setFavoriteMinLuck = function(text)
	-- IMPORTANT: string.gsub returns (string, count). Never pass it
	-- directly into tonumber or the count is treated as the numeric base.
	local cleaned=tostring(text or ""):gsub("%%", "")
	cleaned=cleaned:match("^%s*(.-)%s*$") or cleaned
	local n=tonumber(cleaned)
	if n==nil then return end
	n=math.clamp(n,0,100000)
	Runtime.favoriteMinLuck=n
	LoadedCfg.favoriteMinLuck=n
	-- Save immediately so changing the textbox is persisted before any
	-- later heartbeat/config save can occur.
	local saved=saveConfig()
	if not saved then
		warn("[NXROT] Failed to save favoriteMinLuck config")
	end
	if Toggles.AutoFavoriteItem==true then Runtime.autoFavoriteInventoryStep() end
end

Runtime.toggleFavoriteItem = function()
	Toggles.AutoFavoriteItem=not Toggles.AutoFavoriteItem
	if ToggleSetFn.AutoFavoriteItem then ToggleSetFn.AutoFavoriteItem(Toggles.AutoFavoriteItem) end
	pcall(saveConfig)
	if Toggles.AutoFavoriteItem==true then Runtime.autoFavoriteInventoryStep() end
end

Runtime.favoriteWatchBackpack = function(backpack)
	if not backpack then return end

	if Runtime.favoriteBackpackConn then
		pcall(function()
			Runtime.favoriteBackpackConn:Disconnect()
		end)
	end

	Runtime.favoriteBackpackConn = backpack.ChildAdded:Connect(function(child)
		if not Toggles.AutoFavoriteItem or not child:IsA("Tool") then
			return
		end

		-- Tunggu sampai UI crystal/LuckBoost benar-benar dibuat.
		task.spawn(function()
			local deadline = os.clock() + 3

			while os.clock() < deadline do
				if not Toggles.AutoFavoriteItem or child.Parent ~= backpack then
					return
				end

				local handle = child:FindFirstChild("Handle")
				local billboard = handle and handle:FindFirstChild("CrystalToolBillboard")
				local luckLabel = billboard and billboard:FindFirstChild("LuckBoost")

				if billboard and luckLabel and luckLabel:IsA("TextLabel") then
					-- Sudah siap, langsung evaluasi berdasarkan threshold TERBARU.
					Runtime.autoFavoriteInventoryStep()
					return
				end

				task.wait(0.1)
			end

			-- Fallback satu kali kalau UI dibuat sangat lambat.
			if Toggles.AutoFavoriteItem and child.Parent == backpack then
				Runtime.autoFavoriteInventoryStep()
			end
		end)
	end)
end

Runtime.favoriteWatchCharacter = function(character)
	if not character then return end

	if Runtime.favoriteCharacterConn then
		pcall(function()
			Runtime.favoriteCharacterConn:Disconnect()
		end)
	end

	Runtime.favoriteCharacterConn = character.ChildAdded:Connect(function(child)
		if not Toggles.AutoFavoriteItem or not child:IsA("Tool") then
			return
		end

		task.spawn(function()
			local deadline = os.clock() + 3

			while os.clock() < deadline do
				if not Toggles.AutoFavoriteItem or child.Parent ~= character then
					return
				end

				local handle = child:FindFirstChild("Handle")
				local billboard = handle and handle:FindFirstChild("CrystalToolBillboard")
				local luckLabel = billboard and billboard:FindFirstChild("LuckBoost")

				if billboard and luckLabel and luckLabel:IsA("TextLabel") then
					Runtime.autoFavoriteInventoryStep()
					return
				end

				task.wait(0.1)
			end

			if Toggles.AutoFavoriteItem and child.Parent == character then
				Runtime.autoFavoriteInventoryStep()
			end
		end)
	end)
end

task.spawn(function()
	local backpack=LocalPlayer:FindFirstChildOfClass("Backpack") or LocalPlayer:WaitForChild("Backpack",10)
	Runtime.favoriteWatchBackpack(backpack)
	Runtime.favoriteWatchCharacter(LocalPlayer.Character)
end)

function meetsFilter(inst, value)
	if valueFilter and (value or crystalValue(inst)) < minValue then return false end
	if next(crystalFilter)~=nil then
		local cname=crystalName(inst)
		if not crystalFilter[cname] then return false end
	end
	return true
end
-- New filter logic applied for Money Farm
function meetsFarmFilter(inst, value)
	if valueFilter and (value or crystalValue(inst)) < minValue then return false end
	if next(farmCrystalFilter)~=nil then
		local cname=crystalName(inst)
		if not farmCrystalFilter[cname] then return false end
	end
	if next(farmRarityFilter)~=nil then
		local rarity=crystalRarity(inst)
		if not farmRarityFilter[rarity] then return false end
	end
	return true
end
-- Unified rarity/luck pickup rule. An empty rarity filter means ALL rarities.
-- A positive luck threshold means luck >= the configured percentage.
function meetsPickupFilter(inst, value)
	if not inst then return false end
	value = value or crystalValue(inst)
	if next(rarityPickupFilter)~=nil and not rarityPickupFilter[crystalRarity(inst)] then return false end
	if boulderMinLuck>0 then
		local luckPct=(tonumber(crystalLuck(inst)) or 0)*100
		if luckPct+1e-6<boulderMinLuck then return false end
	end
	return true
end

-- [14] BACKPACK
function ownsGamepass(name)
	local folder=LocalPlayer:FindFirstChild("GamepassesOwned"); if not folder then return false end
	local flag=folder:FindFirstChild(name)
	return flag~=nil and flag:IsA("BoolValue") and flag.Value==true
end
function realStat(name)
	local data=LocalPlayer:FindFirstChild("PlayerData")
	local stats=data and data:FindFirstChild("RealStats")
	local entry=stats and stats:FindFirstChild(name)
	return entry and tonumber(entry.Value) or nil
end
function hasActiveRune(keyword)
	local data=LocalPlayer:FindFirstChild("PlayerData")
	local plot=data and data:FindFirstChild("PlotData")
	local runes=plot and plot:FindFirstChild("Runes")
	if not runes then return false end
	for _,child in ipairs(runes:GetChildren()) do
		local runeName=child:GetAttribute("RuneName")
		if type(runeName)=="string" and runeName:find(keyword,1,true) then
			if (tonumber(child:GetAttribute("Remaining")) or 0)>0 then return true end
		end
	end
	return false
end
function backpackCapacity()
	if LocalPlayer:GetAttribute("InfBackpack")==true then return math.huge end
	local base=realStat("CarryWeight") or 10
	if ownsGamepass("CarryKgPlus4") then base=base*4 end
	local total=base+(realStat("CarryWeightBonus") or 0)
	if hasActiveRune("Weight") then return total*2 end
	return total
end
function backpackWeight()
	local total=0
	local function scan(c)
		if not c then return end
		for _,child in ipairs(c:GetChildren()) do
			if child:IsA("Tool") and getAttr(child,"Tier")~=nil then
				local kg=tonumber(getAttr(child,"WeightKg"))
				if kg then total=total+kg end
			end
		end
	end
	scan(LocalPlayer:FindFirstChildOfClass("Backpack"))
	scan(LocalPlayer.Character)
	return total
end
function backpackFree()
	local cap=backpackCapacity()
	if cap==math.huge then return math.huge end
	return cap-backpackWeight()
end

-- [15] BOMB INVENTORY
function getBombCount(bombId)
	local data=LocalPlayer:FindFirstChild("PlayerData")
	local inv=data and data:FindFirstChild("Inventory")
	local bombs=inv and inv:FindFirstChild("Bombs")
	if not bombs then return 0 end
	local entry=bombs:FindFirstChild(bombId)
	if entry then
		local n=tonumber(entry.Value); if n then return n end
		if entry:IsA("IntValue") or entry:IsA("NumberValue") then return tonumber(entry.Value) or 0 end
	end
	return 0
end

-- [16] CRYSTAL DETECTION
function looksLikeCrystal(inst)
	if not inst:IsA("BasePart") then return false end
	return inst.Name:find("Crystal",1,true)~=nil
end
local crystalFlags=setmetatable({},{__mode="k"})
function isCrystal(inst)
	local cached=crystalFlags[inst]; if cached~=nil then return cached end
	local result=false
	if inst:IsA("BasePart") and getAttr(inst,"Value")~=nil then
		result=getAttr(inst,"CrystalName")~=nil or inst.Name:find("Crystal",1,true)~=nil
	end
	crystalFlags[inst]=result
	return result
end

-- [17] CONTAINERS
local containerList={}
local containerClock=0
function rebuildContainers()
	table.clear(containerList); local seen={}
	local function push(c)
		if not c or seen[c] then return end
		seen[c]=true; containerList[#containerList+1]=c
	end
	push(S.Workspace)
	for _,name in ipairs(CFG.CONTAINER_NAMES) do push(S.Workspace:FindFirstChild(name)) end
	local things=S.Workspace:FindFirstChild("Things")
	if things then for _,name in ipairs(CFG.CONTAINER_NAMES) do push(things:FindFirstChild(name)) end end
end
function eachContainer(fn)
	local now=os.clock()
	local stale=#containerList==0 or now-containerClock>=1
	if not stale then
		for _,c in ipairs(containerList) do
			if not c.Parent and c~=S.Workspace then stale=true; break end
		end
	end
	if stale then containerClock=now; rebuildContainers() end
	for _,c in ipairs(containerList) do fn(c) end
end

-- [18] ESP HELPERS + CRYSTAL TRACKING
function newLabel(name,parent,order,total,color,rich,maxText)
	local label=Instance.new("TextLabel")
	label.Name=name; label.BackgroundTransparency=1; label.BorderSizePixel=0
	label.Size=UDim2.new(1,0,1/total,0); label.Position=UDim2.new(0,0,order/total,0)
	label.Font=CFG.ESP.font; label.TextScaled=true; label.TextTransparency=0
	label.TextStrokeTransparency=0; label.TextStrokeColor3=CFG.COLORS.stroke
	label.TextColor3=color; label.RichText=rich==true; label.Text=""; label.Parent=parent
	local constraint=Instance.new("UITextSizeConstraint")
	constraint.MaxTextSize=maxText; constraint.Parent=label
	return label, constraint
end
function crystalGuiSize()  return UDim2.fromOffset(CFG.ESP.width*espScale, CFG.ESP.height*espScale) end
function crystalTextSize() return math.max(6,math.floor(CFG.ESP.text*espScale+0.5)) end
function playerGuiSize()   return UDim2.fromOffset(CFG.PLAYER.width*playerScale, CFG.PLAYER.height*playerScale) end
function playerTextSize()  return math.max(6,math.floor(CFG.PLAYER.text*playerScale+0.5)) end
function createEntry(inst)
	local bb=Instance.new("BillboardGui")
	bb.Name="UniverseEsp"; bb.Adornee=inst; bb.AlwaysOnTop=true
	bb.ResetOnSpawn=false; bb.LightInfluence=0
	bb.Size=crystalGuiSize(); bb.StudsOffsetWorldSpace=CFG.ESP.offset
	bb.MaxDistance=CFG.ESP.crystalDistance; bb.Parent=EspHolder
	local ts=crystalTextSize()
	local rarity,rc=newLabel("Rarity",bb,0,3,CFG.COLORS.default,false,ts)
	local info,ic  =newLabel("Info",  bb,1,3,CFG.COLORS.money,  false,ts)
	local extra,ec =newLabel("Extra", bb,2,3,CFG.COLORS.extra,  true, ts)
	return {gui=bb,rarity=rarity,info=info,extra=extra,constraints={rc,ic,ec},signature=false,luckText="+0%",distanceText=false}
end
function destroyEntry(inst,entry)
	entry=entry or Cache.espCache[inst]; if not entry then return end
	if entry.gui then entry.gui:Destroy() end
	Cache.espCache[inst]=nil; espCount=espCount-1; Runtime.statsDirty=true
end
function applyEspScale()
	local size=crystalGuiSize(); local ts=crystalTextSize()
	for _,e in pairs(Cache.espCache) do
		if e.gui then e.gui.Size=size; e.gui.MaxDistance=CFG.ESP.crystalDistance end
		for _,c in ipairs(e.constraints) do c.MaxTextSize=ts end
	end
end
function applyPlayerScale()
	local size=playerGuiSize(); local ts=playerTextSize()
	for _,e in pairs(Cache.playerCache) do
		if e.gui then e.gui.Size=size; e.gui.MaxDistance=CFG.PLAYER.distance end
		for _,c in ipairs(e.constraints) do c.MaxTextSize=ts end
	end
end
function applyExtra(entry,distanceText)
	entry.distanceText=distanceText
	entry.extra.Text=string.format(
		'<font color="#%s">%s</font>  \u{2022}  <font color="#%s">%s</font>',
		CFG.COLORS.hexDistance,distanceText,CFG.COLORS.hexLuck,entry.luckText)
end
function buildTitle(inst)
	local rarity=crystalRarity(inst); local name=crystalName(inst)
	local mutation=getAttr(inst,"Mutation")
	if type(mutation)=="string" and mutation~="" then
		return string.format("[%s] %s (%s)",rarity,name,mutation)
	end
	return string.format("[%s] %s",rarity,name)
end
function applyDetails(inst,entry,origin)
	local luckOk,luck=pcall(crystalLuck,inst)
	entry.luckText=formatLuck(luckOk and luck or 0)
	entry.rarity.Text=buildTitle(inst); entry.rarity.TextColor3=crystalColor(inst)
	entry.info.Text=string.format("%s  \u{2022}  %s",
		formatShort(crystalValue(inst),"$"),formatWeight(crystalWeight(inst)))
	applyExtra(entry,origin and formatDistance((inst.Position-origin).Magnitude) or "--")
end
function crystalSignature(inst)
	return table.concat({
		tostring(getAttr(inst,"Tier")),tostring(getAttr(inst,"TierName")),
		tostring(getAttr(inst,"CrystalName")),tostring(getAttr(inst,"Value")),
		tostring(getAttr(inst,"WeightKg")),tostring(getAttr(inst,"Mutation")),
		tostring(getAttr(inst,"ExtraMutations")),tostring(luckLabelText(inst)),
	},"|")
end
function inventoryCrystalKey(tool)
	if not tool or not tool:IsA("Tool") then return nil end
	local handle=tool:FindFirstChild("Handle")
	local billboard=handle and handle:FindFirstChild("CrystalToolBillboard")
	local luckLabel=billboard and billboard:FindFirstChild("LuckBoost")
	local isCrystalTool=(getAttr(tool,"Tier")~=nil or getAttr(tool,"CrystalName")~=nil or (luckLabel and luckLabel:IsA("TextLabel")))
	if not isCrystalTool then return nil end
	local luckText=luckLabel and luckLabel:IsA("TextLabel") and luckLabel.Text or ""
	return table.concat({
		tostring(getAttr(tool,"Tier")),tostring(getAttr(tool,"TierName")),
		tostring(getAttr(tool,"CrystalName") or tool.Name),tostring(getAttr(tool,"Value")),
		tostring(getAttr(tool,"WeightKg")),tostring(getAttr(tool,"Mutation")),
		tostring(getAttr(tool,"ExtraMutations")),tostring(luckText),
	},"|")
end
function inventoryCrystalLuckPercent(tool)
	local handle=tool and tool:FindFirstChild("Handle")
	local billboard=handle and handle:FindFirstChild("CrystalToolBillboard")
	local label=billboard and billboard:FindFirstChild("LuckBoost")

	if label and label:IsA("TextLabel") then
		local text=tostring(label.Text or "")
		local normalized=text:gsub(",","")
		local pct=tonumber(normalized:match("([%d%.]+)%s*%%"))

		if pct then
			return pct
		end
	end

	return (tonumber(crystalLuck(tool)) or 0)*100
end
function inventoryCrystalAllowed(tool)
	if not tool or not tool:IsA("Tool") then return false end
	local rarity=crystalRarity(tool)
	if next(rarityPickupFilter)~=nil and not rarityPickupFilter[rarity] then return false end
	if boulderMinLuck>0 and inventoryCrystalLuckPercent(tool)+1e-6<boulderMinLuck then return false end
	return inventoryCrystalKey(tool)~=nil
end
function inventoryCrystalSnapshot()
	local counts={}
	local function scan(container)
		if not container then return end
		for _,child in ipairs(container:GetChildren()) do
			if child:IsA("Tool") then
				local key=inventoryCrystalKey(child)
				if key then counts[key]=(counts[key] or 0)+1 end
			end
		end
	end
	scan(LocalPlayer:FindFirstChildOfClass("Backpack")); scan(LocalPlayer.Character)
	return counts
end
function inventoryHasNewEligibleCrystal(before)
	before=before or {}
	local current={}
	local function scan(container)
		if not container then return end
		for _,child in ipairs(container:GetChildren()) do
			if child:IsA("Tool") and inventoryCrystalAllowed(child) then
				local key=inventoryCrystalKey(child)
				if key then current[key]=(current[key] or 0)+1 end
			end
		end
	end
	scan(LocalPlayer:FindFirstChildOfClass("Backpack")); scan(LocalPlayer.Character)
	for key,count in pairs(current) do
		if count>(before[key] or 0) then return true end
	end
	return false
end
function markDirty(inst) Cache.dirty[inst]=true end
-- Local-only crystal visibility optimization.
-- Low-value crystals are hidden on this client while FPS Boost is active.
local crystalHideState=setmetatable({}, {__mode="k"})
function crystalHidePart(inst, hidden)
	if not inst or not inst:IsA("BasePart") then return end
	local state=crystalHideState[inst]
	if hidden then
		if not state then
			state={base=inst.LocalTransparencyModifier, descendants={}}
			crystalHideState[inst]=state
			pcall(function() inst.LocalTransparencyModifier=1 end)
			-- Descendants are traversed only once when the crystal becomes hidden.
			-- The old code repeated GetDescendants() every sync, which caused
			-- unnecessary CPU spikes when many crystals were present.
			for _,obj in ipairs(inst:GetDescendants()) do
				if obj:IsA("BasePart") then
					state.descendants[obj]=obj.LocalTransparencyModifier
					pcall(function() obj.LocalTransparencyModifier=1 end)
				elseif obj:IsA("BillboardGui") or obj:IsA("SurfaceGui") then
					state.descendants[obj]=obj.Enabled
					pcall(function() obj.Enabled=false end)
				end
			end
		else
			-- Already hidden: do not traverse the whole model again.
			pcall(function() inst.LocalTransparencyModifier=1 end)
		end
	elseif state then
		pcall(function() inst.LocalTransparencyModifier=state.base or 0 end)
		for obj,oldValue in pairs(state.descendants) do
			if obj and obj.Parent then
				if obj:IsA("BasePart") then
					pcall(function() obj.LocalTransparencyModifier=oldValue or 0 end)
				elseif obj:IsA("BillboardGui") or obj:IsA("SurfaceGui") then
					pcall(function() obj.Enabled=oldValue end)
				end
			end
		end
		crystalHideState[inst]=nil
	end
end
function shouldHideCrystal(inst)
	if not fpsBoostActive or not valueFilter then return false end
	return crystalValue(inst) < minValue
end
function refreshCrystalVisibility(inst)
	if inst then
		crystalHidePart(inst, shouldHideCrystal(inst))
		return
	end
	for crystal in pairs(Cache.registry) do
		crystalHidePart(crystal, shouldHideCrystal(crystal))
	end
end
function untrackCrystal(inst)
	local conns=Cache.registry[inst]; if not conns then return end
	crystalHidePart(inst, false)
	for _,c in ipairs(conns) do c:Disconnect() end
	Cache.registry[inst]=nil; registryCount=registryCount-1
	Cache.dirty[inst]=nil; Cache.candidates[inst]=nil; Runtime.statsDirty=true
	destroyEntry(inst)
end
function trackCrystal(inst)
	if Cache.registry[inst] then return end
	local conns={}; Cache.registry[inst]=conns; registryCount=registryCount+1; Runtime.statsDirty=true
	local ok=pcall(function()
		conns[#conns+1]=inst.Destroying:Connect(function() untrackCrystal(inst) end)
		conns[#conns+1]=inst.AncestryChanged:Connect(function()
			if not inst:IsDescendantOf(S.Workspace) then untrackCrystal(inst) end
		end)
		for _,name in ipairs(CFG.WATCHED_ATTRIBUTES) do
			conns[#conns+1]=inst:GetAttributeChangedSignal(name):Connect(function() markDirty(inst) end)
		end
		local label=luckLabel(inst)
		if label then
			conns[#conns+1]=label:GetPropertyChangedSignal("Text"):Connect(function() markDirty(inst) end)
		end
	end)
	if not ok then untrackCrystal(inst); return end
	markDirty(inst)
end
function syncCrystal(inst)
	Cache.dirty[inst]=nil
	if not Cache.registry[inst] then return end
	if not inst.Parent then untrackCrystal(inst); return end
	-- Hide low-value dropped crystals only while FPS Boost is active.
	-- The object is never destroyed, so farming/pickup logic remains intact.
	crystalHidePart(inst, shouldHideCrystal(inst))
	local entry=Cache.espCache[inst]
	local hidden=not espActive or getAttr(inst,"Collected")==true
	if not hidden then
		if next(crystalEspFilter)~=nil then
			local cname=crystalName(inst)
			if not crystalEspFilter[cname] then hidden=true end
		end
		if not hidden and not meetsFilter(inst) then hidden=true end
	end
	if hidden then if entry then destroyEntry(inst,entry) end; return end
	if not entry then
		local built,result=pcall(createEntry,inst)
		if not built then reportError("billboard",result); return end
		entry=result; Cache.espCache[inst]=entry; espCount=espCount+1; Runtime.statsDirty=true
	end
	local sig=crystalSignature(inst)
	if sig==entry.signature then return end
	local root=getRoot()
	local ok,err=pcall(applyDetails,inst,entry,root and root.Position or nil)
	if ok then entry.signature=sig else reportError("details",err) end
end
local sweepSeen={}
function sweep()
	local seen=sweepSeen; table.clear(seen)
	eachContainer(function(c)
		for _,child in ipairs(c:GetChildren()) do
			if not seen[child] and isCrystal(child) then
				seen[child]=true
				if not Cache.registry[child] then trackCrystal(child) end
			end
		end
	end)
	local stale
	for inst in pairs(Cache.registry) do
		if not seen[inst] then stale=stale or {}; stale[#stale+1]=inst end
	end
	if stale then for _,inst in ipairs(stale) do untrackCrystal(inst) end end
end
local lastDistanceOrigin
function updateDistances()
	local root=getRoot(); if not root then return end
	local origin=root.Position
	if lastDistanceOrigin and (origin-lastDistanceOrigin).Magnitude<1 then return end
	lastDistanceOrigin=origin
	for inst,entry in pairs(Cache.espCache) do
		if inst.Parent then
			local text=formatDistance((inst.Position-origin).Magnitude)
			if text~=entry.distanceText then applyExtra(entry,text) end
		end
	end
end
function clearEsp()
	for inst,entry in pairs(Cache.espCache) do destroyEntry(inst,entry) end
	Cache.espCache={}; espCount=0; Runtime.statsDirty=true
end
function clearRegistry()
	local all; for inst in pairs(Cache.registry) do all=all or {}; all[#all+1]=inst end
	if all then for _,inst in ipairs(all) do untrackCrystal(inst) end end
	clearEsp(); Cache.registry={}; Cache.candidates={}; Cache.dirty={}; registryCount=0; Runtime.statsDirty=true
end
function requestRefresh()
	for inst in pairs(Cache.registry) do Cache.dirty[inst]=true end
	Runtime.sweepAccumulator=math.huge
end
function onContainerChild(child)
	if looksLikeCrystal(child) then Cache.candidates[child]=os.clock()+CFG.ESP.ttl end
end
function watchContainers()
	for c,conn in pairs(Cache.containerConns) do
		if not c:IsDescendantOf(game) then conn:Disconnect(); Cache.containerConns[c]=nil end
	end
	eachContainer(function(c)
		if Cache.containerConns[c] then return end
		Cache.containerConns[c]=c.ChildAdded:Connect(onContainerChild)
	end)
end
function unwatchContainers()
	for c,conn in pairs(Cache.containerConns) do conn:Disconnect(); Cache.containerConns[c]=nil end
end
function updateTracking()
	if espActive then Runtime.sweepAccumulator=math.huge; watchContainers(); requestRefresh()
	else unwatchContainers(); clearRegistry() end
end
function getTrackedCrystalNames()
	local names={}; local seen={}
	local function addName(name)
		if type(name)~="string" then return end
		name=name:gsub("^%s+",""):gsub("%s+$","")
		if name=="" or seen[name] then return end
		seen[name]=true; names[#names+1]=name
	end
	local function addInst(inst)
		if not inst then return end
		local attr=getAttr(inst,"CrystalName")
		if type(attr)=="string" and attr~="" then
			addName(attr)
		elseif inst.Name and inst.Name:find("Crystal",1,true) then
			-- Only use names from explicit crystal data folders for directory
			-- discovery; do not treat arbitrary Workspace objects as a directory.
			addName(inst.Name:gsub("%s*Crystal$",""))
		end
	end

	-- Prefer the game's replicated/static data when it exists.
	local rs=S.ReplicatedStorage
	local directoryNames={"Crystals","CrystalTools","CrystalDirectory","CrystalData","CrystalTypes"}
	for _,folderName in ipairs(directoryNames) do
		local folder=rs:FindFirstChild(folderName,true)
		if folder then
			for _,child in ipairs(folder:GetChildren()) do
				local attr=getAttr(child,"CrystalName")
				if type(attr)=="string" and attr~="" then addName(attr)
				elseif child:IsA("Folder") or child:IsA("Model") or child:IsA("Configuration") then
					addName(child.Name)
				elseif child.Name and child.Name~="" then
					addName(child.Name)
				end
			end
		end
	end
	for _,inst in ipairs(rs:GetDescendants()) do
		local attr=getAttr(inst,"CrystalName")
		if type(attr)=="string" and attr~="" then addName(attr) end
	end

	-- Live-world fallback/merge so newly introduced crystal types also appear.
	for inst in pairs(Cache.registry) do
		if inst and inst.Parent and isCrystal(inst) then addName(crystalName(inst)) end
	end
	eachContainer(function(c)
		for _,inst in ipairs(c:GetDescendants()) do
			if isCrystal(inst) then addName(crystalName(inst)) end
		end
	end)
	table.sort(names,function(a,b) return string.lower(a)<string.lower(b) end)
	return names
end

function getTrackedRuneNames()
	-- The game's authoritative rune directory is:
	-- ReplicatedStorage > Assets > RuneTools
	-- Do NOT build this list from DroppedRunes/Workspace because that only
	-- contains runes that are currently spawned in the world.
	local names = {}
	local seen = {}

	local function addName(name)
		if type(name) ~= "string" then return end
		name = name:gsub("^%s+", ""):gsub("%s+$", "")
		if name == "" or seen[name] then return end
		seen[name] = true
		names[#names + 1] = name
	end

	local assets = S.ReplicatedStorage:FindFirstChild("Assets")
	local runeTools = assets and assets:FindFirstChild("RuneTools")
	if runeTools then
		for _, rune in ipairs(runeTools:GetChildren()) do
			addName(rune.Name)
		end
	end

	-- Fallback only if the directory is temporarily unavailable.
	if #names == 0 then
		local rs = S.ReplicatedStorage
		for _, inst in ipairs(rs:GetDescendants()) do
			local id = getAttr(inst, "RuneId") or getAttr(inst, "RuneName")
			if type(id) == "string" and id ~= "" then
				addName(id)
			end
		end
	end

	table.sort(names, function(a, b)
		return string.lower(a) < string.lower(b)
	end)
	return names
end

-- [19] PLAYER ESP
function destroyPlayerEntry(player)
	local entry=Cache.playerCache[player]; if not entry then return end
	if entry.gui then entry.gui:Destroy() end
	Cache.playerCache[player]=nil
end
function createPlayerEntry(player)
	local bb=Instance.new("BillboardGui")
	bb.Name="UniversePlayerEsp"; bb.AlwaysOnTop=true; bb.ResetOnSpawn=false
	bb.LightInfluence=0; bb.Size=playerGuiSize()
	bb.StudsOffsetWorldSpace=CFG.PLAYER.offset; bb.MaxDistance=CFG.PLAYER.distance; bb.Parent=EspHolder
	local ts=playerTextSize()
	local nameLabel,nc=newLabel("Name",    bb,0,2,CFG.COLORS.player,false,ts)
	local distLabel,dc=newLabel("Distance",bb,1,2,CFG.COLORS.extra, false,ts)
	nameLabel.Text=player.DisplayName
	return {gui=bb,name=nameLabel,distance=distLabel,constraints={nc,dc},nameText=player.DisplayName,distanceText=false}
end
function clearPlayerEsp()
	for player in pairs(Cache.playerCache) do destroyPlayerEntry(player) end
	Cache.playerCache={}
end
function updatePlayerEsp()
	if not playerEspActive then return end
	local root=getRoot(); local origin=root and root.Position or nil
	for _,player in ipairs(S.Players:GetPlayers()) do
		if player~=LocalPlayer then
			local char=player.Character
			local target=char and char:FindFirstChild("HumanoidRootPart")
			if target then
				local entry=Cache.playerCache[player]
				if not entry then
					local built,result=pcall(createPlayerEntry,player)
					if built then entry=result; Cache.playerCache[player]=entry else reportError("player",result) end
				end
				if entry then
					if entry.gui.Adornee~=target then entry.gui.Adornee=target end
					if entry.nameText~=player.DisplayName then
						entry.nameText=player.DisplayName; entry.name.Text=player.DisplayName
					end
					local text=origin and formatDistance((target.Position-origin).Magnitude) or "--"
					if text~=entry.distanceText then entry.distanceText=text; entry.distance.Text=text end
				end
			else
				destroyPlayerEntry(player)
			end
		end
	end
	local gone
	for player in pairs(Cache.playerCache) do
		if player==LocalPlayer or not player.Parent then gone=gone or {}; gone[#gone+1]=player end
	end
	if gone then for _,p in ipairs(gone) do destroyPlayerEntry(p) end end
end

-- [19.5] VEIN ESP MODULE — Optimized Terrain Scanner
local VeinsModule = {}
local veinConn
do
	local function install()
		local VEIN_MATS = {
			[Enum.Material.Pavement]    = {name="Gunpowder Stone", bomb="Classic Bomb",   color=Color3.fromRGB(150,150,150)},
			[Enum.Material.Salt]        = {name="Skyglass",         bomb="Wind Bomb",      color=Color3.fromRGB(200,220,255)},
			[Enum.Material.Ice]         = {name="Cryostone",        bomb="Ice Bomb",       color=Color3.fromRGB(100,200,255)},
			[Enum.Material.LeafyGrass]  = {name="Cinderforge Plate",bomb="Fire Bomb",      color=Color3.fromRGB(255,100,50)},
			[Enum.Material.Asphalt]     = {name="Stormsteel",       bomb="Thunder Bomb",   color=Color3.fromRGB(255,255,0)},
			[Enum.Material.Concrete]    = {name="Venomite",         bomb="Poison Bomb",    color=Color3.fromRGB(150,255,100)},
			[Enum.Material.Cobblestone] = {name="Chronoshard",      bomb="Time Bomb",      color=Color3.fromRGB(200,150,255)},
			[Enum.Material.Brick]       = {name="Dreadstone",        bomb="Agony Bomb",     color=Color3.fromRGB(255,50,50)},
			-- Dig veins from the exact NXROT engine:
			[Enum.Material.WoodPlanks]  = {name="Prismarite",        bomb="Dig", color=Color3.fromRGB(200,120,255)},
			[Enum.Material.Limestone]   = {name="Aetherstone",       bomb="Dig", color=Color3.fromRGB(80,220,255)},
			[Enum.Material.CrackedLava] = {name="Cracked Lava",      bomb="Dig", color=Color3.fromRGB(255,80,30)},
		}

				local ALL_VEIN_NAMES = {}
		do
			local seen = {}
			for _,info in pairs(VEIN_MATS) do
				if not seen[info.name] then
					seen[info.name] = true
					ALL_VEIN_NAMES[#ALL_VEIN_NAMES+1] = info.name
				end
			end
			table.sort(ALL_VEIN_NAMES)
		end

		-- SCAN RADIUS: ReadVoxels region scales as radius^3/4^3 voxels.
		-- 200 studs XZ, 100 studs Y → safe and covers all nearby veins.
		-- CFG.ESP.veinDistance controls BillboardGui MaxDistance (visual), NOT scan radius.
		local SCAN_RADIUS_XZ = 200
		local SCAN_RADIUS_Y  = 100
		local VEIN_STEP      = 4.0
		local VEIN_TTL       = 8.0
		local MAX_CARDS      = 40
		local OCCUPANCY_MIN  = 0.25  -- lower = catches partially-filled voxels
		local VEIN_OFFSET    = Vector3.new(0, 5, 0)

		local veinClusters = {}
		local veinClock = VEIN_STEP
		local enabled = false
		local scanRunning = false

		local function textSize()
			return math.max(6, math.floor(CFG.ESP.text * espScale + 0.5))
		end

		local function createCard(anchorPart, info)
			local bb = Instance.new("BillboardGui")
			bb.Name = "UniverseVeinEsp"
			bb.Adornee = anchorPart
			bb.AlwaysOnTop = true
			bb.ResetOnSpawn = false
			bb.LightInfluence = 0
			bb.MaxDistance = math.max(200, CFG.ESP.veinDistance)  -- visual range, separate from scan radius
			bb.Size = UDim2.fromOffset(220 * espScale, 44 * espScale)
			bb.StudsOffsetWorldSpace = VEIN_OFFSET
			bb.Parent = EspHolder

			local sz = textSize()
			local nameLabel,nc = newLabel("Name",bb,0,2,info.color,false,sz)
			nameLabel.Text = "[VEIN] " .. info.name
			local distLabel,dc = newLabel("Dist",bb,1,2,CFG.COLORS.extra,false,sz)
			distLabel.Text = info.bomb

			return {gui=bb,nameLabel=nameLabel,distLabel=distLabel,constraints={nc,dc}}
		end

		local function scaleCard(entry)
			if not entry or not entry.gui then return end
			entry.gui.Size = UDim2.fromOffset(220 * espScale, 44 * espScale)
			local sz = textSize()
			for _,c in ipairs(entry.constraints) do c.MaxTextSize = sz end
		end

		local function makeAnchor(position)
			local part = Instance.new("Part")
			part.Name = "UniverseVeinAnchor"
			part.Size = Vector3.new(0.5,0.5,0.5)
			part.CFrame = CFrame.new(position)
			part.Anchored = true
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
			part.CastShadow = false
			part.Transparency = 1
			part.Parent = EspHolder
			return part
		end

		local function destroyCard(cluster)
			if cluster.card then
				if cluster.card.gui then cluster.card.gui:Destroy() end
				cluster.card = nil
			end
			if cluster.anchor then
				cluster.anchor:Destroy()
				cluster.anchor = nil
			end
		end

		local function clearAll()
			for _,cluster in pairs(veinClusters) do destroyCard(cluster) end
			table.clear(veinClusters)
		end

		local function passesFilter(info)
			if not next(veinEspFilter) then return true end
			return veinEspFilter[info.name] == true
		end


		local function scanTerrain()
			if not enabled then return end
			if scanRunning then return end
			scanRunning = true
			local root = getRoot()
			if not root then scanRunning = false; return end
			local origin = root.Position

			local minPos = origin - Vector3.new(SCAN_RADIUS_XZ,SCAN_RADIUS_Y,SCAN_RADIUS_XZ)
			local maxPos = origin + Vector3.new(SCAN_RADIUS_XZ,SCAN_RADIUS_Y,SCAN_RADIUS_XZ)
			local ok,region = pcall(function()
				return Region3.new(minPos,maxPos):ExpandToGrid(4)
			end)
			if not ok or not region then scanRunning = false; return end

			local readOk,mats,occs = pcall(function()
				return S.Workspace.Terrain:ReadVoxels(region,4)
			end)
			if not readOk or not mats or not occs then scanRunning = false; return end

			local sz = mats.Size
			local regionMin = region.CFrame.Position - region.Size * 0.5
			local now = os.clock()

			-- ── PASS 1: collect valid voxel indices ──────────────────────────────
			-- comp[x][y][z] = component ID (0 = not a valid vein voxel)
			-- We work in voxel-index space, not world space, for speed.
			local matOf  = {}   -- [x][y][z] = Enum.Material  (only valid voxels)
			local comp   = {}   -- [x][y][z] = component id
			for x=1,sz.X do
				matOf[x]={}; comp[x]={}
				for y=1,sz.Y do
					matOf[x][y]={}; comp[x][y]={}
					for z=1,sz.Z do
						local occ = occs[x][y][z]
						if occ and occ >= OCCUPANCY_MIN then
							local mat = mats[x][y][z]
							local info = VEIN_MATS[mat]
							if info and passesFilter(info) then
								matOf[x][y][z] = mat
							end
						end
					end
				end
			end

			-- ── PASS 2: flood-fill connected components (6-connectivity) ─────────
			-- Two voxels are connected if they share a face AND have the same material.
			local numComps = 0
			local compData = {}   -- [id] = {mat, sumX, sumY, sumZ, count}
			local dirs = {{1,0,0},{-1,0,0},{0,1,0},{0,-1,0},{0,0,1},{0,0,-1}}
			local stack = {}

			for x=1,sz.X do for y=1,sz.Y do for z=1,sz.Z do
				if matOf[x][y][z] and not comp[x][y][z] then
					numComps = numComps + 1
					local id = numComps
					local mat = matOf[x][y][z]
					compData[id] = {mat=mat, sx=0, sy=0, sz=0, count=0}
					-- iterative BFS
					comp[x][y][z] = id
					local sp = 1; stack[1] = {x,y,z}
					while sp > 0 do
						local cur = stack[sp]; sp = sp - 1
						local cx,cy,cz = cur[1],cur[2],cur[3]
						local d = compData[id]
						d.sx = d.sx + cx; d.sy = d.sy + cy; d.sz = d.sz + cz; d.count = d.count + 1
						for _,dir in ipairs(dirs) do
							local nx,ny,nz = cx+dir[1], cy+dir[2], cz+dir[3]
							if nx>=1 and nx<=sz.X and ny>=1 and ny<=sz.Y and nz>=1 and nz<=sz.Z then
								if matOf[nx][ny][nz]==mat and not comp[nx][ny][nz] then
									comp[nx][ny][nz] = id
									sp = sp + 1; stack[sp] = {nx,ny,nz}
								end
							end
						end
					end
				end
			end end end

			-- ── PASS 3: compute centroid in world space, build/update clusters ────
			-- Component key = "comp_N" so it's stable within one scan but
			-- refreshes every scan interval (TTL handles persistence).
			local seen = {}
			for id=1,numComps do
				local d = compData[id]
				if d and d.count > 0 then
					local avgX = d.sx / d.count
					local avgY = d.sy / d.count
					local avgZ = d.sz / d.count
					local worldPos = regionMin + Vector3.new(
						(avgX - 0.5)*4, (avgY - 0.5)*4, (avgZ - 0.5)*4)
					local key = "cc_" .. tostring(d.mat) .. "_" ..
						tostring(math.floor(worldPos.X/32)) .. "_" ..
						tostring(math.floor(worldPos.Y/32)) .. "_" ..
						tostring(math.floor(worldPos.Z/32))
					seen[key] = true
					local cl = veinClusters[key]
					if not cl then
						cl = {material=d.mat, position=worldPos, lastSeen=now,
						      card=nil, anchor=nil, voxelCount=d.count}
						veinClusters[key] = cl
					else
						-- smooth centroid update between scans
						cl.position = cl.position:Lerp(worldPos, 0.35)
						cl.voxelCount = d.count
						cl.lastSeen = now
					end
				end
			end

			-- expire dead clusters
			for key,cl in pairs(veinClusters) do
				if not seen[key] and now - cl.lastSeen > VEIN_TTL then
					destroyCard(cl); veinClusters[key] = nil
				end
			end

			-- ── PASS 4: render nearest MAX_CARDS clusters only ───────────────────
			local candidates = {}
			for key,cl in pairs(veinClusters) do
				if seen[key] then
					local info = VEIN_MATS[cl.material]
					if info and passesFilter(info) then
						candidates[#candidates+1] = {
							key=key, cl=cl,
							dist=(cl.position-origin).Magnitude
						}
					end
				end
			end
			table.sort(candidates, function(a,b) return a.dist < b.dist end)

			local keep = {}
			for i=1,math.min(MAX_CARDS,#candidates) do
				local item = candidates[i]
				keep[item.key] = true
				local cl   = item.cl
				local info = VEIN_MATS[cl.material]
				if not cl.anchor then cl.anchor = makeAnchor(cl.position) end
				cl.anchor.CFrame = CFrame.new(cl.position)
				if not cl.card then cl.card = createCard(cl.anchor, info) end
				scaleCard(cl.card)
				local method = (info.bomb == "Dig") and "Dig" or ("Bomb: "..info.bomb)
				local distText = string.format("%s  •  %dm  •  %d vxl",
					method, math.floor(item.dist), cl.voxelCount)
				if cl.card.distLabel.Text ~= distText then
					cl.card.distLabel.Text = distText
				end
			end

			for key,cl in pairs(veinClusters) do
				if not keep[key] then destroyCard(cl) end
			end
			scanRunning = false
		end

		function VeinsModule.getClusters()
			return veinClusters
		end
		function VeinsModule.getAllMats()
			return VEIN_MATS
		end

		function VeinsModule.setVeinEsp(value)
			enabled = value == true
			if enabled then
				-- Langsung scan, jangan tunggu interval pertama
				veinClock = VEIN_STEP
			else
				clearAll()
			end
		end

		function VeinsModule.getTrackedVeinNames()
			return ALL_VEIN_NAMES
		end

		function VeinsModule.applyScale()
			veinClock=0
			for _,cluster in pairs(veinClusters) do
				if cluster.card then scaleCard(cluster.card); cluster.card.gui.MaxDistance=CFG.ESP.veinDistance end
			end
		end

		-- Driven by the single global scheduler. Keeping ESP scanners off their
		-- own Heartbeat connection prevents connection accumulation on reruns.
		function VeinsModule.tick(dt)
			if not enabled then return end
			veinClock = veinClock + dt
			local veinInterval = fpsBoostActive and math.max(VEIN_STEP,5.0) or VEIN_STEP
			if veinClock >= veinInterval then
				veinClock = 0
				task.spawn(function()
					pcall(scanTerrain)
				end)
			end
		end
	end
	install()
end

-- [19.6] PRISMARITE ESP MODULE — Terrain WoodPlanks Scanner
-- Standalone from Vein ESP. Prismarite is represented by Terrain Material WoodPlanks.
local PrismariteModule = {}
do
	local enabled = false
	local scannerEnabled = false
	local clock = 1.5
	local STEP = 1.5
	-- Keep Prismarite scans small. A 600x240x600 stud ReadVoxels region
	-- creates ~1.35M voxels per pass and causes large frame stalls.
	local SCAN_RADIUS_XZ = math.max(96, CFG.ESP.prismariteDistance)
	local SCAN_RADIUS_Y = math.max(64, CFG.ESP.prismariteDistance)
	local FARM_SCAN_RADIUS_XZ = 96
	local FARM_SCAN_RADIUS_Y = 96
	local FARM_SCAN_INTERVAL = 0.60
	local CLUSTER_SIZE = 16
	local OCCUPANCY_MIN = 0.35
	local TTL = 7.0
	local MAX_CARDS = 300
	local OFFSET = Vector3.new(0,5,0)
	local clusters = {}
	local scanning = false
	local scanSerial = 0

	local INFO = {
		name = "Prismarite",
		color = Color3.fromRGB(255,120,255),
	}

	local function textSize()
		return math.max(6, math.floor(CFG.ESP.text * espScale + 0.5))
	end

	local function makeAnchor(position)
		local part = Instance.new("Part")
		part.Name = "UniversePrismariteAnchor"
		part.Size = Vector3.new(0.5,0.5,0.5)
		part.CFrame = CFrame.new(position)
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.CastShadow = false
		part.Transparency = 1
		part.Parent = EspHolder
		return part
	end

	local function createCard(anchorPart)
		local bb = Instance.new("BillboardGui")
		bb.Name = "UniversePrismariteEsp"
		bb.Adornee = anchorPart
		bb.AlwaysOnTop = true
		bb.ResetOnSpawn = false
		bb.LightInfluence = 0
		bb.MaxDistance = math.max(3000, CFG.ESP.prismariteDistance)
		bb.Size = UDim2.fromOffset(220 * espScale, 44 * espScale)
		bb.StudsOffsetWorldSpace = OFFSET
		bb.Parent = EspHolder

		local sz = textSize()
		local nameLabel,nc = newLabel("Name",bb,0,2,INFO.color,false,sz)
		nameLabel.Text = "[PRISMARITE] Prismarite"
		local distLabel,dc = newLabel("Dist",bb,1,2,CFG.COLORS.extra,false,sz)

		return {gui=bb,nameLabel=nameLabel,distLabel=distLabel,constraints={nc,dc}}
	end

	local function destroyCard(cluster)
		if cluster.card then
			if cluster.card.gui then cluster.card.gui:Destroy() end
			cluster.card = nil
		end
		if cluster.anchor then
			cluster.anchor:Destroy()
			cluster.anchor = nil
		end
	end

	local function clear()
		for id,cluster in pairs(clusters) do
			destroyCard(cluster)
			clusters[id] = nil
		end
	end

	local function cellCoord(v)
		return math.floor(v / CLUSTER_SIZE)
	end

	local function cellKey(x,y,z)
		return tostring(x)..":"..tostring(y)..":"..tostring(z)
	end

	local function applyScaleCard(entry)
		if not entry or not entry.gui then return end
		entry.gui.Size = UDim2.fromOffset(220 * espScale,44 * espScale)
		local sz = textSize()
		for _,c in ipairs(entry.constraints) do c.MaxTextSize = sz end
	end

	local function scan()
		if scanning then return end
		scanning = true

		local root = getRoot()
		if not root then scanning=false; return end

		local origin = root.Position
		-- Farm scans a tighter hidden bubble while moving. At 350 studs/s and
		-- 0.45s cadence, an 80-stud radius almost exactly overlaps the flight
		-- path, while keeping each ReadVoxels pass to about 38k voxels.
		local radiusXZ = Runtime.PrismariteFarmActive==true and FARM_SCAN_RADIUS_XZ or SCAN_RADIUS_XZ
		local radiusY = Runtime.PrismariteFarmActive==true and FARM_SCAN_RADIUS_Y or SCAN_RADIUS_Y
		local minPos = origin - Vector3.new(radiusXZ,radiusY,radiusXZ)
		local maxPos = origin + Vector3.new(radiusXZ,radiusY,radiusXZ)
		local ok,region = pcall(function()
			return Region3.new(minPos,maxPos):ExpandToGrid(4)
		end)
		if not ok or not region then scanning=false; return end

		local readOk,mats,occs = pcall(function()
			return S.Workspace.Terrain:ReadVoxels(region,4)
		end)
		if not readOk or not mats or not occs then scanning=false; return end

		local size = mats.Size
		local regionMin = region.CFrame.Position - region.Size * 0.5
		local now = os.clock()
		local seen = {}

		for x=1,size.X do
			for y=1,size.Y do
				for z=1,size.Z do
					local occ = occs[x][y][z]
					if occ and occ >= OCCUPANCY_MIN and mats[x][y][z] == Enum.Material.WoodPlanks then
						local pos = regionMin + Vector3.new((x-0.5)*4,(y-0.5)*4,(z-0.5)*4)
						local cx,cy,cz = cellCoord(pos.X),cellCoord(pos.Y),cellCoord(pos.Z)
						local id = cellKey(cx,cy,cz)
						local cluster = clusters[id]
						if not cluster then
							cluster = {position=pos,lastSeen=now,count=0,card=nil,anchor=nil}
							clusters[id] = cluster
						end

						-- Rebuild this cluster from the CURRENT terrain scan.
						if not seen[id] then
							cluster.position = pos
							cluster.count = 0
						end
						cluster.position = cluster.position:Lerp(pos,1/math.max(1,cluster.count+1))
						cluster.count = cluster.count + 1
						cluster.lastSeen = now
						seen[id] = true
					end
				end
			end
		end

		for id,cluster in pairs(clusters) do
			if not seen[id] then
				local p=cluster.position
				local insideScan = p and p.X >= minPos.X-8 and p.X <= maxPos.X+8
					and p.Y >= minPos.Y-8 and p.Y <= maxPos.Y+8
					and p.Z >= minPos.Z-8 and p.Z <= maxPos.Z+8

				if Runtime.PrismariteFarmActive==true and insideScan then
					-- Fresh farm scan says this old voxel cluster is gone.
					destroyCard(cluster)
					clusters[id] = nil
				elseif now-cluster.lastSeen > TTL then
					destroyCard(cluster)
					clusters[id] = nil
				end
			end
		end

		-- Scanner-only mode is intentionally invisible: keep the cache but do not
		-- create hundreds of Parts/BillboardGuis while Premium Farm is running.
		if enabled then
			local candidates={}
			for id,cluster in pairs(clusters) do
				if seen[id] then
					candidates[#candidates+1] = {id=id,cluster=cluster,dist=(cluster.position-origin).Magnitude}
				end
			end
			table.sort(candidates,function(a,b) return a.dist < b.dist end)

			local keep={}
			for i=1,math.min(MAX_CARDS,#candidates) do
				local item=candidates[i]
				keep[item.id]=true
				local cluster=item.cluster
				if not cluster.anchor then cluster.anchor=makeAnchor(cluster.position) end
				cluster.anchor.CFrame=CFrame.new(cluster.position)
				if not cluster.card then cluster.card=createCard(cluster.anchor) end
				applyScaleCard(cluster.card)
				cluster.card.distLabel.Text=string.format("D-Hub On Top  •  %dm",math.floor(item.dist))
			end

			for id,cluster in pairs(clusters) do
				if not keep[id] then destroyCard(cluster) end
			end
		else
			for _,cluster in pairs(clusters) do
				destroyCard(cluster)
			end
		end

		scanSerial = scanSerial + 1
		scanning=false
	end

	function PrismariteModule.getScanSerial()
		return scanSerial
	end

	function PrismariteModule.setActive(value)
		enabled = value == true
		if enabled then
			scannerEnabled = true
		else
			-- Do not kill the hidden scanner while Premium Farm is active.
			if Runtime.PrismariteFarmActive ~= true then
				scannerEnabled = false
				clear()
			end
		end
		clock = STEP
	end

	function PrismariteModule.setScannerActive(value)
		scannerEnabled = value == true
		if scannerEnabled then clock = FARM_SCAN_INTERVAL end
		if not scannerEnabled and not enabled then
			clear()
		end
		clock = 0
	end

	function PrismariteModule.isActive()
		return enabled == true
	end

	function PrismariteModule.isScannerActive()
		return scannerEnabled == true
	end

	function PrismariteModule.applyScale()
		clock=0
		for _,cluster in pairs(clusters) do
			if cluster.card then applyScaleCard(cluster.card); cluster.card.gui.MaxDistance=math.max(3000, CFG.ESP.prismariteDistance) end
		end
	end

	-- Read-only target API for Premium Prismarite Farm.
	function PrismariteModule.getTargets(origin)
		local list={}
		local now=os.clock()
		local pos=origin or Vector3.zero
		for id,cluster in pairs(clusters) do
			if cluster.position and cluster.count and cluster.count>0 and now-cluster.lastSeen<=TTL then
				local dist=(cluster.position-pos).Magnitude
				if dist<=SCAN_RADIUS_XZ+30 then
					list[#list+1]={id=id,position=cluster.position,count=cluster.count,distance=dist,lastSeen=cluster.lastSeen}
				end
			end
		end
		table.sort(list,function(a,b) return a.distance<b.distance end)
		return list
	end

	function PrismariteModule.getAllTargets()
		local list={}
		local now=os.clock()
		for id,cluster in pairs(clusters) do
			if cluster.position and cluster.count and cluster.count>0 and now-cluster.lastSeen<=TTL then
				list[#list+1]={id=id,position=cluster.position,count=cluster.count,distance=0,lastSeen=cluster.lastSeen}
			end
		end
		table.sort(list,function(a,b) return a.lastSeen>b.lastSeen end)
		return list
	end

	function PrismariteModule.getAreaTargets(center,radius,maxAge)
		local list={}
		local now=os.clock()
		if typeof(center)~="Vector3" then return list end
		radius=tonumber(radius) or 56
		maxAge=tonumber(maxAge) or 1.1
		for id,cluster in pairs(clusters) do
			if cluster.position and cluster.count and cluster.count>0 and now-cluster.lastSeen<=maxAge then
				local distance=(cluster.position-center).Magnitude
				if distance<=radius then
					list[#list+1]={id=id,position=cluster.position,count=cluster.count,distance=distance,lastSeen=cluster.lastSeen}
				end
			end
		end
		table.sort(list,function(a,b)
			if a.distance==b.distance then return a.count>b.count end
			return a.distance<b.distance
		end)
		return list
	end

	function PrismariteModule.getNearest(origin,excludeId)
		local list=PrismariteModule.getTargets(origin)
		for _,entry in ipairs(list) do if entry.id~=excludeId then return entry end end
		return nil
	end

	function PrismariteModule.getStats(origin)
		local list=PrismariteModule.getTargets(origin)
		local nearest=list[1]
		return #list,nearest and nearest.distance or nil
	end

	PrismariteModule.clear=clear

	PrismariteModule.tick=function(dt)
		if not scannerEnabled then return end
		clock=clock+dt
		local interval
		if Runtime.PrismariteFarmActive==true then
			interval=FARM_SCAN_INTERVAL
		else
			interval=fpsBoostActive and math.max(STEP,2.5) or STEP
		end
		if clock>=interval then
			clock=0
			task.spawn(function() pcall(scan) end)
		end
	end

end
-- [20] TELEPORT
local streamMark=0; local streamSpot
function requestStream(position)
	if typeof(position)~="Vector3" then return end
	local now=os.clock()
	if streamSpot and now-streamMark<0.3 and (streamSpot-position).Magnitude<32 then return end
	streamMark=now; streamSpot=position
	task.spawn(function() pcall(function() LocalPlayer:RequestStreamAroundAsync(position,1) end) end)
end
function applyPivot(cframe)
	local char=LocalPlayer.Character; if not char then return false end
	requestStream(cframe.Position)
	local root=getRoot(); if not root then return false end
	local moved=pcall(function() char:PivotTo(cframe) end)
	if not moved then moved=pcall(function() root.CFrame=cframe end) end
	if not moved then return false end
	pcall(function()
		root.AssemblyLinearVelocity=Vector3.zero
		root.AssemblyAngularVelocity=Vector3.zero
	end)
	return true
end
function findClearGoal(position,ignore)
	local params=OverlapParams.new()
	params.FilterType=Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances=ignore; params.MaxParts=1
	for _,offset in ipairs(CFG.TP.clear) do
		local candidate=position+offset
		local ok,hits=pcall(function() return S.Workspace:GetPartBoundsInRadius(candidate,2.5,params) end)
		if ok and #hits==0 then return candidate end
	end
	return position+CFG.TP.clear[#CFG.TP.clear]
end
function finishTeleport()
	if not Runtime.tpState then return end
	local root=getRoot()
	if root then pcall(function()
		root.AssemblyLinearVelocity=Vector3.zero
		root.AssemblyAngularVelocity=Vector3.zero
	end) end
	local char=LocalPlayer.Character
	local h=char and char:FindFirstChildOfClass("Humanoid")
	if h then pcall(function()
		h.PlatformStand=false
		h:SetStateEnabled(Enum.HumanoidStateType.Freefall,true)
		h:SetStateEnabled(Enum.HumanoidStateType.FallingDown,true)
		h:SetStateEnabled(Enum.HumanoidStateType.Ragdoll,true)
		h:ChangeState(Enum.HumanoidStateType.GettingUp)
	end) end
	Runtime.tpState=nil
end
function teleportTo(target)
	local position
	if typeof(target)=="Vector3" then position=target
	elseif typeof(target)=="Instance" and target.Parent then position=target.Position end
	if not position then return false end
	local char=LocalPlayer.Character; if not char then return false end
	local root=getRoot(); if not root then return false end
	finishTeleport()
	local h=char:FindFirstChildOfClass("Humanoid")
	if h then pcall(function()
		if h.SeatPart or h.Sit then h.Sit=false end
		h:SetStateEnabled(Enum.HumanoidStateType.FallingDown,false)
		h:SetStateEnabled(Enum.HumanoidStateType.Ragdoll,false)
	end) end
	local ignore={char}
	if typeof(target)=="Instance" then ignore[#ignore+1]=target end
	local goalFrame=CFrame.new(findClearGoal(position+CFG.TP.offset,ignore))
	if not applyPivot(goalFrame) then return false end
	Runtime.tpState={goal=goalFrame,holdUntil=os.clock()+CFG.TP.hold}
	return true
end

-- [21] PICKUP MECHANICS
local promptCache=setmetatable({},{__mode="k"})
function crystalPrompt(inst)
	local cached=promptCache[inst]
	if cached and cached.Parent then return cached end
	local ok,prompt=pcall(inst.FindFirstChildOfClass,inst,"ProximityPrompt")
	if not (ok and prompt) then
		ok,prompt=pcall(inst.FindFirstChildWhichIsA,inst,"ProximityPrompt",true)
	end
	if ok and prompt then promptCache[inst]=prompt; return prompt end
	promptCache[inst]=nil; return nil
end
function surfaceDistance(part,origin)
	local ok,distance=pcall(function()
		local point=part.CFrame:PointToObjectSpace(origin)
		local half=part.Size*0.5
		local clamped=Vector3.new(
			math.clamp(point.X,-half.X,half.X),
			math.clamp(point.Y,-half.Y,half.Y),
			math.clamp(point.Z,-half.Z,half.Z))
		return (point-clamped).Magnitude
	end)
	if ok and distance then return distance end
	return (part.Position-origin).Magnitude
end
function firePrompt(prompt)
	if not Cache.promptRestores[prompt] then
		Cache.promptRestores[prompt]={
			hold=prompt.HoldDuration,sight=prompt.RequiresLineOfSight,
			enabled=prompt.Enabled,range=prompt.MaxActivationDistance,
		}
	end
	pcall(function()
		prompt.HoldDuration=0; prompt.RequiresLineOfSight=false
		prompt.Enabled=true; prompt.MaxActivationDistance=1000
	end)
	local fired=false
	if typeof(fireproximityprompt)=="function" then
		fired=pcall(fireproximityprompt,prompt,1)
		if not fired then fired=pcall(fireproximityprompt,prompt) end
	end
	if not fired then
		fired=pcall(function() prompt:InputHoldBegin(); prompt:InputHoldEnd() end)
	end
	schedule(CFG.PICK.restore,function()
		local saved=Cache.promptRestores[prompt]; if not saved then return end
		Cache.promptRestores[prompt]=nil
		if prompt.Parent then
			prompt.HoldDuration=saved.hold; prompt.RequiresLineOfSight=saved.sight
			prompt.Enabled=saved.enabled; prompt.MaxActivationDistance=saved.range
		end
	end)
	return fired
end
local pickupParams=OverlapParams.new()
pickupParams.FilterType=Enum.RaycastFilterType.Exclude
pcall(function() pickupParams.MaxParts=300; pickupParams.RespectCanCollide=false end)
function pickupCandidates(free,origin,rangeOverride)
	local found=Cache.pickupFound; local seen=Cache.pickupSeen
	local scanRange=tonumber(rangeOverride) or CFG.PICK.range
	table.clear(found); table.clear(seen)
	local now=os.clock()
	local function consider(child)
		if not child or seen[child] then return end; seen[child]=true
		if not child.Parent or not isCrystal(child) or getAttr(child,"Collected")==true then return end
		local claim=Cache.claimed[child]
		if claim and now-claim<CFG.PICK.retry then return end
		local value=crystalValue(child)
		if not meetsPickupFilter(child,value) then return end
		local weight=crystalWeight(child)
		if weight>free then return end
		local dist=surfaceDistance(child,origin)
		if dist>scanRange then return end
		found[#found+1]={inst=child,prompt=crystalPrompt(child),value=value,weight=weight,distance=dist,tier=crystalTier(child)}
	end
	pickupParams.FilterDescendantsInstances={LocalPlayer.Character or LocalPlayer}
	local ok,hits=pcall(function() return S.Workspace:GetPartBoundsInRadius(origin,scanRange+CFG.PICK.pad,pickupParams) end)
	if ok and hits then for _,p in ipairs(hits) do consider(p) end end
	eachContainer(function(c)
		for _,child in ipairs(c:GetChildren()) do
			if child:IsA("BasePart") then consider(child)
			elseif child:IsA("Model") then for _,inner in ipairs(child:GetChildren()) do consider(inner) end end
		end
	end)
	for inst in pairs(Cache.registry) do consider(inst) end
	local useRarityPriority=(next(rarityPickupFilter)~=nil and next(rarityPickupFilter,next(rarityPickupFilter))~=nil)
	table.sort(found,function(a,b)
		if useRarityPriority and a.tier~=b.tier then return a.tier>b.tier end
		if a.value==b.value then return a.distance<b.distance end
		return a.value>b.value
	end)
	return found
end
function grabCrystal(inst,prompt,forcePickup)
	local sent=false
	local hp=tonumber(getAttr(inst,"MinedHP"))
	if RMT.HoldComplete and (forcePickup or not hp or hp<=0) then
		sent=pcall(function() RMT.HoldComplete:FireServer(inst) end)
		if typeof(getnilinstances)=="function" then
			local ok,nilList=pcall(getnilinstances)
			if ok and nilList then
				for _,obj in ipairs(nilList) do
					if obj.Name==inst.Name and typeof(obj)=="Instance" then
						pcall(function() RMT.HoldComplete:FireServer(obj) end); break
					end
				end
			end
		end
	end
	-- Trigger extra client logic per request
	local pickupJuice = findRemote("CrystalPickupJuice")
	if pickupJuice and (forcePickup or not hp or hp<=0) then
		pcall(function() pickupJuice:FireServer(inst, true) end)
	end
	if not prompt then prompt=crystalPrompt(inst) end
	if prompt and prompt.Parent and firePrompt(prompt) then sent=true end
	if not sent and typeof(fireclickdetector)=="function" then
		local ok,det=pcall(inst.FindFirstChildWhichIsA,inst,"ClickDetector",true)
		if ok and det then sent=pcall(fireclickdetector,det,0) end
	end
	return sent
end
function instantPromptPatch(prompt)
	if Cache.instantPatched[prompt] or Cache.promptRestores[prompt] then return end
	Cache.instantPatched[prompt]={hold=prompt.HoldDuration,sight=prompt.RequiresLineOfSight,enabled=prompt.Enabled}
	pcall(function() prompt.HoldDuration=0; prompt.RequiresLineOfSight=false; prompt.Enabled=true end)
end
function restoreInstantPrompts()
	for prompt,saved in pairs(Cache.instantPatched) do
		if prompt.Parent then
			pcall(function()
				prompt.HoldDuration=saved.hold; prompt.RequiresLineOfSight=saved.sight; prompt.Enabled=saved.enabled
			end)
		end
	end
	table.clear(Cache.instantPatched)
end
function nearbyCrystalParts(origin,radius)
	pickupParams.FilterDescendantsInstances={LocalPlayer.Character or LocalPlayer}
	local ok,hits=pcall(function() return S.Workspace:GetPartBoundsInRadius(origin,radius,pickupParams) end)
	return (ok and hits) and hits or nil
end
function refreshInstantPrompts()
	local root=getRoot(); if not root then return end
	local stale
	for prompt in pairs(Cache.instantPatched) do
		if not prompt.Parent then stale=stale or {}; stale[#stale+1]=prompt end
	end
	if stale then for _,p in ipairs(stale) do Cache.instantPatched[p]=nil end end
	local hits=nearbyCrystalParts(root.Position,CFG.PICK.instantRadius)
	if not hits then return end
	local seen={}
	for _,part in ipairs(hits) do
		local prompt=part:FindFirstChildWhichIsA("ProximityPrompt",true)
		if prompt and not seen[prompt] then seen[prompt]=true; instantPromptPatch(prompt) end
		local model=part:FindFirstAncestorOfClass("Model")
		if model then
			prompt=model:FindFirstChildWhichIsA("ProximityPrompt",true)
			if prompt and not seen[prompt] then seen[prompt]=true; instantPromptPatch(prompt) end
		end
	end
end

function setInstantPrompt(value)
	instantPromptActive=value; Runtime.instantAccumulator=math.huge
	if not value then restoreInstantPrompts() end
end
function instantGrab()
	if not instantPromptActive then return end
	local root=getRoot(); if not root then return end
	local hits=nearbyCrystalParts(root.Position,CFG.PICK.range+CFG.PICK.pad)
	if not hits then return end
	local best,bestPrompt,bestDistance
	for _,part in ipairs(hits) do
		if part.Parent and isCrystal(part) and getAttr(part,"Collected")~=true and meetsPickupFilter(part,crystalValue(part)) then
			local dist=surfaceDistance(part,root.Position)
			if dist<=CFG.PICK.range and (not best or dist<bestDistance) then
				best=part; bestPrompt=crystalPrompt(part); bestDistance=dist
			end
		end
	end
	if not best then return end
	if bestPrompt then instantPromptPatch(bestPrompt) end
	if grabCrystal(best,bestPrompt) then Cache.claimed[best]=os.clock() end
end
function pickupStep()
	if Runtime._pickupStepRunning then return end
	Runtime._pickupStepRunning=true
	local now=os.clock()
	if now-Runtime.lastPickup<CFG.PICK.cooldown then Runtime._pickupStepRunning=false; return end
	local root=getRoot(); if not root then Runtime._pickupStepRunning=false; return end
	local free=backpackFree()
	if free<=0 then
		if now-Runtime.lastBagWarn>=8 then Runtime.lastBagWarn=now; Notify("Backpack full",2) end
		Runtime._pickupStepRunning=false; return
	end
	for inst,stamp in pairs(Cache.claimed) do
		if now-stamp>=CFG.PICK.forget or not inst.Parent then Cache.claimed[inst]=nil end
	end
	local cands=pickupCandidates(free,root.Position)
	if #cands==0 then requestStream(root.Position); Runtime._pickupStepRunning=false; return end
	local budget=free; local grabs=0
	for _,entry in ipairs(cands) do
		if grabs>=CFG.PICK.burst then break end
		if entry.weight<=budget then
			Cache.claimed[entry.inst]=now
			if grabCrystal(entry.inst,entry.prompt) then budget=budget-entry.weight; grabs=grabs+1 end
		end
	end
	if grabs>0 then Runtime.lastPickup=now end
	Runtime._pickupStepRunning=false
end

-- [22] SPEED
function enforceSpeed(humanoid)
	if not humanoid or humanoid.WalkSpeed==CFG.PACE.boost then return end
	pcall(function() humanoid.WalkSpeed=CFG.PACE.boost end)
end
function watchSpeed(humanoid)
	if Runtime.speedHooked==humanoid then return end
	if Runtime.speedConn then Runtime.speedConn:Disconnect(); Runtime.speedConn=nil end
	Runtime.speedHooked=humanoid; if not humanoid then return end
	local ok,conn=pcall(function()
		return humanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
			if speedActive then enforceSpeed(humanoid) end
		end)
	end)
	if ok then Runtime.speedConn=conn end
end
function setSpeedBoost(value)
	speedActive=value
	local char=LocalPlayer.Character
	local h=char and char:FindFirstChildOfClass("Humanoid")
	if value then watchSpeed(h); enforceSpeed(h); return end
	watchSpeed(nil)
	if h then pcall(function() h.WalkSpeed=CFG.PACE.normal end) end
end

-- [23] FPS BOOST (ULTRA / ALL-IN-ONE — UI SAFE)
-- One toggle only. Aggressive visual optimization without touching game UI.
-- IMPORTANT: Do not lower Roblox rendering quality globally and do not modify
-- GuiObjects/LayerCollectors/SurfaceGui/BillboardGui outside the crystal-hide system.
function applyFpsBoost(enabled)
	fpsBoostActive=enabled
	Toggles.FpsBoost=enabled
	Toggles.UltraFps=enabled -- compatibility only
	local Lighting=S.Lighting
	local POST_TYPES={BloomEffect=true,BlurEffect=true,ColorCorrectionEffect=true,DepthOfFieldEffect=true,SunRaysEffect=true}
	local KILL_TYPES={ParticleEmitter=true,Trail=true,Beam=true,Smoke=true,Fire=true,Sparkles=true}

	if enabled then
		Runtime.fpsPassId=Runtime.fpsPassId+1
		local passId=Runtime.fpsPassId

		-- Save only global visual settings that we actually change.
		Runtime.savedLightState.GlobalShadows=Lighting.GlobalShadows
		Runtime.savedLightState.FogEnd=Lighting.FogEnd
		Runtime.savedWaterWaveSpeed=workspace.Terrain.WaterWaveSpeed
		Runtime.savedWaterReflectance=workspace.Terrain.WaterReflectance

		pcall(function() Lighting.GlobalShadows=false end)
		pcall(function() Lighting.FogEnd=100000 end)

		-- Do NOT force QualityLevel=Level01 here.
		-- That setting is global and can alter the game's own presentation/UI.
		-- We get the FPS gain from disabling expensive visual effects instead.

		table.clear(Runtime.savedParticleState)
		table.clear(Runtime.savedPostFx)
		table.clear(Runtime.savedCastShadow)

		-- Only process visual effect instances. We deliberately do NOT iterate
		-- BaseParts and do not touch anything under PlayerGui/CoreGui.
		local ok,objects=pcall(function() return workspace:GetDescendants() end)
		if ok and type(objects)=="table" then
			task.spawn(function()
				local processed=0
				for _,obj in ipairs(objects) do
					if Runtime.fpsPassId~=passId or not fpsBoostActive then return end
					local cls=obj.ClassName
					if KILL_TYPES[cls] then
						Runtime.savedParticleState[obj]=obj.Enabled
						if obj.Enabled then pcall(function() obj.Enabled=false end) end
					elseif POST_TYPES[cls] then
						Runtime.savedPostFx[obj]=obj.Enabled
						if obj.Enabled then pcall(function() obj.Enabled=false end) end
					end
					processed=processed+1
					if processed%300==0 then task.wait() end
				end
			end)
		end

		-- Lighting post-processing is kept separate and chunked.
		local okLight,lightObjects=pcall(function() return Lighting:GetDescendants() end)
		if okLight and type(lightObjects)=="table" then
			task.spawn(function()
				for i,obj in ipairs(lightObjects) do
					if Runtime.fpsPassId~=passId or not fpsBoostActive then return end
					if POST_TYPES[obj.ClassName] then
						Runtime.savedPostFx[obj]=obj.Enabled
						pcall(function() obj.Enabled=false end)
					end
					if i%50==0 then task.wait() end
				end
			end)
		end

		pcall(function() workspace.Terrain.Decoration=false end)
		pcall(function() workspace.Terrain.WaterWaveSize=0 end)
		pcall(function() workspace.Terrain.WaterWaveSpeed=0 end)
		pcall(function() workspace.Terrain.WaterReflectance=0 end)

		-- New visual effects are handled, but GUI objects are never modified.
		if not Runtime.fpsBoostDescConn then
			Runtime.fpsBoostDescConn=workspace.DescendantAdded:Connect(function(obj)
				if not fpsBoostActive then return end
				local cls=obj.ClassName
				if KILL_TYPES[cls] then
					Runtime.savedParticleState[obj]=obj.Enabled
					pcall(function() obj.Enabled=false end)
				elseif POST_TYPES[cls] then
					Runtime.savedPostFx[obj]=obj.Enabled
					pcall(function() obj.Enabled=false end)
				end
			end)
		end

		-- Keep the low-value crystal optimization, but it is the ONLY place
		-- where the script intentionally hides BillboardGui/SurfaceGui children.
		pcall(refreshCrystalVisibility)
		Notify("FPS Boost ON - Ultra / UI Safe",2)
	else
		Runtime.fpsPassId=Runtime.fpsPassId+1

		if Runtime.savedLightState.GlobalShadows~=nil then
			pcall(function() Lighting.GlobalShadows=Runtime.savedLightState.GlobalShadows end)
		end
		if Runtime.savedLightState.FogEnd~=nil then
			pcall(function() Lighting.FogEnd=Runtime.savedLightState.FogEnd end)
		end

		for obj,wasEnabled in pairs(Runtime.savedParticleState) do
			if obj and obj.Parent then pcall(function() obj.Enabled=wasEnabled end) end
		end
		for obj,wasEnabled in pairs(Runtime.savedPostFx) do
			if obj and obj.Parent then pcall(function() obj.Enabled=wasEnabled end) end
		end

		-- Kept only for compatibility with older saved state. This version does
		-- not modify CastShadow, so normally this table stays empty.
		for obj,oldShadow in pairs(Runtime.savedCastShadow) do
			if obj and obj.Parent then pcall(function() obj.CastShadow=oldShadow end) end
		end

		table.clear(Runtime.savedParticleState)
		table.clear(Runtime.savedPostFx)
		table.clear(Runtime.savedCastShadow)
		pcall(function() workspace.Terrain.Decoration=true end)
		if Runtime.savedWaterWaveSpeed~=nil then pcall(function() workspace.Terrain.WaterWaveSpeed=Runtime.savedWaterWaveSpeed end) end
		if Runtime.savedWaterReflectance~=nil then pcall(function() workspace.Terrain.WaterReflectance=Runtime.savedWaterReflectance end) end
		if Runtime.fpsBoostDescConn then Runtime.fpsBoostDescConn:Disconnect(); Runtime.fpsBoostDescConn=nil end
		fpsBoostActive=false
		pcall(refreshCrystalVisibility)
		Notify("FPS Boost OFF",2)
	end
end

-- [24] AUTO REVIVE
if RMT.ReviveShow then
	RMT.ReviveShow.OnClientEvent:Connect(function()
		if not autoReviveActive then return end
		task.wait(0.4)
		pcall(function() RMT.ReviveBase:FireServer() end)
	end)
end

-- [25] AUTO HOP
function startAutoHop()
	if Runtime.autoHopConn then Runtime.autoHopConn:Disconnect(); Runtime.autoHopConn=nil end
	if not autoHopActive then return end
	Runtime.autoHopStartClock=os.clock()
	local targetSec=autoHopMinutes*60
	Runtime.autoHopConn=S.RunService.Heartbeat:Connect(function()
		if not autoHopActive then Runtime.autoHopConn:Disconnect(); Runtime.autoHopConn=nil; return end
		if os.clock()-Runtime.autoHopStartClock>=targetSec then
			Runtime.autoHopConn:Disconnect(); Runtime.autoHopConn=nil
			Notify(string.format("Auto-hop: %d min reached",autoHopMinutes),3)
			task.wait(1)
			if Net and Net.hop then Net.hop() end
		end
	end)
end
function setAutoHop(enabled)
	autoHopActive=enabled
	if enabled then startAutoHop()
	else if Runtime.autoHopConn then Runtime.autoHopConn:Disconnect(); Runtime.autoHopConn=nil end end
	if saveConfig then pcall(saveConfig) end
end

-- [26] MOUNTAIN MODULE
local Mountain={}
local mountainConn
do
	local function install()
		local BOULDER_INFO={
			Mossite   ={rarity="Common",    pickaxe="Titanium Spike", crystals="8-11",  runes="Luck / Haste",        color=Color3.fromRGB(150,220,120)},
			Voltite   ={rarity="Uncommon",  pickaxe="Celestial Apex", crystals="10-14", runes="Storm / Weight",        color=Color3.fromRGB(110,190,240)},
			Gildrite  ={rarity="Rare",      pickaxe="Eclipse Fang",   crystals="11-15", runes="Fortune / Detonation",  color=Color3.fromRGB(255,200,60)},
			Rimeveil  ={rarity="Epic",      pickaxe="Voidreign",      crystals="13-18", runes="Preservation / Warmth", color=Color3.fromRGB(170,100,255)},
			Nocturnite={rarity="Legendary", pickaxe="The Terminus",   crystals="16-22", runes="Excavator / Colossus",  color=Color3.fromRGB(255,80,180)},
		}
		local BOULDER_OFFSET=Vector3.new(0,7,0)
		local BOULDER_WIDTH=300; local BOULDER_HEIGHT=78
		local BOULDER_STEP=0.8; local BOULDER_MAX_DISTANCE=math.max(350, CFG.ESP.boulderDistance); local GRAB_RANGE=20
		local GRAB_STEP=0.08; local GRAB_LIMIT=8; local GRAB_RETRY=0.15
		-- Rune pickup: wider sweep radius, separate fly-to logic
		local RUNE_FLY_RANGE=90   -- how far we scan for missed runes
		local RUNE_FLY_DIST=6     -- approach within this to grab
		local runeFlyTarget=nil   -- current rune we're flying to grab
		local runeFlyAt=0         -- clock when we started approaching it
		local boulderEsp=false; local autoGrab=false
		local boulderCache={}; local grabbed={}
		local boulderClock=0; local grabClock=0
		local scanParams=OverlapParams.new()
		scanParams.FilterType=Enum.RaycastFilterType.Exclude
		local function textSize() return math.max(6,math.floor(CFG.ESP.text*boulderScale+0.5)) end
		local function anchorPart(inst)
			if inst:IsA("BasePart") then return inst end
			if inst:IsA("Model") then return inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart") end
			return nil
		end
		local function createCard(anchor,offset,colors,width,height)
			local bb=Instance.new("BillboardGui")
			bb.Name="UniverseMountainEsp"; bb.Adornee=anchor; bb.AlwaysOnTop=true
			bb.ResetOnSpawn=false; bb.LightInfluence=0
			bb.Size=UDim2.fromOffset(width*boulderScale,height*boulderScale)
			bb.StudsOffsetWorldSpace=offset; bb.MaxDistance=CFG.ESP.boulderDistance; bb.Parent=EspHolder
			local total=#colors; local sz=textSize(); local labels={}; local constraints={}
			for i,color in ipairs(colors) do
				local label,constraint=newLabel("Line"..i,bb,i-1,total,color,false,sz)
				labels[i]=label; constraints[i]=constraint
			end
			-- Highlight on the model for AlwaysOnTop outline visible from any distance
			local hl=Instance.new("Highlight")
			hl.Name="NXROTBoulderHL"; hl.Adornee=anchor.Parent or anchor
			hl.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop
			hl.FillTransparency=0.82; hl.OutlineTransparency=0.05
			hl.FillColor=colors[1]; hl.OutlineColor=colors[1]; hl.Parent=EspHolder
			return {gui=bb,hl=hl,labels=labels,constraints=constraints,width=width,height=height,text={}}
		end
		local function scaleCard(entry)
			entry.gui.Size=UDim2.fromOffset(entry.width*boulderScale,entry.height*boulderScale)
			local sz=textSize(); for _,c in ipairs(entry.constraints) do c.MaxTextSize=sz end
		end
		local function setLine(entry,index,text)
			if entry.text[index]==text then return end
			entry.text[index]=text; entry.labels[index].Text=text
		end
		local function dropCard(cache,key)
			local e=cache[key]; if not e then return end
			if e.gui then e.gui:Destroy() end; cache[key]=nil
		end
		local function clearCache(cache) for key in pairs(cache) do dropCard(cache,key) end end
		local function boulderKind(inst)
			for kind in pairs(BOULDER_INFO) do if inst.Name:find(kind,1,true) then return kind end end
			return nil
		end
		local function boulderRoots()
			local roots={}
			local deco=S.Workspace:FindFirstChild("MountainDecorations")
			local fold=deco and deco:FindFirstChild("Boulders"); if fold then roots[#roots+1]=fold end
			local test=S.Workspace:FindFirstChild("BoulderTest"); if test then roots[#roots+1]=test end
			return roots
		end
		local function eachBoulder(fn)
			for _,container in ipairs(boulderRoots()) do
				for _,child in ipairs(container:GetChildren()) do
					local kind=boulderKind(child); if kind then fn(child,kind) end
				end
			end
		end
		local function isRune(inst)
			if getAttr(inst,"RuneId")~=nil then return true end
			if getAttr(inst,"IsRune")==true then return true end
			if getAttr(inst,"RuneName")~=nil then return true end
			return inst.Name:find(" Rune",1,true)~=nil
		end
		local function runeTitle(inst)
			local id=getAttr(inst,"RuneId") or getAttr(inst,"RuneName")
			if type(id)=="string" and id~="" then
				if id:find("Rune",1,true) then return id end
				return id.." Rune"
			end
			return inst.Name
		end
		local function eachRune(origin,radius,fn)
			local seen={}
			local function offer(owner,part)
				if not owner or seen[owner] then return end
				local anchor=part or anchorPart(owner)
				if not anchor or not anchor.Parent then return end
				if (anchor.Position-origin).Magnitude>radius then return end
				seen[owner]=true; fn(owner,anchor)
			end
			local function scanFolder(c)
				if not c then return end
				for _,child in ipairs(c:GetChildren()) do
					if isRune(child) then offer(child,anchorPart(child)) end
				end
			end
			scanFolder(S.Workspace:FindFirstChild("DroppedRunes"))
			local char=LocalPlayer.Character
			scanParams.FilterDescendantsInstances=char and {char} or {}
			local ok,parts=pcall(function() return S.Workspace:GetPartBoundsInRadius(origin,radius,scanParams) end)
			if not ok or not parts then return end
			for _,part in ipairs(parts) do
				if isRune(part) then offer(part,part)
				else
					local parent=part.Parent
					if parent and parent~=S.Workspace and isRune(parent) then
						offer(parent,anchorPart(parent) or part)
					end
				end
			end
		end
		local function syncBoulders()
			local root=getRoot(); local origin=root and root.Position or nil; local seen={}
			eachBoulder(function(model,kind)
				local anchor=anchorPart(model); if not anchor then return end
			local distance=origin and (anchor.Position-origin).Magnitude or 0
			if origin and distance>BOULDER_MAX_DISTANCE then dropCard(boulderCache,model); return end
				seen[model]=true
				if next(boulderEspFilter)~=nil and not boulderEspFilter[kind] then
					local entry=boulderCache[model]
					if entry then dropCard(boulderCache,model) end
					return
				end
				local info=BOULDER_INFO[kind]
				local entry=boulderCache[model]
				if entry and not entry.gui.Parent then dropCard(boulderCache,model); entry=nil end
				if not entry then
					entry=createCard(anchor,BOULDER_OFFSET,{info.color,CFG.COLORS.extra,CFG.COLORS.money},BOULDER_WIDTH,BOULDER_HEIGHT)
					boulderCache[model]=entry
				end
				if entry.gui.Adornee~=anchor then entry.gui.Adornee=anchor end
				scaleCard(entry)
				setLine(entry,1,string.format("[%s] %s",info.rarity,kind))
				setLine(entry,2,string.format("%s  \u{2022}  %s crystals",info.pickaxe,info.crystals))
				local dist=origin and formatDistance((anchor.Position-origin).Magnitude) or "--"
				setLine(entry,3,string.format("%s  \u{2022}  %s",info.runes,dist))
			end)
			local stale
			for model in pairs(boulderCache) do
				if not seen[model] then stale=stale or {}; stale[#stale+1]=model end
			end
			if stale then for _,m in ipairs(stale) do dropCard(boulderCache,m) end end
		end
		local function runeMatchesFilter(owner)
			-- V2.4: Auto Pickup Rune is intentionally unfiltered.
			return true
		end
		local function grabRunes(radius)
			local root=getRoot(); if not root then return 0 end
			local now=os.clock(); local fired=0
			-- Clear stale grabbed entries faster
			for prompt,stamp in pairs(grabbed) do
				if now-stamp>3 or not prompt.Parent then grabbed[prompt]=nil end
			end
			-- Normal radius sweep
			eachRune(root.Position,radius or GRAB_RANGE,function(owner,part)
				if fired>=GRAB_LIMIT then return end
				if not runeMatchesFilter(owner) then return end
				local prompt=owner:FindFirstChildOfClass("ProximityPrompt") or crystalPrompt(owner)
				if not prompt and part~=owner then prompt=crystalPrompt(part) end
				if not prompt or not prompt.Parent then return end
				local last=grabbed[prompt]
				if last and now-last<GRAB_RETRY then return end
				grabbed[prompt]=now
				if firePrompt(prompt) then fired=fired+1; Notify(string.format("Rune: %s",runeTitle(owner)),2) end
			end)
			return fired
		end
		-- Wide-area rune sweep: finds runes up to RUNE_FLY_RANGE away.
		-- If found and not within RUNE_FLY_DIST, flies toward it.
		-- Called from Mountain.tick() when autoGrab is on.
		local function sweepAndFlyRunes()
			local root=getRoot(); if not root then return end
			local now=os.clock()
			-- Validate current fly target
			if runeFlyTarget then
				local owner=runeFlyTarget.owner; local part=runeFlyTarget.part
				if not owner or not owner.Parent or not part or not part.Parent then
					runeFlyTarget=nil
				end
			end
			-- Try to grab anything close first (normal range)
			local fired=grabRunes(GRAB_RANGE)
			if fired>0 then runeFlyTarget=nil; return end
			-- Wide sweep for missed runes
			local bestOwner,bestPart,bestDist
			eachRune(root.Position,RUNE_FLY_RANGE,function(owner,part)
				if not runeMatchesFilter(owner) then return end
				local prompt=owner:FindFirstChildOfClass("ProximityPrompt") or crystalPrompt(owner)
				if not prompt and part~=owner then prompt=crystalPrompt(part) end
				if not prompt or not prompt.Parent then return end
				local d=(part.Position-root.Position).Magnitude
				if not bestDist or d<bestDist then
					bestOwner=owner; bestPart=part; bestDist=d
				end
			end)
			if bestOwner then
				if runeFlyTarget==nil or runeFlyTarget.owner~=bestOwner then
					runeFlyTarget={owner=bestOwner,part=bestPart}; runeFlyAt=now
				end
				-- Fly toward the rune
				local dest=bestPart.Position
				if Move and Move.glide then
					Move.glide(CFrame.new(dest+Vector3.new(0,3,0),dest),dest)
				end
				-- Once close enough, attempt grab
				local dist=(root.Position-dest).Magnitude
				if dist<=RUNE_FLY_DIST then
					local prompt=bestOwner:FindFirstChildOfClass("ProximityPrompt") or crystalPrompt(bestOwner)
					if not prompt and bestPart~=bestOwner then prompt=crystalPrompt(bestPart) end
					if prompt and prompt.Parent then
						local last=grabbed[prompt]
						if not last or now-last>=GRAB_RETRY then
							grabbed[prompt]=now
							if firePrompt(prompt) then
								Notify(string.format("Rune (flew): %s",runeTitle(bestOwner)),2)
								runeFlyTarget=nil
							end
						end
					end
				end
				-- Watchdog: abandon if stuck for 8 seconds
				if now-runeFlyAt>8 then runeFlyTarget=nil end
			else
				runeFlyTarget=nil
			end
		end
		function Mountain.applyScale()
			boulderClock=0
			for _,entry in pairs(boulderCache) do scaleCard(entry); if entry.gui then entry.gui.MaxDistance=CFG.ESP.boulderDistance end end
		end
		function Mountain.boulderList()
			local list={}
			for _,kind in ipairs({"Mossite","Voltite","Gildrite","Rimeveil","Nocturnite"}) do
				local info=BOULDER_INFO[kind]
				list[#list+1]=string.format("%s  \u{2022}  %s",kind,info.pickaxe)
			end
			return list
		end
		function Mountain.setBoulderEsp(value)
			boulderEsp=value
			if value then boulderClock=math.huge else clearCache(boulderCache) end
		end
		function Mountain.setAutoGrab(value)
			autoGrab=value
			if not value then table.clear(grabbed) end
		end
		function Mountain.grabRange() return GRAB_RANGE end
		function Mountain.grabNear(radius)
			local ok,fired=pcall(grabRunes,radius)
			if not ok then reportError("runeGrab",fired); return 0 end
			return fired or 0
		end
		function Mountain.runesNear(radius)
			local root=getRoot(); if not root then return 0 end
			local count=0
			eachRune(root.Position,radius or GRAB_RANGE,function() count=count+1 end)
			return count
		end
		function Mountain.shutdown()
			boulderEsp=false; autoGrab=false
			clearCache(boulderCache); table.clear(grabbed)
		end
		function Mountain.tick(deltaTime)
			if boulderEsp then
				boulderClock=boulderClock+deltaTime
				if boulderClock>=BOULDER_STEP then
					boulderClock=0
					local ok,err=pcall(syncBoulders); if not ok then reportError("boulder",err) end
				end
			end
			if autoGrab then
				grabClock=grabClock+deltaTime
				if grabClock>=GRAB_STEP then
					grabClock=0
					local ok,err=pcall(sweepAndFlyRunes); if not ok then reportError("runeGrab",err) end
				end
			end
		end
	end
	install()
end

-- [27] MOVE MODULE
local Move={}
do
	local function install()
		local FLY_KEYS={
			{key=Enum.KeyCode.W,           axis="look",  sign= 1},
			{key=Enum.KeyCode.S,           axis="look",  sign=-1},
			{key=Enum.KeyCode.D,           axis="right", sign= 1},
			{key=Enum.KeyCode.A,           axis="right", sign=-1},
			{key=Enum.KeyCode.Space,       axis="up",    sign= 1},
			{key=Enum.KeyCode.LeftControl, axis="up",    sign=-1},
		}
		local flyActive=false; local noclipActive=false; local jumpActive=false
		local flySpeed=100
		local velocity,gyro
		local flyConn,noclipConn,jumpConn
		local collisions={}
		local function humanoidOf()
			local char=LocalPlayer.Character
			return char and char:FindFirstChildOfClass("Humanoid")
		end
		local function dropMovers()
			if velocity then pcall(function() velocity:Destroy() end); velocity=nil end
			if gyro     then pcall(function() gyro:Destroy()     end); gyro=nil     end
		end
		local function attach(root)
			dropMovers()
			local ok=pcall(function()
				local body=Instance.new("BodyVelocity")
				body.Name="UniverseFlyVelocity"; body.MaxForce=Vector3.new(9e9,9e9,9e9)
				body.P=9e4; body.Velocity=Vector3.zero; body.Parent=root; velocity=body
				local spin=Instance.new("BodyGyro")
				spin.Name="UniverseFlyGyro"; spin.MaxTorque=Vector3.new(9e9,9e9,9e9)
				spin.P=9e4; spin.D=500; spin.CFrame=root.CFrame; spin.Parent=root; gyro=spin
			end)
			if not ok then dropMovers() end; return ok
		end
		local function flyStep()
			if Runtime.tpState then return end
			local root=getRoot(); if not root then return end
			if not velocity or velocity.Parent~=root then if not attach(root) then return end end
			local camera=S.Workspace.CurrentCamera; if not camera then return end
			local h=humanoidOf()
			if h and not h.PlatformStand then h.PlatformStand=true end
			local frame=camera.CFrame; local direction=Vector3.zero
			if not S.UserInputService:GetFocusedTextBox() then
				for _,entry in ipairs(FLY_KEYS) do
					if S.UserInputService:IsKeyDown(entry.key) then
						if     entry.axis=="look"  then direction=direction+frame.LookVector*entry.sign
						elseif entry.axis=="right" then direction=direction+frame.RightVector*entry.sign
						else                            direction=direction+Vector3.yAxis*entry.sign end
					end
				end
			end
			if direction.Magnitude>0.1 then velocity.Velocity=direction.Unit*flySpeed
			else                            velocity.Velocity=Vector3.zero end
			local flat=Vector3.new(frame.LookVector.X,0,frame.LookVector.Z)
			if flat.Magnitude>0.05 then gyro.CFrame=CFrame.new(root.Position,root.Position+flat) end
		end
		local function noclipStep()
			local char=LocalPlayer.Character; if not char then return end
			for _,part in ipairs(char:GetDescendants()) do
				if part:IsA("BasePart") and part.CanCollide then
					if collisions[part]==nil then collisions[part]=true end
					part.CanCollide=false
				end
			end
		end
		function Move.setFly(value)
			flyActive=value
			if value then
				local root=getRoot(); if root then attach(root) end
				if not flyConn then
					flyConn=S.RunService.Heartbeat:Connect(function()
						if not flyActive then return end
						local ok,err=pcall(flyStep); if not ok then reportError("fly",err) end
					end)
				end; return
			end
			if flyConn then flyConn:Disconnect(); flyConn=nil end
			dropMovers()
			local h=humanoidOf()
			if h then pcall(function() h.PlatformStand=false; h:ChangeState(Enum.HumanoidStateType.GettingUp) end) end
		end
		function Move.setFlySpeed(value) flySpeed=math.clamp(value,10,500) end
		function Move.setNoclip(value)
			noclipActive=value
			if value then
				if not noclipConn then
					noclipConn=S.RunService.Heartbeat:Connect(function()
						if not noclipActive then return end
						local ok,err=pcall(noclipStep); if not ok then reportError("noclip",err) end
					end)
				end; return
			end
			if noclipConn then noclipConn:Disconnect(); noclipConn=nil end
			for part,state in pairs(collisions) do
				if part.Parent then pcall(function() part.CanCollide=state end) end
			end; table.clear(collisions)
		end
		function Move.setInfJump(value)
			jumpActive=value
			if value then
				if not jumpConn then
					jumpConn=S.UserInputService.JumpRequest:Connect(function()
						if not jumpActive then return end
						local h=humanoidOf()
						if h then pcall(function() h:ChangeState(Enum.HumanoidStateType.Jumping) end) end
					end)
				end; return
			end
			if jumpConn then jumpConn:Disconnect(); jumpConn=nil end
		end
		function Move.shutdown()
			Move.setFly(false); Move.setNoclip(false); Move.setInfJump(false)
			if Move.glideStop then Move.glideStop() end
		end
	end
	install()
end

-- [28] MOVE GLIDE
do
	local function install()
		local GLIDE_SPEED=350; local AIM_RATE=9; local SNAP_GAP=0.35
		local RESPONSE=200; local STREAM_GAP=0.5
		local HOLD_FORCE=1e7; local HOLD_TORQUE=1e7
		local attachment,mover,aligner
		local cursor,facing,goalFrame,aimSpot
		local streamClock=0; local glideConn; local running=false
		local function humanoidOf()
			local char=LocalPlayer.Character
			return char and char:FindFirstChildOfClass("Humanoid")
		end
		local function detach()
			if mover     then pcall(function() mover:Destroy()      end); mover=nil      end
			if aligner   then pcall(function() aligner:Destroy()    end); aligner=nil    end
			if attachment then pcall(function() attachment:Destroy() end); attachment=nil end
		end
		local function attach(root)
			detach()
			local ok=pcall(function()
				local point=Instance.new("Attachment"); point.Name="UniverseGlidePoint"; point.Parent=root
				local position=Instance.new("AlignPosition"); position.Name="UniverseGlidePosition"
				position.Mode=Enum.PositionAlignmentMode.OneAttachment; position.Attachment0=point
				position.RigidityEnabled=false; position.ApplyAtCenterOfMass=true
				position.ReactionForceEnabled=false; position.MaxForce=HOLD_FORCE
				position.MaxVelocity=math.huge; position.Responsiveness=RESPONSE
				position.Position=root.Position; position.Parent=root
				local orientation=Instance.new("AlignOrientation"); orientation.Name="UniverseGlideOrientation"
				orientation.Mode=Enum.OrientationAlignmentMode.OneAttachment; orientation.Attachment0=point
				orientation.RigidityEnabled=false; orientation.ReactionTorqueEnabled=false
				orientation.MaxTorque=HOLD_TORQUE; orientation.MaxAngularVelocity=math.huge
				orientation.Responsiveness=RESPONSE; orientation.CFrame=root.CFrame.Rotation
				orientation.Parent=root
				attachment=point; mover=position; aligner=orientation
			end)
			if not ok then detach() end; return ok
		end
		local function step(deltaTime)
			if not goalFrame then return end
			local root=getRoot(); if not root then return end
			if not mover or mover.Parent~=root or not aligner or aligner.Parent~=root then
				if not attach(root) then return end
				cursor=root.Position; facing=root.CFrame.Rotation
			end
			local h=humanoidOf()
			if h and not h.PlatformStand then pcall(function() h.PlatformStand=true end) end
			cursor=cursor or root.Position; facing=facing or root.CFrame.Rotation
			local delta=goalFrame.Position-cursor; local span=GLIDE_SPEED*deltaTime
			if delta.Magnitude<=math.max(span,SNAP_GAP) then cursor=goalFrame.Position
			else cursor=cursor+delta.Unit*span end
			streamClock=streamClock+deltaTime
			if streamClock>=STREAM_GAP then streamClock=0; requestStream(goalFrame.Position) end
			local look=goalFrame.Rotation
			if aimSpot then
				local gap=aimSpot-cursor
				if gap.Magnitude>0.1 then look=CFrame.lookAt(cursor,aimSpot).Rotation end
			end
			facing=facing:Lerp(look,1-math.exp(-AIM_RATE*deltaTime))
			mover.Position=cursor; aligner.CFrame=facing
		end
		function Move.glide(goal,aim)
			if typeof(goal)~="CFrame" then return false end
			goalFrame=goal; aimSpot=typeof(aim)=="Vector3" and aim or nil
			if not running then
				running=true
				local root=getRoot()
				if root then cursor=root.Position; facing=root.CFrame.Rotation; attach(root) end
			end
			if not glideConn then
				glideConn=S.RunService.Heartbeat:Connect(function(dt)
					if not running then return end
					local ok,err=pcall(step,dt); if not ok then reportError("glide",err) end
				end)
			end
			return true
		end
		function Move.glideStop()
			running=false; goalFrame=nil; aimSpot=nil; cursor=nil; facing=nil; streamClock=0
			if glideConn then glideConn:Disconnect(); glideConn=nil end
			detach()
			local root=getRoot()
			if root then pcall(function()
				root.AssemblyLinearVelocity=Vector3.zero; root.AssemblyAngularVelocity=Vector3.zero
			end) end
			local h=humanoidOf()
			if h then pcall(function() h.PlatformStand=false; h:ChangeState(Enum.HumanoidStateType.GettingUp) end) end
		end
	end
	install()
end

-- [29] NET MODULE
local Net={}
local netConns={}
do
	local function install()
		local PLACE=game.PlaceId; local PAGES=1; local POOL_TARGET=20
		local RETRY_STEP=1.5; local RETRY_LIMIT=10; local BACK_DELAY=3
		local REFILL_MARK=8; local WARM_STEP=30
		local visited={}; local pool={}; local hopping=false; local reviving=false
		local lastCode=0; local alive=true
		local function note(text) pcall(function() Notify("Hop  "..text,4) end) end
		local function grab(link)
			local sender=(syn and syn.request) or (http and http.request) or http_request or request
			if type(sender)=="function" then
				local ok,response=pcall(function() return sender({Url=link,Method="GET"}) end)
				if ok and type(response)=="table" then
					local code=tonumber(response.StatusCode) or 0
					if code>=200 and code<300 and type(response.Body)=="string" then return response.Body,code end
					return nil,code
				end
			end
			local ok,body=pcall(function() return game:HttpGet(link) end)
			if ok and type(body)=="string" then return body,200 end
			return nil,0
		end
		local function fetch(cursor)
			local link=string.format("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Desc&excludeFullGames=true&limit=100",PLACE)
			if type(cursor)=="string" and cursor~="" then link=link.."&cursor="..cursor end
			local body,code=grab(link)
			if type(body)~="string" then lastCode=code or 0; return nil,nil end
			local parsed,data=pcall(function() return S.HttpService:JSONDecode(body) end)
			if not parsed or type(data)~="table" then lastCode=-1; return nil,nil end
			return data.data,data.nextPageCursor
		end
		local function refill()
			table.clear(pool)
			local cursor
			for _=1,PAGES do
				local entries,nextCursor=fetch(cursor)
				if type(entries)=="table" then
					for _,entry in ipairs(entries) do
						local id=type(entry)=="table" and entry.id or nil
						if type(id)=="string" and id~=game.JobId and not visited[id] then
							local playing=tonumber(entry.playing) or 0
							local room=tonumber(entry.maxPlayers) or 0
							if room==0 or playing<room then pool[#pool+1]=id end
						end
					end
				end
				cursor=nextCursor
				if type(cursor)~="string" or cursor=="" or #pool>=POOL_TARGET then break end
			end
			for i=#pool,2,-1 do
				local swap=math.random(1,i); pool[i],pool[swap]=pool[swap],pool[i]
			end
			return #pool
		end
		function Net.rejoin()
			if reviving then return end; reviving=true
			local jobId=game.JobId
			task.spawn(function()
				for _=1,RETRY_LIMIT do
					local sent=pcall(function() S.TeleportService:TeleportToPlaceInstance(PLACE,jobId,LocalPlayer) end)
					if not sent then pcall(function() S.TeleportService:Teleport(PLACE,LocalPlayer) end) end
					task.wait(RETRY_STEP)
				end; reviving=false
			end)
		end
		function Net.hop()
			if hopping then return false end
			hopping=true; visited[game.JobId]=true
			task.spawn(function()
				for round=1,RETRY_LIMIT do
					if #pool==0 and refill()==0 then table.clear(visited); visited[game.JobId]=true; refill() end
					local choice=table.remove(pool)
					if choice then
						visited[choice]=true
						note(string.format("try %d  %s",round,string.sub(choice,1,8)))
						local sent,err=pcall(function() S.TeleportService:TeleportToPlaceInstance(PLACE,choice,LocalPlayer) end)
						if not sent then note("blocked  "..tostring(err)) end
						if #pool<=REFILL_MARK then task.spawn(refill) end
					else
						note(string.format("no servers  http %d",lastCode))
					end
					task.wait(RETRY_STEP)
				end; hopping=false
			end); return true
		end
		function Net.forget() table.clear(visited); table.clear(pool); visited[game.JobId]=true end
		function Net.busy()  return hopping end
		function Net.ready() return #pool   end
		function Net.stop()  alive=false     end
		task.spawn(function()
			while alive do
				if #pool<POOL_TARGET and not hopping then refill() end
				task.wait(WARM_STEP)
			end
		end)
		netConns[#netConns+1]=S.TeleportService.TeleportInitFailed:Connect(function() hopping=false end)
		netConns[#netConns+1]=S.GuiService.ErrorMessageChanged:Connect(function()
			local ok,message=pcall(function() return S.GuiService:GetErrorMessage() end)
			if ok and type(message)=="string" and message~="" then task.delay(BACK_DELAY,Net.rejoin) end
		end)
		local prompts=S.CoreGui:FindFirstChild("RobloxPromptGui")
		local overlay=prompts and prompts:FindFirstChild("promptOverlay")
		if overlay then
			netConns[#netConns+1]=overlay.ChildAdded:Connect(function(child)
				if child.Name:find("ErrorPrompt") then task.delay(BACK_DELAY,Net.rejoin) end
			end)
		end
	end
	install()
end

-- [30] SHARED TOOLS
local Tools={}
do
	local _digRemote
	local PICK_NAMES={
		["Rusty Scrapper"]=true,["Weathered Wood"]=true,["Chipped Stone"]=true,
		["Hardened Iron"]=true,["Copper Pick"]=true,["Reinforced Steel"]=true,
		["Titanium Spike"]=true,["Frostbite Pick"]=true,["Emerald Carver"]=true,
		["Volcano Basalt"]=true,["Obsidian Edge"]=true,["Tempest Pick"]=true,
		["Celestial Apex"]=true,["Astral Rend"]=true,["Eclipse Fang"]=true,
		["Nebular Throne"]=true,Voidreign=true,Singularity=true,
		["The Terminus"]=true,["Admin Pickaxe"]=true,["Shark Pickaxe"]=true,["Diamond Pickaxe"]=true,
	}
	local COOLDOWN_KEYS={"SwingCooldown","DigCooldown","Cooldown","SwingSpeed","DigSpeed"}
	local SWING_GAP=0.04; local SWING_FLOOR=0.00001
	function Tools.digEvent()
		if _digRemote and _digRemote.Parent then return _digRemote end
		_digRemote=RMT.DigRequest or findRemote("DigRequest")
		return _digRemote
	end
	function Tools.isPickaxe(tool)
		if not tool or not tool:IsA("Tool") then return false end
		if getAttr(tool,"IsPickaxe")==true then return true end
		if PICK_NAMES[tool.Name] then return true end
		return getAttr(tool,"DigPower")~=nil and getAttr(tool,"Tier")==nil
	end
	function Tools.pickScore(tool)
		if not Tools.isPickaxe(tool) then return 0 end
		local score=1; local power=tonumber(getAttr(tool,"DigPower"))
		if power then score=score+power end; return score
	end
	function Tools.equipPick()
		local char=LocalPlayer.Character
		local h=char and char:FindFirstChildOfClass("Humanoid")
		if not char or not h then return nil end
		local held=char:FindFirstChildOfClass("Tool")
		local choice; local best=0
		local function consider(tool)
			local score=Tools.pickScore(tool); if score>best then best=score; choice=tool end
		end
		consider(held)
		local bp=LocalPlayer:FindFirstChildOfClass("Backpack")
		if bp then for _,tool in ipairs(bp:GetChildren()) do consider(tool) end end
		if not choice then return nil end
		if choice==held then return held end
		pcall(function() h:EquipTool(choice) end)
		local now=char:FindFirstChildOfClass("Tool")
		return (now and Tools.isPickaxe(now)) and now or nil
	end
	function Tools.swingGap(tool)
		local mult=1
		if boulderFastDig then
			mult=1+((math.clamp(boulderDigSpeed or 100,100,10000)-100)/9900)*999
		end
		if tool then
			for _,key in ipairs(COOLDOWN_KEYS) do
				local value=tonumber(getAttr(tool,key))
				if value and value>0 then return math.max(value,SWING_FLOOR)/mult end
			end
		end
		return SWING_GAP/mult
	end

	-- Global PickaxeHit visual-speed controller.
	-- Only adjusts the animation already played by the game; it does not create requests.
	function Tools.installPickaxeHitSpeed()
		local character=LocalPlayer.Character
		local humanoid=character and character:FindFirstChildOfClass("Humanoid")
		local animator=humanoid and humanoid:FindFirstChildOfClass("Animator")
		if not animator then return end
		if Tools._pickaxeHitAnimator==animator then return end
		Tools._pickaxeHitAnimator=animator
		if Tools._pickaxeHitAnimConn then pcall(function() Tools._pickaxeHitAnimConn:Disconnect() end) end
		Tools._pickaxeHitAnimConn=animator.AnimationPlayed:Connect(function(track)
			local animation=track and track.Animation
			if not animation then return end
			if animation.Name=="PickaxeHit" or animation.AnimationId=="rbxassetid://82311454956442" then
				local speed=1
				if boulderFastDig then
					speed=1+((math.clamp(boulderDigSpeed or 100,100,10000)-100)/9900)*999
				end
				pcall(function() track:AdjustSpeed(speed) end)
			end
		end)
	end
end

-- Install once and again after respawn so PickaxeHit remains synchronized with Dig Speed.
pcall(Tools.installPickaxeHitSpeed)
LocalPlayer.CharacterAdded:Connect(function()
	task.defer(function() pcall(Tools.installPickaxeHitSpeed) end)
end)

-- ============================================================
-- [30.5] SHARED FARM LOOT ENGINE
-- ============================================================
Runtime.FarmLoot = Runtime.FarmLoot or {}
do
	local L=Runtime.FarmLoot
	L.active=false
	L.origins=L.origins or {}
	L.radius=22
	L.startedAt=0
	L.quietSince=0
	L.target=nil
	L.sentAt=0
	L.snapshot={}
	L.graceUntil=0

	function L.setOrigins(origins,radius)
		table.clear(L.origins)
		if typeof(origins)=="Vector3" then
			L.origins[1]=origins
		elseif type(origins)=="table" then
			for _,v in ipairs(origins) do
				local pos=typeof(v)=="Vector3" and v or (type(v)=="table" and v.position)
				if typeof(pos)=="Vector3" then L.origins[#L.origins+1]=pos end
			end
		end
		L.radius=math.clamp(tonumber(radius) or 22,8,80)
		L.target=nil; L.sentAt=0; L.quietSince=0
	end

	function L.start()
		L.active=true; L.startedAt=os.clock(); L.quietSince=0; L.target=nil; L.sentAt=0
		-- Grace: 2 detik (cukup untuk crystal settle setelah vein hancur)
		-- Total max: ~6 detik kalau memang tidak ada crystal yang cocok spesifikasi
		L.graceUntil=os.clock()+2
		if type(inventoryCrystalSnapshot)=="function" then L.snapshot=inventoryCrystalSnapshot() else table.clear(L.snapshot) end
	end

	function L.stop()
		L.active=false; L.target=nil; L.sentAt=0; L.quietSince=0; L.graceUntil=0
		table.clear(L.origins); table.clear(L.snapshot)
	end

	local function valid(entry)
		return entry and entry.inst and entry.inst.Parent and getAttr(entry.inst,"Collected")~=true
	end

	local function findCandidate()
		local free=backpackFree()
		if free<=0 then return nil end
		local found={}; local seen=setmetatable({},{__mode="k"})
		local roots={}
		for _,origin in ipairs(L.origins) do roots[#roots+1]=origin end
		-- NOTE: root.Position intentionally NOT added here — it would sweep crystals
		-- unrelated to the farm area if the player has moved away from the drop zone.
		for _,origin in ipairs(roots) do
			local list=pickupCandidates(free,origin,L.radius)
			if type(list)=="table" then
				for _,entry in ipairs(list) do
					if valid(entry) and not seen[entry.inst] then
						seen[entry.inst]=true; found[#found+1]=entry
					end
				end
			end
		end
		table.sort(found,function(a,b)
			if (a.tier or 0)~=(b.tier or 0) then return (a.tier or 0)>(b.tier or 0) end
			if (a.value or 0)~=(b.value or 0) then return (a.value or 0)>(b.value or 0) end
			return (a.distance or 0)<(b.distance or 0)
		end)
		return found[1]
	end

	function L.step()
		if not L.active then return true end
		local root=getRoot(); if not root then return false end
		local now=os.clock()

		if not valid(L.target) then L.target=nil; L.sentAt=0 end

		if L.target then
			local crystal=L.target.inst
			local pos=crystal.Position
			requestStream(pos)
			local distance=(root.Position-pos).Magnitude
			Move.glide(CFrame.lookAt(pos+Vector3.new(0,3,0),pos),pos)
			if distance<=8 and (L.sentAt==0 or now-L.sentAt>=0.35) then
				local prompt=L.target.prompt or crystalPrompt(crystal)
				if prompt then instantPromptPatch(prompt) end
				if grabCrystal(crystal,prompt,true) then
					Cache.claimed[crystal]=now; L.sentAt=now
				end
			end
			if getAttr(crystal,"Collected")==true or not crystal.Parent then
				L.target=nil; L.sentAt=0; L.quietSince=0
			elseif L.sentAt>0 and now-L.sentAt>=0.45 and type(inventoryHasNewEligibleCrystal)=="function" and inventoryHasNewEligibleCrystal(L.snapshot) then
				L.snapshot=inventoryCrystalSnapshot(); L.target=nil; L.sentAt=0; L.quietSince=0
			end
			return false
		end

		local candidate=findCandidate()
		if candidate then L.target=candidate; L.sentAt=0; L.quietSince=0; return false end
		if L.quietSince==0 then L.quietSince=now end
		if now < (L.graceUntil or 0) then return false end
		if now-L.quietSince>=4 or now-L.startedAt>=20 then
			L.active=false; L.target=nil; return true
		end
		return false
	end
end

do
    local function __InstallExactNXROTBoulderEngine()
        -- [31] NXROT BOULDER FARM ENGINE
        -- [31] FARM MODULE (BOULDER FARM) - TERRAIN-TOP DIG + NO FLOOR + SAFE LOOT + NOCLIP FORCE
        Farm = {}
        farmConn=nil

        do
        	local function install()
        		local FARM_KINDS = { "Mossite", "Voltite", "Gildrite", "Rimeveil", "Nocturnite" }

        		local SCAN_SPOTS = {
        			CFrame.new(
        				-12.7105675, 459.090942, 818.847412,
        				0.993408799, -0.00500036497, -0.11451605,
        				0.000644713698, 0.999275982, -0.0380407833,
        				0.114623353, 0.0377162211, 0.992692769
        			),
        			CFrame.new(
        				13.0506754, 318.450409, -488.078888,
        				-0.99998939, 0.000884758658, -0.00452193478,
        				-0.000498382491, 0.954864502, 0.297041386,
        				0.00458064489, 0.297040492, -0.954853892
        			),
        			CFrame.new(
        				74.3923645, 610.789368, 210.838226,
        				-0.94896102, -0.27110818, 0.161162555,
        				2.26557495e-06, 0.51098305, 0.859590769,
        				-0.315393418, 0.815718472, -0.484902382
        			),
        		}

        		local TeleportService = game:GetService("TeleportService")
        		local RunService = game:GetService("RunService")
        		local Players = game:GetService("Players")
        		local LocalPlayer = Players.LocalPlayer
        		local Workspace = game:GetService("Workspace")
        		local PLACE_ID = game.PlaceId

        		local HOLD_DIST = 8
        		local HOLD_SLACK = 0.75
        		local HOLD_AIM = 0.999
        		local SCAN_HOLD = 1.4
        		local SWING_GAP = 0.04
        		local SWING_BURST = 14  -- rapid multi-shot burst for the crazy beam lines
        		local SWING_FLOOR = 0.02
        		local COOLDOWN_KEYS = { "SwingCooldown", "DigCooldown", "Cooldown", "SwingSpeed", "DigSpeed" }
        		local AIM_ANGLES = { 0, 35, -35, 70, -70, 110, -110, 145, -145, 180 }
        		local AIM_LIFT = { 0, 5, -4, 12 }
        		local SIGHT_GRACE = 1.5
        		local SIGHT_STEPS = 8
        		local LOST_GRACE = 2.5
        		local DRY_ROUNDS = 4
        		local DRY_TIME = 1.1
        		local PROBE_DIST = { 0, -3, 4, -5, 8 }
        		local SWEEP_PARTS = 12  -- more parts = more beam lines like in the video
        		local RUNE_SWEEP = 90
        		
        		-- Smart Loot Variables
        		local LOOT_WATCHDOG = 60
        		local LOOT_SCAN_RANGE = 70
        		local LOOT_QUIET_TIME = 1.50
        		local RESET_WAIT = 2
        		local EQUIP_STEP = 1

        		local PICK_NAMES = {
        			["Rusty Scrapper"] = true,
        			["Weathered Wood"] = true,
        			["Chipped Stone"] = true,
        			["Hardened Iron"] = true,
        			["Copper Pick"] = true,
        			["Reinforced Steel"] = true,
        			["Titanium Spike"] = true,
        			["Frostbite Pick"] = true,
        			["Emerald Carver"] = true,
        			["Volcano Basalt"] = true,
        			["Obsidian Edge"] = true,
        			["Tempest Pick"] = true,
        			["Celestial Apex"] = true,
        			["Astral Rend"] = true,
        			["Eclipse Fang"] = true,
        			["Nebular Throne"] = true,
        			Voidreign = true,
        			Singularity = true,
        			["The Terminus"] = true,
        			["Admin Pickaxe"] = true,
        			["Shark Pickaxe"] = true,
        			["Diamond Pickaxe"] = true,
        		}

        		local digRemote
        		local active = false
        		local targets = {}
        		local phase = "idle"
        		local target, anchor
        		local swingClock = 0
        		local equipClock = 0
        		local waitUntil = 0
        		local lastSpot
        		local hpMark
        		local dryRounds = 0
        		local scanned = false
        		local scanIndex = 0
        		local heldPick
        		local spotFrame
        		local aimTurn = 0
        		local blindClock = 0
        		local lostClock = 0
        		local dryClock = 0
        		local probeIndex = 0
        		local partCursor = 0
        		local pendingFinish = false
        		local statusText = "Idle"

        		-- Smart Loot states
        		local lootSnapshot = {}
        		local lootDropSeen = false
        		local lootTarget = nil
        		local lootAreaCenter = nil  -- boulder center at loot-begin; crystals beyond 30st are ignored
        		local lootApproachClock = 0
        		local lootPickupSentAt = 0
        		local lootStartedAt = 0
        		local lootQuietSince = 0
        		local lootFocus = nil
        		
        		-- Boulder Farm uses terrain-top digging; no artificial floor is created.
        		local safetyFloor = nil

        		local function toggleValue(name)
        			if typeof(Toggles) == "table" and Toggles[name] then
        				if type(Toggles[name]) == "boolean" then return Toggles[name] end
        				if type(Toggles[name].Value) == "boolean" then return Toggles[name].Value end
        			end
        			local store = Library and Library.Toggles
        			local entry = store and store[name]
        			if entry and type(entry.Value) == "boolean" then
        				return entry.Value
        			end
        			return false
        		end

        		local function safeNotify(msg, dur)
        			if type(Notify) == "function" then
        				Notify(msg, dur)
        			elseif Library and type(Library.Notify) == "function" then
        				Library:Notify(msg, dur)
        			end
        		end

        		local function safeReportError(ctx, err)
        			if type(reportError) == "function" then
        				reportError(ctx, err)
        			else
        				warn("["..ctx.."] Error: "..tostring(err))
        			end
        		end
        		
        		local function removeSafetyFloor()
        			if safetyFloor and safetyFloor.Parent then pcall(function() safetyFloor:Destroy() end) end
        			safetyFloor = nil
        		end

        		local function ensureSafetyFloor()
        			removeSafetyFloor()
        		end

        		local function digEvent()
        			if digRemote and digRemote.Parent then
        				return digRemote
        			end
        			if type(findRemote) == "function" then
        				digRemote = findRemote("DigRequest")
        			end
        			if not digRemote and type(Tools) == "table" and type(Tools.digEvent) == "function" then
        				digRemote = Tools.digEvent()
        			end
        			return digRemote
        		end

        		local function isPickaxe(tool)
        			if not tool or not tool:IsA("Tool") then
        				return false
        			end
        			local isPick = false
        			if type(getAttr) == "function" then
        				isPick = (getAttr(tool, "IsPickaxe") == true) or (getAttr(tool, "DigPower") ~= nil and getAttr(tool, "Tier") == nil)
        			end
        			if isPick or PICK_NAMES[tool.Name] then
        				return true
        			end
        			return false
        		end

        		local function pickScore(tool)
        			if not isPickaxe(tool) then
        				return 0
        			end
        			local score = 1
        			if type(getAttr) == "function" then
        				local power = tonumber(getAttr(tool, "DigPower"))
        				if power then
        					score = score + power
        				end
        			end
        			return score
        		end

        		local function equipPick()
        			local character = LocalPlayer.Character
        			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        			if not character or not humanoid then
        				return nil
        			end

        			local held = character:FindFirstChildOfClass("Tool")
        			local choice
        			local best = 0

        			local function consider(tool)
        				local score = pickScore(tool)
        				if score > best then
        					best = score
        					choice = tool
        				end
        			end

        			consider(held)
        			local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
        			if backpack then
        				for _, tool in ipairs(backpack:GetChildren()) do
        					consider(tool)
        				end
        			end

        			if not choice then
        				return nil
        			end
        			if choice == held then
        				return held
        			end
        			pcall(function()
        				humanoid:EquipTool(choice)
        			end)

        			local now = character:FindFirstChildOfClass("Tool")
        			if now and isPickaxe(now) then
        				return now
        			end
        			return nil
        		end

        		local rayParams = RaycastParams.new()
        		rayParams.FilterType = Enum.RaycastFilterType.Exclude
        		rayParams.IgnoreWater = true
        		rayParams.RespectCanCollide = false

        		local JUNK_WORDS = { "vfx", "effect", "fx", "debris", "particle", "shard", "chunk", "dust", "smoke" }

        		local function junkName(instance)
        			local name = string.lower(instance.Name)
        			for _, word in ipairs(JUNK_WORDS) do
        				if string.find(name, word, 1, true) then
        					return true
        				end
        			end
        			return false
        		end

        		local function ignorable(instance, model)
        			if not instance then return true end
        			if model and instance:IsDescendantOf(model) then return true end
        			if instance:IsA("Terrain") then return true end
        			if not instance:IsA("BasePart") then return true end
        			if instance.Transparency >= 0.5 or not instance.CanCollide or not instance.CanQuery then return true end
        			if not instance.Anchored or instance.Massless then return true end
        			if junkName(instance) then return true end
        			local owner = instance:FindFirstAncestorOfClass("Model")
        			if owner and Players:GetPlayerFromCharacter(owner) then return true end
        			return false
        		end

        		local function sightClear(origin, part, model)
        			if not part or not part.Parent then return true end
        			local delta = part.Position - origin
        			local distance = delta.Magnitude
        			if distance < 1 then return true end

        			local skip = { LocalPlayer.Character, Workspace.Terrain }
        			if safetyFloor then skip[#skip + 1] = safetyFloor end

        			for _ = 1, SIGHT_STEPS do
        				rayParams.FilterDescendantsInstances = skip
        				local hit = Workspace:Raycast(origin, delta.Unit * (distance + 2), rayParams)
        				if not hit then return true end

        				local instance = hit.Instance
        				if instance == part or (model and instance:IsDescendantOf(model)) then return true end
        				if not ignorable(instance, model) then return false end
        				skip[#skip + 1] = instance
        			end
        			return true
        		end

        		local function usablePart(item)
        			if not item:IsA("BasePart") then return false end
        			if not item.Anchored or item.Transparency >= 0.9 or item.Massless then return false end
        			return not junkName(item)
        		end

        		local function partList(model)
        			local list = {}
        			if model:IsA("BasePart") then
        				list[1] = model
        				return list
        			end
        			local spare = {}
        			for _, item in ipairs(model:GetDescendants()) do
        				if item:IsA("BasePart") then
        					if usablePart(item) then
        						list[#list + 1] = item
        					else
        						spare[#spare + 1] = item
        					end
        				end
        			end
        			if #list > 0 then return list end
        			return spare
        		end

        		local function anchorSpot(model, part)
        			if part and part.Parent then return part.Position end
        			if not model or not model.Parent then return nil end
        			local ok, pivot = pcall(model.GetPivot, model)
        			if ok and pivot then return pivot.Position end
        			return nil
        		end

        		local function coreSpot(model)
        			if not model or not model.Parent then return nil end
        			if model:IsA("BasePart") then return model.Position end
        			local boxed, box = pcall(model.GetBoundingBox, model)
        			if boxed and box then return box.Position end
        			local ok, pivot = pcall(model.GetPivot, model)
        			if ok and pivot then return pivot.Position end
        			return nil
        		end

        		local function coreFrame(core, part)
        			local look = part and part.Parent and part.Position or nil
        			if not look or (look - core).Magnitude < 1 then
        				look = core + Vector3.new(0, -2, 0)
        			end
        			return CFrame.new(core, look)
        		end

        		local function visibleAnchor(model)
        			local root = nil
        			if type(getRoot) == "function" then root = getRoot() end
        			local origin = root and root.Position
        			local pick, pickDistance, fallback, fallbackDistance

        			for _, part in ipairs(partList(model)) do
        				local distance = origin and (part.Position - origin).Magnitude or 0
        				if not fallback or distance < fallbackDistance then
        					fallback = part
        					fallbackDistance = distance
        				end
        				if origin and sightClear(origin, part, model) then
        					if not pick or distance < pickDistance then
        						pick = part
        						pickDistance = distance
        					end
        				end
        			end
        			return pick or fallback
        		end

        		local function freshAnchor(model)
        			local list = partList(model)
        			local count = #list
        			if count == 0 then return nil end
        			for _ = 1, count do
        				partCursor = partCursor % count + 1
        				local item = list[partCursor]
        				if item and item.Parent then
        					return item
        				end
        			end
        			return nil
        		end

        		local function hitSpot(part, model)
        			local root = nil
        			if type(getRoot) == "function" then root = getRoot() end
        			if not root then return part.Position end

        			local origin = root.Position
        			local delta = part.Position - origin
        			local distance = delta.Magnitude
        			if distance < 1 then return part.Position end

        			local skip = { LocalPlayer.Character, Workspace.Terrain }
        			if safetyFloor then skip[#skip + 1] = safetyFloor end

        			for _ = 1, SIGHT_STEPS do
        				rayParams.FilterDescendantsInstances = skip
        				local hit = Workspace:Raycast(origin, delta.Unit * (distance + 2), rayParams)
        				if not hit then break end
        				if hit.Instance == part or hit.Instance:IsDescendantOf(model) then
        					return hit.Position
        				end
        				skip[#skip + 1] = hit.Instance
        			end
        			return part.Position
        		end

        		local function swingGap(tool)
        			local pick = tool or heldPick
        			if pick and type(getAttr) == "function" then
        				for _, key in ipairs(COOLDOWN_KEYS) do
        					local value = tonumber(getAttr(pick, key))
        					if value and value > 0 then
        						return math.max(value, SWING_FLOOR)
        					end
        				end
        			end
        			return SWING_GAP
        		end

        		local function swing(part, model, center)
        			local event = digEvent()
        			if not event or not heldPick then return false end
        			local name = heldPick.Name
        			local core = center or (part and part.Parent and part.Position)
        			local spot = core

        			if part and part.Parent then
        				spot = hitSpot(part, model) or core
        			end
        			if not spot and not core then return false end

        			spot = spot or core
        			core = core or spot
        			local sweep = {}

        			if model and model.Parent then
        				local list = partList(model)
        				local count = #list
        				if count > 0 then
        					for _ = 1, math.min(SWEEP_PARTS, count) do
        						partCursor = partCursor % count + 1
        						local item = list[partCursor]
        						if item and item.Parent then
        							sweep[#sweep + 1] = item.Position
        						end
        					end
        				end
        			end

        			return pcall(function()
        				for index = 1, SWING_BURST do
        					if index % 2 == 0 then
        						event:FireServer(name, core)
        					else
        						event:FireServer(name, spot)
        					end
        				end
        				for _, point in ipairs(sweep) do
        					event:FireServer(name, point)
        				end
        			end)
        		end

        		local function hold(goal, aim)
        			if Move and type(Move.glide) == "function" then
        				return Move.glide(goal, aim)
        			end
        		end

        		local function restart()
        			task.spawn(function()
        				pcall(function() LocalPlayer:Kick("D-Hub Curent Server") end)
        				for _ = 1, 20 do
        					task.wait(1.5)
        					local sent = pcall(function() TeleportService:Teleport(PLACE_ID, LocalPlayer) end)
        					if not sent then
        						pcall(function() TeleportService:TeleportToPlaceInstance(PLACE_ID, game.JobId, LocalPlayer) end)
        					end
        				end
        			end)
        		end

        		local function boulderRoots()
        			local roots = {}
        			local decorations = Workspace:FindFirstChild("MountainDecorations")
        			local folder = decorations and decorations:FindFirstChild("Boulders")
        			if folder then roots[#roots + 1] = folder end
        			local test = Workspace:FindFirstChild("BoulderTest")
        			if test then roots[#roots + 1] = test end
        			return roots
        		end

        		local function boulderKind(inst)
        			for _, kind in ipairs(FARM_KINDS) do
        				if inst.Name:find(kind, 1, true) then return kind end
        			end
        			return nil
        		end

        		local function anchorOf(model)
        			if model:IsA("BasePart") then return model end
        			local list = partList(model)
        			if list[1] then return list[1] end
        			local ok, part = pcall(model.FindFirstChildWhichIsA, model, "BasePart", true)
        			if ok and part then return part end
        			return nil
        		end

        		local function boulderHealth(model)
        			if type(getAttr) == "function" then
        				local hp = getAttr(model, "HP")
        				if hp == nil then hp = getAttr(model, "Health") end
        				if hp == nil then hp = getAttr(model, "Hp") end
        				if hp == nil then hp = getAttr(model, "CurrentHealth") end
        				return tonumber(hp)
        			end
        			return nil
        		end

        		local function pickTarget()
        			local root = nil
        			if type(getRoot) == "function" then root = getRoot() end
        			if not root then return nil end

        			local best, bestAnchor, bestScore
        			for _, container in ipairs(boulderRoots()) do
        				for _, child in ipairs(container:GetChildren()) do
        					local kind = boulderKind(child)
        					if kind and targets[kind] then
        						local part = anchorOf(child)
        						if part then
        							local distance = (part.Position - root.Position).Magnitude
        							local hp = boulderHealth(child) or 0
        							local score = hp * 2 + distance
        							if not best or score < bestScore then
        								best = child
        								bestAnchor = part
        								bestScore = score
        							end
        						end
        					end
        				end
        			end
        			return best, bestAnchor
        		end

        		-- ============================================================
        		-- TERRAIN-TOP BOULDER DIGGING
        		-- ============================================================
        		local TOP_STAND_HEIGHT = 4.5
        		local TOP_SURFACE_REFRESH = 0.12
        		local TOP_DIG_BURST = 3
        		local TOP_DIG_SINK = 1.35
        		local TOP_DIG_REACH = 18
        		local TOP_LOST_GRACE = 3.0
        		local TOP_EMPTY_CONFIRM = 3
        		local TOP_EMPTY_DELAY = 0.55

        		local topSurfaceParams = RaycastParams.new()
        		topSurfaceParams.FilterType = Enum.RaycastFilterType.Include
        		topSurfaceParams.FilterDescendantsInstances = { Workspace.Terrain }
        		topSurfaceParams.IgnoreWater = true

        		local topDigParams = RaycastParams.new()
        		topDigParams.FilterType = Enum.RaycastFilterType.Include
        		topDigParams.IgnoreWater = true

        		local topSurfaceClock = 0
        		local topSurface = nil
        		local topDigClock = 0
        		local emptyChecks = 0
        		local emptyCheckClock = 0

        		local function mountainBaseY()
        			local v = Workspace:GetAttribute("MountainBaseY")
        			return typeof(v) == "number" and v or 0
        		end

        		local function mountainPeakY()
        			local v = Workspace:GetAttribute("MountainPeakY")
        			return typeof(v) == "number" and v or (mountainBaseY() + 900)
        		end

        		local function terrainSurfaceAt(x, z)
        			if typeof(x) ~= "number" or typeof(z) ~= "number" then return nil end
        			local top = mountainPeakY() + 120
        			local base = mountainBaseY()
        			local hit = Workspace:Raycast(
        				Vector3.new(x, top, z),
        				Vector3.new(0, -(top - base + 180), 0),
        				topSurfaceParams
        			)
        			if hit and hit.Position.Y > base + 0.5 then return hit.Position end
        			return nil
        		end

        		local function boulderCenter(model, part)
        			if model and model:IsA("BasePart") then return model.Position end
        			if model and model.Parent then
        				local ok, cf = pcall(model.GetBoundingBox, model)
        				if ok and cf then return cf.Position end
        			end
        			return part and part.Parent and part.Position or nil
        		end

        		local function boulderTopY(model, part)
        			if model and model:IsA("BasePart") then
        				return model.Position.Y + model.Size.Y * 0.5
        			end
        			if model and model.Parent then
        				local ok, cf, size = pcall(function()
        					local c, s = model:GetBoundingBox()
        					return c, s
        				end)
        				if ok and cf and size then return cf.Position.Y + size.Y * 0.5 end
        			end
        			if part and part.Parent then return part.Position.Y + part.Size.Y * 0.5 end
        			return nil
        		end

        		local function refreshTopDigFilter()
        			local list = { Workspace.Terrain }
        			local deco = Workspace:FindFirstChild("MountainDecorations")
        			local boulders = deco and deco:FindFirstChild("Boulders")
        			if boulders then list[#list + 1] = boulders end
        			local test = Workspace:FindFirstChild("BoulderTest")
        			if test then list[#list + 1] = test end
        			topDigParams.FilterDescendantsInstances = list
        		end

        		local function topDownGoal(model, part)
        			local center = boulderCenter(model, part)
        			if not center then return nil, nil end
        			local topY = boulderTopY(model, part) or center.Y
        			local surface = terrainSurfaceAt(center.X, center.Z)
        			local standY = math.max(topY, surface and surface.Y or topY) + TOP_STAND_HEIGHT
        			local aimY = surface and surface.Y or topY
        			return CFrame.new(center.X, standY, center.Z, 1, 0, 0, 0, 0, -1, 0, 1, 0), surface
        		end

        		local function topDownHit(root, model, part)
        			if not root or not model or not part then return nil, nil end
        			refreshTopDigFilter()
        			local reach = TOP_DIG_REACH
        			if heldPick and type(getAttr) == "function" then
        				local override = tonumber(getAttr(heldPick, "OverrideMaxReach"))
        				if override and override > 0 then reach = override + 3 end
        			end
        			local hit = Workspace:Raycast(root.Position, Vector3.new(0, -reach, 0), topDigParams)
        			if hit then
        				return hit.Position, hit.Instance
        			end
        			local center = boulderCenter(model, part)
        			local topY = boulderTopY(model, part)
        			if center and topY and math.abs(root.Position.X - center.X) < 10 and math.abs(root.Position.Z - center.Z) < 10 then
        				return Vector3.new(center.X, topY, center.Z), part
        			end
        			return nil, nil
        		end

        		local function topDownDig(root, model, part)
        			local event = digEvent()
        			if not event or not heldPick then return false, nil end
        			local point, hitInstance = topDownHit(root, model, part)
        			if not point then return false, nil end
        			local name = heldPick.Name
        			local ok = pcall(function()
        				for i = 0, TOP_DIG_BURST - 1 do
        					event:FireServer(name, point - Vector3.new(0, i * TOP_DIG_SINK, 0))
        				end
        			end)
        			return ok, hitInstance
        		end

        		local function approach(part, model, turn, spot, pad)
        			local root = nil
        			if type(getRoot) == "function" then root = getRoot() end
        			if not root then return nil end

        			local center = spot or (part and part.Parent and part.Position)
        			if not center then return nil end

        			local away = root.Position - center
        			away = Vector3.new(away.X, 0, away.Z)
        			if away.Magnitude < 0.5 then away = Vector3.new(0, 0, 1) end
        			away = away.Unit

        			local span = part and part.Parent and part.Size.Magnitude * 0.5 or 6
        			local reach = math.max(span + HOLD_DIST + (pad or 0), span + 3)
        			local skip = turn or 0

        			for _, lift in ipairs(AIM_LIFT) do
        				for _, angle in ipairs(AIM_ANGLES) do
        					local dir = (CFrame.fromAxisAngle(Vector3.yAxis, math.rad(angle)) * away).Unit
        					local candidate = center + dir * reach + Vector3.new(0, lift, 0)
        					if sightClear(candidate, part, model) then
        						if skip <= 0 then return CFrame.new(candidate, center) end
        						skip = skip - 1
        					end
        				end
        			end
        			return CFrame.new(center + away * reach + Vector3.new(0, AIM_LIFT[2], 0), center)
        		end

        		-- SMART LOOT INTEGRATION
        		local function beginLoot(finish)
        			pendingFinish = finish == true
        			-- Save where the boulder was — only pick crystals that dropped near here.
        			-- Priority: (1) live anchor part, (2) boulder bounding box, (3) player position.
        			-- We snapshot this NOW before the boulder model is destroyed.
        			local savedAnchorPos = anchor and anchor.Parent and anchor.Position
        			if not savedAnchorPos and target and target.Parent then
        				local ok,cf=pcall(target.GetBoundingBox,target)
        				savedAnchorPos = ok and cf and cf.Position or nil
        			end
        			if not savedAnchorPos then
        				local r=getRoot(); savedAnchorPos = r and r.Position
        			end
        			lootAreaCenter = savedAnchorPos
        			if type(inventoryCrystalSnapshot) == "function" then
        				lootSnapshot = inventoryCrystalSnapshot()
        			else
        				lootSnapshot = {}
        			end
        			lootDropSeen = false
        			lootTarget = nil
        			lootApproachClock = 0
        			lootPickupSentAt = 0
        			lootStartedAt = os.clock()
        			lootQuietSince = 0
        			lootFocus = nil
        			if Runtime.FarmLoot then
        				Runtime.FarmLoot.setOrigins(lootAreaCenter or (getRoot() and getRoot().Position),lootRadiusBoulder)
        				Runtime.FarmLoot.start()
        			end
        			phase = "loot"
        			statusText = "Waiting for Boulder loot"
        		end

        		local function stop()
        			active = false
					if Runtime.FarmLoot then Runtime.FarmLoot.stop() end
        			phase = "idle"
        			target = nil
        			anchor = nil
        			waitUntil = 0
        			if Move and type(Move.glideStop) == "function" then Move.glideStop() end
        			hpMark = nil
        			dryRounds = 0
        			pendingFinish = false
        			spotFrame = nil
        			aimTurn = 0
        			blindClock = 0
        			lostClock = 0
        			dryClock = 0
        			probeIndex = 0
        			topSurface = nil; topSurfaceClock = 0; topDigClock = 0
        			emptyChecks = 0; emptyCheckClock = 0
        			statusText = "Idle"
        			
        			lootDropSeen = false
        			lootTarget = nil
        			lootAreaCenter = nil
        			lootApproachClock = 0
        			lootPickupSentAt = 0
        			lootStartedAt = 0
        			lootQuietSince = 0
        			lootFocus = nil
        			table.clear(lootSnapshot)
        			removeSafetyFloor()

        			if Move and type(Move.setFly) == "function" then Move.setFly(toggleValue("Fly")) end
        			if Move and type(Move.setNoclip) == "function" then Move.setNoclip(toggleValue("Noclip")) end
        			if Mountain and type(Mountain.setAutoGrab) == "function" then Mountain.setAutoGrab(toggleValue("AutoRunePickup")) end
        		end

        		-- ============================================================
        		-- STEP - FORCE NOCLIP SETIAP FRAME
        		-- ============================================================
        		local function step(deltaTime)
        			-- 🔥 FORCE NOCLIP AKTIF SELAMA FARM BERJALAN
        			if Move and type(Move.setNoclip) == "function" then
        				Move.setNoclip(true)
        			end

        			local root = getRoot()
        			if not root then statusText = "Waiting for character"; return end
        			local now = os.clock()

        			if phase == "scan" then
        				if not scanned then
        					if scanIndex == 0 then scanIndex = 1; waitUntil = now + SCAN_HOLD end
        					if scanIndex <= #SCAN_SPOTS then
        						hold(SCAN_SPOTS[scanIndex])
        						statusText = string.format("Scanning %d/%d", scanIndex, #SCAN_SPOTS)
        						if now >= waitUntil then scanIndex = scanIndex + 1; waitUntil = now + SCAN_HOLD end
        						return
        					end
        					scanned = true
        				end

        				local model, part = pickTarget()
        				if not model then
        					if emptyCheckClock == 0 then emptyCheckClock = now end
        					if now - emptyCheckClock >= TOP_EMPTY_DELAY then
        						emptyChecks = emptyChecks + 1
        						emptyCheckClock = now
        					end
        					if emptyChecks < TOP_EMPTY_CONFIRM then
        						statusText = string.format("Confirming Boulder area %d/%d", emptyChecks, TOP_EMPTY_CONFIRM)
        						return
        					end
        					emptyChecks = 0; emptyCheckClock = 0
        					beginLoot(true)
        					statusText = "Boulder area clear"
        					return
        				end
        				emptyChecks = 0; emptyCheckClock = 0

        				target = model
        				anchor = part or visibleAnchor(model)
        				lastSpot = root.CFrame
        				hpMark = boulderHealth(model)
        				dryRounds = 0; dryClock = 0; lostClock = 0
        				topSurface = nil; topSurfaceClock = 0; topDigClock = 0
        				phase = "mine"
        				statusText = "Boulder found • going to terrain top"
        				return
        			end

        			if phase == "mine" then
        				if not target or not target.Parent or not target:IsDescendantOf(Workspace) then
        					lastSpot = root.CFrame; beginLoot(false); return
        				end

        				local kind = boulderKind(target) or "Boulder"
        				local hp = boulderHealth(target)
        				if hp and hp <= 0 then lastSpot = root.CFrame; beginLoot(false); return end
        				if not anchor or not anchor.Parent or not anchor:IsDescendantOf(target) then
        					anchor = anchorOf(target) or visibleAnchor(target)
        				end
        				if not anchor then
        					lostClock = lostClock + deltaTime
        					if lostClock >= TOP_LOST_GRACE then lastSpot = root.CFrame; beginLoot(false); return end
        					statusText = "Finding Boulder"; return
        				end
        				lostClock = 0

        				-- VIDEO-STYLE APPROACH: glide to a position BESIDE the boulder at
        				-- boulder height. Fire multi-directional dig bursts at all parts of
        				-- the model simultaneously — that's what creates the "crazy lines"
        				-- radiating outward from all angles visible in the video.
        				local center = boulderCenter(target, anchor)
        				if center then
        					local sideGoal = approach(anchor, target, aimTurn, center, 2)
        					if sideGoal then
        						hold(sideGoal, center)
        					end
        				end

        				if heldPick == nil or heldPick.Parent ~= LocalPlayer.Character then
        					equipClock = 0; heldPick = equipPick()
        				else
        					equipClock = equipClock + deltaTime
        					if equipClock >= EQUIP_STEP then equipClock = 0; heldPick = equipPick() or heldPick end
        				end
        				if not heldPick then statusText = "No pickaxe"; return end

        				local baseGap = math.max(SWING_FLOOR, swingGap(heldPick))
        				local gap = math.max(0.035, baseGap * 0.60)
        				swingClock = swingClock + deltaTime
        				if swingClock >= gap then
        					swingClock = swingClock - gap
        					swing(anchor, target, center)
        					statusText = string.format("Mining %s", kind)
        				end

        				if hp then
        					if hpMark == nil or hp < hpMark - 0.001 then
        						hpMark = hp; dryRounds = 0; dryClock = 0
        					else
        						dryClock = dryClock + deltaTime
        						dryRounds = dryRounds + 1
        						if dryClock >= DRY_TIME or dryRounds >= DRY_ROUNDS then
        							dryClock = 0; dryRounds = 0
        							-- rotate approach angle to get a fresh angle on the boulder
        							aimTurn = (aimTurn + 1) % #AIM_ANGLES
        							anchor = anchorOf(target) or visibleAnchor(target) or anchor
        							statusText = "Rotating Boulder angle"
        						end
        					end
        				end
        				return
        			end

        			if phase == "loot" then
				if Runtime.FarmLoot then
					local done=Runtime.FarmLoot.step()
					if not done then
						statusText="Loot • collecting eligible crystals"
						return
					end
				end
				lootTarget=nil; lootPickupSentAt=0
				if pendingFinish then
					phase="reset"; waitUntil=now+RESET_WAIT
					statusText="Boulder loot complete"
				else
					target=nil; anchor=nil; phase="scan"; scanned=true
					scanIndex=#SCAN_SPOTS+1; lootDropSeen=false; lootQuietSince=0
					statusText="Loot complete • Next Boulder"
				end
				return
			end
			if phase == "reset" then
        				if now < waitUntil then return end

        				-- V4.2 FIX: never hop/reset while crystal loot is still pending.
        				if Runtime.FarmLoot and Runtime.FarmLoot.active then
        					statusText = "Finishing crystal loot before hop..."
        					Runtime.FarmLoot.step()
        					return
        				end

        				-- V4.2 FIX: wait for nearby runes before server hop.
        				if Mountain and type(Mountain.runesNear) == "function" then
        					local runesLeft = Mountain.runesNear(lootRadiusBoulder)
        					if runesLeft > 0 then
        						statusText = string.format("Waiting for %d rune(s) before hop...", runesLeft)
        						if Mountain and type(Mountain.setAutoGrab) == "function" then
        							Mountain.setAutoGrab(true)
        						end
        						return
        					end
        				end

        				target = nil; anchor = nil; pendingFinish = false
        				safeNotify("Empty Boulder\n" .. tostring(Runtime.farmMethod or "Unknown"), 4)
        				statusText = "Server: " .. tostring(Runtime.farmMethod or "Unknown")
        				if Runtime.farmMethod == "Current Server" then
        					restart()
        				elseif Net and type(Net.hop) == "function" then
        					Net.hop()
        				else
        					restart()
        				end
        				waitUntil = now + 18
        				phase = "reset"
        				return
        			end
        		end

        		local function setTargets(value)
        			table.clear(targets)
        			if type(value) == "table" then
        				for key, flag in pairs(value) do
        					if type(key) == "string" and flag == true then
        						targets[key] = true
        					elseif type(flag) == "string" then
        						targets[flag] = true
        					end
        				end
        			elseif type(value) == "string" then
        				targets[value] = true
        			end
        		end

        		local function setActive(value)
        			if not value then
        				stop()
        				return
        			end

        			if not next(targets) then
        				safeNotify("Pick at least one boulder", 2)
        				local store = Library and Library.Toggles
        				local entry = store and store.AutoFarmBoulders
        				if entry and entry.SetValue then
        					entry:SetValue(false)
        				elseif type(ToggleSetFn) == "table" and ToggleSetFn.AutoFarmBoulders then
        					ToggleSetFn.AutoFarmBoulders(false)
        				end
        				return
        			end

        			active = true
        			phase = "scan"
        			waitUntil = 0
        			target = nil
        			anchor = nil
        			lastSpot = nil
        			swingClock = 0
        			equipClock = 0
        			hpMark = nil
        			dryRounds = 0
        			spotFrame = nil
        			aimTurn = 0
        			blindClock = 0
        			lostClock = 0
        			dryClock = 0
        			probeIndex = 0
        			scanned = false
        			scanIndex = 0
        			heldPick = nil
        			pendingFinish = false
        			statusText = "Starting"

        			lootDropSeen = false
        			lootTarget = nil
        			lootAreaCenter = nil
        			lootStartedAt = 0
        			lootQuietSince = 0
        			lootFocus = nil
        			removeSafetyFloor()

        			if Move and type(Move.setFly) == "function" then Move.setFly(false) end
        			-- 🔥 NOCLIP DIPAKSA AKTIF SAAT FARM START
        			if Move and type(Move.setNoclip) == "function" then Move.setNoclip(true) end
        			if Mountain and type(Mountain.setAutoGrab) == "function" then Mountain.setAutoGrab(true) end
        		end

        		-- UI Status
        		local FarmStatusLabel
        		local labelClock = 0

        		farmConn = RunService.Heartbeat:Connect(function(deltaTime)
        			if active then
        				local ok, err = pcall(step, deltaTime)
        				if not ok then
        					safeReportError("boulderFarm", err)
        				end
        			end

        			labelClock = labelClock + deltaTime
        			if labelClock >= 0.25 then
        				labelClock = 0
        				if FarmStatusLabel then 
        					FarmStatusLabel.Text = statusText 
        				end
        			end
        		end)

        		Farm._getStatusLabel = function(lbl) FarmStatusLabel = lbl end
        		Farm.getState = function()
        			return {active=active,phase=phase,target=target,anchor=anchor,status=statusText,lootTarget=lootTarget}
        		end
        		Farm.stop = stop
        		Farm.setTargets = setTargets
        		Farm.setActive = setActive
        		Farm.equipPick = equipPick
        		Farm.swingGap = swingGap
        		Farm.digEvent = digEvent
        	end

        	install()
        end


    end
    __InstallExactNXROTBoulderEngine()
end
do
    local function __InstallExactNXROTDigEngine()
        -- [35] VEIN FARM — DIG VARIANT
        -- Connected-component flood-fill: every touching voxel cluster
        -- is treated as ONE area. The farm digs ALL voxels in that blob
        -- continuously while flying, body always facing current voxel.
        -- Only enters loot when the WHOLE connected area is gone.
        -- Error notifications (cant dig here, etc.) instantly skip the
        -- current voxel and treat it as done so the ESP disappears.
        -- ═══════════════════════════════════════════════════════════════
        DigVeinFarm = {}
        do
          local HOVER_OFFSET   = 9
          local DIG_BURST      = 5
          local DIG_SINK       = 0.9
          local DIG_GAP        = 0.08
          local ARRIVE_DIST    = 11
          local WATCHDOG       = 18      -- per-voxel watchdog before force-skip
          local SCAN_RADIUS_XZ = 150
          local SCAN_RADIUS_Y  = 90
          local OCCUPANCY_MIN  = 0.28
          local VOXEL_STEP     = 4       -- terrain voxel resolution (studs)
          local CONNECT_DIST   = 9       -- max stud distance between touching voxels (diagonal ~7)
          local LOOT_SETTLE    = 4.0
          local AREA_CONFIRM   = 1.5
          -- Scan spots: bukan titik hardcode ketinggian — kita generate di runtime
          -- berdasarkan posisi karakter saat ini, terbang LURUS ke arah gunung (XZ only)
          -- tanpa naik ketinggian. Arah gunung = pusat map (0,0,0) atau bisa disesuaikan.
          local MOUNTAIN_DIR_HINTS = {
            Vector3.new(0,   0,  800),   -- utara
            Vector3.new(0,   0, -500),   -- selatan
            Vector3.new(80,  0,  200),   -- timur laut
            Vector3.new(-100,0,  300),   -- barat laut
          }
          local function getApproachSpots(root)
            local spots = {}
            local rpos = root.Position
            local ry = rpos.Y + 8   -- terbang sejajar + 8 studs di atas posisi spawn
            for _, hint in ipairs(MOUNTAIN_DIR_HINTS) do
              local dir = Vector3.new(hint.X - rpos.X, 0, hint.Z - rpos.Z)
              if dir.Magnitude > 1 then dir = dir.Unit end
              -- titik 120 studs ke arah gunung, ketinggian sejajar karakter
              local dest = Vector3.new(rpos.X + dir.X*120, ry, rpos.Z + dir.Z*120)
              spots[#spots+1] = CFrame.lookAt(dest, dest + dir)
            end
            return spots
          end

          local active=false; local phase="idle"; local statusText="Idle"
          local voxelQueue={}; local queueIdx=1
          local currentVoxel=nil
          local skipCurrent=false        -- set true by error-notification hook
          local phaseClock=0; local digClock=0; local emptyClock=0; local lootStart=0
          local farmOrigin=nil
          local heldPick=nil; local statusLabel=nil; local conn; local errorConn
          local noVeinSince=0            -- tracks how long scan found nothing
          local NO_VEIN_HOP_DELAY=30     -- seconds before server hop when no veins
          -- Vein startup must stream/load the mountain before ReadVoxels is used.
          local mountainLoadIndex=0; local mountainLoadUntil=0

          local function setStatus(txt)
            statusText=txt
            if statusLabel then pcall(function() statusLabel.Text=txt end) end
          end

          -- ── FLOOD-FILL: find all voxels in terrain, group into connected components,
          --   return the component closest to the player as a sorted position list.
          --   Two voxels belong to the same component when they are within CONNECT_DIST
          --   studs of each other (6-connectivity + diagonals tolerated).
          local function scanConnectedArea(overrideOrigin, overrideRadius)
            local root=getRoot(); if not root then return {} end
            local origin = overrideOrigin or root.Position
            local rxz = overrideRadius or SCAN_RADIUS_XZ
            local ry  = overrideRadius and math.ceil(overrideRadius*0.7) or SCAN_RADIUS_Y
            local minP=origin-Vector3.new(rxz,ry,rxz)
            local maxP=origin+Vector3.new(rxz,ry,rxz)
            local ok,region=pcall(function() return Region3.new(minP,maxP):ExpandToGrid(VOXEL_STEP) end)
            if not ok then return {} end
            local ok2,mats,occs=pcall(function() return S.Workspace.Terrain:ReadVoxels(region,VOXEL_STEP) end)
            if not ok2 or not mats then return {} end
            local sz=mats.Size
            local regionMin=region.CFrame.Position-region.Size*0.5

            -- Pass 1: collect all valid dig voxel world positions
            local rawVoxels={}
            for x=1,sz.X do for y=1,sz.Y do for z=1,sz.Z do
              local occ=occs[x][y][z]
              if occ and occ>=OCCUPANCY_MIN then
                local mat=mats[x][y][z]; local info=DIG_MATERIALS[mat]
                if info then
                  local mname=info.matName
                  if next(Cache.digVeinFilter)==nil or Cache.digVeinFilter[mname] then
                    local pos=regionMin+Vector3.new((x-0.5)*VOXEL_STEP,(y-0.5)*VOXEL_STEP,(z-0.5)*VOXEL_STEP)
                    rawVoxels[#rawVoxels+1]={pos=pos, info=info, comp=0}
                  end
                end
              end
            end end end

            if #rawVoxels==0 then return {} end

            -- Pass 2: union-find flood-fill by proximity (CONNECT_DIST)
            -- For performance, only do this if voxel count is manageable
            -- (large areas: bucket-grid approach)
            local CELL=CONNECT_DIST
            local grid={}
            for i,v in ipairs(rawVoxels) do
              local gx=math.floor(v.pos.X/CELL)
              local gy=math.floor(v.pos.Y/CELL)
              local gz=math.floor(v.pos.Z/CELL)
              local key=gx..","..gy..","..gz
              if not grid[key] then grid[key]={} end
              grid[key][#grid[key]+1]=i
            end

            local compId=0
            local compOf={}  -- voxel index -> component id
            local stack={}

            local function neighbours(idx)
              local v=rawVoxels[idx]
              local gx=math.floor(v.pos.X/CELL)
              local gy=math.floor(v.pos.Y/CELL)
              local gz=math.floor(v.pos.Z/CELL)
              local result={}
              for dx=-1,1 do for dy=-1,1 do for dz=-1,1 do
                local key=(gx+dx)..",".. (gy+dy)..",".. (gz+dz)
                local bucket=grid[key]
                if bucket then
                  for _,j in ipairs(bucket) do
                    if j~=idx and not compOf[j] then
                      if (rawVoxels[j].pos-v.pos).Magnitude<=CONNECT_DIST then
                        result[#result+1]=j
                      end
                    end
                  end
                end
              end end end
              return result
            end

            for i=1,#rawVoxels do
              if not compOf[i] then
                compId=compId+1
                compOf[i]=compId
                stack[1]=i; local sp=1
                while sp>0 do
                  local cur=stack[sp]; sp=sp-1
                  for _,nb in ipairs(neighbours(cur)) do
                    compOf[nb]=compId
                    sp=sp+1; stack[sp]=nb
                  end
                end
              end
            end

            -- Pass 3: find the component whose centroid is closest to player
            local compData={}
            for i,v in ipairs(rawVoxels) do
              local c=compOf[i]
              if not compData[c] then compData[c]={sum=Vector3.zero,count=0,voxels={}} end
              compData[c].sum=compData[c].sum+v.pos
              compData[c].count=compData[c].count+1
              compData[c].voxels[#compData[c].voxels+1]={position=v.pos,info=v.info}
            end

            local bestComp,bestDist
            for c,data in pairs(compData) do
              local centroid=data.sum/data.count
              local d=(centroid-origin).Magnitude
              if not bestComp or d<bestDist then bestComp=c; bestDist=d end
            end

            if not bestComp then return {} end

            -- Sort the winning component's voxels nearest-first from player
            local list=compData[bestComp].voxels
            table.sort(list,function(a,b)
              return (a.position-origin).Magnitude < (b.position-origin).Magnitude
            end)
            return list, compData[bestComp].sum/compData[bestComp].count
          end

          local function voxelStillPresent(position)
            local r=6
            local ok,region=pcall(function()
              return Region3.new(position-Vector3.new(r,r,r),position+Vector3.new(r,r,r)):ExpandToGrid(4)
            end)
            if not ok then return false end
            local ok2,mats,occs=pcall(function() return S.Workspace.Terrain:ReadVoxels(region,4) end)
            if not ok2 or not mats then return false end
            local sz=mats.Size
            for x=1,sz.X do for y=1,sz.Y do for z=1,sz.Z do
              if (occs[x][y][z] or 0)>=OCCUPANCY_MIN and isDigMaterial(mats[x][y][z]) then return true end
            end end end
            return false
          end

          local function hoverGoal(voxelPos, rootPos)
            local away=rootPos-voxelPos
            away=Vector3.new(away.X,0,away.Z)
            if away.Magnitude<0.5 then away=Vector3.new(1,0,0) end
            away=away.Unit
            return CFrame.lookAt(voxelPos+away*HOVER_OFFSET+Vector3.new(0,2,0), voxelPos)
          end

          local function digAt(voxelPos)
            local event=Tools.digEvent(); if not event then return end
            heldPick=heldPick or Tools.equipPick(); if not heldPick then return end
            local root=getRoot(); if not root then return end
            local aim=voxelPos
            local delta=voxelPos-root.Position
            if delta.Magnitude>16 then aim=root.Position+delta.Unit*16 end
            pcall(function()
              for i=0,DIG_BURST-1 do
                event:FireServer(heldPick.Name, aim-Vector3.new(0,i*DIG_SINK,0))
              end
            end)
          end

          -- Skip to next voxel (used by watchdog AND error-notification hook)
          local function advanceVoxel()
            repeat
              queueIdx=queueIdx+1
              currentVoxel=voxelQueue[queueIdx]
            until not currentVoxel or voxelStillPresent(currentVoxel.position)
            skipCurrent=false
            phaseClock=os.clock(); digClock=0
            if currentVoxel then
              local goal=hoverGoal(currentVoxel.position, (getRoot() or {Position=Vector3.zero}).Position)
              Move.glide(goal, currentVoxel.position)
              setStatus(string.format("Voxel %d/%d — %s", queueIdx, #voxelQueue, currentVoxel.info.matName))
            else
              phase="areaclear"; emptyClock=os.clock()
              setStatus("Checking area clear...")
            end
          end

          local function stopFarm()
            active=false; phase="idle"; setStatus("Idle")
            if Runtime.FarmLoot then Runtime.FarmLoot.stop() end
            currentVoxel=nil; table.clear(voxelQueue); queueIdx=1
            skipCurrent=false; heldPick=nil; phaseClock=0; digClock=0; emptyClock=0
            mountainLoadIndex=0; mountainLoadUntil=0
            if errorConn then errorConn:Disconnect(); errorConn=nil end
            Move.glideStop(); Move.setFly(false); Move.setNoclip(false)
          end

          local function step(dt)
            local root=getRoot(); if not root then return end
            local now=os.clock()

            if phase=="load" then
              -- Skip slow mountain preload — go straight to scanning with noclip active.
              Move.setFly(false); Move.setNoclip(true)
              mountainLoadIndex=0; mountainLoadUntil=0
              phase="scan"; phaseClock=now
              setStatus("Scanning for dig veins")
              return

            elseif phase=="scan" then
              local list, centroid = scanConnectedArea()
              if #list==0 then
                -- No veins in immediate area — track how long we've been empty.
                if noVeinSince==0 then noVeinSince=now end
                local elapsed=now-noVeinSince

                -- After NO_VEIN_HOP_DELAY seconds with no veins, hop server.
                if elapsed>=NO_VEIN_HOP_DELAY then
                  noVeinSince=0
                  setStatus("No veins — hopping server")
                  Notify("Dig Vein: no veins found, hopping server",3)
                  task.spawn(function()
                    task.wait(1)
                    if Runtime.farmMethod=="Current Server" then
                      -- Rejoin same server
                      local placeId=game.PlaceId; local jobId=game.JobId
                      pcall(function() S.TeleportService:TeleportToPlaceInstance(placeId,jobId,LocalPlayer) end)
                      task.wait(3)
                      pcall(function() S.TeleportService:Teleport(placeId,LocalPlayer) end)
                    elseif Net and type(Net.hop)=="function" then
                      Net.hop()
                    else
                      local placeId=game.PlaceId
                      pcall(function() S.TeleportService:Teleport(placeId,LocalPlayer) end)
                    end
                  end)
                  return
                end

                -- Still searching — move toward nearest known vein cluster or scan spots.
                local moved=false
                if VeinsModule then
                  local clusters=VeinsModule.getClusters()
                  local best,bestDist
                  for _,cl in pairs(clusters or {}) do
                    if cl.position then
                      local d=(cl.position-root.Position).Magnitude
                      if not best or d<bestDist then best=cl; bestDist=d end
                    end
                  end
                  if best then
                    local goal=hoverGoal(best.position, root.Position)
                    Move.glide(goal, best.position)
                    moved=true
                  end
                end
                if not moved then
                  local spots = getApproachSpots(root)
                  local spotIdx = math.random(1, #spots)
                  Move.glide(spots[spotIdx])
                end
                setStatus(string.format("No dig veins — searching (hop in %ds)", math.ceil(NO_VEIN_HOP_DELAY-elapsed)))
                return
              end
              -- Found veins — reset the no-vein timer
              noVeinSince=0
              voxelQueue=list; queueIdx=1
              farmOrigin=centroid or root.Position
              if Runtime.FarmLoot then Runtime.FarmLoot.setOrigins(list,22) end
              heldPick=Tools.equipPick()
              currentVoxel=voxelQueue[queueIdx]
              skipCurrent=false
              phase="dig"; phaseClock=now; digClock=0; emptyClock=0
              Move.setNoclip(true)  -- re-enable flying for dig phase (may have been off during loot)
              local goal=hoverGoal(currentVoxel.position, root.Position)
              Move.glide(goal, currentVoxel.position)
              setStatus(string.format("Digging area — %d voxels (%s)", #voxelQueue, currentVoxel.info.matName))

            elseif phase=="dig" then
              if not currentVoxel then
                phase="areaclear"; emptyClock=now
                setStatus("Checking area clear..."); return
              end

              -- Error-notification hook flagged this voxel as blocked — skip immediately
              if skipCurrent then
                advanceVoxel(); return
              end

              heldPick=heldPick or Tools.equipPick()
              local vpos=currentVoxel.position

              local goal=hoverGoal(vpos, root.Position)
              Move.glide(goal, vpos)

              digClock=digClock+dt
              if digClock>=DIG_GAP then
                digClock=0
                digAt(vpos)
              end

              local dist=(root.Position-vpos).Magnitude
              local voxelGone = dist<=ARRIVE_DIST and not voxelStillPresent(vpos)
              local timedOut  = now-phaseClock>WATCHDOG

              if voxelGone or timedOut then
                advanceVoxel()
              end

            elseif phase=="areaclear" then
              if now-emptyClock < AREA_CONFIRM then return end
              -- Check ONLY the area we just finished (farmOrigin ± 35 studs).
              -- Using full 150-stud radius here would catch OTHER veins nearby
              -- and cause the farm to fly away and abandon all dropped crystals.
              local checkOrigin = farmOrigin or root.Position
              local remaining = scanConnectedArea(checkOrigin, 35)
              if #remaining>0 then
                -- Same area still has voxels left — re-queue and keep digging
                voxelQueue=remaining; queueIdx=1
                if Runtime.FarmLoot then Runtime.FarmLoot.setOrigins(remaining,22) end
                currentVoxel=voxelQueue[queueIdx]
                skipCurrent=false
                phase="dig"; phaseClock=now; digClock=0
                local goal=hoverGoal(currentVoxel.position, root.Position)
                Move.glide(goal, currentVoxel.position)
                setStatus(string.format("Re-queued %d remaining voxels", #remaining))
              else
                -- Area fully cleared — pakai FarmLoot engine supaya karakter
                -- terbang mendekati tiap crystal persis seperti boulder farm.
                -- Origin di-set ke posisi player sekarang dengan radius 25 studs.
                local lootRoot = getRoot()
                if lootRoot and Runtime.FarmLoot then
                  Runtime.FarmLoot.setOrigins(lootRoot.Position, lootRadiusVein)
                  Runtime.FarmLoot.start()
                end
                Move.setNoclip(true)  -- tetap terbang saat loot
                emptyClock = 0
                -- V4.2 FIX: loot time must not inherit the previous no-vein hop timer.
                noVeinSince = 0
                phase="loot"; lootStart=now
                setStatus("Area clear — looting crystals")
              end

            elseif phase=="loot" then
              -- FarmLoot engine: karakter terbang ke tiap crystal persis boulder farm.
              -- JANGAN setOrigins tiap tick — itu reset quietSince dan bikin stuck selamanya.
              Move.setNoclip(true)
              if Mountain and type(Mountain.setAutoGrab) == "function" then
                Mountain.setAutoGrab(true)
              end
              if Runtime.FarmLoot then
                local done = Runtime.FarmLoot.step()
                if done then
                  -- V4.2 FIX: finish nearby runes before leaving the loot phase.
                  if Mountain and type(Mountain.runesNear) == "function" then
                    local runesLeft = Mountain.runesNear(lootRadiusVein)
                    if runesLeft > 0 then
                      setStatus(string.format("Collecting %d rune(s) before next scan...", runesLeft))
                      return
                    end
                  end
                  if Mountain and type(Mountain.setAutoGrab) == "function" then
                    Mountain.setAutoGrab(Toggles.AutoRunePickup == true)
                  end
                  currentVoxel=nil; table.clear(voxelQueue); queueIdx=1; heldPick=nil
                  emptyClock=0
                  noVeinSince=0
                  phase="scan"; phaseClock=now
                  setStatus("Loot done — scanning next area")
                else
                  -- Update origin sekali tiap 3 detik saat tidak ada target aktif
                  -- supaya crystal yang agak jauh tetap ke-scan, tapi jangan tiap tick
                  if not Runtime.FarmLoot.target then
                    if emptyClock==0 then emptyClock=now end
                    if now-emptyClock >= 3.0 then
                      local lootRoot=getRoot()
                      if lootRoot then
                        Runtime.FarmLoot.setOrigins(lootRoot.Position, lootRadiusVein)
                        emptyClock=now
                      end
                    end
                  else
                    emptyClock=0  -- ada target aktif, reset timer
                  end
                  setStatus("Looting crystals...")
                end
              else
                -- Fallback kalau FarmLoot tidak tersedia: scan radius 25, grab
                local lootRoot = getRoot()
                if lootRoot then
                  local free = backpackFree()
                  if free > 0 then
                    local params = OverlapParams.new()
                    params.FilterType = Enum.RaycastFilterType.Exclude
                    params.FilterDescendantsInstances = {LocalPlayer.Character or LocalPlayer}
                    local ok, hits = pcall(function()
                      return S.Workspace:GetPartBoundsInRadius(lootRoot.Position, 25, params)
                    end)
                    local grabbed = 0
                    if ok and hits then
                      for _, part in ipairs(hits) do
                        if free <= 0 then break end
                        if not part or not part.Parent then continue end
                        if not isCrystal(part) then continue end
                        if getAttr(part,"Collected") == true then continue end
                        local claim = Cache.claimed[part]
                        if claim and now - claim < CFG.PICK.retry then continue end
                        local val = crystalValue(part)
                        if not meetsPickupFilter(part, val) then continue end
                        local w = crystalWeight(part)
                        if w > free then continue end
                        local prompt = crystalPrompt(part)
                        if prompt then instantPromptPatch(prompt) end
                        if grabCrystal(part, prompt, true) then
                          Cache.claimed[part] = now
                          free = free - w
                          grabbed = grabbed + 1
                        end
                      end
                    end
                    if grabbed > 0 then
                      emptyClock = now
                    else
                      if emptyClock == 0 then emptyClock = now end
                      if now - emptyClock >= 4.0 then
                        currentVoxel=nil; table.clear(voxelQueue); queueIdx=1; heldPick=nil
                        emptyClock=0
                        phase="scan"; phaseClock=now
                        setStatus("Loot done — scanning next area")
                      end
                    end
                  else
                    currentVoxel=nil; table.clear(voxelQueue); queueIdx=1; heldPick=nil
                    emptyClock=0
                    phase="scan"; phaseClock=now
                    setStatus("Bag full — scanning next area")
                  end
                end
              end
            end
          end

          function DigVeinFarm.setActive(v)
            if v then
              if active then return end
              active=true; phase="load"; phaseClock=os.clock(); skipCurrent=false
              mountainLoadIndex=0; mountainLoadUntil=0
              Move.setFly(false); Move.setNoclip(true); setStatus("Dig Vein Farm starting")
              -- Hook the game's Notify remote: "error" or "warn" while digging = skip voxel
              if not errorConn then
                local notifyRemote=S.ReplicatedStorage:FindFirstChild("Remotes")
                notifyRemote=notifyRemote and notifyRemote:FindFirstChild("Notify")
                if notifyRemote then
                  errorConn=notifyRemote.OnClientEvent:Connect(function(kind, _msg)
                    if (kind=="error" or kind=="warn") and phase=="dig" and currentVoxel then
                      skipCurrent=true  -- handled next heartbeat tick
                    end
                  end)
                end
              end
              if not conn then
                conn=S.RunService.Heartbeat:Connect(function(dt)
                  if not active then return end
                  local ok,e=pcall(step,dt); if not ok then reportError("DigVeinFarm",e) end
                end)
              end
            else
              if conn then conn:Disconnect(); conn=nil end; stopFarm()
            end
          end
          function DigVeinFarm.isActive() return active end
          function DigVeinFarm.getStatus() return statusText end
          function DigVeinFarm._setLabel(lbl) statusLabel=lbl end
        end

    end
    __InstallExactNXROTDigEngine()
end
do
    local function __InstallExactNXROTBombEngine()
        -- [36] VEIN FARM — BOMB VARIANT
        -- Flies to bomb vein, hovers beside it FACING the vein center,
        -- bombs once, waits for explosion, loots with filter, moves on.
        -- ═══════════════════════════════════════════════════════════════
        BombVeinFarm = {}
        do
          local ARRIVE_DIST    = 10
          local HOVER_OFFSET   = 8
          local EQUIP_TIMEOUT  = 2.5
          local EXPLOSION_WAIT = 7.0
          local WATCHDOG       = 45
          local LOOT_TIME      = 12
          local SCAN_RADIUS_XZ = 200
          local SCAN_RADIUS_Y  = 120
          local OCCUPANCY_MIN  = 0.28
          local CLUSTER_SIZE   = 20

          local active=false; local phase="idle"; local statusText="Idle"
          local target=nil; local phaseClock=0; local lootStart=0
          local equippedBomb=nil; local statusLabel=nil; local conn
          local noVeinSince=0           -- tracks how long scan found nothing
          local NO_VEIN_HOP_DELAY=30    -- seconds before server hop when no veins

          local function setStatus(txt) statusText=txt; if statusLabel then pcall(function() statusLabel.Text=txt end) end end

          local function findNearestBombVein()
            local root=getRoot(); if not root then return nil end
            local origin=root.Position
            local minP=origin-Vector3.new(SCAN_RADIUS_XZ,SCAN_RADIUS_Y,SCAN_RADIUS_XZ)
            local maxP=origin+Vector3.new(SCAN_RADIUS_XZ,SCAN_RADIUS_Y,SCAN_RADIUS_XZ)
            local ok,region=pcall(function() return Region3.new(minP,maxP):ExpandToGrid(4) end)
            if not ok then return nil end
            local ok2,mats,occs=pcall(function() return S.Workspace.Terrain:ReadVoxels(region,4) end)
            if not ok2 or not mats then return nil end
            local sz=mats.Size; local regionMin=region.CFrame.Position-region.Size*0.5
            local clusters={}
            for x=1,sz.X do for y=1,sz.Y do for z=1,sz.Z do
              local occ=occs[x][y][z]
              if occ and occ>=OCCUPANCY_MIN then
                local mat=mats[x][y][z]; local info=BOMB_MATERIALS[mat]
                if info then
                  local mname=info.matName
                  if next(Cache.bombVeinFilter)==nil or Cache.bombVeinFilter[mname] then
                    local pos=regionMin+Vector3.new((x-0.5)*4,(y-0.5)*4,(z-0.5)*4)
                    local cx=math.floor(pos.X/CLUSTER_SIZE); local cy=math.floor(pos.Y/CLUSTER_SIZE); local cz=math.floor(pos.Z/CLUSTER_SIZE)
                    local id=tostring(mat)..":"..cx..":"..cy..":"..cz
                    if not clusters[id] then clusters[id]={position=pos,material=mat,info=info,bombId=info.bombId,tier=info.tier} end
                  end
                end
              end
            end end end
            local best,bestDist
            for _,cl in pairs(clusters) do
              -- find a bomb we actually have for this tier
              local useBombId=nil
              for bombId,tier in pairs(BOMB_TIER) do
                if tier>=cl.tier and getBombCount(bombId)>0 then
                  if not useBombId or tier<BOMB_TIER[useBombId] then useBombId=bombId end
                end
              end
              if useBombId then
                cl.useBombId=useBombId
                local d=(cl.position-origin).Magnitude
                if not best or d<bestDist then best=cl; bestDist=d end
              end
            end
            return best
          end

          local function hoverGoal(veinPos, rootPos)
            local away = rootPos - veinPos
            away = Vector3.new(away.X, 0, away.Z)
            if away.Magnitude < 0.5 then away = Vector3.new(1,0,0) end
            local hoverPos = veinPos + away.Unit*HOVER_OFFSET + Vector3.new(0, 2, 0)
            return CFrame.lookAt(hoverPos, veinPos)
          end

          local function bombToolMatches(tool, bombId)
            if not tool or not tool:IsA("Tool") or not bombId then return false end
            local id=getAttr(tool,"BombId") or getAttr(tool,"ItemId") or getAttr(tool,"Id")
            if tostring(id)==bombId then return true end
            if tool.Name==bombId then return true end
            local display=BOMB_CONFIG[bombId] and BOMB_CONFIG[bombId].displayName
            if display and tool.Name==display then return true end
            local lower=tool.Name:lower():gsub("[%s_%-]","")
            local wanted=bombId:lower():gsub("[%s_%-]","")
            return lower:find("bomb",1,true)~=nil and lower:find(wanted,1,true)~=nil
          end

          local function equipBomb(bombId)
            local char=LocalPlayer.Character
            local h=char and char:FindFirstChildOfClass("Humanoid")
            if not char or not h then return nil end
            local function findTool()
              local held=char:FindFirstChildOfClass("Tool")
              if bombToolMatches(held,bombId) then return held end
              local bp=LocalPlayer:FindFirstChildOfClass("Backpack")
              if bp then for _,t in ipairs(bp:GetChildren()) do if bombToolMatches(t,bombId) then return t end end end
              return nil
            end
            local tool=findTool(); if not tool then return nil end
            if tool.Parent~=char then pcall(function() h:EquipTool(tool) end) end
            local deadline=os.clock()+EQUIP_TIMEOUT
            while os.clock()<deadline do
              local held=char:FindFirstChildOfClass("Tool")
              if held and bombToolMatches(held,bombId) then return held end
              task.wait()
            end
            return nil
          end

          local function activateBomb(tool, position)
            if not tool or not tool.Parent then return false end
            local root=getRoot()
            if root then Move.glide(CFrame.lookAt(root.Position, position), position) end
            if RMT.BombActivate then
              local sent=pcall(function() RMT.BombActivate:FireServer(tool,position) end)
              if sent then return true end
            end
            pcall(function() tool:Activate() end)
            return true
          end

          local function stopFarm()
            active=false; phase="idle"; setStatus("Idle")
            if Runtime.FarmLoot then Runtime.FarmLoot.stop() end
            target=nil; equippedBomb=nil; phaseClock=0; lootStart=0
            Move.glideStop(); Move.setFly(false); Move.setNoclip(false)
          end

          local function step(dt)
            local root=getRoot(); if not root then return end
            local now=os.clock()
            if phase=="scan" then
              local found=findNearestBombVein()
              if found then
                noVeinSince=0
                target=found; phase="fly"; phaseClock=now; equippedBomb=nil
                Move.setNoclip(true)
                Move.glide(hoverGoal(found.position, root.Position), found.position)
                setStatus("Flying to "..found.info.matName)
              else
                if noVeinSince==0 then noVeinSince=now end
                local elapsed=now-noVeinSince
                if elapsed>=NO_VEIN_HOP_DELAY then
                  noVeinSince=0
                  setStatus("No bomb veins — hopping server")
                  Notify("Bomb Vein: no veins found, hopping server",3)
                  task.spawn(function()
                    task.wait(1)
                    if Runtime.farmMethod=="Current Server" then
                      local placeId=game.PlaceId; local jobId=game.JobId
                      pcall(function() S.TeleportService:TeleportToPlaceInstance(placeId,jobId,LocalPlayer) end)
                      task.wait(3)
                      pcall(function() S.TeleportService:Teleport(placeId,LocalPlayer) end)
                    elseif Net and type(Net.hop)=="function" then
                      Net.hop()
                    else
                      pcall(function() S.TeleportService:Teleport(game.PlaceId,LocalPlayer) end)
                    end
                  end)
                else
                  setStatus(string.format("No bomb veins — searching (hop in %ds)", math.ceil(NO_VEIN_HOP_DELAY-elapsed)))
                end
              end
            elseif phase=="fly" then
              if not target then phase="scan"; return end
              Move.glide(hoverGoal(target.position, root.Position), target.position)
              local dist=(root.Position-target.position).Magnitude
              if dist<=ARRIVE_DIST then
                phase="equip"; phaseClock=now
                setStatus("Equipping "..(BOMB_CONFIG[target.useBombId] and BOMB_CONFIG[target.useBombId].displayName or target.useBombId))
              elseif now-phaseClock>WATCHDOG then target=nil; phase="scan"; phaseClock=now end
            elseif phase=="equip" then
              if not target then phase="scan"; return end
              -- keep hovering + facing while equipping
              Move.glide(hoverGoal(target.position, root.Position), target.position)
              equippedBomb=equipBomb(target.useBombId)
              if equippedBomb then
                phase="bomb"; phaseClock=now
                setStatus("Bombing "..target.info.matName)
                -- bomb once immediately
                activateBomb(equippedBomb, target.position)
              elseif now-phaseClock>EQUIP_TIMEOUT*2 then
                setStatus("No bomb found, skipping"); target=nil; phase="scan"; phaseClock=now
              end
            elseif phase=="bomb" then
              if not target then phase="scan"; return end
              -- hover beside vein facing it while waiting for explosion
              Move.glide(hoverGoal(target.position, root.Position), target.position)
              local fuse=(target.useBombId and BOMB_CONFIG[target.useBombId] and BOMB_CONFIG[target.useBombId].fuse) or 2.5
              if now-phaseClock>EXPLOSION_WAIT+fuse then
                -- V4.2 FIX: loot time must not inherit the previous no-vein hop timer.
                noVeinSince=0
                phase="loot"; lootStart=now
                if Runtime.FarmLoot then
                  Runtime.FarmLoot.setOrigins(root.Position,lootRadiusVein)
                  Runtime.FarmLoot.start()
                end
                setStatus("Looting "..target.info.matName.." crystals")
              end
            elseif phase=="loot" then
              if Mountain and type(Mountain.setAutoGrab) == "function" then
                Mountain.setAutoGrab(true)
              end
              if Runtime.FarmLoot then
                local done=Runtime.FarmLoot.step()
                if not done then setStatus("Looting eligible crystals..."); return end
              end
              -- V4.2 FIX: finish nearby runes before returning to scan/hop logic.
              if Mountain and type(Mountain.runesNear) == "function" then
                local runesLeft = Mountain.runesNear(lootRadiusVein)
                if runesLeft > 0 then
                  setStatus(string.format("Collecting %d rune(s) before next scan...", runesLeft))
                  return
                end
              end
              if Mountain and type(Mountain.setAutoGrab) == "function" then
                Mountain.setAutoGrab(Toggles.AutoRunePickup == true)
              end
              noVeinSince=0
              target=nil; equippedBomb=nil; phase="scan"; phaseClock=now
              setStatus("Loot done — scanning next bomb vein")
            end
          end

          function BombVeinFarm.setActive(v)
            if v then
              if active then return end
              active=true; phase="scan"; phaseClock=os.clock()
              Move.setNoclip(true); setStatus("Bomb Vein Farm starting")
              if not conn then
                conn=S.RunService.Heartbeat:Connect(function(dt)
                  if not active then return end
                  local ok,e=pcall(step,dt); if not ok then reportError("BombVeinFarm",e) end
                end)
              end
            else
              if conn then conn:Disconnect(); conn=nil end; stopFarm()
            end
          end
          function BombVeinFarm.isActive() return active end
          function BombVeinFarm.getStatus() return statusText end
          function BombVeinFarm._setLabel(lbl) statusLabel=lbl end
        end

    end
    __InstallExactNXROTBombEngine()
end
-- [32] MONEY FARM
local Money={}
local moneyConn
do
	local function install()
		local SCAN_SPOTS={
			CFrame.new(-12.7105675,459.090942,818.847412,0.993408799,-0.00500036497,-0.11451605,0.000644713698,0.999275982,-0.0380407833,0.114623353,0.0377162211,0.992692769),
			CFrame.new(13.0506754,318.450409,-488.078888,-0.99998939,0.000884758658,-0.00452193478,-0.000498382491,0.954864502,0.297041386,0.00458064489,0.297040492,-0.954853892),
			CFrame.new(74.3923645,610.789368,210.838226,-0.94896102,-0.27110818,0.161162555,2.26557495e-06,0.51098305,0.859590769,-0.315393418,0.815718472,-0.484902382),
		}
		local SCAN_HOLD=1.4; local PEAK_GAP=10; local PEAK_STEP=48; local PEAK_RINGS=12
		local COLUMN_STEP=8; local RING_MAX=6; local RAY_TOP=120; local RAY_DROP=60
		local ZONE_PAD=12; local SURFACE_GAP=0.15; local COLUMN_DRY=40
		local DIG_BURST=7; local DIG_SINK=1.2; local DIG_LIFT=6; local DIG_REACH=12
		local DIG_REFRESH=5; local COLLECT_RANGE=32000; local COLLECT_LIFT=5
		local COLLECT_GAP=0.12; local GRAB_GAP=0.05; local EQUIP_STEP=1
		local SELL_MARK=0.5; local SELL_WAIT=7
		local OFFSETS={Vector2.new(0,0)}
		local PEAK_OFFSETS={Vector2.new(0,0)}
		for ring=1,RING_MAX do
			local slices=ring*6
			for slice=0,slices-1 do
				local angle=slice/slices*math.pi*2; local reach=ring*COLUMN_STEP
				OFFSETS[#OFFSETS+1]=Vector2.new(math.cos(angle)*reach,math.sin(angle)*reach)
			end
		end
		for ring=1,PEAK_RINGS do
			local slices=ring*3
			for slice=0,slices-1 do
				local angle=slice/slices*math.pi*2; local reach=ring*PEAK_STEP
				PEAK_OFFSETS[#PEAK_OFFSETS+1]=Vector2.new(math.cos(angle)*reach,math.sin(angle)*reach)
			end
		end
		local surfaceParams=RaycastParams.new()
		surfaceParams.FilterType=Enum.RaycastFilterType.Include
		surfaceParams.FilterDescendantsInstances={S.Workspace.Terrain}
		surfaceParams.IgnoreWater=true
		local digParams=RaycastParams.new()
		digParams.FilterType=Enum.RaycastFilterType.Include
		digParams.IgnoreWater=true
		local digClock=0
		local function digFilter(now)
			if digClock>0 and now-digClock<DIG_REFRESH then return end
			digClock=now
			local list={S.Workspace.Terrain}
			local deco=S.Workspace:FindFirstChild("MountainDecorations")
			local boulders=deco and deco:FindFirstChild("Boulders")
			if boulders then list[#list+1]=boulders end
			local test=S.Workspace:FindFirstChild("BoulderTest"); if test then list[#list+1]=test end
			digParams.FilterDescendantsInstances=list
		end
		local function pickReach(tool)
			local override=tool and tonumber(getAttr(tool,"OverrideMaxReach"))
			return (override or DIG_REACH)+3
		end
		local function aimPoint(origin,spot,reach,now)
			digFilter(now)
			local goals={spot,spot-Vector3.new(0,2,0),origin-Vector3.new(0,reach,0)}
			for _,goal in ipairs(goals) do
				local delta=goal-origin; local distance=delta.Magnitude
				if distance>0.05 then
					local span=math.min(distance+4,reach)
					local hit=S.Workspace:Raycast(origin,delta.Unit*span,digParams)
					if hit then return hit.Position end
				end
			end
			local delta=spot-origin
			if delta.Magnitude<=reach then return spot end
			return origin+delta.Unit*reach
		end
		local active=false; local autoSell=false; local heldPick
		local loot,lootClock,grabClock=nil,0,0
		local lootScanClock=0
		local lootHp,lootMax
		local digTarget,columnY
		local columnDry,columnSwings=0,0
		local surfaceClock,peakClock=0,0
		local scanIndex,scanUntil=0,0; local loaded=false
		local swingClock,equipClock=0,0
		local sellSpot,sellUntil=nil,0; local lootBlocked=false
		local statusText="Idle"
		local function zoneBase()
			local base=S.Workspace:GetAttribute("MountainBaseY")
			return typeof(base)=="number" and base or 0
		end
		local function zonePeak()
			local peak=S.Workspace:GetAttribute("MountainPeakY")
			return typeof(peak)=="number" and peak or zoneBase()+900
		end
		local function mountainSpot()
			local cx=S.Workspace:GetAttribute("MountainCenterX")
			local cz=S.Workspace:GetAttribute("MountainCenterZ")
			if typeof(cx)=="number" and typeof(cz)=="number" then
				local base=S.Workspace:GetAttribute("MountainBaseY")
				local peak=S.Workspace:GetAttribute("MountainPeakY")
				local height=700
				if typeof(base)=="number" and typeof(peak)=="number" then height=base+(peak-base)*0.55 end
				return Vector3.new(cx,height,cz)
			end
			local things=S.Workspace:FindFirstChild("Things")
			local zones=things and things:FindFirstChild("MountainZones")
			if zones then
				for _,child in ipairs(zones:GetChildren()) do
					if child:IsA("BasePart") and child.Name=="MountainZone" then return child.Position end
				end
			end
			return nil
		end
		local function mountainSpan()
			local r=S.Workspace:GetAttribute("MountainRadius")
			if typeof(r)=="number" and r>20 then return r end; return 150
		end
		local function zoneCenter()
			local spot=mountainSpot(); if spot then return Vector2.new(spot.X,spot.Z) end; return nil
		end
		local function insideZone(x,z)
			local center=zoneCenter(); if not center then return false end
			return (Vector2.new(x,z)-center).Magnitude<=mountainSpan()+ZONE_PAD
		end
		local function surfaceAt(x,z)
			if not insideZone(x,z) then return nil end
			local base=zoneBase(); local top=zonePeak()+RAY_TOP
			local hit=S.Workspace:Raycast(Vector3.new(x,top,z),Vector3.new(0,-(top-base+RAY_DROP),0),surfaceParams)
			if not hit or hit.Position.Y<=base+1 then return nil end
			return hit.Position
		end
		local function farmOrigin(root)
			if insideZone(root.Position.X,root.Position.Z) then return root.Position end
			return mountainSpot() or root.Position
		end
		local function highestColumn(origin,offsets)
			local best
			for _,offset in ipairs(offsets) do
				local spot=surfaceAt(origin.X+offset.X,origin.Z+offset.Y)
				if spot and (not best or spot.Y>best.Y) then best=spot end
			end
			return best
		end
		local function findDigTarget(origin,now)
			local center=mountainSpot()
			if center and now-peakClock>=PEAK_GAP then
				peakClock=now; local high=highestColumn(center,PEAK_OFFSETS); if high then return high end
			end
			local spot=highestColumn(origin,OFFSETS); if spot then return spot end
			if center then peakClock=now; return highestColumn(center,PEAK_OFFSETS) end
			return nil
		end
		local function swing(spot)
			local event=Tools.digEvent(); if not event or not heldPick then return false end
			local name=heldPick.Name; local root=getRoot(); local aim=spot
			if root then aim=aimPoint(root.Position,spot,pickReach(heldPick),os.clock()) or spot end
			return pcall(function()
				for step=0,DIG_BURST-1 do event:FireServer(name,aim-Vector3.new(0,step*DIG_SINK,0)) end
			end)
		end
		local function bagRatio()
			local cap=backpackCapacity(); if cap==math.huge or cap<=0 then return 0 end
			return backpackWeight()/cap
		end

		-- ============================================================
		-- CRYSTAL SCANNER
		-- ============================================================
		-- This scanner is intentionally reused by Money Farm and the
		-- "Refresh Crystal" UI. It scans the game's crystal containers
		-- plus the live registry, without doing Workspace:GetDescendants()
		-- every frame.
		local function scanCrystalEntries()
			local byName={}
			local function consider(inst)
				if not inst or not inst.Parent or not isCrystal(inst) then return end
				if getAttr(inst,"Collected")==true then return end
				local value=crystalValue(inst)
				if value < minValue then return end
				local name=crystalName(inst)
				if type(name)~="string" or name=="" then return end
				local rarity=crystalRarity(inst)
				local current=byName[name]
				if not current or value>current.value then
					byName[name]={name=name,rarity=rarity,value=value}
				end
			end
			eachContainer(function(c)
				for _,child in ipairs(c:GetChildren()) do
					if child:IsA("BasePart") then
						consider(child)
					elseif child:IsA("Model") then
						for _,inner in ipairs(child:GetChildren()) do
							if inner:IsA("BasePart") then consider(inner) end
						end
					end
				end
			end)
			for inst in pairs(Cache.registry) do consider(inst) end
			local list={}
			for _,entry in pairs(byName) do list[#list+1]=entry end
			table.sort(list,function(a,b)
				if a.value==b.value then return string.lower(a.name)<string.lower(b.name) end
				return a.value>b.value
			end)
			return list
		end

		local function findLoot(free,origin)
			local best,bestValue,bestDistance; local blocked=false; local seen={}
			local function consider(inst)
				if not inst or seen[inst] then return end; seen[inst]=true
				if not inst.Parent or not isCrystal(inst) or getAttr(inst,"Collected")==true then return end
				local value=crystalValue(inst)
				if not meetsFarmFilter(inst,value) then return end
				local distance=(inst.Position-origin).Magnitude; if distance>COLLECT_RANGE then return end
				local weight=crystalWeight(inst)
				if weight>free then blocked=true; return end
				local better=not best or value>bestValue
				if not better and value==bestValue and distance<bestDistance then better=true end
				if better then best=inst; bestValue=value; bestDistance=distance end
			end
			eachContainer(function(c)
				for _, child in ipairs(c:GetChildren()) do
					if child:IsA("BasePart") then consider(child)
					elseif child:IsA("Model") then
						for _, inner in ipairs(child:GetChildren()) do if inner:IsA("BasePart") then consider(inner) end end
					end
				end
			end)
			for inst in pairs(Cache.registry) do consider(inst) end
			return best,blocked
		end

		function Money.scanEligibleCrystals()
			return scanCrystalEntries()
		end

		local function stopMoney()
			active=false; digTarget=nil; columnY=nil; loaded=false
			Move.glideStop(); scanIndex=0; loot=nil; lootHp=nil; lootMax=nil; lootScanClock=0
			lootBlocked=false; sellSpot=nil; sellUntil=0; heldPick=nil; statusText="Idle"
			Move.setFly(Toggles.Fly); Move.setNoclip(Toggles.Noclip)
			Mountain.setAutoGrab(Toggles.AutoRunePickup)
		end
		local function step(deltaTime)
			-- Boulder Farm owns noclip for its entire active lifetime. Other movement
			-- features must not be able to turn it off between Heartbeats.
			Move.setNoclip(true)
			local root=getRoot(); if not root then statusText="Waiting for character"; return end
			local now=os.clock()
			-- Never let crystal pickup interrupt terrain excavation or Boulder mining.
			if phase=="scan" or phase=="mine" then
				Mountain.setAutoGrab(false)
				if instantPromptActive then setInstantPrompt(false) end
			end
			if not loaded then
				if scanIndex==0 then scanIndex=1; scanUntil=now+SCAN_HOLD end
				if scanIndex<=#SCAN_SPOTS then
					Move.glide(SCAN_SPOTS[scanIndex])
					statusText=string.format("Loading terrain %d/%d",scanIndex,#SCAN_SPOTS)
					if now>=scanUntil then scanIndex=scanIndex+1; scanUntil=now+SCAN_HOLD end; return
				end
				loaded=true; peakClock=0
			end
			if sellUntil>0 then
				if now<sellUntil then statusText="Selling"; return end
				sellUntil=0
				if sellSpot then applyPivot(sellSpot); sellSpot=nil end
				digTarget=nil; columnY=nil; surfaceClock=0
			end
			-- Removed general auto-sell from here, moved to global scheduler. 
			-- However, keeping the emergency fail-safe if loot blocked by full bag.
			if autoSell and lootBlocked and backpackFree()<=0 then
				sellSpot=root.CFrame
				if doSell() then lootBlocked=false; sellUntil=now+SELL_WAIT; statusText="Selling"; return end
			end

			-- Continuously rescan for eligible crystals while the terrain column
			-- is being dug. We do NOT scan every frame: this interval is frequent
			-- enough to catch newly spawned high-value crystals without turning
			-- the farm into a Workspace scanning loop.
			local free=backpackFree()
			if not loot and now-lootScanClock>=0.18 then
				lootScanClock=now
				local candidate,blocked=findLoot(free,root.Position)
				lootBlocked=blocked
				if candidate then
					loot=candidate
					local hp=tonumber(getAttr(loot,"MinedHP")); lootHp=hp; lootMax=hp
					Move.glideStop()
					statusText="High-value crystal found"
				end
			end
			swingClock=swingClock+deltaTime
			if loot then
				-- MONEY FARM PICKUP MODE:
				-- Never mine/break the selected crystal. Use the exact same
				-- pickup helper used by Boulder loot, regardless of rarity.
				if not loot.Parent or getAttr(loot,"Collected")==true then
					loot=nil; lootHp=nil; lootMax=nil
				else
					local spot=loot.Position
					Move.glide(CFrame.new(spot+Vector3.new(0,COLLECT_LIFT,0),spot),spot)
					requestStream(spot)
					if now-grabClock>=GRAB_GAP then
						grabClock=now
						local prompt=crystalPrompt(loot)
						if prompt then instantPromptPatch(prompt) end
						if grabCrystal(loot,prompt,true) then
							Cache.claimed[loot]=now
						end
					end
					statusText="Collecting crystal"
				end
				return
			end

			-- No eligible crystal is currently targeted. Preserve the original
			-- Money Farm digging fallback exactly as before.
			if heldPick==nil or heldPick.Parent~=LocalPlayer.Character then
				equipClock=0; heldPick=Tools.equipPick()
			else
				equipClock=equipClock+deltaTime
				if equipClock>=EQUIP_STEP then equipClock=0; heldPick=Tools.equipPick() or heldPick end
			end
			if not heldPick then statusText="No pickaxe"; return end
			local swingNeed=math.max(0.02,Tools.swingGap(heldPick)*0.4)
			local canSwing=swingClock>=swingNeed
			local origin=farmOrigin(root)
			if digTarget and now-surfaceClock>=SURFACE_GAP then
				surfaceClock=now
				local spot=surfaceAt(digTarget.X,digTarget.Z)
				if not spot then digTarget=nil; columnY=nil; columnDry=0; columnSwings=0
				else
					if not columnY or spot.Y<columnY-0.05 then columnDry=0 else columnDry=columnDry+columnSwings end
					columnSwings=0; columnY=spot.Y; digTarget=spot
					if columnDry>=COLUMN_DRY then digTarget=nil; columnY=nil; columnDry=0 end
				end
			end
			if not digTarget then
				local spot=findDigTarget(origin,now) or surfaceAt(origin.X,origin.Z)
				if not spot then
					requestStream(origin)
					if canSwing then swingClock=swingClock-swingNeed; swing(root.Position-Vector3.new(0,DIG_REACH*0.5,0)) end
					statusText="Loading terrain"; return
				end
				digTarget=spot; columnY=spot.Y; columnDry=0; columnSwings=0; surfaceClock=now
			end
			Move.glide(CFrame.new(digTarget+Vector3.new(0,DIG_LIFT,0),digTarget),digTarget)
			if canSwing then swingClock=swingClock-swingNeed; columnSwings=columnSwings+1; swing(digTarget) end
			statusText=string.format("Mining surface at %dm",math.floor(digTarget.Y))
		end
		function Money.stop() stopMoney() end
		function Money.setActive(value)
			if not value then stopMoney(); return end
			active=true; digTarget=nil; columnY=nil; columnDry=0; columnSwings=0
			surfaceClock=0; peakClock=0; scanIndex=0; scanUntil=0; loaded=true
			loot=nil; lootClock=0; lootScanClock=0; lootHp=nil; lootMax=nil; lootBlocked=false
			swingClock=0; equipClock=0; sellSpot=nil; sellUntil=0; heldPick=nil; statusText="Starting"
			Move.setFly(false); Move.setNoclip(true); Mountain.setAutoGrab(true)
		end
		function Money.setAutoSell(v) autoSell=v end
		local MoneyStatusLabel; local labelClock=0
		moneyConn=S.RunService.Heartbeat:Connect(function(deltaTime)
			if active then
				local ok,err=pcall(step,deltaTime)
				if not ok then reportError("moneyFarm",err) end
			end
			labelClock=labelClock+deltaTime
			if labelClock>=0.25 then
				labelClock=0
				if MoneyStatusLabel then MoneyStatusLabel.Text=statusText end
			end
		end)
		Money._getStatusLabel=function(lbl) MoneyStatusLabel=lbl end
	end
	install()
end

-- [33] AUTO BOMB MODULE
local AutoBomb = {}
local autoBombConn
do
	local function install()
		local CONFIG = {
			STEP = 0.12,
			ACTIVATE_COOLDOWN = 0.85,
			FUSE_BUFFER = 0.65,
			EXPLOSION_TIMEOUT = 6.0,
			MAX_RETRY = 2,
			RETRY_DELAY = 0.45,
			EQUIP_TIMEOUT = 1.50,
			POST_EXPLOSION_PICK_DELAY = 0.18,
			NO_BOMB_TELEPORT_COOLDOWN = 1.5,
			TELEPORT_SURFACE_HEIGHT = 5,
			NOTIFICATION_TARGET_RADIUS = 10,
			TARGET_SAMPLE_STEP = 2,
			TARGET_SAMPLE_DEPTH = 10,
			TOOL_ACTIVATE_DELAY = 0.10,
			REMOTE_RETRY_DELAY = 0.20,
		}
		local STATE = {
			IDLE="IDLE", WAITING_NOTIFICATION="WAITING_NOTIFICATION", READY="READY",
			EQUIPPING="EQUIPPING", ACTIVATING="ACTIVATING",
			WAITING_EXPLOSION="WAITING_EXPLOSION", VERIFYING="VERIFYING",
			SUCCESS="SUCCESS", RETRY="RETRY", FAILED="FAILED",
		}
		local state = STATE.IDLE
		local statusText = "Idle"
		local bombStatusLabel
		local currentBomb, currentMaterial, currentPosition
		local equippedBombTool
		local attempt, retryAt = 0, 0
		local lastActivation, activationAt, expectedExplosionAt = 0, 0
		local accumulator, labelClock = 0, 0
		local requiredBombTier, requiredBombId
		local notificationClock = 0
		local lastNotificationText = ""
		local lastNoBombTeleport = 0
		local activationConfirmed = false
		local function safeNotify(text, duration) pcall(function() Notify(text, duration or 2) end) end
		local function setState(newState, text)
			state = newState
			statusText = text or newState
		end
		local function resetAttempt(keepRequirement)
			currentBomb = nil; currentMaterial = nil; currentPosition = nil; equippedBombTool = nil
			attempt = 0; retryAt = 0; activationAt = 0; expectedExplosionAt = 0; activationConfirmed = false
			if not keepRequirement then requiredBombTier = nil; requiredBombId = nil end
		end
		local function bombToolMatches(tool, bombId)
			if not tool or not tool:IsA("Tool") or not bombId then return false end
			local id = getAttr(tool,"BombId") or getAttr(tool,"ItemId") or getAttr(tool,"Id")
			if tostring(id) == bombId then return true end
			if tool.Name == bombId then return true end
			local display = BOMB_CONFIG[bombId] and BOMB_CONFIG[bombId].displayName
			if display and (tool.Name == display or tool.Name:gsub(" ",""):lower() == bombId:gsub(" ",""):lower()) then return true end
			local lower = tool.Name:lower():gsub("[%s_%-]","")
			local wanted = bombId:lower():gsub("[%s_%-]","")
			return lower:find("bomb",1,true) ~= nil and lower:find(wanted,1,true) ~= nil
		end
		local function findBombTool(bombId)
			local char = LocalPlayer.Character
			if char then
				local held = char:FindFirstChildOfClass("Tool")
				if bombToolMatches(held,bombId) then return held end
			end
			local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
			if bp then
				for _,tool in ipairs(bp:GetChildren()) do if bombToolMatches(tool,bombId) then return tool end end
			end
			return nil
		end
		local function equipBombTool(bombId)
			local char = LocalPlayer.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if not char or not hum then return nil end
			local tool = findBombTool(bombId)
			if not tool then return nil end
			if tool.Parent ~= char then pcall(function() hum:EquipTool(tool) end) end
			local deadline = os.clock() + CONFIG.EQUIP_TIMEOUT
			while os.clock() < deadline do
				local held = char:FindFirstChildOfClass("Tool")
				if held and bombToolMatches(held,bombId) then return held end
				task.wait()
			end
			return nil
		end
		local function equipPickaxeAfterBomb()
			task.wait(CONFIG.POST_EXPLOSION_PICK_DELAY)
			local ok, tool = pcall(function() return Tools.equipPick() end)
			return ok and tool or nil
		end
		local function getBestBombForRequirement(requiredTier)
			requiredTier = tonumber(requiredTier) or 1
			local bestId, bestTier, bestCount = nil, math.huge, 0
			for bombId in pairs(BOMB_CONFIG) do
				local tier = BOMB_TIER[bombId] or 0
				local count = getBombCount(bombId)
				if tier >= requiredTier and count > 0 and tier < bestTier then
					bestId, bestTier, bestCount = bombId, tier, count
				end
			end
			return bestId,bestTier,bestCount
		end
		local function parseBombRequirement(text)
			if type(text) ~= "string" then return nil,nil end
			local lower = text:lower()
			local names = {
				{ "Agony Bomb", "AgonyBomb", 8 }, { "Time Bomb", "TimeBomb", 7 },
				{ "Poison Bomb", "PoisonBomb", 6 }, { "Thunder Bomb", "ThunderBomb", 5 },
				{ "Fire Bomb", "FireBomb", 4 }, { "Ice Bomb", "IceBomb", 3 },
				{ "Wind Bomb", "WindBomb", 2 }, { "Classic Bomb", "ClassicBomb", 1 },
			}
			for _,entry in ipairs(names) do if lower:find(entry[1]:lower(),1,true) then return entry[2],entry[3] end end
			return nil,nil
		end
		local function teleportToFreshSurface()
			local now=os.clock()
			if now-lastNoBombTeleport < CONFIG.NO_BOMB_TELEPORT_COOLDOWN then return false end
			local root=getRoot()
			if not root then return false end
			local cx=S.Workspace:GetAttribute("MountainCenterX")
			local cz=S.Workspace:GetAttribute("MountainCenterZ")
			local base=S.Workspace:GetAttribute("MountainBaseY")
			local peak=S.Workspace:GetAttribute("MountainPeakY")
			local radius=S.Workspace:GetAttribute("MountainRadius")
			if typeof(cx)~="number" or typeof(cz)~="number" then return false end
			base=typeof(base)=="number" and base or 0
			peak=typeof(peak)=="number" and peak or (base+900)
			radius=typeof(radius)=="number" and math.max(radius-10,20) or 120
			local rayParams=RaycastParams.new()
			rayParams.FilterType=Enum.RaycastFilterType.Include
			rayParams.FilterDescendantsInstances={S.Workspace.Terrain}
			rayParams.IgnoreWater=true
			for _=1,12 do
				local angle=math.random()*math.pi*2
				local r=math.sqrt(math.random())*radius
				local x=cx+math.cos(angle)*r
				local z=cz+math.sin(angle)*r
				local top=peak+80
				local hit=S.Workspace:Raycast(Vector3.new(x,top,z),Vector3.new(0,-(top-base+120),0),rayParams)
				if hit and hit.Position.Y>base+5 then
					local target=hit.Position+Vector3.new(0,CONFIG.TELEPORT_SURFACE_HEIGHT,0)
					if applyPivot(CFrame.new(target,target-Vector3.new(0,1,0))) then
						lastNoBombTeleport=now; requestStream(target); return true
					end
				end
			end
			return false
		end
		local function sampleNearbyBombTarget(rootPosition)
			if not rootPosition then return nil,nil end
			local bestMat,bestPos,bestDistance
			local offsets={
				Vector3.new(0,0,0), Vector3.new(0,-2,0), Vector3.new(0,-4,0), Vector3.new(0,-6,0),
				Vector3.new(0,-8,0), Vector3.new(0,-10,0), Vector3.new(0,-12,0), Vector3.new(0,-14,0),
				Vector3.new(0,-16,0), Vector3.new(0,-18,0), Vector3.new(2,-6,0), Vector3.new(-2,-6,0),
				Vector3.new(0,-6,2), Vector3.new(0,-6,-2), Vector3.new(2,-12,0), Vector3.new(-2,-12,0),
				Vector3.new(0,-12,2), Vector3.new(0,-12,-2),
			}
			for _,offset in ipairs(offsets) do
				local pos=rootPosition+offset
				local mat=sampleTerrainMaterial(pos)
				if mat and isBombMaterial(mat) then
					local d=offset.Magnitude
					if bestDistance==nil or d<bestDistance then bestMat,bestPos,bestDistance=mat,pos,d end
				end
			end
			return bestMat,bestPos
		end
		local function getNotificationTarget()
			local root=getRoot()
			if not root then return nil,nil end
			local mat,pos=sampleNearbyBombTarget(root.Position)
			if mat and pos then return mat,pos end
			return nil,root.Position+Vector3.new(0,-6,0)
		end
		local function activateBomb(bombId, position)
			if not bombId or not position then return false end
			if os.clock() - lastActivation < CONFIG.ACTIVATE_COOLDOWN then return false end
			if getBombCount(bombId) <= 0 then setState(STATE.FAILED,"Need "..tostring(bombId)); return false end
			setState(STATE.EQUIPPING,"Equipping "..tostring(bombId))
			local tool=equippedBombTool
			if not tool or not bombToolMatches(tool,bombId) or tool.Parent~=LocalPlayer.Character then tool=equipBombTool(bombId) end
			if not tool then statusText="Bomb tool not found"; return false end
			equippedBombTool=tool
			local toolActivated=pcall(function() tool:Activate() end)
			if not toolActivated then statusText="Bomb tool activation failed"; return false end
			task.wait(CONFIG.TOOL_ACTIVATE_DELAY)
			if not RMT.BombActivate or not RMT.BombActivate:IsA("RemoteEvent") then statusText="BombActivate remote unavailable"; return false end
			setState(STATE.ACTIVATING,"Using "..tostring(bombId))
			local sent=false
			local ok,err=pcall(function() RMT.BombActivate:FireServer(bombId,position); sent=true end)
			if not ok or not sent then reportError("autoBomb.activate",err or "BombActivate failed"); return false end
			local now=os.clock()
			lastActivation=now; activationAt=now; activationConfirmed=true
			local fuse=(BOMB_CONFIG[bombId] and BOMB_CONFIG[bombId].fuse) or 2.5
			expectedExplosionAt=now+fuse+CONFIG.FUSE_BUFFER; currentBomb=bombId
			setState(STATE.WAITING_EXPLOSION,"Waiting for "..tostring(bombId).." explosion")
			return true
		end
		local function verifyExplosion()
			if not currentPosition then return false end
			local mat=sampleTerrainMaterial(currentPosition)
			return (not mat) or (not isBombMaterial(mat))
		end
		local function failAndReturnSurface(reason)
			setState(STATE.FAILED,reason or "Bomb failed")
			safeNotify((reason or "Bomb failed").." - returning to surface",2)
			teleportToFreshSurface(); resetAttempt(false)
			state=autoBombActive and STATE.WAITING_NOTIFICATION or STATE.IDLE
			statusText=autoBombActive and "Waiting for bomb notification" or "Idle"
		end
		local function scheduleRetry(reason)
			attempt=attempt+1
			if attempt>=CONFIG.MAX_RETRY then failAndReturnSurface(reason or "Bomb failed"); return end
			retryAt=os.clock()+CONFIG.RETRY_DELAY
			setState(STATE.RETRY,string.format("Retry %d/%d",attempt,CONFIG.MAX_RETRY))
		end
		local function onNotify(kind,text)
			if not autoBombActive or type(text)~="string" then return end
			local bombId,tier=parseBombRequirement(text)
			if not bombId then return end
			if state==STATE.WAITING_EXPLOSION or state==STATE.EQUIPPING or state==STATE.ACTIVATING then return end
			if os.clock()-notificationClock<0.20 and text==lastNotificationText then return end
			notificationClock=os.clock(); lastNotificationText=text; requiredBombId=bombId; requiredBombTier=tier
			local selected,count=getBestBombForRequirement(tier)
			if not selected then failAndReturnSurface("No "..tostring(bombId).." or higher"); return end
			local mat,pos=getNotificationTarget()
			currentMaterial=mat; currentPosition=pos; currentBomb=selected; attempt=0
			statusText=string.format("Notification -> %s (%d)",selected,count or 0)
			state=STATE.READY
		end
		if RMT.Notify and RMT.Notify:IsA("RemoteEvent") then
			RMT.Notify.OnClientEvent:Connect(function(kind,text) pcall(function() onNotify(kind,text) end) end)
		end
		local function step()
			if not autoBombActive then setState(STATE.IDLE,"Idle"); return end
			local now=os.clock()
			if state==STATE.IDLE then state=STATE.WAITING_NOTIFICATION; statusText="Waiting for bomb notification"; return end
			if state==STATE.RETRY then if now<retryAt then return end; state=STATE.READY end
			if state==STATE.WAITING_NOTIFICATION then statusText="Waiting for bomb notification"; return end
			if state==STATE.READY then
				if not currentBomb or not currentPosition then state=STATE.WAITING_NOTIFICATION; return end
				if getBombCount(currentBomb)<=0 then failAndReturnSurface("Bomb empty"); return end
				state=STATE.ACTIVATING
			end
			if state==STATE.ACTIVATING then
				if not activateBomb(currentBomb,currentPosition) then
					if getBombCount(currentBomb)<=0 then failAndReturnSurface("Bomb unavailable")
					else scheduleRetry("Bomb activation failed") end
				end
				return
			end
			if state==STATE.WAITING_EXPLOSION then
				if now<expectedExplosionAt then statusText=string.format("Bomb active %.1fs",expectedExplosionAt-now); return end
				state=STATE.VERIFYING
			end
			if state==STATE.VERIFYING then
				if verifyExplosion() then
					Runtime.BoulderVeinBlocked=false
					setState(STATE.SUCCESS,"Bomb exploded - pickaxe restored")
					attempt=0
					task.spawn(function()
						equipPickaxeAfterBomb()
						currentBomb=nil; currentMaterial=nil; currentPosition=nil; requiredBombId=nil; requiredBombTier=nil
						state=autoBombActive and STATE.WAITING_NOTIFICATION or STATE.IDLE
						statusText=autoBombActive and "Bomb cleared - digging continues" or "Idle"
					end)
					return
				end
				if now-activationAt>=CONFIG.EXPLOSION_TIMEOUT then scheduleRetry("Explosion not detected"); return end
				statusText="Explosion not verified"
			end
		end
		function AutoBomb.setActive(value)
			autoBombActive=value==true; resetAttempt(false)
			if autoBombActive then state=STATE.WAITING_NOTIFICATION; statusText="Waiting for bomb notification"
			else state=STATE.IDLE; statusText="Idle" end
		end
		AutoBomb._getStatusLabel=function(label) bombStatusLabel=label end
		autoBombConn=S.RunService.Heartbeat:Connect(function(dt)
			if autoBombActive then
				accumulator=accumulator+dt
				if accumulator>=CONFIG.STEP then
					accumulator=0
					local ok,err=pcall(step)
					if not ok then reportError("autoBomb",err); scheduleRetry("Internal error") end
				end
			end
			labelClock=labelClock+dt
			if labelClock>=0.30 then
				labelClock=0
				if bombStatusLabel then bombStatusLabel.Text=statusText end
			end
		end)
	end
	install()
end

-- [34] AUTO UPGRADE
local AutoUpgrade={}
local autoUpgradeConn
do
	local function install()
		local PICKAXE_ORDER={
			"RustyScrapper","WeatheredWood","ChippedStone",
			"HardenedIron","CopperPick","ReinforcedSteel",
			"TitaniumSpike","FrostbitePick","EmeraldCarver",
			"VolcanoBasalt","ObsidianEdge","TempestPick",
			"CelestialApex","AstralRend","EclipseFang",
			"NebularThrone","Voidreign","Singularity","TheTerminus",
		}
		local autoWeight=false; local autoAir=false; local autoPick=false
		local weightTier=LoadedCfg.weightTier or 3
		local airTier=LoadedCfg.airTier or 2
		local upgradeClock=0; local UPGRADE_STEP=4
		local priceCache={}
		local autoBuyBombClock=0; local AUTO_BUY_STEP=0.50; local SHOP_BUY_DELAY=0.05
		local autoBuyRadarClock=0
		local function getCash()
			local data=LocalPlayer:FindFirstChild("PlayerData")
			local stats=data and data:FindFirstChild("RealStats")
			local cash=stats and stats:FindFirstChild("Cash")
			return cash and tonumber(cash.Value) or 0
		end
		local function getOwnedPickaxes()
			local data=LocalPlayer:FindFirstChild("PlayerData")
			local inv=data and data:FindFirstChild("Inventory")
			local picks=inv and inv:FindFirstChild("Pickaxes")
			local owned=picks and picks:FindFirstChild("Owned")
			if not owned then return {} end
			local result={}
			for _,child in ipairs(owned:GetChildren()) do result[child.Name]=true end
			return result
		end
		local function getEquippedPickaxe()
			local data=LocalPlayer:FindFirstChild("PlayerData")
			local inv=data and data:FindFirstChild("Inventory")
			local picks=inv and inv:FindFirstChild("Pickaxes")
			local equip=picks and picks:FindFirstChild("Equipped")
			return equip and equip.Value or nil
		end
		local function fetchPrices(kind)
			if not RMT.UpgradePrices then return priceCache[kind] end
			local ok,result=pcall(function() return RMT.UpgradePrices:InvokeServer(kind) end)
			if ok and type(result)=="table" then priceCache[kind]=result; return result end
			return priceCache[kind]
		end
		local function tryWeightUpgrade()
			if not RMT.UpgradeBuy then return end
			local prices=fetchPrices("Weight"); local price=prices and prices[weightTier]
			if not price then return end
			if getCash()>=price then
				pcall(function() RMT.UpgradeBuy:FireServer("Weight",weightTier) end)
				local amounts={1,5,10}
				Notify(string.format("Weight +%dkg",amounts[weightTier] or weightTier),2)
			end
		end
		local function tryAirUpgrade()
			if not RMT.UpgradeBuy then return end
			local prices=fetchPrices("Air"); local price=prices and prices[airTier]
			if not price then return end
			if getCash()>=price then
				pcall(function() RMT.UpgradeBuy:FireServer("Air",airTier) end)
				local amounts={10,50,100}
				Notify(string.format("Warmth +%d",amounts[airTier] or airTier),2)
			end
		end
		local function tryBuyBestPickaxe()
			if not RMT.ShopBuy or not RMT.ShopEquip then return end
			local owned=getOwnedPickaxes(); local equipped=getEquippedPickaxe(); local cash=getCash()
			local nextBuy
			for i=1,#PICKAXE_ORDER do
				local id=PICKAXE_ORDER[i]; local price=math.huge
				for _,entry in ipairs(PICKAXE_SHOP) do
					if entry.id==id then price=tonumber(entry.cashPrice) or math.huge; break end
				end
				if not owned[id] and cash>=price then nextBuy=id end
			end
			if nextBuy then
				pcall(function() RMT.ShopBuy:FireServer(nextBuy) end); task.wait(0.1)
				owned=getOwnedPickaxes()
			end
			local bestOwned
			for i=#PICKAXE_ORDER,1,-1 do
				local id=PICKAXE_ORDER[i]; if owned[id] then bestOwned=id; break end
			end
			if bestOwned and bestOwned~=equipped then
				pcall(function() RMT.ShopEquip:FireServer(bestOwned) end)
				Notify("Equipped: "..bestOwned,2)
			end
		end
		local function tryBuySelectedPickaxe()
			if not autoPick or selectedPickaxeToBuy=="" then return end
			if not RMT.ShopBuy then return end
			local price=0
			for _,entry in ipairs(PICKAXE_SHOP) do
				if entry.id==selectedPickaxeToBuy then price=entry.cashPrice; break end
			end
			local cash=getCash()
			if cash>=price then
				pcall(function() RMT.ShopBuy:FireServer(selectedPickaxeToBuy) end)
				Notify("Bought: "..(selectedPickaxeToBuy),2)
			end
		end
		local function tryBuySelectedBomb()
			if not autoBuyBombsActive then return end
			if type(selectedBombToBuy) ~= "table" then return end
			local bombBuyRequest=RMT.BombBuyRequest
			if not bombBuyRequest or not bombBuyRequest:IsA("RemoteFunction") then return end
			for _,bombId in ipairs(BOMB_SHOP_ORDER) do
				if selectedBombToBuy[bombId] then
					local cfg=BOMB_CONFIG[bombId]
					if cfg and getCash()>=cfg.cashPrice then
						local ok,result=pcall(function() return bombBuyRequest:InvokeServer(bombId) end)
						if ok and type(result)=="table" and result.ok==true then Notify("Bought: "..cfg.displayName,1.2) end
						task.wait(SHOP_BUY_DELAY)
					end
				end
			end
		end
		local function tryBuySelectedRadar()
			if not autoBuyRadarActive or selectedRadarToBuy=="" then return end
			if not RMT.RadarBuyRequest then return end
			local price=nil
			for _,entry in ipairs(RADAR_SHOP) do
				if entry.id==selectedRadarToBuy then price=tonumber(entry.cashPrice); break end
			end
			if RMT.RadarShopQuery then pcall(function() RMT.RadarShopQuery:InvokeServer() end) end
			if price and price>0 and getCash()<price then return end
			local ok,result=pcall(function() return RMT.RadarBuyRequest:InvokeServer(selectedRadarToBuy,1) end)
			if ok then
				local success=true
				if type(result)=="table" and result.ok~=nil then success=result.ok==true end
				if success then Notify("Bought: "..selectedRadarToBuy,2) end
			end
		end
		local function step(dt)
			upgradeClock=upgradeClock+dt
			if upgradeClock>=UPGRADE_STEP then
				upgradeClock=0
				if autoWeight then pcall(tryWeightUpgrade) end
				if autoAir    then pcall(tryAirUpgrade)    end
				if autoPick   then pcall(tryBuyBestPickaxe) end
			end
			autoBuyBombClock=autoBuyBombClock+dt
			if autoBuyBombClock>=AUTO_BUY_STEP then
				autoBuyBombClock=0
				if autoBuyBombsActive then pcall(tryBuySelectedBomb) end
				if autoBuyRadarActive then pcall(tryBuySelectedRadar) end
			end
		end
		AutoUpgrade.setWeight     = function(v) autoWeight=v end
		AutoUpgrade.setAir        = function(v) autoAir=v    end
		AutoUpgrade.setAutoPick   = function(v) autoPick=v   end
		AutoUpgrade.setWeightTier = function(v) weightTier=math.clamp(math.floor(v),1,3) end
		AutoUpgrade.setAirTier    = function(v) airTier=math.clamp(math.floor(v),1,3)    end
		AutoUpgrade.equipBest     = tryBuyBestPickaxe
		AutoUpgrade.getWeightTier = function() return weightTier end
		AutoUpgrade.getAirTier    = function() return airTier    end
		AutoUpgrade.shutdown      = function() autoWeight=false; autoAir=false; autoPick=false end
		task.spawn(function() task.wait(2); pcall(fetchPrices,"Weight"); pcall(fetchPrices,"Air") end)
		autoUpgradeConn=S.RunService.Heartbeat:Connect(function(dt)
			if autoWeight or autoAir or autoPick or autoBuyBombsActive or autoBuyRadarActive then
				local ok,err=pcall(step,dt)
				if not ok then reportError("autoUpgrade",err) end
			end
		end)
	end
	install()
end

-- [35] CONFIG SAVE
saveConfig = function()
	if isfolder and makefolder then pcall(function() if not isfolder("NXROT") then makefolder("NXROT") end end) end
	LoadedCfg.favoriteMinLuck = tonumber(Runtime.favoriteMinLuck) or 10
	LoadedCfg.PrismariteEsp = Toggles.PrismariteEsp == true
	local filterArr={}; for name in pairs(crystalFilter) do filterArr[#filterArr+1]=name end
	local rarityPickArr={}; for name in pairs(rarityPickupFilter) do rarityPickArr[#rarityPickArr+1]=name end
	local crystalEspArr={}; for name in pairs(crystalEspFilter) do crystalEspArr[#crystalEspArr+1]=name end
	local boulderEspArr={}; for name in pairs(boulderEspFilter) do boulderEspArr[#boulderEspArr+1]=name end
	local veinEspArr={}; for name in pairs(veinEspFilter) do veinEspArr[#veinEspArr+1]=name end
	local farmCrystalArr={}; for name in pairs(farmCrystalFilter) do farmCrystalArr[#farmCrystalArr+1]=name end
	local farmRarityArr={}; for name in pairs(farmRarityFilter) do farmRarityArr[#farmRarityArr+1]=name end
	local config={
		CrystalEsp       = Toggles.CrystalEsp,
		PlayerEsp        = Toggles.PlayerEsp,
		BoulderEsp       = Toggles.BoulderEsp,
		VeinEsp          = Toggles.VeinEsp,
		PrismariteEsp    = Toggles.PrismariteEsp,
		PlayerLines      = Toggles.PlayerLines,
		CrystalLines     = Toggles.CrystalLines,
		BoulderLines     = Toggles.BoulderLines,
		VeinLines        = Toggles.VeinLines,
		AimTeleport      = Toggles.AimTeleport,
		AutoPickup       = Toggles.AutoPickup,
		InstantPrompt    = Toggles.InstantPrompt,
		AutoRunePickup   = Toggles.AutoRunePickup,
		AutoFavoriteItem = Toggles.AutoFavoriteItem,
		AutoDig          = Toggles.AutoDig,
		AutoFarmMoney    = Toggles.AutoFarmMoney,
		AutoFarmBoulders = Toggles.AutoFarmBoulders,
		MoneyAutoSell    = Toggles.MoneyAutoSell,
		AutoWeightUpgrade= Toggles.AutoWeightUpgrade,
		AutoAirUpgrade   = Toggles.AutoAirUpgrade,
		AutoBuyPick      = Toggles.AutoBuyPick,
		AutoBomb         = Toggles.AutoBomb,
		AutoBuyBombs     = Toggles.AutoBuyBombs,
		AutoBuyRadar     = Toggles.AutoBuyRadar,
		SpeedBoost       = Toggles.SpeedBoost,
		Noclip           = Toggles.Noclip,
		InfJump          = Toggles.InfJump,
		Fly              = Toggles.Fly,
		minValue         = minValue,
		boulderMinLuck   = boulderMinLuck,
		favoriteMinLuck  = math.max(0,tonumber(Runtime.favoriteMinLuck) or 10),
		farmMethod       = Runtime.farmMethod,
		espScale         = math.floor(espScale*100),
		playerScale      = math.floor(playerScale*100),
		boulderScale     = math.floor(boulderScale*100),
		playerEspDistance = CFG.PLAYER.distance,
		crystalEspDistance = CFG.ESP.crystalDistance,
		veinEspDistance = CFG.ESP.veinDistance,
		prismariteEspDistance = CFG.ESP.prismariteDistance,
		boulderEspDistance = CFG.ESP.boulderDistance,
		boulderFastDig   = boulderFastDig == true,
		boulderDigSpeed  = math.floor(boulderDigSpeed),
		autoRevive       = Toggles.AutoRevive,
		fpsBoost         = Toggles.FpsBoost,
		ultraFps         = Toggles.UltraFps,
		autoHop          = Toggles.AutoHop,
		autoHopMinutes   = autoHopMinutes,
		weightTier       = AutoUpgrade.getWeightTier(),
		airTier          = AutoUpgrade.getAirTier(),
		crystalFilter    = filterArr,
		rarityPickupFilter = rarityPickArr,
		crystalEspFilter = crystalEspArr,
		boulderEspFilter = boulderEspArr,
		veinEspFilter    = veinEspArr,
		farmCrystalFilter = farmCrystalArr,
		farmRarityFilter = farmRarityArr,
		boulderFarmFilter = (function() local t={}; for name in pairs(Cache.boulderFarmFilter) do t[#t+1]=name end; return t end)(),
		selectedPickaxeToBuy = selectedPickaxeToBuy,
		selectedBombToBuy    = (function() local t={}; for _,id in ipairs(BOMB_SHOP_ORDER) do if selectedBombToBuy[id] then t[#t+1]=id end end; return t end)(),
		selectedRadarToBuy   = selectedRadarToBuy,
		-- Vein farm settings (were missing — caused reset on every rejoin)
		AutoFarmDigVein      = Toggles.AutoFarmDigVein  == true,
		AutoFarmBombVein     = Toggles.AutoFarmBombVein == true,
		digVeinFilter        = (function() local t={}; for k in pairs(Cache.digVeinFilter)  do t[#t+1]=k end; return t end)(),
		bombVeinFilter       = (function() local t={}; for k in pairs(Cache.bombVeinFilter) do t[#t+1]=k end; return t end)(),
		lootRadiusBoulder = lootRadiusBoulder,
        lootRadiusVein    = lootRadiusVein,
	}
	local ok=pcall(function()
		writefile(CONFIG_PATH,S.HttpService:JSONEncode(config))
	end)
	return ok
end

-- [36] HEARTBEAT CONNECTIONS & GLOBAL AUTO SELL
function updateBackpackLabel()
	if not Runtime.BackpackLabel then return end
	local cap=backpackCapacity(); local used=backpackWeight()
	if cap==math.huge then Runtime.BackpackLabel.Text=string.format("%.1f / ∞ KG",used); return end
	Runtime.BackpackLabel.Text=string.format("%.1f / %.1f KG",used,cap)
end

function doSell()
	local now=os.clock()
	if now-Runtime.sellClock<1.5 then return false end
	Runtime.sellClock=now; fireRemote(RMT.GoHome,"sell")
	schedule(0.6,function() fireRemote(RMT.SellRequest,"all") end)
	return true
end

Runtime.autoDigStep = function()
	if not Toggles.AutoDig then return end
	local event=Tools.digEvent(); if not event then return end
	local tool=Tools.equipPick(); if not tool then return end
	local hit=Mouse.Hit
	if not hit then return end
	local point=hit.Position
	pcall(function() event:FireServer(tool.Name,point) end)
end

Runtime.favoriteAccumulator=0
Runtime.favoriteConn=S.RunService.Heartbeat:Connect(function(dt)
	Runtime.favoriteAccumulator=Runtime.favoriteAccumulator+dt
	if Runtime.favoriteAccumulator>=2.0 then
		Runtime.favoriteAccumulator=0
		if Toggles.AutoFavoriteItem == true then pcall(Runtime.autoFavoriteInventoryStep) end
	end
	if Toggles.AutoDig then
		Runtime.autoDigAccumulator=Runtime.autoDigAccumulator+dt
		if Runtime.autoDigAccumulator>=0.03 then
			Runtime.autoDigAccumulator=0
			pcall(Runtime.autoDigStep)
		end
	end
end)

Runtime.crystalEspTick=function(deltaTime)
	if Runtime.statsDirty and Runtime.StatsLabel then
		Runtime.statsDirty=false
		Runtime.StatsLabel.Text=string.format("Tracking: %d  |  Shown: %d",registryCount,espCount)
	end
	if not espActive then return end
	local now=os.clock()
	for inst,expiry in pairs(Cache.candidates) do
		if not inst.Parent then Cache.candidates[inst]=nil
		elseif isCrystal(inst) then Cache.candidates[inst]=nil; trackCrystal(inst)
		elseif now>expiry then Cache.candidates[inst]=nil end
	end
	local deadline=now+(fpsBoostActive and math.min(CFG.ESP.budget,0.0015) or CFG.ESP.budget)
	if next(Cache.dirty)~=nil then
		for inst in pairs(Cache.dirty) do
			local ok,err=pcall(syncCrystal,inst)
			if not ok then Cache.dirty[inst]=nil; reportError("sync",err) end
			if os.clock()>deadline then break end
		end
	end
	Runtime.sweepAccumulator=Runtime.sweepAccumulator+deltaTime
	if Runtime.sweepAccumulator>=(fpsBoostActive and math.max(CFG.ESP.sweep,2.5) or CFG.ESP.sweep) then
		Runtime.sweepAccumulator=0
		local ok,err=pcall(function() watchContainers(); sweep() end)
		if not ok then reportError("sweep",err) end
	end
	Runtime.distanceAccumulator=Runtime.distanceAccumulator+deltaTime
	if Runtime.distanceAccumulator>=(fpsBoostActive and math.max(CFG.PACE.distance,0.25) or CFG.PACE.distance) then
		Runtime.distanceAccumulator=0
		local ok,err=pcall(updateDistances); if not ok then reportError("distance",err) end
	end
end

-- Register-limit fix:
-- Keep the global scheduler connection in Runtime instead of allocating
-- another top-level local register. The previous `local schedulerConn`
-- crossed the executor/Luau local-register limit in this large script.
Runtime.schedulerConn=S.RunService.Heartbeat:Connect(function(deltaTime)
	-- Global Auto Sell Logic (Works all the time, completely independent of Money Farm)
	if Toggles.MoneyAutoSell then
		local bagRatio = 0
		local cap = backpackCapacity()
		if cap ~= math.huge and cap > 0 then bagRatio = backpackWeight() / cap end
		if bagRatio >= 0.5 then
			if os.clock() - Runtime.lastGlobalAutoSell > 10 then -- 10s cooldown fail-safe to prevent spam
				Runtime.lastGlobalAutoSell = os.clock()
				if doSell() then Notify("Auto Selling...", 2) end
			end
		end
	end

	if Runtime.tpState then
		local ok,err=pcall(function()
			if not applyPivot(Runtime.tpState.goal) then finishTeleport(); return end
			if os.clock()>=Runtime.tpState.holdUntil then finishTeleport() end
		end)
		if not ok then finishTeleport(); reportError("teleport",err) end
	end

	-- Aim Teleport uses the existing scheduler instead of creating a dedicated
	-- UserInputService.InputBegan connection. It fires once per F key press.
	local fDown=false
	if aimTpEnabled and not S.UserInputService:GetFocusedTextBox() then
		fDown=S.UserInputService:IsKeyDown(Enum.KeyCode.F)
		if fDown and not Runtime.aimFDown and aimTeleport then
			local ok,err=pcall(aimTeleport)
			if not ok then reportError("aimTeleport",err) end
		end
	end
	Runtime.aimFDown=fDown

	-- All ESP scanners share this one existing Heartbeat. No separate
	-- espConn/veinConn/Prismarite/mountain Heartbeat connections are created.
	if Runtime.crystalEspTick then
		local ok,err=pcall(Runtime.crystalEspTick,deltaTime)
		if not ok then reportError("esp",err) end
	end
	if VeinsModule.tick then
		local ok,err=pcall(VeinsModule.tick,deltaTime)
		if not ok then reportError("veinEsp",err) end
	end
	if PrismariteModule.tick then
		local ok,err=pcall(PrismariteModule.tick,deltaTime)
		if not ok then reportError("prismariteEsp",err) end
	end
	if Mountain.tick then
		local ok,err=pcall(Mountain.tick,deltaTime)
		if not ok then reportError("boulderEsp",err) end
	end

	-- Instant Pickup is global and independent of Money/Boulder Farm.
	if instantPromptActive then
		Runtime.instantAccumulator=Runtime.instantAccumulator+deltaTime
		if Runtime.instantAccumulator>=CFG.PICK.instantTick then
			Runtime.instantAccumulator=0
			local ok,err=pcall(refreshInstantPrompts); if not ok then reportError("instant",err) end
		end
	end
	if speedActive then
		local body=LocalPlayer.Character
		local mover=body and body:FindFirstChildOfClass("Humanoid")
		if mover then watchSpeed(mover); enforceSpeed(mover) end
	end
	if playerEspActive then
		Runtime.ultraPlayerAccumulator=Runtime.ultraPlayerAccumulator+deltaTime
		local playerInterval=fpsBoostActive and 0.15 or 0.05
		if Runtime.ultraPlayerAccumulator>=playerInterval then
			Runtime.ultraPlayerAccumulator=0
			local ok,err=pcall(updatePlayerEsp); if not ok then reportError("playerEsp",err) end
		end
	end
	Runtime.statsAccumulator=Runtime.statsAccumulator+deltaTime
	if fpsBoostActive then
		Runtime.ultraBackpackAccumulator=Runtime.ultraBackpackAccumulator+deltaTime
		if Runtime.ultraBackpackAccumulator>=0.75 then
			Runtime.ultraBackpackAccumulator=0
			local ok,err=pcall(updateBackpackLabel); if not ok then reportError("backpack",err) end
		end
	else
		Runtime.ultraBackpackAccumulator=0
		if Runtime.statsAccumulator>=CFG.PACE.stats then
			Runtime.statsAccumulator=0
			local ok,err=pcall(updateBackpackLabel); if not ok then reportError("backpack",err) end
		end
	end
	-- Config persistence is intentionally handled by this existing global
	-- scheduler. Do NOT create a separate Heartbeat connection for config saves;
	-- repeated script execution would otherwise accumulate ConfigSaveConn
	-- connections until the executor's connection limit is reached.
	Runtime.configSaveClock=Runtime.configSaveClock+deltaTime
	if Runtime.configSaveClock>=30 then
		Runtime.configSaveClock=0
		pcall(saveConfig)
	end

	if #Cache.pendingActions==0 then return end
	local now=os.clock()
	for index=#Cache.pendingActions,1,-1 do
		local job=Cache.pendingActions[index]
		if now>=job.at then
			table.remove(Cache.pendingActions,index)
			local ok,err=pcall(job.fn); if not ok then reportError("action",err) end
		end
	end
end)

-- [37] SORT / TELEPORT ACTIONS
Runtime.aimParams=RaycastParams.new()
Runtime.aimParams.FilterType=Enum.RaycastFilterType.Exclude
Runtime.aimParams.IgnoreWater=true
function sortedByScore(scoreFn)
	local scored={}; local seen={}
	local function consider(inst)
		if seen[inst] or not inst.Parent then return end
		if getAttr(inst,"Collected")==true then return end
		seen[inst]=true
		local ok,score=pcall(scoreFn,inst)
		scored[#scored+1]={inst=inst,score=ok and score or 0}
	end
	for inst in pairs(Cache.registry) do consider(inst) end
	eachContainer(function(c) for _,child in ipairs(c:GetChildren()) do if isCrystal(child) then consider(child) end end end)
	table.sort(scored,function(a,b) return a.score>b.score end)
	return scored
end
function getAimedCrystal()
	local unitRay=Mouse.UnitRay; local origin=unitRay.Origin; local direction=unitRay.Direction.Unit
	local char=LocalPlayer.Character
	Runtime.aimParams.FilterDescendantsInstances=char and {char} or {}
	local hit=S.Workspace:Raycast(origin,direction*CFG.PICK.aimRange,Runtime.aimParams)
	if hit and hit.Instance and (Cache.registry[hit.Instance] or isCrystal(hit.Instance)) then return hit.Instance end
	local best,bestDot; local seen={}
	local function consider(inst)
		if seen[inst] or not inst.Parent then return end; seen[inst]=true
		local offset=(inst.Position+CFG.ESP.offset)-origin; local mag=offset.Magnitude
		if mag>0 then
			local dot=direction:Dot(offset/mag)
			if not bestDot or dot>bestDot then bestDot=dot; best=inst end
		end
	end
	for inst in pairs(Cache.espCache) do consider(inst) end
	eachContainer(function(c) for _,child in ipairs(c:GetChildren()) do if isCrystal(child) then consider(child) end end end)
	if best and bestDot and bestDot>=CFG.PICK.aimDot then return best end
	return nil
end
aimTeleport=function()
	if not espActive then Notify("Enable Crystal ESP first",3); return end
	local inst=getAimedCrystal()
	if not inst then Notify("No crystal aimed",2); return end
	if teleportTo(inst) then Notify(string.format("TP -> %s",crystalName(inst)),2)
	else Notify("Teleport failed",2) end
end
-- Register-limit fix:
-- tpToRank was the next top-level local after schedulerConn and could push
-- this large script over the executor's 200 local-register limit.
-- Store the same function on Runtime instead; behavior is unchanged.
Runtime.tpToRank=function(scoreFn,rank,formatter)
	local entry=sortedByScore(scoreFn)[rank]
	if not entry or entry.score<=0 then Notify(string.format("No crystal #%d",rank),3); return end
	if teleportTo(entry.inst) then
		Notify(string.format("TP #%d %s (%s)",rank,crystalName(entry.inst),formatter(entry.inst,entry.score)),3)
	else Notify("Teleport failed",3) end
end

function UIH_Corner(UI,p,r) local c=Instance.new("UICorner",p); c.CornerRadius=UDim.new(0,r or 6) end

function UIH_Stroke(UI,p,col,th) local s=Instance.new("UIStroke",p); s.Color=col or UI.C.BORDER; s.Thickness=th or 1; return s end

function UIH_MakeDraggable(UI,frame,handle)
		local drag,ds,sp
		handle.InputBegan:Connect(function(inp)
			if inp.UserInputType==Enum.UserInputType.MouseButton1 or inp.UserInputType==Enum.UserInputType.Touch then
				drag=true; ds=inp.Position; sp=frame.Position
				inp.Changed:Connect(function() if inp.UserInputState==Enum.UserInputState.End then drag=false end end)
			end
		end)
		S.UserInputService.InputChanged:Connect(function(inp)
			if drag and (inp.UserInputType==Enum.UserInputType.MouseMovement or inp.UserInputType==Enum.UserInputType.Touch) then
				local d=inp.Position-ds
				frame.Position=UDim2.new(sp.X.Scale,sp.X.Offset+d.X,sp.Y.Scale,sp.Y.Offset+d.Y)
			end
		end)
	end

function UIH_BuatPage(UI,name)
		local Page=Instance.new("ScrollingFrame",UI.ContentArea)
		Page.Name=name; Page.Size=UDim2.new(1,0,1,0); Page.BackgroundTransparency=1
		Page.BorderSizePixel=0; Page.ScrollBarThickness=4; Page.ScrollBarImageColor3=UI.C.DIVIDER; Page.Visible=false
		local Layout=Instance.new("UIListLayout",Page)
		Layout.Padding=UDim.new(0,8); Layout.SortOrder=Enum.SortOrder.LayoutOrder
		local Pad=Instance.new("UIPadding",Page)
		Pad.PaddingTop=UDim.new(0,15); Pad.PaddingBottom=UDim.new(0,15)
		Pad.PaddingLeft=UDim.new(0,15); Pad.PaddingRight=UDim.new(0,15)
		Layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
			Page.CanvasSize=UDim2.new(0,0,0,Layout.AbsoluteContentSize.Y+30)
		end)
		UI.Pages[name]=Page; return Page
	end

function UIH_SwitchTab(UI,targetName)
		for name,page in pairs(UI.Pages) do page.Visible=(name==targetName) end
		for name,btnData in pairs(UI.NavButtons) do
			local isActive=(name==targetName)
			S.TweenService:Create(btnData.Indicator,TweenInfo.new(0.2),{BackgroundTransparency=isActive and 0 or 1}):Play()
			S.TweenService:Create(btnData.Label,TweenInfo.new(0.2),{TextColor3=isActive and UI.C.TEXT_1 or UI.C.TEXT_2}):Play()
			S.TweenService:Create(btnData.Btn,TweenInfo.new(0.2),{BackgroundColor3=isActive and UI.C.ELEVATED or UI.C.SURFACE}):Play()
		end
	end

function UIH_BuatNavButton(UI,name)
		local Btn=Instance.new("TextButton",UI.TabContainer)
		Btn.Size=UDim2.new(1,-16,0,36); Btn.BackgroundColor3=UI.C.SURFACE
		Btn.BorderSizePixel=0; Btn.Text=""; Btn.AutoButtonColor=false; UIH_Corner(UI,Btn,6)
		local Indicator=Instance.new("Frame",Btn)
		Indicator.Size=UDim2.new(0,3,0,18); Indicator.Position=UDim2.new(0,0,0.5,-9)
		Indicator.BackgroundColor3=UI.C.ACCENT; Indicator.BorderSizePixel=0; Indicator.BackgroundTransparency=1; UIH_Corner(UI,Indicator,2)
		local Label=Instance.new("TextLabel",Btn)
		Label.Size=UDim2.new(1,-16,1,0); Label.Position=UDim2.new(0,12,0,0)
		Label.BackgroundTransparency=1; Label.Text=name; Label.TextColor3=UI.C.TEXT_2
		Label.Font=Enum.Font.GothamMedium; Label.TextSize=12; Label.TextXAlignment=Enum.TextXAlignment.Left
		Btn.MouseButton1Click:Connect(function() UIH_SwitchTab(UI,name) end)
		UI.NavButtons[name]={Btn=Btn,Indicator=Indicator,Label=Label}
	end

function UIH_BuatSection(UI,parent,text)
		local Lbl=Instance.new("TextLabel",parent)
		Lbl.Size=UDim2.new(1,0,0,20); Lbl.BackgroundTransparency=1
		Lbl.Font=Enum.Font.GothamBold; Lbl.TextColor3=UI.C.TEXT_2
		Lbl.Text=text:upper(); Lbl.TextSize=11; Lbl.TextXAlignment=Enum.TextXAlignment.Left
	end

function UIH_BuatLabel(UI,parent,defaultText)
		local Row=Instance.new("Frame",parent)
		Row.Size=UDim2.new(1,0,0,30); Row.BackgroundColor3=UI.C.SURFACE; UIH_Corner(UI,Row,6)
		local LabelTxt=Instance.new("TextLabel",Row)
		LabelTxt.Size=UDim2.new(1,-20,1,0); LabelTxt.Position=UDim2.new(0,14,0,0)
		LabelTxt.BackgroundTransparency=1; LabelTxt.Text=defaultText
		LabelTxt.TextColor3=UI.C.TEXT_1; LabelTxt.Font=Enum.Font.GothamMedium
		LabelTxt.TextSize=12; LabelTxt.TextXAlignment=Enum.TextXAlignment.Left
		return LabelTxt
	end

function UIH_BuatToggle(UI,parent,label,sublabel,defaultState,accentColor)
	local Row=Instance.new("Frame",parent)
	Row.Size=UDim2.new(1,0,0,42); Row.BackgroundColor3=UI.C.SURFACE; UIH_Corner(UI,Row,6)
	local RowStroke=UIH_Stroke(UI,Row,UI.C.BORDER)
	local LeftAccent=Instance.new("Frame",Row)
	LeftAccent.Size=UDim2.new(0,2,0,18); LeftAccent.Position=UDim2.new(0,0,0.5,-9)
	LeftAccent.BackgroundColor3=UI.C.BORDER; UIH_Corner(UI,LeftAccent,1)
	local LabelTxt=Instance.new("TextLabel",Row)
	LabelTxt.Size=UDim2.new(1,-70,1,0); LabelTxt.Position=UDim2.new(0,14,0,0)
	LabelTxt.BackgroundTransparency=1; LabelTxt.Text=label
	LabelTxt.TextColor3=UI.C.TEXT_2; LabelTxt.Font=Enum.Font.GothamMedium; LabelTxt.TextSize=12; LabelTxt.TextXAlignment=Enum.TextXAlignment.Left
	local Pill=Instance.new("Frame",Row)
	Pill.Size=UDim2.new(0,38,0,20); Pill.Position=UDim2.new(1,-50,0.5,-10); Pill.BackgroundColor3=UI.C.DIVIDER; UIH_Corner(UI,Pill,10)
	local PillDot=Instance.new("Frame",Pill)
	PillDot.Size=UDim2.new(0,14,0,14); PillDot.Position=UDim2.new(0,3,0.5,-7); PillDot.BackgroundColor3=UI.C.TEXT_3; UIH_Corner(UI,PillDot,7)
	local Btn=Instance.new("TextButton",Row)
	Btn.Size=UDim2.new(1,0,1,0); Btn.BackgroundTransparency=1; Btn.Text=""
	local accent=accentColor or UI.C.ACCENT
	local accentD=accentColor and accentColor:lerp(Color3.new(0,0,0),0.25) or UI.C.ACCENT_D
	local function SetInstant(on)
		Row.BackgroundColor3=on and UI.C.ELEVATED or UI.C.SURFACE
		RowStroke.Color=on and accentD or UI.C.BORDER
		LabelTxt.TextColor3=on and UI.C.TEXT_1 or UI.C.TEXT_2
		LeftAccent.BackgroundColor3=on and accent or UI.C.BORDER
		Pill.BackgroundColor3=on and accentD or UI.C.DIVIDER
		PillDot.Position=on and UDim2.new(1,-17,0.5,-7) or UDim2.new(0,3,0.5,-7)
		PillDot.BackgroundColor3=on and accent or UI.C.TEXT_3
	end
	local function SetTween(on)
		S.TweenService:Create(Row,TweenInfo.new(0.2),{BackgroundColor3=on and UI.C.ELEVATED or UI.C.SURFACE}):Play()
		RowStroke.Color=on and accentD or UI.C.BORDER
		LabelTxt.TextColor3=on and UI.C.TEXT_1 or UI.C.TEXT_2
		LeftAccent.BackgroundColor3=on and accent or UI.C.BORDER
		S.TweenService:Create(Pill,TweenInfo.new(0.2),{BackgroundColor3=on and accentD or UI.C.DIVIDER}):Play()
		S.TweenService:Create(PillDot,TweenInfo.new(0.2),{
			Position=on and UDim2.new(1,-17,0.5,-7) or UDim2.new(0,3,0.5,-7),
			BackgroundColor3=on and accent or UI.C.TEXT_3,
		}):Play()
	end
	SetInstant(defaultState==true)
	return Btn,SetTween
end

function UIH_BuatButton(UI,parent,label,sublabel,bgColor)
	local Row=Instance.new("TextButton",parent)
	Row.Size=UDim2.new(1,0,0,36); Row.BackgroundColor3=bgColor or UI.C.SURFACE
	Row.Text=""; Row.AutoButtonColor=false; UIH_Corner(UI,Row,6); UIH_Stroke(UI,Row,UI.C.BORDER)
	local LeftAccent=Instance.new("Frame",Row)
	LeftAccent.Size=UDim2.new(0,2,0,18); LeftAccent.Position=UDim2.new(0,0,0.5,-9)
	LeftAccent.BackgroundColor3=UI.C.BORDER; UIH_Corner(UI,LeftAccent,1)
	local LabelTxt=Instance.new("TextLabel",Row)
	LabelTxt.Size=UDim2.new(1,-20,1,0); LabelTxt.Position=UDim2.new(0,14,0,0)
	LabelTxt.BackgroundTransparency=1; LabelTxt.Text=label
	LabelTxt.TextColor3=UI.C.TEXT_1; LabelTxt.Font=Enum.Font.GothamMedium; LabelTxt.TextSize=12; LabelTxt.TextXAlignment=Enum.TextXAlignment.Left
	return Row
end

function UIH_BuatSlider(UI,parent,label,min,max,default,callback)
		local Row=Instance.new("Frame",parent)
		Row.Size=UDim2.new(1,0,0,50); Row.BackgroundColor3=UI.C.SURFACE; UIH_Corner(UI,Row,6); UIH_Stroke(UI,Row,UI.C.BORDER)
		local LabelTxt=Instance.new("TextLabel",Row)
		LabelTxt.Size=UDim2.new(0.7,0,0,20); LabelTxt.Position=UDim2.new(0,14,0,5)
		LabelTxt.BackgroundTransparency=1; LabelTxt.Text=label..": "..tostring(default)
		LabelTxt.TextColor3=UI.C.TEXT_1; LabelTxt.Font=Enum.Font.GothamMedium; LabelTxt.TextSize=11; LabelTxt.TextXAlignment=Enum.TextXAlignment.Left
		local Track=Instance.new("Frame",Row)
		Track.Size=UDim2.new(1,-28,0,4); Track.Position=UDim2.new(0,14,1,-12); Track.BackgroundColor3=UI.C.DIVIDER; UIH_Corner(UI,Track,2)
		local Progress=Instance.new("Frame",Track); Progress.Size=UDim2.new(0,0,1,0); Progress.BackgroundColor3=UI.C.ACCENT; UIH_Corner(UI,Progress,2)
		local Thumb=Instance.new("Frame",Track)
		Thumb.Size=UDim2.new(0,12,0,12); Thumb.Position=UDim2.new(0,-6,0.5,-6); Thumb.BackgroundColor3=UI.C.TEXT_1; UIH_Corner(UI,Thumb,6)
		local Dragger=Instance.new("TextButton",Track)
		Dragger.Size=UDim2.new(1,0,3,0); Dragger.Position=UDim2.new(0,0,-1,0); Dragger.BackgroundTransparency=1; Dragger.Text=""
		local function UpdateSlider(value)
			local pct=math.clamp((value-min)/(max-min),0,1)
			Progress.Size=UDim2.new(pct,0,1,0); Thumb.Position=UDim2.new(pct,-6,0.5,-6)
			LabelTxt.Text=label..": "..string.format("%d",value); callback(math.floor(value))
		end
		UpdateSlider(default)
		local dragging=false
		Dragger.InputBegan:Connect(function(i)
			if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then dragging=true end
		end)
		Dragger.InputEnded:Connect(function(i)
			if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then dragging=false end
		end)
		S.UserInputService.InputChanged:Connect(function(i)
			if dragging and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then
				local relX=i.Position.X-Track.AbsolutePosition.X
				local pct=math.clamp(relX/Track.AbsoluteSize.X,0,1)
				UpdateSlider(min+(max-min)*pct)
			end
		end)
		return Row
	end

function UIH_BuatInput(UI,parent,label,placeholder,default,callback)
		local Row=Instance.new("Frame",parent)
		Row.Size=UDim2.new(1,0,0,42); Row.BackgroundColor3=UI.C.SURFACE; UIH_Corner(UI,Row,6); UIH_Stroke(UI,Row,UI.C.BORDER)
		local LabelTxt=Instance.new("TextLabel",Row)
		LabelTxt.Size=UDim2.new(0.5,-20,1,0); LabelTxt.Position=UDim2.new(0,14,0,0)
		LabelTxt.BackgroundTransparency=1; LabelTxt.Text=label
		LabelTxt.TextColor3=UI.C.TEXT_1; LabelTxt.Font=Enum.Font.GothamMedium; LabelTxt.TextSize=12; LabelTxt.TextXAlignment=Enum.TextXAlignment.Left
		local InputBox=Instance.new("TextBox",Row)
		InputBox.Size=UDim2.new(0.4,0,0,24); InputBox.Position=UDim2.new(0.6,-14,0.5,-12)
		InputBox.BackgroundColor3=UI.C.ELEVATED; UIH_Corner(UI,InputBox,4); UIH_Stroke(UI,InputBox,UI.C.DIVIDER)
		InputBox.Text=default or ""; InputBox.PlaceholderText=placeholder or ""
		InputBox.TextColor3=UI.C.TEXT_1; InputBox.Font=Enum.Font.Gotham; InputBox.TextSize=11
		InputBox.FocusLost:Connect(function() callback(InputBox.Text) end)
		return Row
	end

function UIH_BuatDropdown(UI,parent, label, options, isMulti, defaultSelected, callback)
		local selected = isMulti and {} or ""
		if isMulti and type(defaultSelected)=="table" then
			for _,v in ipairs(defaultSelected) do
				if type(v)=="string" and v~="Default" and v~="" then selected[v]=true end
			end
		elseif not isMulti and type(defaultSelected)=="string" then
			selected=(defaultSelected=="Default") and "" or defaultSelected
		end
		local function displayText()
			if isMulti then
				local keys={}; for k in pairs(selected) do keys[#keys+1]=k end
				if #keys==0 then return "[Default]" end
				table.sort(keys)
				if #keys==1 then return keys[1] end
				return keys[1].." +"..tostring(#keys-1)
			else
				return selected=="" and "[Default]" or selected
			end
		end
		local Row=Instance.new("Frame",parent)
		Row.Size=UDim2.new(1,0,0,42); Row.BackgroundColor3=UI.C.SURFACE; UIH_Corner(UI,Row,6); UIH_Stroke(UI,Row,UI.C.BORDER)
		local LabelTxt=Instance.new("TextLabel",Row)
		LabelTxt.Size=UDim2.new(0.42,0,1,0); LabelTxt.Position=UDim2.new(0,14,0,0)
		LabelTxt.BackgroundTransparency=1; LabelTxt.Text=label
		LabelTxt.TextColor3=UI.C.TEXT_2; LabelTxt.Font=Enum.Font.GothamMedium; LabelTxt.TextSize=11; LabelTxt.TextXAlignment=Enum.TextXAlignment.Left
		local DropBtn=Instance.new("TextButton",Row)
		DropBtn.Size=UDim2.new(0.55,0,0,28); DropBtn.Position=UDim2.new(0.44,0,0.5,-14)
		DropBtn.BackgroundColor3=UI.C.ELEVATED; UIH_Corner(UI,DropBtn,4); UIH_Stroke(UI,DropBtn,UI.C.DIVIDER)
		DropBtn.Text=displayText(); DropBtn.TextColor3=UI.C.TEXT_1
		DropBtn.Font=Enum.Font.GothamMedium; DropBtn.TextSize=11
		DropBtn.AutoButtonColor=false
		local Panel=Instance.new("Frame",UI.MainSG)
		Panel.Size=UDim2.new(0,220,0,math.min(#options*28+8,180))
		Panel.BackgroundColor3=UI.C.ELEVATED; UIH_Corner(UI,Panel,6); UIH_Stroke(UI,Panel,UI.C.BORDER)
		Panel.Visible=false; Panel.ZIndex=20
		local PanelScroll=Instance.new("ScrollingFrame",Panel)
		PanelScroll.Size=UDim2.new(1,-4,1,-4); PanelScroll.Position=UDim2.new(0,2,0,2)
		PanelScroll.BackgroundTransparency=1; PanelScroll.BorderSizePixel=0
		PanelScroll.ScrollBarThickness=3; PanelScroll.ZIndex=20
		local PanelLayout=Instance.new("UIListLayout",PanelScroll)
		PanelLayout.Padding=UDim.new(0,2); PanelLayout.SortOrder=Enum.SortOrder.LayoutOrder
		PanelLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
			PanelScroll.CanvasSize=UDim2.new(0,0,0,PanelLayout.AbsoluteContentSize.Y+6)
		end)
		local function rebuildOptions(optList)
			for _,ch in ipairs(PanelScroll:GetChildren()) do
				if ch:IsA("TextButton") then ch:Destroy() end
			end
			local clearBtn=Instance.new("TextButton",PanelScroll)
			clearBtn.Size=UDim2.new(1,0,0,26); clearBtn.BackgroundTransparency=1
			clearBtn.Text="[Default]"; clearBtn.TextColor3=UI.C.TEXT_3
			clearBtn.Font=Enum.Font.GothamMedium; clearBtn.TextSize=11; clearBtn.ZIndex=21
			clearBtn.MouseButton1Click:Connect(function()
				if isMulti then table.clear(selected) else selected="" end
				DropBtn.Text=displayText()
				Panel.Visible=false; UI.activeDropdown=nil
				callback(isMulti and {} or "")
			end)
			for _,opt in ipairs(optList) do
				local isOn=isMulti and selected[opt]==true or selected==opt
				local OBtn=Instance.new("TextButton",PanelScroll)
				OBtn.Size=UDim2.new(1,0,0,26); OBtn.BackgroundColor3=isOn and UI.C.ACCENT_D or UI.C.ELEVATED
				OBtn.BorderSizePixel=0; UIH_Corner(UI,OBtn,4)
				OBtn.Text=opt; OBtn.TextColor3=isOn and UI.C.TEXT_1 or UI.C.TEXT_2
				OBtn.Font=Enum.Font.GothamMedium; OBtn.TextSize=11; OBtn.ZIndex=21
				OBtn.MouseButton1Click:Connect(function()
					if isMulti then
						if opt=="Default" then
							table.clear(selected)
						else
							if selected[opt] then selected[opt]=nil else selected[opt]=true end
						end
						selected.Default=nil
						for _,child in ipairs(PanelScroll:GetChildren()) do
							if child:IsA("TextButton") and child~=clearBtn then
								local on=selected[child.Text]==true
								child.BackgroundColor3=on and UI.C.ACCENT_D or UI.C.ELEVATED
								child.TextColor3=on and UI.C.TEXT_1 or UI.C.TEXT_2
							end
						end
					else
						selected=(opt=="Default") and "" or opt
						Panel.Visible=false; UI.activeDropdown=nil
					end
					DropBtn.Text=displayText()
					local result
					if isMulti then
						result={}; for k in pairs(selected) do if k~="Default" then result[#result+1]=k end end
					else result=selected end
					callback(result)
				end)
			end
		end
		rebuildOptions(options)
		DropBtn.MouseButton1Click:Connect(function()
			if Panel.Visible then
				Panel.Visible=false; UI.activeDropdown=nil; return
			end
			if UI.activeDropdown and UI.activeDropdown~=Panel then UI.activeDropdown.Visible=false end
			local absPos=DropBtn.AbsolutePosition
			local absSize=DropBtn.AbsoluteSize
			Panel.Position=UDim2.fromOffset(absPos.X,absPos.Y+absSize.Y+4)
			Panel.Visible=true; UI.activeDropdown=Panel
		end)
		local function GetSelected() return isMulti and selected or selected end
		local function SetOptions(newOpts)
			rebuildOptions(newOpts)
			Panel.Size=UDim2.new(0,220,0,math.min(#newOpts*28+8+28,180))
		end
		local function SetSelected(val)
			if isMulti and type(val)=="table" then
				table.clear(selected)
				for _,v in ipairs(val) do selected[v]=true end
			elseif not isMulti and type(val)=="string" then
				selected=val
			end
			DropBtn.Text=displayText()
		end
		return Row, GetSelected, SetOptions, SetSelected
	end

function UIH_BuatStepSelect(UI,parent, label, default, callback)
		local Row=Instance.new("Frame",parent)
		Row.Size=UDim2.new(1,0,0,42); Row.BackgroundColor3=UI.C.SURFACE; UIH_Corner(UI,Row,6); UIH_Stroke(UI,Row,UI.C.BORDER)
		local LabelTxt=Instance.new("TextLabel",Row)
		LabelTxt.Size=UDim2.new(0.55,0,1,0); LabelTxt.Position=UDim2.new(0,14,0,0)
		LabelTxt.BackgroundTransparency=1; LabelTxt.Text=label
		LabelTxt.TextColor3=UI.C.TEXT_2; LabelTxt.Font=Enum.Font.GothamMedium; LabelTxt.TextSize=12; LabelTxt.TextXAlignment=Enum.TextXAlignment.Left
		local BtnHolder=Instance.new("Frame",Row)
		BtnHolder.Size=UDim2.new(0,96,0,28); BtnHolder.Position=UDim2.new(1,-110,0.5,-14)
		BtnHolder.BackgroundTransparency=1
		local BHL=Instance.new("UIListLayout",BtnHolder)
		BHL.FillDirection=Enum.FillDirection.Horizontal; BHL.Padding=UDim.new(0,4)
		local current=default or 1
		local btns={}
		local function refreshBtns()
			for i,btn in ipairs(btns) do
				btn.BackgroundColor3=i==current and UI.C.ACCENT or UI.C.ELEVATED
				btn.TextColor3=i==current and UI.C.TEXT_1 or UI.C.TEXT_2
			end
		end
		for i=1,3 do
			local B=Instance.new("TextButton",BtnHolder)
			B.Size=UDim2.new(0,28,1,0); B.BackgroundColor3=i==current and UI.C.ACCENT or UI.C.ELEVATED
			UIH_Corner(UI,B,4); B.Text=tostring(i); B.TextColor3=i==current and UI.C.TEXT_1 or UI.C.TEXT_2
			B.Font=Enum.Font.GothamBold; B.TextSize=12; B.AutoButtonColor=false
			B.MouseButton1Click:Connect(function()
				current=i; refreshBtns(); callback(i)
			end)
			btns[i]=B
		end
		return Row
	end

function UIH_BuatShopDropdown(UI,parent, label, items, defaultId, callback)
		local options={}
		local idByDisplay={}
		for _,item in ipairs(items) do
			local display=item.displayName.."  ["..formatShort(item.cashPrice,"$").."]"
			options[#options+1]=display
			idByDisplay[display]=item.id
		end
		local selectedDisplay=""
		local displayById={}
		for _,item in ipairs(items) do
			displayById[item.id]=item.displayName.."  ["..formatShort(item.cashPrice,"$").."]"
		end
		if defaultId and defaultId~="" and displayById[defaultId] then
			selectedDisplay=displayById[defaultId]
		end
		local row, getter, setOptions, setter = UIH_BuatDropdown(UI,parent, label, options, false, selectedDisplay, function(val)
			local id=idByDisplay[val] or ""
			callback(id)
		end)
		if selectedDisplay~="" then setter(selectedDisplay) end
		return row
	end

UIHelpers={
	Corner=UIH_Corner,
	Stroke=UIH_Stroke,
	MakeDraggable=UIH_MakeDraggable,
	BuatPage=UIH_BuatPage,
	SwitchTab=UIH_SwitchTab,
	BuatNavButton=UIH_BuatNavButton,
	BuatSection=UIH_BuatSection,
	BuatLabel=UIH_BuatLabel,
	BuatToggle=UIH_BuatToggle,
	BuatButton=UIH_BuatButton,
	BuatSlider=UIH_BuatSlider,
	BuatInput=UIH_BuatInput,
	BuatDropdown=UIH_BuatDropdown,
	BuatStepSelect=UIH_BuatStepSelect,
	BuatShopDropdown=UIH_BuatShopDropdown,
}



function InitializeUI()
	local C={
		BASE    =Color3.fromRGB(13,  8,  32),
		SURFACE =Color3.fromRGB(22, 14,  46),
		ELEVATED=Color3.fromRGB(33, 22,  66),
		BORDER  =Color3.fromRGB(74, 45, 128),
		DIVIDER =Color3.fromRGB(30, 18,  58),
		TEXT_1  =Color3.fromRGB(237,232,255),
		TEXT_2  =Color3.fromRGB(184,159,232),
		TEXT_3  =Color3.fromRGB(112, 85,168),
		ACCENT  =Color3.fromRGB(0, 170, 255),
		ACCENT_D=Color3.fromRGB(0, 105, 190),
		DANGER  =Color3.fromRGB(196, 94,138),
		SHOP    =Color3.fromRGB(60,180,120),
		BOMB    =Color3.fromRGB(220,120, 40),
	}
	local MainSG=Instance.new("ScreenGui",GuiRoot)
	MainSG.Name="DScriptsPF"; MainSG.ResetOnSpawn=false
	local UI={C=C,MainSG=MainSG}
	local H=UIHelpers
	local Root=Instance.new("Frame",MainSG)
	Root.Size=UDim2.new(0,520,0,400); Root.Position=UDim2.new(0.5,-260,0.5,-200); Root.BackgroundTransparency=1
	local MinimizedIcon=Instance.new("TextButton",Root)
MinimizedIcon.Size=UDim2.new(1,0,1,0)
MinimizedIcon.BackgroundColor3=C.SURFACE
MinimizedIcon.BorderSizePixel=0
MinimizedIcon.Text="▯"
MinimizedIcon.TextColor3=C.ACCENT
MinimizedIcon.Font=Enum.Font.GothamBold
MinimizedIcon.TextSize=32
MinimizedIcon.Visible=false
MinimizedIcon.AutoButtonColor=false
H.Corner(UI,MinimizedIcon,10)
H.Stroke(UI,MinimizedIcon,C.BORDER,1)
H.MakeDraggable(UI,Root,MinimizedIcon)
	local Win=Instance.new("Frame",Root)
	Win.Size=UDim2.new(1,0,1,0); Win.BackgroundColor3=C.BASE; Win.ClipsDescendants=true; H.Corner(UI,Win,8); H.Stroke(UI,Win,C.BORDER,1)
	local Header=Instance.new("Frame",Win)
	Header.Size=UDim2.new(1,0,0,45); Header.BackgroundColor3=C.SURFACE; H.Corner(UI,Header,8)
	local HFix=Instance.new("Frame",Header)
	HFix.Size=UDim2.new(1,0,0,8); HFix.Position=UDim2.new(0,0,1,-8); HFix.BackgroundColor3=C.SURFACE; HFix.BorderSizePixel=0
	local AccentLine=Instance.new("Frame",Header)
	AccentLine.Size=UDim2.new(0,40,0,3); AccentLine.Position=UDim2.new(0,16,0,0)
	AccentLine.BackgroundColor3=C.ACCENT; AccentLine.BorderSizePixel=0; H.Corner(UI,AccentLine,2)
	local HeaderIcon=Instance.new("ImageLabel",Header)
	HeaderIcon.Size=UDim2.new(0,30,0,30); HeaderIcon.Position=UDim2.new(0,8,0.5,-15)
	HeaderIcon.BackgroundTransparency=1; HeaderIcon.Image="rbxassetid://90635907660208"
	H.Corner(UI,HeaderIcon,8)
	local TitleLbl=Instance.new("TextLabel",Header)
	TitleLbl.Size=UDim2.new(1,-132,1,0); TitleLbl.Position=UDim2.new(0,46,0,0)
	TitleLbl.BackgroundTransparency=1; TitleLbl.RichText=true
	TitleLbl.Text="NXROT: <font color='#EB3C3C'>MINE A MOUNTAIN</font> <font color='#888'>NXROT</font>"
	TitleLbl.TextColor3=C.TEXT_1; TitleLbl.Font=Enum.Font.GothamBold; TitleLbl.TextSize=14; TitleLbl.TextXAlignment=Enum.TextXAlignment.Left
	H.MakeDraggable(UI,Root,Header)
	local originalSize=Root.Size; local minimizedSize=UDim2.new(0,52,0,52)
	local MinBtn=Instance.new("TextButton",Header)
	MinBtn.Size=UDim2.new(0,24,0,24); MinBtn.Position=UDim2.new(1,-34,0.5,-12)
	MinBtn.BackgroundColor3=C.SURFACE; MinBtn.BorderSizePixel=0; MinBtn.Text="—"
	MinBtn.TextColor3=C.TEXT_2; MinBtn.Font=Enum.Font.GothamBold; MinBtn.TextSize=14
	MinBtn.AutoButtonColor=false; H.Corner(UI,MinBtn,4)
	MinBtn.MouseButton1Click:Connect(function()
		Win.Visible=false; MinimizedIcon.Visible=true
		S.TweenService:Create(Root,TweenInfo.new(0.2),{Size=minimizedSize}):Play()
	end)
	MinimizedIcon.MouseButton1Click:Connect(function()
		Win.Visible=true; MinimizedIcon.Visible=false
		S.TweenService:Create(Root,TweenInfo.new(0.2),{Size=originalSize}):Play()
	end)
	local Body=Instance.new("Frame",Win)
	Body.Size=UDim2.new(1,0,1,-45); Body.Position=UDim2.new(0,0,0,45); Body.BackgroundTransparency=1
	local Sidebar=Instance.new("Frame",Body)
	Sidebar.Size=UDim2.new(0,140,1,0); Sidebar.BackgroundColor3=C.SURFACE; Sidebar.BorderSizePixel=0
	local SidebarStroke=Instance.new("Frame",Sidebar)
	SidebarStroke.Size=UDim2.new(0,1,1,0); SidebarStroke.Position=UDim2.new(1,0,0,0)
	SidebarStroke.BackgroundColor3=C.DIVIDER; SidebarStroke.BorderSizePixel=0
	local TabContainer=Instance.new("ScrollingFrame",Sidebar)
	TabContainer.Size=UDim2.new(1,0,1,-65); TabContainer.BackgroundTransparency=1
	TabContainer.BorderSizePixel=0; TabContainer.ScrollBarThickness=2
	local TabLayout=Instance.new("UIListLayout",TabContainer)
	TabLayout.Padding=UDim.new(0,5); TabLayout.HorizontalAlignment=Enum.HorizontalAlignment.Center
	Instance.new("UIPadding",TabContainer).PaddingTop=UDim.new(0,10)
	TabLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		TabContainer.CanvasSize=UDim2.new(0,0,0,TabLayout.AbsoluteContentSize.Y+20)
	end)
	local ProfileContainer=Instance.new("Frame",Sidebar)
	ProfileContainer.Size=UDim2.new(1,0,0,65); ProfileContainer.Position=UDim2.new(0,0,1,-65)
	ProfileContainer.BackgroundColor3=C.BASE; ProfileContainer.BorderSizePixel=0
	local AvatarImg=Instance.new("ImageLabel",ProfileContainer)
	AvatarImg.Size=UDim2.new(0,36,0,36); AvatarImg.Position=UDim2.new(0,12,0.5,-18)
	AvatarImg.BackgroundColor3=C.SURFACE; AvatarImg.BorderSizePixel=0; H.Corner(UI,AvatarImg,18)
	task.spawn(function()
		pcall(function()
			AvatarImg.Image=S.Players:GetUserThumbnailAsync(LocalPlayer.UserId,Enum.ThumbnailType.HeadShot,Enum.ThumbnailSize.Size420x420)
		end)
	end)
	local NameLbl=Instance.new("TextLabel",ProfileContainer)
	NameLbl.Size=UDim2.new(1,-60,0,16); NameLbl.Position=UDim2.new(0,56,0.5,-16)
	NameLbl.BackgroundTransparency=1; NameLbl.Text=LocalPlayer.DisplayName
	NameLbl.TextColor3=C.TEXT_1; NameLbl.Font=Enum.Font.GothamBold; NameLbl.TextSize=11; NameLbl.TextXAlignment=Enum.TextXAlignment.Left
	local StatusLbl=Instance.new("TextLabel",ProfileContainer)
	StatusLbl.Size=UDim2.new(1,-60,0,14); StatusLbl.Position=UDim2.new(0,56,0.5,2)
	StatusLbl.BackgroundTransparency=1; StatusLbl.Text=DEV_MODE and "DEV MODE" or "Licensed"
	StatusLbl.TextColor3=C.ACCENT; StatusLbl.Font=Enum.Font.GothamMedium; StatusLbl.TextSize=10; StatusLbl.TextXAlignment=Enum.TextXAlignment.Left
	local ContentArea=Instance.new("Frame",Body)
	ContentArea.Size=UDim2.new(1,-155,1,0); ContentArea.Position=UDim2.new(0,155,0,0); ContentArea.BackgroundTransparency=1
	local Pages,NavButtons={},{}
	UI.ContentArea=ContentArea; UI.TabContainer=TabContainer
	UI.Pages=Pages; UI.NavButtons=NavButtons
	UI.BuatPage=H.BuatPage; UI.BuatNavButton=H.BuatNavButton
	UI.BuatSection=H.BuatSection; UI.BuatLabel=H.BuatLabel
	UI.BuatToggle=H.BuatToggle; UI.BuatButton=H.BuatButton
	UI.BuatSlider=H.BuatSlider; UI.BuatInput=H.BuatInput
	UI.BuatDropdown=H.BuatDropdown; UI.BuatStepSelect=H.BuatStepSelect
	UI.BuatShopDropdown=H.BuatShopDropdown
	UI.activeDropdown=nil
	S.UserInputService.InputBegan:Connect(function(input)
		if not UI.activeDropdown or not UI.activeDropdown.Visible then return end
		if input.UserInputType~=Enum.UserInputType.MouseButton1 and input.UserInputType~=Enum.UserInputType.Touch then return end
		local p=input.Position
		local pos=UI.activeDropdown.AbsolutePosition; local size=UI.activeDropdown.AbsoluteSize
		if p.X>=pos.X and p.X<=pos.X+size.X and p.Y>=pos.Y and p.Y<=pos.Y+size.Y then return end
		UI.activeDropdown.Visible=false; UI.activeDropdown=nil
	end)

	-- ============================================================
	-- TABS
	-- ============================================================
local PageNames={"Farming","Shop","ESP","Teleport","Misc","Dupe"}
	for _,name in ipairs(PageNames) do H.BuatNavButton(UI,name); H.BuatPage(UI,name) end

	BuildTabsUI(UI)

	-- Initialization
	H.SwitchTab(UI,"Farming")
	Win.Visible=true
end


function BuildFarmingTab(UI,P_FAR)
	UI.BuatSection(UI,P_FAR,"Farm Money")
	UI.BuatInput(UI,P_FAR,"Minimum Crystal Value","Example: 1M / 1B / 1T",formatShort(minValue,"$"),function(text)
		local v=parseValue(text)
		minValue=math.max(0,tonumber(v) or 0)
		valueFilter=minValue>0
		pcall(refreshCrystalVisibility)
		requestRefresh()
		saveConfig()
	end)

	-- Money Farm crystal directory:
	-- only crystals currently detected at/above the minimum are listed,
	-- sorted from highest value to lowest value.
	local farmCrystalDisplayToName={}
	local farmCrystalRow,farmCrystalGetter,farmCrystalSetOptions,farmCrystalSetSelected =
		UI.BuatDropdown(UI,P_FAR,"Crystal To Farm",{},true,{},function(selectedDisplays)
			table.clear(farmCrystalFilter)
			for _,display in ipairs(selectedDisplays) do
				local rawName=farmCrystalDisplayToName[display] or display
				if rawName and rawName~="" then farmCrystalFilter[rawName]=true end
			end
			saveConfig()
		end)

	local function refreshMoneyCrystalDropdown()
		local ok,entries=pcall(Money.scanEligibleCrystals)
		if not ok or type(entries)~="table" then
			farmCrystalSetOptions({})
			return
		end
		local options={}
		farmCrystalDisplayToName={}
		local displayByName={}
		for _,entry in ipairs(entries) do
			local display=string.format("%s  •  %s  •  %s",
				entry.name,entry.rarity,formatShort(entry.value,"$"))
			options[#options+1]=display
			farmCrystalDisplayToName[display]=entry.name
			displayByName[entry.name]=display
		end
		farmCrystalSetOptions(options)
		local selectedDisplays={}
		for name in pairs(farmCrystalFilter) do
			if displayByName[name] then selectedDisplays[#selectedDisplays+1]=displayByName[name] end
		end
		farmCrystalSetSelected(selectedDisplays)
	end

	local crystalRefreshBtn=UI.BuatButton(UI,P_FAR,"Refresh Crystal","Scan eligible crystals >= minimum value")
	crystalRefreshBtn.MouseButton1Click:Connect(function()
		refreshMoneyCrystalDropdown()
		Notify("Crystal list refreshed",2)
	end)

	local farmRarityRow = UI.BuatDropdown(UI,
		P_FAR,"Rarity To Farm",RARITY_LIST,true,
		(function() local t={}; for k in pairs(farmRarityFilter) do t[#t+1]=k end; return t end)(),
		function(selected)
			table.clear(farmRarityFilter)
			for _,v in ipairs(selected) do farmRarityFilter[v]=true end
			saveConfig()
		end
	)

	local M_FarmBtn,M_SetFarm=UI.BuatToggle(UI,
		P_FAR,"Auto Farm Crystal",
		"Continuously scans for eligible crystals, then digs them",
		Toggles.AutoFarmMoney
	)
	M_FarmBtn.MouseButton1Click:Connect(function()
		local v=not Toggles.AutoFarmMoney
		Toggles.AutoFarmMoney=v
		M_SetFarm(v)
		if v then refreshMoneyCrystalDropdown() end
		Money.setActive(v)
		saveConfig()
	end)

	local M_SellBtn,M_SetSell=UI.BuatToggle(UI,
		P_FAR,"Auto Sell At 50%",
		"Sell automatically when backpack reaches 50%",
		Toggles.MoneyAutoSell
	)
	M_SellBtn.MouseButton1Click:Connect(function()
		local v=not Toggles.MoneyAutoSell
		Toggles.MoneyAutoSell=v
		M_SetSell(v)
		saveConfig()
	end)

	local MoneyStatusLbl=UI.BuatLabel(UI,P_FAR,"Idle")
	Money._getStatusLabel(MoneyStatusLbl)
	refreshMoneyCrystalDropdown()


    UI.BuatSection(UI,P_FAR,"Farm Boulder")
    local boulderFarmOptions={"Mossite","Voltite","Gildrite","Rimeveil","Nocturnite"}
    UI.BuatDropdown(UI,P_FAR,"Select Boulder",boulderFarmOptions,true,
        (function() local t={}; for k in pairs(Cache.boulderFarmFilter) do t[#t+1]=k end return t end)(),
        function(selected)
            table.clear(Cache.boulderFarmFilter)
            for _,v in ipairs(selected) do Cache.boulderFarmFilter[v]=true end
            Farm.setTargets(Cache.boulderFarmFilter)
            saveConfig()
        end)
    local BF_Btn,BF_Set=UI.BuatToggle(UI,P_FAR,"Auto Farm Boulder","Exact NXROT Boulder engine",Toggles.AutoFarmBoulders)
    BF_Btn.MouseButton1Click:Connect(function()
        local v=not Toggles.AutoFarmBoulders
        Toggles.AutoFarmBoulders=v; BF_Set(v)
        Farm.setTargets(Cache.boulderFarmFilter); Farm.setActive(v); saveConfig()
    end)
    local BStop=UI.BuatButton(UI,P_FAR,"Stop Boulder Farm","Stop NXROT Boulder engine",UI.C.RED)
    BStop.MouseButton1Click:Connect(function() Toggles.AutoFarmBoulders=false; BF_Set(false); Farm.setActive(false); saveConfig() end)
    local BStatus=UI.BuatLabel(UI,P_FAR,"Idle"); Farm._getStatusLabel(BStatus)

    UI.BuatSection(UI,P_FAR,"Farm Veins")
    local digVeinNames={"Prismarite","Aetherstone","Cracked Lava"}
    local bombVeinNames={}; local seenBomb={}
    for _,info in pairs(BOMB_MATERIALS) do
        if not seenBomb[info.matName] then seenBomb[info.matName]=true; bombVeinNames[#bombVeinNames+1]=info.matName end
    end
    table.sort(bombVeinNames)
    local allVeinNames={}
    for _,n in ipairs(digVeinNames) do allVeinNames[#allVeinNames+1]="[Dig] "..n end
    for _,n in ipairs(bombVeinNames) do allVeinNames[#allVeinNames+1]="[Bomb] "..n end
    local veinSel={}
    for k in pairs(Cache.digVeinFilter) do veinSel[#veinSel+1]="[Dig] "..k end
    for k in pairs(Cache.bombVeinFilter) do veinSel[#veinSel+1]="[Bomb] "..k end
    UI.BuatDropdown(UI,P_FAR,"Select Veins",allVeinNames,true,veinSel,function(vals)
        table.clear(Cache.digVeinFilter); table.clear(Cache.bombVeinFilter)
        for _,v in ipairs(vals) do
            local d=v:match("^%[Dig%] (.+)$"); local b=v:match("^%[Bomb%] (.+)$")
            if d then Cache.digVeinFilter[d]=true end
            if b then Cache.bombVeinFilter[b]=true end
        end
        saveConfig()
    end)
    local VE_Btn,VE_Set=UI.BuatToggle(UI,P_FAR,"Auto Farm Veins","Exact NXROT Dig/Bomb Vein engines",Toggles.AutoFarmDigVein or Toggles.AutoFarmBombVein)
    VE_Btn.MouseButton1Click:Connect(function()
        local hasDig=next(Cache.digVeinFilter)~=nil; local hasBomb=next(Cache.bombVeinFilter)~=nil
        local active=(DigVeinFarm.isActive and DigVeinFarm.isActive()) or (BombVeinFarm.isActive and BombVeinFarm.isActive())
        local v=not active; VE_Set(v)
        if v then
            if not hasDig and not hasBomb then hasDig=true; hasBomb=true end
            Toggles.AutoFarmDigVein=hasDig; Toggles.AutoFarmBombVein=hasBomb
            DigVeinFarm.setActive(hasDig); BombVeinFarm.setActive(hasBomb)
        else
            Toggles.AutoFarmDigVein=false; Toggles.AutoFarmBombVein=false
            DigVeinFarm.setActive(false); BombVeinFarm.setActive(false)
        end
        saveConfig()
    end)
    local DVStatus=UI.BuatLabel(UI,P_FAR,"Dig Vein: Idle"); DigVeinFarm._setLabel(DVStatus)
    local BVStatus=UI.BuatLabel(UI,P_FAR,"Bomb Vein: Idle"); BombVeinFarm._setLabel(BVStatus)
    local VStop=UI.BuatButton(UI,P_FAR,"Stop Vein Farm","Stop both Vein engines",UI.C.RED)
    VStop.MouseButton1Click:Connect(function()
        Toggles.AutoFarmDigVein=false; Toggles.AutoFarmBombVein=false; VE_Set(false)
        DigVeinFarm.setActive(false); BombVeinFarm.setActive(false); saveConfig()
    end)

    UI.BuatSection(UI,P_FAR,"Loot Settings")
    UI.BuatDropdown(UI,P_FAR,"Rarity",RARITY_LIST,true,
        (function() local t={}; for k in pairs(rarityPickupFilter) do t[#t+1]=k end return t end)(),
        function(selected)
            table.clear(rarityPickupFilter)
            for _,v in ipairs(selected) do if v~="Default" then rarityPickupFilter[v]=true end end
            saveConfig()
        end)
    UI.BuatInput(UI,P_FAR,"Min Luck","Example: 10%",string.format("%g%%",boulderMinLuck),function(text)
        local cleaned=tostring(text or ""):gsub("%%","")
        boulderMinLuck=math.clamp(tonumber(cleaned) or 0,0,100000); saveConfig()
    end)
    local IP_Btn,IP_Set=UI.BuatToggle(UI,P_FAR,"Instant Pickup","Use instant pickup for all eligible loot",Toggles.InstantPrompt)
    IP_Btn.MouseButton1Click:Connect(function()
        local v=not Toggles.InstantPrompt; Toggles.InstantPrompt=v; IP_Set(v); setInstantPrompt(v); saveConfig()
    end)

    local FD_Btn,FD_Set=UI.BuatToggle(UI,P_FAR,"Fast Dig","Increase digging frequency",boulderFastDig)
    FD_Btn.MouseButton1Click:Connect(function()
        boulderFastDig=not boulderFastDig
        FD_Set(boulderFastDig)
        saveConfig()
    end)
    UI.BuatSlider(UI,P_FAR,"Dig Speed",100,10000,boulderDigSpeed,function(v)
        boulderDigSpeed=math.clamp(tonumber(v) or 10000,100,10000)
        saveConfig()
    end)

    local Rune_Btn,Rune_Set=UI.BuatToggle(UI,P_FAR,"Pickup Runes","Automatically collect nearby runes",Toggles.AutoRunePickup)
    Rune_Btn.MouseButton1Click:Connect(function()
        local v=not Toggles.AutoRunePickup; Toggles.AutoRunePickup=v; Rune_Set(v); Mountain.setAutoGrab(v); saveConfig()
    end)

	UI.BuatSlider(UI,P_FAR,"Loot Radius Boulder",8,80,lootRadiusBoulder,function(v)
        lootRadiusBoulder=math.clamp(math.floor(v),8,80); saveConfig()
    end)
    UI.BuatSlider(UI,P_FAR,"Loot Radius Veins",8,80,lootRadiusVein,function(v)
        lootRadiusVein=math.clamp(math.floor(v),8,80); saveConfig()
    end)

    UI.BuatSection(UI,P_FAR,"Farm Method")
    Runtime.FarmMethodButton,Runtime.FarmMethodGet,Runtime.FarmMethodSet=UI.BuatDropdown(UI,P_FAR,"Server Mode",{"Current Server","Random Server"},false,Runtime.farmMethod,function(selected)
        Runtime.farmMethod=(selected=="Random Server") and "Random Server" or "Current Server"; saveConfig()
    end)
    Runtime.BackpackLabel=UI.BuatLabel(UI,P_FAR,"0 / 0 KG")
end
function BuildShopTab(UI,P_SHP)
	UI.BuatSection(UI,P_SHP,"Auto Buy Pickaxe")
	UI.BuatShopDropdown(UI,P_SHP,"Pickaxe To Buy",PICKAXE_SHOP,selectedPickaxeToBuy,function(id)
		selectedPickaxeToBuy=id; saveConfig()
	end)
	local AU_PBtn,AU_SetP=UI.BuatToggle(UI,P_SHP,"Auto Buy Pickaxe","Buy selected pickaxe when affordable",Toggles.AutoBuyPick)
	AU_PBtn.MouseButton1Click:Connect(function()
		local v=not Toggles.AutoBuyPick; Toggles.AutoBuyPick=v; AU_SetP(v); AutoUpgrade.setAutoPick(v); saveConfig()
	end)
	UI.BuatSection(UI,P_SHP,"Auto Upgrades")
	UI.BuatStepSelect(UI,P_SHP,"Weight Upgrade",AutoUpgrade.getWeightTier(),function(v)
		AutoUpgrade.setWeightTier(v); saveConfig()
	end)
	local AU_WBtn,AU_SetW=UI.BuatToggle(UI,P_SHP,"Auto Weight Upgrade","Spend cash upgrading carry weight",Toggles.AutoWeightUpgrade)
	AU_WBtn.MouseButton1Click:Connect(function()
		local v=not Toggles.AutoWeightUpgrade; Toggles.AutoWeightUpgrade=v; AU_SetW(v); AutoUpgrade.setWeight(v); saveConfig()
	end)
	UI.BuatStepSelect(UI,P_SHP,"Warm Upgrade",AutoUpgrade.getAirTier(),function(v)
		AutoUpgrade.setAirTier(v); saveConfig()
	end)
	local AU_ABtn,AU_SetA=UI.BuatToggle(UI,P_SHP,"Auto Warm Upgrade","Spend cash upgrading warmth",Toggles.AutoAirUpgrade)
	AU_ABtn.MouseButton1Click:Connect(function()
		local v=not Toggles.AutoAirUpgrade; Toggles.AutoAirUpgrade=v; AU_SetA(v); AutoUpgrade.setAir(v); saveConfig()
	end)
	UI.BuatSection(UI,P_SHP,"Auto Buy Bombs")
	local bombShopItems={}
	for _,id in ipairs(BOMB_SHOP_ORDER) do
		local cfg=BOMB_CONFIG[id]
		if cfg then bombShopItems[#bombShopItems+1]={id=id,displayName=cfg.displayName,cashPrice=cfg.cashPrice} end
	end
	do
		local options={}
		local displayToId={}
		local idToDisplay={}
		for _,item in ipairs(bombShopItems) do
			local display=item.displayName.."  ["..formatShort(item.cashPrice,"$").."]"
			options[#options+1]=display
			displayToId[display]=item.id
			idToDisplay[item.id]=display
		end
		local defaults={}
		for _,id in ipairs(BOMB_SHOP_ORDER) do
			if selectedBombToBuy[id] and idToDisplay[id] then defaults[#defaults+1]=idToDisplay[id] end
		end
		local _,_,_,setSelected = UI.BuatDropdown(UI,P_SHP,"Bombs To Buy",options,true,defaults,function(values)
			table.clear(selectedBombToBuy)
			for _,display in ipairs(values) do
				local id=displayToId[display]
				if id then selectedBombToBuy[id]=true end
			end
			saveConfig()
		end)
	end
	local ABB_Btn,ABB_Set=UI.BuatToggle(UI,P_SHP,"Auto Buy Bombs","Buy selected bomb when affordable",Toggles.AutoBuyBombs,UI.C.BOMB)
	ABB_Btn.MouseButton1Click:Connect(function()
		local v=not Toggles.AutoBuyBombs; Toggles.AutoBuyBombs=v; ABB_Set(v); autoBuyBombsActive=v; saveConfig()
	end)
	UI.BuatSection(UI,P_SHP,"Auto Buy Radar")
	UI.BuatShopDropdown(UI,P_SHP,"Radar To Buy",RADAR_SHOP,selectedRadarToBuy,function(id)
		selectedRadarToBuy=id; saveConfig()
	end)
	local ABR_Btn,ABR_Set=UI.BuatToggle(UI,P_SHP,"Auto Buy Radar","Buy selected radar automatically",Toggles.AutoBuyRadar,UI.C.SHOP)
	ToggleSetFn.AutoBuyRadar=ABR_Set
	ABR_Btn.MouseButton1Click:Connect(function()
		local v=not Toggles.AutoBuyRadar; Toggles.AutoBuyRadar=v; if ToggleSetFn.AutoBuyRadar then ToggleSetFn.AutoBuyRadar(v) end; autoBuyRadarActive=v; saveConfig()
	end)
	-- Standalone Auto Favorite Item: inventory-only, unrelated to farming/pickup/rune logic.
	UI.BuatSection(UI,P_SHP,"Auto Favorite Item")
	UI.BuatInput(UI,P_SHP,"Minimum Luck","Enter Luck %",string.format("%g%%",Runtime.favoriteMinLuck),Runtime.setFavoriteMinLuck)
	ABR_Btn,ABR_Set = UI.BuatToggle(UI,P_SHP,"Auto Favorite Item","Favorite crystals at or above Min Luck",Toggles.AutoFavoriteItem)
	ToggleSetFn.AutoFavoriteItem=ABR_Set
	ABR_Btn.MouseButton1Click:Connect(function()
	Runtime.toggleFavoriteItem()
end)
	UI.BuatButton(UI,P_SHP,"Unfavorite All Crystal","Unfavorite all crystals").MouseButton1Click:Connect(function()
		Runtime.unfavoriteAllCrystalItems()
	end)

	UI.BuatSection(UI,P_SHP,"Inventory")
	UI.BuatButton(UI,P_SHP,"Sell All","Sell non-favorited items").MouseButton1Click:Connect(function()
		if doSell() then Notify("Selling non-favorited items",2) end
	end)

	end

-- ============================================================
-- [37.5] UNIFIED ESP TRACER LINES
-- ============================================================
Runtime.TracerLines = Runtime.TracerLines or {}
do
	local T=Runtime.TracerLines
	local pools={player={},crystal={},boulder={},vein={}}
	local conn=nil
	local MAX={player=12,crystal=10,boulder=10,vein=8}

	local function worldToScreen(pos)
		local cam=S.Workspace.CurrentCamera
		if not cam then return nil,false end
		local ok,sp,on=pcall(function() return cam:WorldToViewportPoint(pos) end)
		if not ok or not sp then return nil,false end
		return Vector2.new(sp.X,sp.Y),on and sp.Z>0
	end

	local function rootScreen()
		local root=getRoot(); if not root then return nil end
		local sp,on=worldToScreen(root.Position)
		return on and sp or nil
	end

	local function line(pool,index)
		local l=pool[index]; if l then return l end
		if typeof(Drawing)~="table" then return nil end
		local ok,obj=pcall(function()
			local x=Drawing.new("Line")
			x.Thickness=2.5; x.Transparency=0.35; x.Visible=false; x.ZIndex=5
			return x
		end)
		if ok and obj then pool[index]=obj; return obj end
		return nil
	end

	local function hide(pool,index)
		local l=pool[index]; if l then pcall(function() l.Visible=false end) end
	end

	local function draw(pool,index,from,to,color)
		local l=line(pool,index); if not l then return end
		pcall(function() l.From=from; l.To=to; l.Color=color; l.Visible=true end)
	end

	local function update()
		local origin=rootScreen()
		if not origin then
			for _,pool in pairs(pools) do for i=1,#pool do hide(pool,i) end end
			return
		end
		local root=getRoot()
		local maxDist=math.max(
			tonumber(CFG.ESP.crystalDistance) or 3000,
			tonumber(CFG.ESP.veinDistance) or 3000,
			tonumber(CFG.ESP.boulderDistance) or 3000,
			tonumber(CFG.PLAYER.distance) or 3000)

		local n=0
		if Toggles.PlayerLines and root then
			local list={}
			for _,plr in ipairs(S.Players:GetPlayers()) do
				if plr~=LocalPlayer then
					local r=plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
					if r then
						local d=(r.Position-root.Position).Magnitude
						if d<=maxDist then list[#list+1]={r=r,d=d} end
					end
				end
			end
			table.sort(list,function(a,b) return a.d<b.d end)
			for i=1,math.min(MAX.player,#list) do
				local sp,on=worldToScreen(list[i].r.Position)
				if sp and on then draw(pools.player,i,origin,sp,CFG.COLORS.player); n=i else hide(pools.player,i) end
			end
		end
		for i=n+1,#pools.player do hide(pools.player,i) end

		n=0
		if Toggles.CrystalLines and root then
			local list=pickupCandidates(math.huge,root.Position,math.min(maxDist,3000)) or {}
			for i=1,math.min(MAX.crystal,#list) do
				local inst=list[i].inst
				local sp,on=worldToScreen(inst.Position)
				if sp and on then draw(pools.crystal,i,origin,sp,crystalColor(inst)); n=i else hide(pools.crystal,i) end
			end
		end
		for i=n+1,#pools.crystal do hide(pools.crystal,i) end

		n=0
		-- Boulder tracer: draw line from player to EVERY ESPed boulder (respects filter),
		-- not just the active farm target. Requires BoulderEsp toggle ON.
		if Toggles.BoulderEsp and Toggles.BoulderLines and root then
			local boulderRootsFn = Mountain and Mountain._boulderRoots
			-- Fallback: walk workspace directly
			local blist={}
			local function scanBoulderContainer(container)
				if not container then return end
				for _,child in ipairs(container:GetChildren()) do
					local kind=nil
					for _,k in ipairs({"Mossite","Voltite","Gildrite","Rimeveil","Nocturnite"}) do
						if child.Name:find(k,1,true) then kind=k; break end
					end
					if kind then
						if next(boulderEspFilter)==nil or boulderEspFilter[kind] then
							local part=child:IsA("BasePart") and child or child:FindFirstChildWhichIsA("BasePart",true)
							if part then
								local d=(part.Position-root.Position).Magnitude
								if d<=CFG.ESP.boulderDistance then
									blist[#blist+1]={part=part,kind=kind,d=d}
								end
							end
						end
					end
				end
			end
			local deco=S.Workspace:FindFirstChild("MountainDecorations")
			scanBoulderContainer(deco and deco:FindFirstChild("Boulders"))
			scanBoulderContainer(S.Workspace:FindFirstChild("BoulderTest"))
			table.sort(blist,function(a,b) return a.d<b.d end)
			local BOULDER_COLORS={
				Mossite   =Color3.fromRGB(150,220,120),
				Voltite   =Color3.fromRGB(110,190,240),
				Gildrite  =Color3.fromRGB(255,200,60),
				Rimeveil  =Color3.fromRGB(170,100,255),
				Nocturnite=Color3.fromRGB(255,80,180),
			}
			for i=1,math.min(MAX.boulder,#blist) do
				local entry=blist[i]
				local sp,on=worldToScreen(entry.part.Position)
				if sp and on then
					local col=BOULDER_COLORS[entry.kind] or Color3.fromRGB(255,205,70)
					local l=line(pools.boulder,i)
					if l then pcall(function()
						l.Thickness=3.5; l.Transparency=0.20
						l.From=origin; l.To=sp; l.Color=col; l.Visible=true
					end) end
					n=i
				else hide(pools.boulder,i) end
			end
		elseif Toggles.BoulderLines and Farm and Farm.getState then
			-- Fallback: lines only to active farm target when ESP toggle is off
			local st=Farm.getState()
			local target=st and st.target
			local part=target and (target:IsA("BasePart") and target or target:FindFirstChildWhichIsA("BasePart",true))
			if part then
				local sp,on=worldToScreen(part.Position)
				if sp and on then
					local l=line(pools.boulder,1)
					if l then pcall(function()
						l.Thickness=4; l.Transparency=0.20
						l.From=origin; l.To=sp; l.Color=Color3.fromRGB(255,205,70); l.Visible=true
					end) end
					n=1
				end
			end
		end
		for i=n+1,#pools.boulder do hide(pools.boulder,i) end

		n=0
		-- Vein tracer: draw line from player to every visible vein cluster centroid.
		-- Respects veinEspFilter — only clusters whose matName passes the filter get a line.
		if Toggles.VeinEsp and Toggles.VeinLines and VeinsModule and VeinsModule.getClusters and VeinsModule.getAllMats and root then
			local clusters=VeinsModule.getClusters()
			local mats=VeinsModule.getAllMats()
			local list={}
			for _,cl in pairs(clusters or {}) do
				local info=mats[cl.material]
				if cl.position and info then
					-- Apply veinEspFilter
					local matName=info.name or info.matName or ""
					local passes=next(veinEspFilter)==nil or veinEspFilter[matName]==true
					if passes then
						local d=(cl.position-root.Position).Magnitude
						if d<=CFG.ESP.veinDistance then
							list[#list+1]={p=cl.position,d=d,c=info.color}
						end
					end
				end
			end
			table.sort(list,function(a,b) return a.d<b.d end)
			for i=1,math.min(MAX.vein,#list) do
				local sp,on=worldToScreen(list[i].p)
				if sp and on then
					local l=line(pools.vein,i)
					if l then pcall(function()
						l.Thickness=3.5; l.Transparency=0.20
						l.From=origin; l.To=sp; l.Color=list[i].c; l.Visible=true
					end) end
					n=i
				else hide(pools.vein,i) end
			end
		elseif Toggles.VeinLines and VeinsModule and VeinsModule.getClusters and VeinsModule.getAllMats and root then
			-- Fallback when VeinEsp toggle is off — still draw lines if Lines toggle is on
			local clusters=VeinsModule.getClusters()
			local mats=VeinsModule.getAllMats()
			local list={}
			for _,cl in pairs(clusters or {}) do
				local info=mats[cl.material]
				if cl.position and info then list[#list+1]={p=cl.position,d=(cl.position-root.Position).Magnitude,c=info.color} end
			end
			table.sort(list,function(a,b) return a.d<b.d end)
			for i=1,math.min(MAX.vein,#list) do
				local sp,on=worldToScreen(list[i].p)
				if sp and on then
					local l=line(pools.vein,i)
					if l then pcall(function()
						l.Thickness=3.5; l.Transparency=0.20
						l.From=origin; l.To=sp; l.Color=list[i].c; l.Visible=true
					end) end
					n=i
				else hide(pools.vein,i) end
			end
		end
		for i=n+1,#pools.vein do hide(pools.vein,i) end
	end

	function T.start()
		if conn or typeof(Drawing)~="table" then return end
		conn=S.RunService.Heartbeat:Connect(function() pcall(update) end)
	end

	function T.stop()
		if conn then conn:Disconnect(); conn=nil end
		for _,pool in pairs(pools) do for i=1,#pool do hide(pool,i) end end
	end
	T.start()
end

function BuildESPTab(UI,P_ESP)
	UI.BuatSection(UI,P_ESP,"Player ESP")
	local pBtn,pSet=UI.BuatToggle(UI,P_ESP,"Player ESP","Show players",Toggles.PlayerEsp)
	pBtn.MouseButton1Click:Connect(function()
		local v=not Toggles.PlayerEsp; Toggles.PlayerEsp=v; playerEspActive=v; pSet(v)
		if not v then clearPlayerEsp() end; saveConfig()
	end)
	local pLine,pLineSet=UI.BuatToggle(UI,P_ESP,"Show Lines","Tracer lines to players",Toggles.PlayerLines)
	pLine.MouseButton1Click:Connect(function() Toggles.PlayerLines=not Toggles.PlayerLines; pLineSet(Toggles.PlayerLines); saveConfig() end)

	-- ── CRYSTAL ESP ────────────────────────────────────────────
	UI.BuatSection(UI,P_ESP,"Crystal ESP")
	local cBtn,cSet=UI.BuatToggle(UI,P_ESP,"Crystal ESP","Show crystals",Toggles.CrystalEsp)
	cBtn.MouseButton1Click:Connect(function()
		local v=not Toggles.CrystalEsp; Toggles.CrystalEsp=v; espActive=v; cSet(v)
		if not v then clearEsp() else updateTracking() end; saveConfig()
	end)
	local cLine,cLineSet=UI.BuatToggle(UI,P_ESP,"Show Lines","Tracer lines to eligible crystals",Toggles.CrystalLines)
	cLine.MouseButton1Click:Connect(function() Toggles.CrystalLines=not Toggles.CrystalLines; cLineSet(Toggles.CrystalLines); saveConfig() end)

	-- ── BOULDER ESP ────────────────────────────────────────────
	UI.BuatSection(UI,P_ESP,"Boulder ESP")
	local bBtn,bSet=UI.BuatToggle(UI,P_ESP,"Boulder ESP","Show boulders + outline",Toggles.BoulderEsp)
	bBtn.MouseButton1Click:Connect(function()
		local v=not Toggles.BoulderEsp; Toggles.BoulderEsp=v; bSet(v); Mountain.setBoulderEsp(v); saveConfig()
	end)
	local bLine,bLineSet=UI.BuatToggle(UI,P_ESP,"Show Lines","Lines from you to each ESPed boulder",Toggles.BoulderLines)
	bLine.MouseButton1Click:Connect(function() Toggles.BoulderLines=not Toggles.BoulderLines; bLineSet(Toggles.BoulderLines); saveConfig() end)
	-- Dropdown: boulder types to show (empty selection = show all)
	local BOULDER_KINDS = {"Mossite","Voltite","Gildrite","Rimeveil","Nocturnite"}
	local boulderEspDefaults={}
	for _,k in ipairs(BOULDER_KINDS) do if boulderEspFilter[k] then boulderEspDefaults[#boulderEspDefaults+1]=k end end
	UI.BuatDropdown(UI,P_ESP,"Select ESP",BOULDER_KINDS,true,boulderEspDefaults,function(vals)
		table.clear(boulderEspFilter)
		for _,name in ipairs(vals) do boulderEspFilter[name]=true end
		Mountain.setBoulderEsp(Toggles.BoulderEsp)
		saveConfig()
	end)

	-- ── VEINS ESP ───────────────────────────────────────────────────────
	UI.BuatSection(UI,P_ESP,"Veins ESP")
	local vBtn,vSet=UI.BuatToggle(UI,P_ESP,"Veins ESP","Show vein clusters",Toggles.VeinEsp)
	vBtn.MouseButton1Click:Connect(function()
		local v=not Toggles.VeinEsp; Toggles.VeinEsp=v; veinEspActive=v; vSet(v); VeinsModule.setVeinEsp(v); saveConfig()
	end)
	local vLine,vLineSet=UI.BuatToggle(UI,P_ESP,"Show Lines","Lines from you to each vein cluster",Toggles.VeinLines)
	vLine.MouseButton1Click:Connect(function() Toggles.VeinLines=not Toggles.VeinLines; vLineSet(Toggles.VeinLines); saveConfig() end)
	-- Dropdown: vein types to show (empty selection = show all)
	local DIG_VEIN_NAMES  = {"Prismarite","Aetherstone","Cracked Lava"}
	local BOMB_VEIN_NAMES = {"Gunpowder Stone","Skyglass","Cryostone","Cinderforge Plate","Stormsteel","Venomite","Chronoshard","Dreadstone"}
	local ALL_VEIN_NAMES  = {}
	for _,n in ipairs(DIG_VEIN_NAMES)  do ALL_VEIN_NAMES[#ALL_VEIN_NAMES+1]=n end
	for _,n in ipairs(BOMB_VEIN_NAMES) do ALL_VEIN_NAMES[#ALL_VEIN_NAMES+1]=n end
	local veinEspDefaults={}
	for _,k in ipairs(ALL_VEIN_NAMES) do if veinEspFilter[k] then veinEspDefaults[#veinEspDefaults+1]=k end end
	UI.BuatDropdown(UI,P_ESP,"Select ESP",ALL_VEIN_NAMES,true,veinEspDefaults,function(vals)
		table.clear(veinEspFilter)
		for _,name in ipairs(vals) do veinEspFilter[name]=true end
		if VeinsModule and VeinsModule.setVeinEsp then VeinsModule.setVeinEsp(Toggles.VeinEsp) end
		saveConfig()
	end)

	UI.BuatSection(UI,P_ESP,"Text Size Settings")
	UI.BuatSlider(UI,P_ESP,"Text Size",40,250,math.floor(espScale*100),function(v)
		espScale=v/100; applyEspScale(); VeinsModule.applyScale(); PrismariteModule.applyScale(); saveConfig()
	end)
	UI.BuatSlider(UI,P_ESP,"Max Distance",50,3000,math.floor(CFG.ESP.crystalDistance),function(v)
		local n=math.clamp(math.floor(v),50,3000)
		CFG.ESP.crystalDistance=n; CFG.ESP.veinDistance=n; CFG.ESP.boulderDistance=n; CFG.ESP.prismariteDistance=n
		applyEspScale(); VeinsModule.applyScale(); PrismariteModule.applyScale(); saveConfig()
	end)
	UI.BuatButton(UI,P_ESP,"Refresh ESP","Refresh crystal/vein ESP data").MouseButton1Click:Connect(function()
		requestRefresh()
		if VeinsModule.setVeinEsp then VeinsModule.setVeinEsp(Toggles.VeinEsp) end
		Notify("ESP refreshed",2)
	end)
end
function BuildTeleportTab(UI,P_TEL)
	UI.BuatSection(UI,P_TEL,"Teleport Crystal")
	local T_AimBtn,T_SetAim=UI.BuatToggle(UI,P_TEL,"Aim Teleport (F key)","Teleport toward aimed crystal",Toggles.AimTeleport)
	T_AimBtn.MouseButton1Click:Connect(function()
		aimTpEnabled=not aimTpEnabled; Toggles.AimTeleport=aimTpEnabled; T_SetAim(aimTpEnabled); saveConfig()
	end)
	UI.BuatSection(UI,P_TEL,"Quick Teleport")
	local function fmtValue(_,score) return formatShort(score,"$") end
	local function fmtLuck(_,score)  return formatLuck(score) end
	local function fmtWeight(inst)   return formatWeight(crystalWeight(inst)) end
	UI.BuatButton(UI,P_TEL,"Teleport High Value","TP to highest value crystal").MouseButton1Click:Connect(function()
		Runtime.tpToRank(crystalValue,1,fmtValue)
	end)
	UI.BuatButton(UI,P_TEL,"Teleport High Luck","TP to highest luck crystal").MouseButton1Click:Connect(function()
		Runtime.tpToRank(crystalLuck,1,fmtLuck)
	end)
	UI.BuatButton(UI,P_TEL,"Teleport High Weight","TP to heaviest crystal").MouseButton1Click:Connect(function()
		Runtime.tpToRank(crystalWeight,1,fmtWeight)
	end)
	UI.BuatButton(UI,P_TEL,"Teleport Home","Go to your home base").MouseButton1Click:Connect(function()
		if fireRemote(RMT.GoHome,"home") then Notify("Teleporting home",2) end
	end)

	end

function BuildMiscTab(UI,P_MIS)
	UI.BuatSection(UI,P_MIS,"Movement")
	local M_SpdBtn,M_SetSpd=UI.BuatToggle(UI,P_MIS,"Speed Boost","Walk faster",Toggles.SpeedBoost)
	M_SpdBtn.MouseButton1Click:Connect(function()
		speedActive=not speedActive; Toggles.SpeedBoost=speedActive; M_SetSpd(speedActive); setSpeedBoost(speedActive); saveConfig()
	end)
	local M_FlyBtn,M_SetFly=UI.BuatToggle(UI,P_MIS,"Fly","Fly around freely",Toggles.Fly)
	M_FlyBtn.MouseButton1Click:Connect(function()
		local v=not Toggles.Fly; Toggles.Fly=v; M_SetFly(v); Move.setFly(v); saveConfig()
	end)
	UI.BuatSlider(UI,P_MIS,"Fly Speed",10,500,100,function(v) Move.setFlySpeed(v) end)
	local M_ClipBtn,M_SetClip=UI.BuatToggle(UI,P_MIS,"Noclip","Walk through objects",Toggles.Noclip)
	M_ClipBtn.MouseButton1Click:Connect(function()
		local v=not Toggles.Noclip; Toggles.Noclip=v; M_SetClip(v); Move.setNoclip(v); saveConfig()
	end)
	local M_JmpBtn,M_SetJmp=UI.BuatToggle(UI,P_MIS,"Infinite Jump","Jump in mid-air",Toggles.InfJump)
	M_JmpBtn.MouseButton1Click:Connect(function()
		local v=not Toggles.InfJump; Toggles.InfJump=v; M_SetJmp(v); Move.setInfJump(v); saveConfig()
	end)

	UI.BuatSection(UI,P_MIS,"Utility")
	local U_RevBtn,U_SetRev=UI.BuatToggle(UI,P_MIS,"Auto Revive","Instantly revive on death",Toggles.AutoRevive)
	U_RevBtn.MouseButton1Click:Connect(function()
		local v=not Toggles.AutoRevive; Toggles.AutoRevive=v; U_SetRev(v); autoReviveActive=v; saveConfig()
	end)
	local U_FpsBtn,U_SetFps=UI.BuatToggle(UI,P_MIS,"FPS Boost","Ultra performance mode - particles, shadows, post FX and low-value crystals",Toggles.FpsBoost)
	U_FpsBtn.MouseButton1Click:Connect(function()
		local v=not Toggles.FpsBoost
		U_SetFps(v)
		applyFpsBoost(v)
		saveConfig()
	end)

	UI.BuatSection(UI,P_MIS,"Server")
	local U_HopBtn,U_SetHop=UI.BuatToggle(UI,P_MIS,"Auto Hop","Hop server every X minutes",Toggles.AutoHop)
	U_HopBtn.MouseButton1Click:Connect(function()
		local v=not Toggles.AutoHop; Toggles.AutoHop=v; U_SetHop(v); setAutoHop(v); saveConfig()
	end)
	UI.BuatSlider(UI,P_MIS,"Auto Hop Minutes",5,120,autoHopMinutes,function(v)
		autoHopMinutes=v; if autoHopActive then setAutoHop(true) end; saveConfig()
	end)
	UI.BuatButton(UI,P_MIS,"Hop Server","Join a different server").MouseButton1Click:Connect(function() Net.hop() end)
	UI.BuatButton(UI,P_MIS,"Rejoin Server","Rejoin current server").MouseButton1Click:Connect(function() Net.rejoin() end)

	end

function BuildDupeTab(UI, P_DUP)
    local CONFIG_FILE = "DHuh_DupeConfig.json"
    local savedConfig = {}
    
    if writefile and readfile and isfile and isfile(CONFIG_FILE) then
        pcall(function()
            savedConfig = game:GetService("HttpService"):JSONDecode(readfile(CONFIG_FILE))
        end)
    end

    local function saveMyConfig(data)
        if writefile then
            pcall(function()
                writefile(CONFIG_FILE, game:GetService("HttpService"):JSONEncode(data))
            end)
        end
    end

    -- ── STATE ────────────────────────────────────────────────
    local selectedCrystals  = savedConfig.selectedCrystals  or {}
    local selectedRunes     = savedConfig.selectedRunes     or {}
    local selectedRarities  = savedConfig.selectedRarities  or {}
    local crystalOptions    = {}
    local runeOptions       = {}

    local isAutoDropOnKick  = savedConfig.isAutoDropOnKick  or false
    local isAutoCollect     = savedConfig.isAutoCollect     or false
    local isAutoRejoin      = savedConfig.isAutoRejoin      or false

    local rejoinDelay       = savedConfig.rejoinDelay       or 5
    local rejoinMethod      = savedConfig.rejoinMethod      or "Current Server"
    local privateServerLink = savedConfig.privateServerLink or ""
    local collectRadius     = savedConfig.collectRadius     or 100

    local function updateConfig()
        saveMyConfig({
            selectedCrystals  = selectedCrystals,
            selectedRunes     = selectedRunes,
            selectedRarities  = selectedRarities,
            isAutoDropOnKick  = isAutoDropOnKick,
            isAutoCollect     = isAutoCollect,
            isAutoRejoin      = isAutoRejoin,
            rejoinDelay       = rejoinDelay,
            rejoinMethod      = rejoinMethod,
            privateServerLink = privateServerLink,
            collectRadius     = collectRadius,
        })
    end

    -- ── HELPERS ──────────────────────────────────────────────
    local rarityList = {"Common","Uncommon","Rare","Epic","Legendary","Mythic","Empyrean","Pulsar","Quasar"}

    local function getCrystalRarity(child)
        local tierName = child:GetAttribute("TierName")
        if type(tierName) == "string" and tierName ~= "" then return tierName end
        local tier = tonumber(child:GetAttribute("Tier")) or 0
        return rarityList[tier] or "Unknown"
    end

    local function rarityAllowed(child)
        if #selectedRarities == 0 then return true end
        local r = getCrystalRarity(child)
        for _, sel in ipairs(selectedRarities) do
            if sel == r then return true end
        end
        return false
    end

    local function isCrystalTool(child)
        if not child:IsA("Tool") then return false end
        return child:GetAttribute("CrystalName") ~= nil
            or child:GetAttribute("Tier") ~= nil
            or child.Name:find("Crystal") ~= nil
    end

    local function isRuneTool(child)
        if not child:IsA("Tool") then return false end
        return child:GetAttribute("RuneId") ~= nil
            or child:GetAttribute("RuneName") ~= nil
            or child:GetAttribute("IsRune") == true
            or child.Name:find(" Rune", 1, true) ~= nil
    end

    -- ── SCAN INVENTORY ───────────────────────────────────────
    local function scanInventory()
        table.clear(crystalOptions)
        table.clear(runeOptions)
        local crystalMap, runeMap = {}, {}

        local function checkItem(child)
            if isRuneTool(child) then
                if not runeMap[child.Name] then
                    runeMap[child.Name] = true
                    table.insert(runeOptions, child.Name)
                end
            elseif isCrystalTool(child) then
                if not crystalMap[child.Name] then
                    crystalMap[child.Name] = true
                    table.insert(crystalOptions, child.Name)
                end
            end
        end

        local bp = game.Players.LocalPlayer:FindFirstChildOfClass("Backpack")
        if bp then for _, c in ipairs(bp:GetChildren()) do checkItem(c) end end
        local char = game.Players.LocalPlayer.Character
        if char then for _, c in ipairs(char:GetChildren()) do checkItem(c) end end
        table.sort(crystalOptions)
        table.sort(runeOptions)
    end

    scanInventory()

    -- ── CORE LOGIC: DROP ─────────────────────────────────────
    local dropRemoteCache = nil
    local function getDropRemote()
        if dropRemoteCache and dropRemoteCache.Parent then return dropRemoteCache end
        local r = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
        dropRemoteCache = r and r:FindFirstChild("CrystalDropRequest")
        return dropRemoteCache
    end

    local function executeDropItems(crystalList, runeList)
        local remote = getDropRemote()
        if not remote then return end

        local targetCrystals = {}
        local targetRunes = {}
        for _, name in ipairs(crystalList or selectedCrystals) do targetCrystals[name] = true end
        for _, name in ipairs(runeList   or selectedRunes)   do targetRunes[name]   = true end

        local function dropFrom(container)
            if not container then return end
            for _, child in ipairs(container:GetChildren()) do
                if child:IsA("Tool") then
                    if targetCrystals[child.Name] or targetRunes[child.Name] then
                        pcall(function() remote:FireServer(child.Name) end)
                    end
                end
            end
        end

        dropFrom(game.Players.LocalPlayer:FindFirstChildOfClass("Backpack"))
        dropFrom(game.Players.LocalPlayer.Character)
    end

    -- ── CORE LOGIC: COLLECT ──────────────────────────────────
    local holdRemote = nil
    local function getHoldRemote()
        if holdRemote and holdRemote.Parent then return holdRemote end
        local r = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
        holdRemote = r and r:FindFirstChild("CrystalHoldComplete")
        return holdRemote
    end

    local function fireCrystalPickup(part)
        local hold = getHoldRemote()
        if hold then
            pcall(function() hold:FireServer(part) end)
        end

        local prompt = part:FindFirstChildWhichIsA("ProximityPrompt", true)
        if prompt then
            pcall(function()
                prompt.HoldDuration = 0
                prompt.RequiresLineOfSight = false
                prompt.Enabled = true
                prompt.MaxActivationDistance = 9999
            end)
            if typeof(fireproximityprompt) == "function" then
                pcall(function() fireproximityprompt(prompt, 1) end)
                pcall(function() fireproximityprompt(prompt, 0) end)
            end
            pcall(function() prompt:InputHoldBegin(); prompt:InputHoldEnd() end)
        end

        local det = part:FindFirstChildWhichIsA("ClickDetector", true)
        if det and typeof(fireclickdetector) == "function" then
            pcall(function() fireclickdetector(det, 0) end)
        end
    end

    local function collectLoop()
        while task.wait(0.25) do
            if not isAutoCollect then continue end

            local char = game.Players.LocalPlayer.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            if not root then continue end

            local WS = game:GetService("Workspace")

            local containers = {WS}
            local dropped = WS:FindFirstChild("DroppedCrystals") or WS:FindFirstChild("Crystals")
            if dropped then table.insert(containers, dropped) end
            local things = WS:FindFirstChild("Things")
            if things then
                local dc = things:FindFirstChild("DroppedCrystals") or things:FindFirstChild("Crystals")
                if dc then table.insert(containers, dc) end
            end

            for _, container in ipairs(containers) do
                for _, child in ipairs(container:GetChildren()) do
                    if not isAutoCollect then break end
                    if not child:IsA("BasePart") then continue end

                    local isValidCrystal = child:GetAttribute("Value") ~= nil
                        and (child:GetAttribute("CrystalName") ~= nil or child:GetAttribute("Tier") ~= nil)

                    if not isValidCrystal then continue end
                    if child:GetAttribute("Collected") == true then continue end
                    if not rarityAllowed(child) then continue end

                    -- cek radius sebelum teleport
                    local dist = (child.Position - root.Position).Magnitude
                    if dist > collectRadius then continue end

                    local pos = child.Position
                    root.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
                    task.wait(0.05)

                    fireCrystalPickup(child)

                    task.wait(0.1)
                end
            end
        end
    end

    task.spawn(collectLoop)

    -- ── UI: SELECTION ────────────────────────────────────────
    local crystalRow, crystalGet, crystalSetOpts, crystalSetSel
    local runeRow,    runeGet,    runeSetOpts,    runeSetSel
    local methodRow,  methodGet,  methodSetOpts,  methodSetSel

    UI.BuatSection(UI, P_DUP, "Drop Selection")

    crystalRow, crystalGet, crystalSetOpts, crystalSetSel =
        UI.BuatDropdown(UI, P_DUP, "Crystals to Drop", crystalOptions, true, selectedCrystals, function(selected)
            selectedCrystals = selected
            updateConfig()
        end)

    runeRow, runeGet, runeSetOpts, runeSetSel =
        UI.BuatDropdown(UI, P_DUP, "Runes to Drop", runeOptions, true, selectedRunes, function(selected)
            selectedRunes = selected
            updateConfig()
        end)

    local RefreshBtn = UI.BuatButton(UI, P_DUP, "↻ Refresh Inventory", "Scan ulang inventory")
    RefreshBtn.MouseButton1Click:Connect(function()
        scanInventory()
        crystalSetOpts(crystalOptions)
        runeSetOpts(runeOptions)
        if Notify then Notify("Inventory di-refresh", 2) end
    end)

    -- ── UI: COLLECT ──────────────────────────────────────────
    UI.BuatSection(UI, P_DUP, "Auto Collect (Map Scanner)")

    local _,_,_,raritySetSel = UI.BuatDropdown(UI, P_DUP, "Rarity to Collect", rarityList, true, selectedRarities, function(selected)
        selectedRarities = selected
        updateConfig()
    end)

    UI.BuatSlider(UI, P_DUP, "Collect Radius", 10, 5000, collectRadius, function(v)
        collectRadius = math.floor(v)
        updateConfig()
    end)

    local CollectToggleBtn, CollectToggleSet =
        UI.BuatToggle(UI, P_DUP, "Auto Collect Selected", "Auto ambil crystal sesuai rarity dari seluruh map", isAutoCollect)
    CollectToggleBtn.MouseButton1Click:Connect(function()
        isAutoCollect = not isAutoCollect
        CollectToggleSet(isAutoCollect)
        updateConfig()
    end)

    -- ── UI: DROP AUTOMATION ──────────────────────────────────
    UI.BuatSection(UI, P_DUP, "Auto Drop")

    local DropToggleBtn, DropToggleSet =
        UI.BuatToggle(UI, P_DUP, "Auto Drop On Kick", "Drop otomatis saat akun dilogin di tempat lain", isAutoDropOnKick)
    DropToggleBtn.MouseButton1Click:Connect(function()
        isAutoDropOnKick = not isAutoDropOnKick
        DropToggleSet(isAutoDropOnKick)
        updateConfig()
    end)

    -- ── UI: REJOIN SETTINGS ──────────────────────────────────
    UI.BuatSection(UI, P_DUP, "Rejoin Settings")

    UI.BuatInput(UI, P_DUP, "Rejoin Delay [s]", "Contoh: 5", tostring(rejoinDelay), function(val)
        local num = tonumber(val)
        if num then
            rejoinDelay = num
            updateConfig()
            if Notify then Notify("Delay: " .. val .. "s", 2) end
        end
    end)

    methodRow, methodGet, methodSetOpts, methodSetSel =
        UI.BuatDropdown(UI, P_DUP, "Rejoin Method", {"Current Server","Private Server Link","Random Server"},
        false, rejoinMethod, function(selected)
            rejoinMethod = selected
            updateConfig()
        end)

    UI.BuatInput(UI, P_DUP, "Link / JobId Private Server", "Paste link VIP atau JobId", privateServerLink, function(val)
        privateServerLink = val
        updateConfig()
        if Notify then Notify("Server target di-update", 2) end
    end)

    local RejoinToggleBtn, RejoinToggleSet =
        UI.BuatToggle(UI, P_DUP, "Auto Rejoin", "Rejoin otomatis setelah kick", isAutoRejoin)
    RejoinToggleBtn.MouseButton1Click:Connect(function()
        isAutoRejoin = not isAutoRejoin
        RejoinToggleSet(isAutoRejoin)
        updateConfig()
    end)

        -- ── LOGIC: AUTO DROP ON KICK ─────────────────────────────
    local connectionTriggered = false
    local coreGui = game:GetService("CoreGui")

    -- fungsi handleRejoin dikembalikan jadi fungsi terpisah
    -- sama persis seperti versi lama
    local function handleRejoin()
        if not isAutoRejoin then return end
        task.spawn(function()
            task.wait(rejoinDelay)
            local TS = game:GetService("TeleportService")
            local placeId = game.PlaceId
            while task.wait(3) do
                if rejoinMethod == "Current Server" then
                    pcall(function() TS:TeleportToPlaceInstance(placeId, game.JobId, game.Players.LocalPlayer) end)
                elseif rejoinMethod == "Random Server" then
                    if Net and type(Net.hop) == "function" then Net.hop()
                    else pcall(function() TS:Teleport(placeId, game.Players.LocalPlayer) end) end
                elseif rejoinMethod == "Private Server Link" then
                    if privateServerLink ~= "" then
                        local code = privateServerLink:match("privateServerLinkCode=([^&]+)")
                        if code then
                            pcall(function() TS:Teleport(placeId, game.Players.LocalPlayer) end)
                        else
                            pcall(function() TS:TeleportToPlaceInstance(placeId, privateServerLink, game.Players.LocalPlayer) end)
                        end
                    end
                end
            end
        end)
    end

    game:GetService("GuiService").ErrorMessageChanged:Connect(function()
        local msg = game:GetService("GuiService"):GetErrorMessage():lower()
        if (msg:find("same account") or msg:find("device") or msg:find("launched") or msg:find("another device"))
            and not connectionTriggered then
            connectionTriggered = true
            if isAutoDropOnKick then executeDropItems() end
            handleRejoin()  -- fix: tambah handleRejoin disini
        end
    end)

    task.spawn(function()
        while task.wait(0.05) do
            if not connectionTriggered then
                pcall(function()
                    local promptGui = coreGui:FindFirstChild("RobloxPromptGui")
                    if promptGui then
                        local overlay = promptGui:FindFirstChild("promptOverlay")
                        if overlay then
                            for _, child in ipairs(overlay:GetChildren()) do
                                if child.Name:find("ErrorPrompt") then
                                    connectionTriggered = true
                                    if isAutoDropOnKick then executeDropItems() end
                                    handleRejoin()  -- fix: tambah handleRejoin disini juga
                                end
                            end
                        end
                    end
                end)
            end
        end
    end)

    -- ── UI: MISC ─────────────────────────────────────────────
    UI.BuatSection(UI, P_DUP, "Misc")

    local ManualDropBtn = UI.BuatButton(UI, P_DUP, "🗑 Manual Drop Selected", "Drop sekarang juga")
    ManualDropBtn.MouseButton1Click:Connect(function()
        task.spawn(function()
            executeDropItems()
            if Notify then Notify("Manual drop selesai", 2) end
        end)
    end)

    local ResetBtn = UI.BuatButton(UI, P_DUP, "⟳ Reset Character", "Kill & respawn")
    ResetBtn.MouseButton1Click:Connect(function()
        local char = game.Players.LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then pcall(function() hum.Health = 0 end) end
    end)
end
	
function BuildTabsUI(UI)
	BuildFarmingTab(UI,UI.Pages.Farming)
	BuildShopTab(UI,UI.Pages.Shop)
	BuildESPTab(UI,UI.Pages.ESP)
	BuildTeleportTab(UI,UI.Pages.Teleport)
	BuildMiscTab(UI,UI.Pages.Misc)
	BuildDupeTab(UI,UI.Pages.Dupe)
end

InitializeUI()

-- Init Features
if Toggles.FpsBoost then applyFpsBoost(true) end
if Toggles.AutoHop then setAutoHop(true) end
if Toggles.CrystalEsp then updateTracking() end
if Toggles.VeinEsp then VeinsModule.setVeinEsp(true) end

-- Restore visual Prismarite ESP only when its own toggle is saved ON.
if Toggles.PrismariteEsp then
	prismariteEspActive=true
	PrismariteModule.setActive(true)
end

if Toggles.BoulderEsp then Mountain.setBoulderEsp(true) end
if Toggles.AutoFarmBoulders then Farm.setTargets(Cache.boulderFarmFilter); Farm.setActive(true) end
if Toggles.AutoFarmMoney then Money.setActive(true) end
if Toggles.AutoBomb then AutoBomb.setActive(true) end
if Toggles.AutoRunePickup and Toggles.AutoFarmBoulders then Mountain.setAutoGrab(true) end
-- Restore vein farm engines — must run AFTER DigVeinFarm/BombVeinFarm are installed
if Toggles.AutoFarmDigVein  then DigVeinFarm.setActive(true)  end
if Toggles.AutoFarmBombVein then BombVeinFarm.setActive(true) end
if instantPromptActive then setInstantPrompt(true) end
if speedActive then setSpeedBoost(true) end

-- Persist normalized Prismarite Farm/ESP state after startup.
saveConfig()