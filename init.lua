-- ==============================================================================
-- CDID HUB - MAIN INITIALIZER
-- ==============================================================================
local Players = game:GetService("Players")
local StatsService = game:GetService("Stats")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

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

-- Load Utils & UICreate
local Utils = _G.CDID_LoadModule("utils.lua")
local UICreate = _G.CDID_LoadModule("uicreate.lua")
Utils.SetupAntiAFK()

-- Init WindUI
local WindUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"))()

local Window = WindUI:CreateWindow({
	Title = "CDID Multi-Job Hub",
	Author = "by ASRock",
	Folder = "cdid_hub",
	Icon = "solar:car-bold-duotone",
	NewElements = true,
	HideSearchBar = true,
	OpenButton = {
		Title = "Open Hub",
		Enabled = true,
		Draggable = true,
		Scale = 0.5
	}
})

-- DASHBOARD UNIVERSAL (HANYA METRIK GLOBAL)
local DashTab = Window:Tab({ Title = "Dashboard", Icon = "solar:home-2-bold" })
local StatsSection = DashTab:Section({ Title = "Universal System Stats" })

local fpsParagraph = StatsSection:Paragraph({ Title = "Frame Rate (FPS)", Desc = "Membaca...", Image = "monitor" })
local pingParagraph = StatsSection:Paragraph({ Title = "Ping Jaringan", Desc = "Membaca...", Image = "wifi" })
local runtimeParagraph = StatsSection:Paragraph({ Title = "Total Runtime Hub", Desc = "00:00:00", Image = "clock" })

-- Performance Monitor (FPS, Ping, Runtime)
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
-- LOAD FEATURE & JOB MODULES
-- ==============================================================================
-- 1. Server Manager
local ServerModule = _G.CDID_LoadModule("server_manager.lua")
ServerModule.Init(Window, Utils, Context)

-- 2. BCA Courier
local BCAModule = _G.CDID_LoadModule("bca_courier.lua")
BCAModule.Init(Window, Utils, Context, UICreate)

-- 3. Merdeka Event Race Farm (BARU)
local MerdekaModule = _G.CDID_LoadModule("merdeka_farm.lua")
MerdekaModule.Init(Window, Utils, Context, UICreate)

print("🚀 CDID Hub Loaded Successfully with Merdeka Event!")
