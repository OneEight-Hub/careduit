-- ==============================================================================
-- CDID HUB - MAIN INITIALIZER (PREMIUM HEADER & MODERN THEME)
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

-- 1. Load Utils, UICreate & Core Drive Engine
local Utils = _G.CDID_LoadModule("utils.lua")
local UICreate = _G.CDID_LoadModule("uicreate.lua")
local DriveEngine = _G.CDID_LoadModule("drive_engine.lua")

Utils.SetupAntiAFK()

-- 2. Init WindUI & Theme Configuration
local WindUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"))()

-- Set Tema Gelap Modern
WindUI:SetTheme("Midnight")

-- Inisialisasi Window Utama dengan Modifikasi Header
local Window = WindUI:CreateWindow({
	Title = "CDID Multi-Job Hub",
	Author = "by ASRock • ⚡ v2.5 [Private Edition]",
	Folder = "cdid_hub",
	Icon = "solar:shield-star-bold",
	Size = UDim2.fromOffset(600, 435),
	Transparent = true,
	NewElements = true,
	HideSearchBar = true,
	OpenButton = {
		Title = "Open Hub",
		Icon = "solar:widget-bold",
		Enabled = true,
		Draggable = true,
		Scale = 0.55
	}
})

-- 3. Header Action Buttons (Sebelah Tombol Close/Minimize)
pcall(function()
	if Window.AddHeaderButton then
		-- Tombol Salin Link Discord Komunitas
		Window:AddHeaderButton({
			Icon = "solar:link-circle-bold",
			Callback = function()
				if setclipboard then
					setclipboard("https://discord.gg/cdidhub")
					Window:Notify({ 
						Title = "Discord Invite", 
						Content = "Link Discord berhasil disalin ke clipboard!", 
						Duration = 4 
					})
				end
			end
		})

		-- Tombol Panic Disconnect Cepat
		Window:AddHeaderButton({
			Icon = "solar:power-bold",
			Callback = function()
				LocalPlayer:Kick("[CDID Hub] Manual Emergency Disconnect.")
			end
		})
	end
end)

-- ==============================================================================
-- DASHBOARD UNIVERSAL
-- ==============================================================================
local DashTab = Window:Tab({ Title = "Dashboard", Icon = "solar:home-2-bold" })
local StatsSection = DashTab:Section({ Title = "Universal System Stats", Opened = true })

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
-- 1. Safety & Player Radar Module
local SafetyModule = _G.CDID_LoadModule("player_detector.lua")
SafetyModule.Init(Window, Utils, Context)

-- 2. Server Manager
local ServerModule = _G.CDID_LoadModule("server_manager.lua")
ServerModule.Init(Window, Utils, Context)

-- 3. BCA Courier
local BCAModule = _G.CDID_LoadModule("bca_courier.lua")
BCAModule.Init(Window, Utils, Context, UICreate, DriveEngine)

-- 4. Merdeka Event Race Farm
local MerdekaModule = _G.CDID_LoadModule("merdeka_farm.lua")
MerdekaModule.Init(Window, Utils, Context, UICreate, DriveEngine)

print("🚀 [CDID Hub] Dimuat sukses dengan Custom Header & Tema Midnight!")
