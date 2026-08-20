-- ==============================================================================
-- CDID HUB - UTILITIES (SAFE SMART PLATFORM & CLEANER - FIXED NO ELEVATOR)
-- ==============================================================================
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local VirtualUser = game:GetService("VirtualUser")

local Utils = {}
local LocalPlayer = Players.LocalPlayer

-- State Platform
local GiantPlatform = nil
local PlatformConn = nil
local RespawnConn = nil
local CurrentBaseY = nil -- Kunci ketinggian agar tidak terjadi efek eskalator

local function GetPlayerCar()
	local vehicles = Workspace:FindFirstChild("Vehicles")
	if not vehicles then return nil end
	for _, v in ipairs(vehicles:GetChildren()) do
		if v.Name:find(LocalPlayer.Name, 1, true) then
			return v
		end
	end
	return nil
end

local function EnsurePlatformPart()
	if not GiantPlatform or not GiantPlatform.Parent then
		GiantPlatform = Instance.new("Part")
		GiantPlatform.Name = "CDID_SmartPlatform"
		GiantPlatform.Size = Vector3.new(600, 2, 600)
		GiantPlatform.Anchored = true
		GiantPlatform.CanCollide = true
		GiantPlatform.Transparency = 1 -- Transparan penuh agar tidak mengganggu visual
		GiantPlatform.Material = Enum.Material.SmoothPlastic
		GiantPlatform.TopSurface = Enum.SurfaceType.Smooth
		GiantPlatform.Parent = Workspace
	end
	return GiantPlatform
end

-- ==============================================================================
-- 1. SMART DYNAMIC PLATFORM (ANTI-ELEVATOR & STATIC BASE HEIGHT LOCK)
-- ==============================================================================
function Utils.StartGiantPlatform()
	EnsurePlatformPart()

	-- Set Ketinggian Awal Lantai (Dikunci dari titik spawn)
	local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
	local initHrp = char:WaitForChild("HumanoidRootPart", 5)
	if initHrp then
		CurrentBaseY = initHrp.Position.Y - 3.5
	else
		CurrentBaseY = 0
	end

	-- A. Proteksi Respawn (Update ketinggian jika karakter respawn)
	if RespawnConn then RespawnConn:Disconnect() end
	RespawnConn = LocalPlayer.CharacterAdded:Connect(function(newChar)
		local hrp = newChar:WaitForChild("HumanoidRootPart", 10)
		if hrp then
			CurrentBaseY = hrp.Position.Y - 3.5
			local plate = EnsurePlatformPart()
			plate.CFrame = CFrame.new(hrp.Position.X, CurrentBaseY, hrp.Position.Z)
			print("🔄 [Safe Platform] Karakter respawn -> Base Y di-update.")
		end
	end)

	-- B. Tracker Heartbeat (Hanya ikuti X dan Z, Y dikunci agar tidak naik ke langit!)
	if PlatformConn then PlatformConn:Disconnect() end
	PlatformConn = RunService.Heartbeat:Connect(function()
		local plate = EnsurePlatformPart()

		local curChar = LocalPlayer.Character
		local hum = curChar and curChar:FindFirstChildOfClass("Humanoid")
		local hrp = curChar and curChar:FindFirstChild("HumanoidRootPart")
		local car = GetPlayerCar()

		if hum and hum.Health <= 0 then return end

		-- 1. Jika sedang di dalam mobil
		if hum and hum.Sit and car then
			local carPrimary = car.PrimaryPart or car:FindFirstChildWhichIsA("BasePart")
			if carPrimary then
				-- Ketinggian platform menyesuaikan mobil dengan aman
				plate.CFrame = CFrame.new(carPrimary.Position.X, carPrimary.Position.Y - 3.0, carPrimary.Position.Z)
				CurrentBaseY = carPrimary.Position.Y - 3.0
				return
			end
		end

		-- 2. Jika jalan kaki / berdiri (Gunakan X dan Z dari HRP, tapi Y tetap stabil!)
		if hrp then
			-- Jika player pindah area tinggi (misal lantai 2), update secara bertahap bukan per-frame micro
			if math.abs((hrp.Position.Y - 3.5) - CurrentBaseY) > 8 then
				CurrentBaseY = hrp.Position.Y - 3.5
			end

			plate.CFrame = CFrame.new(hrp.Position.X, CurrentBaseY, hrp.Position.Z)
		end
	end)

	print("🛡️ [Safe Platform] Smart Platform Anti-Elevator aktif.")
end

function Utils.StopGiantPlatform()
	if PlatformConn then
		PlatformConn:Disconnect()
		PlatformConn = nil
	end
	if RespawnConn then
		RespawnConn:Disconnect()
		RespawnConn = nil
	end
	if GiantPlatform then
		GiantPlatform:Destroy()
		GiantPlatform = nil
	end
	CurrentBaseY = nil
	print("🛑 [Safe Platform] Smart Platform dinonaktifkan.")
end

-- ==============================================================================
-- 2. MAP CLEANER (HANYA HAPUS MAP & MELAWAI, MY_BCA_COLLAB UTUH 100%)
-- ==============================================================================
function Utils.DestroyHeavyMaps()
	-- Aktifkan platform terlebih dahulu
	Utils.StartGiantPlatform()

	-- 1. Hapus Folder Map
	local map = Workspace:FindFirstChild("Map")
	if map then
		map:Destroy()
		print("🗑️ [Cleaner] Workspace.Map berhasil dihapus total.")
	end

	-- 2. Hapus Folder MELAWAI
	local melawai = Workspace:FindFirstChild("MELAWAI") or Workspace:FindFirstChild("Melawai")
	if melawai then
		melawai:Destroy()
		print("🗑️ [Cleaner] Workspace.MELAWAI berhasil dihapus total.")
	end

	-- 3. Listener jika Map / MELAWAI di-spawn ulang oleh game
	if not _G.CDID_MapDestroyListener then
		_G.CDID_MapDestroyListener = Workspace.ChildAdded:Connect(function(child)
			local name = child.Name:upper()
			if name == "MAP" or name == "MELAWAI" then
				task.wait(0.1)
				child:Destroy()
				print("🗑️ [Cleaner] Map respawn berhasil dicegat & dihapus.")
			end
		end)
	end

	-- 4. Optimasi Lighting & Partikel
	Utils.EnablePerformanceMode()
end

function Utils.EnablePerformanceMode()
	Lighting.GlobalShadows = false
	Lighting.FogEnd = 9e9
	Lighting.Brightness = 1

	for _, effect in ipairs(Lighting:GetChildren()) do
		if effect:IsA("PostProcessEffect") or effect:IsA("BloomEffect") or effect:IsA("BlurEffect") or effect:IsA("SunRaysEffect") or effect:IsA("ColorCorrectionEffect") then
			effect.Enabled = false
		end
	end

	for _, obj in ipairs(Workspace:GetDescendants()) do
		if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Smoke") or obj:IsA("Fire") or obj:IsA("Sparkles") then
			obj.Enabled = false
		end
	end

	if not _G.CDID_ParticlesListener then
		_G.CDID_ParticlesListener = Workspace.DescendantAdded:Connect(function(newObj)
			if newObj:IsA("ParticleEmitter") or newObj:IsA("Trail") or newObj:IsA("Smoke") or newObj:IsA("Fire") or newObj:IsA("Sparkles") then
				newObj.Enabled = false
			end
		end)
	end
end

-- ==============================================================================
-- 3. UTILITIES INTERAKSI & ANTI AFK
-- ==============================================================================
function Utils.SafeTeleportChar(targetCFrame, delayTime)
	local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if hrp then
		hrp.Anchored = false
		hrp.CFrame = targetCFrame + Vector3.new(0, 1.2, 0)
		hrp.AssemblyLinearVelocity = Vector3.zero
		hrp.AssemblyAngularVelocity = Vector3.zero
		if delayTime and delayTime > 0 then task.wait(delayTime) end
	end
end

function Utils.TriggerPrompt(prompt, targetPart, isTrunk)
	if not prompt then return false end
	prompt.Enabled = true
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = 35

	local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return false end

	if targetPart then
		hrp.Anchored = false
		if isTrunk then
			hrp.CFrame = CFrame.new(targetPart.Position + (targetPart.CFrame.LookVector * -1.8), targetPart.Position)
		else
			hrp.CFrame = targetPart.CFrame * CFrame.new(0, 0, 1.5)
		end
		hrp.AssemblyLinearVelocity = Vector3.zero
		hrp.AssemblyAngularVelocity = Vector3.zero
		task.wait(0.1)
	end

	if fireproximityprompt then
		fireproximityprompt(prompt)
	else
		prompt:InputHoldBegin()
		task.wait(prompt.HoldDuration + 0.1)
		prompt:InputHoldEnd()
	end

	return true
end

function Utils.SetupAntiAFK()
	if _G.AntiAfkConnection then pcall(function() _G.AntiAfkConnection:Disconnect() end) end
	_G.AntiAfkConnection = LocalPlayer.Idled:Connect(function()
		VirtualUser:CaptureController()
		VirtualUser:ClickButton2(Vector2.new(0, 0))
	end)
end

return Utils
