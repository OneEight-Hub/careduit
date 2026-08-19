-- ==============================================================================
-- CDID HUB INITIALIZER
-- ==============================================================================
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StatsService = game:GetService("Stats")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

-- Bersihkan Sesi Lama
if _G.MainCoreHooks then
	for _, conn in ipairs(_G.MainCoreHooks) do pcall(function() conn:Disconnect() end) end
end
_G.MainCoreHooks = {}

local session = os.clock()
_G.MainCoreSession = session

local Context = {
	Session = session,
	Hooks = _G.MainCoreHooks
}

-- Load Utilities
local Utils = _G.CDID_LoadModule("utils.lua")
Utils.DestroyBuildingInstances()
Utils.EnablePerformanceMode()
Utils.SetupAntiAFK()

-- Init WindUI Library
local WindUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"))()

local Window = WindUI:CreateWindow({
	Title = "CDID Multi-Job Auto Farm",
	Author = "by ASRock",
	Folder = "cdid_hub",
	Icon = "solar:car-bold-duotone",
	NewElements = true,
	HideSearchBar = true,
	OpenButton = {
		Title = "Open CDID Hub",
		Enabled = true,
		Draggable = true,
		Scale = 0.5
	}
})

-- TAB 1: DASHBOARD & GLOBAL STATS
local DashTab = Window:Tab({ Title = "Dashboard", Icon = "solar:home-2-bold" })
local StatsSection = DashTab:Section({ Title = "System & Game Stats" })

local saldoParagraph = StatsSection:Paragraph({ Title = "Saldo BCA Pocket", Desc = "Membaca data..." })
local fpsParagraph = StatsSection:Paragraph({ Title = "Frame Rate (FPS)", Desc = "Membaca..." })
local pingParagraph = StatsSection:Paragraph({ Title = "Ping Jaringan", Desc = "Membaca..." })
local runtimeParagraph = StatsSection:Paragraph({ Title = "Runtime Hub", Desc = "00:00:00" })

-- Monitor Saldo Pocket
task.spawn(function()
	local ok, RC = pcall(function()
		return require(ReplicatedStorage:WaitForChild('ClientContainer'):WaitForChild('Controller'):WaitForChild('ReplicaController'))
	end)
	local function FormatRupiah(val)
		if type(val) ~= 'number' then return tostring(val or '?') end
		local r = string.format('%d', math.floor(val)):reverse():gsub('%d%d%d','%1.'):reverse():gsub('^%.','')
		return 'Rp ' .. r
	end

	if ok then
		RC.ReplicaOfClassCreated('Player_' .. LocalPlayer.UserId, function(replica)
			local function update()
				local c = replica.Data and replica.Data.Collab
				local p = c and c.MyBca2026 and c.MyBca2026.PocketRupiah
				pcall(function() saldoParagraph:SetDesc(FormatRupiah(p)) end)
			end
			update()
			replica:ListenToChange({'Collab'}, update)
		end)
	end
end)

-- Monitor FPS, Ping, Runtime
task.spawn(function()
	local FPS = {}
	local sec = tick()
	local currentFps = 60
	local startTime = os.clock()

	RunService.RenderStepped:Connect(function()
		local fr = tick()
		for index = #FPS, 1, -1 do
			FPS[index + 1] = (FPS[index] >= fr - 1) and FPS[index] or nil
		end
		FPS[1] = fr
		currentFps = math.floor((tick() - sec >= 1 and #FPS) or (#FPS / (tick() - sec)))
	end)

	while task.wait(1) do
		if Context.Session ~= _G.MainCoreSession then break end
		local pingVal = 0
		pcall(function() pingVal = math.floor((LocalPlayer:GetNetworkPing() or 0) * 1000) end)
		local elapsed = math.floor(os.clock() - startTime)
		
		pcall(function()
			fpsParagraph:SetDesc(string.format("%d FPS", currentFps))
			pingParagraph:SetDesc(string.format("%d ms", pingVal))
			runtimeParagraph:SetDesc(string.format("%02d:%02d:%02d", math.floor(elapsed / 3600), math.floor((elapsed % 3600) / 60), elapsed % 60))
		end)
	end
end)

-- ==============================================================================
-- LOAD JOB MODULES
-- ==============================================================================
-- 1. BCA Courier
local BCAModule = _G.CDID_LoadModule("bca_courier.lua")
BCAModule.Init(Window, Utils, Context)

local ServerModule = _G.CDID_LoadModule("server_manager.lua")
ServerModule.Init(Window, Utils, Context)

-- 2. Tambah Job Lain Nanti Cukup Tambahkan Baris Berikut:
-- local OtherJob = _G.CDID_LoadModule("modules/job_template.lua")
-- OtherJob.Init(Window, Utils, Context)

print("🚀 CDID Hub Loaded Successfully!")
