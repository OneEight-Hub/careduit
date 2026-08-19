-- ==============================================================================
-- CDID HUB - LOADER WITH GAME READINESS VALIDATOR
-- ==============================================================================
local BASE_URL = "https://raw.githubusercontent.com/OneEight-Hub/careduit/main/"

-- 1. Validasi Game Loaded
if not game:IsLoaded() then
	game.Loaded:Wait()
end

-- 2. Validasi Player & Character
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()
if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
	LocalPlayer.CharacterAdded:Wait()
end

-- 3. Validasi Container Utama ReplicatedStorage
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local timeout = os.clock()
while not ReplicatedStorage:FindFirstChild("NetworkContainer") and (os.clock() - timeout < 15) do
	task.wait(0.5)
end

-- Loader Function
local function loadModule(path)
	local url = BASE_URL .. path
	local success, content = pcall(function()
		return game:HttpGet(url .. "?nocache=" .. tostring(math.random(1000, 9999)))
	end)
	
	if not success or not content or content == "404: Not Found" then
		error("[Loader Error] Gagal memuat file dari: " .. url)
	end

	local fn, err = loadstring(content)
	if not fn then
		error("[Syntax Error] Gagal parse " .. path .. ": " .. tostring(err))
	end
	return fn()
end

_G.CDID_LoadModule = loadModule
_G.CDID_BaseURL = BASE_URL

loadModule("init.lua")
