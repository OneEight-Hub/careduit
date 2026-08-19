-- ==============================================================================
-- CDID HUB - MAIN INITIALIZER
-- ==============================================================================
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StatsService = game:GetService("Stats")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

-- Bersihkan Hook Sesi Sebelumnya
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

-- Load Utils & Anti-AFK
local Utils = _G.CDID_LoadModule("utils.lua")
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

-- DASHBOARD TAB
local DashTab = Window:Tab({ Title = "Dashboard", Icon = "solar:home-2-bold" })
local StatsSection = DashTab:Section({ Title = "System & Game Stats" })

local saldoParagraph = StatsSection:Paragraph({ Title = "Saldo BCA Pocket", Desc = "Menunggu masuk ke map..." })
local fpsParagraph = StatsSection:Paragraph({ Title = "Frame Rate (FPS)", Desc = "Membaca..." })
local pingParagraph = StatsSection:Paragraph({ Title = "Ping Jaringan", Desc = "Membaca..." })
local runtimeParagraph = StatsSection:Paragraph({ Title = "Runtime Hub", Desc = "00:00:00" })

-- Safe Saldo Listener (Non-blocking lobby check)
task.spawn(function()
	local function FormatRupiah(val)
		if type(val) ~= 'number' then return tostring(val or '?') end
		local r = string.format('%d', math.floor(val)):reverse():gsub('%d%d%d','%1.'):reverse():gsub('^%.','')
		return 'Rp ' .. r
	end

	while task.wait(2) do
		if Context.Session ~= _G.MainCoreSession then break end

		local clientCont = ReplicatedStorage:FindFirstChild("ClientContainer")
		local controller = clientCont and clientCont:FindFirstChild("Controller")
		local replicaMod = controller and controller:FindFirstChild("ReplicaController")

		if replicaMod and not _G.MainCoreSaldoRegistered then
			local ok, RC = pcall(require, replicaMod)
			if ok and RC then
				_G.MainCoreSaldoRegistered = true
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
		end
	end
end)

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
BCAModule.Init(Window, Utils, Context)

print("🚀 CDID Hub Loaded Successfully!")
