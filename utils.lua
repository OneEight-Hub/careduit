-- ==============================================================================
-- CDID HUB - UTILITIES (SMART PLATFORM 500x500 & AGGRESSIVE MAP CLEANER)
-- ==============================================================================
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local VirtualUser = game:GetService("VirtualUser")

local Utils = {}
local LocalPlayer = Players.LocalPlayer

-- State Internal Platform
local GiantPlatform = nil
local PlatformConn = nil
local RespawnConn = nil

-- Helper Deteksi Mobil Player
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

-- Helper Pembuatan/Pengecekan Part Platform
local function EnsurePlatformPart()
	if not GiantPlatform or not GiantPlatform.Parent then
		GiantPlatform = Instance.new("Part")
		GiantPlatform.Name = "CDID_SmartPlatform"
		GiantPlatform.Size = Vector3.new(500, 2, 500)
		GiantPlatform.Anchored = true
		GiantPlatform.CanCollide = true
		GiantPlatform.Transparency = 1 -- Ubah ke 0.5 jika ingin melihat bentuk fisiknya
		GiantPlatform.Material = Enum.Material.SmoothPlastic
		GiantPlatform.TopSurface = Enum.SurfaceType.Smooth
		GiantPlatform.Parent = Workspace
	end
	return GiantPlatform
end

-- ==============================================================================
-- 1. SMART DYNAMIC PLATFORM (PLAYER & MOBIL + ANTI-RESPAWN)
-- ==============================================================================
function Utils.StartGiantPlatform()
	EnsurePlatformPart()

	-- A. Proteksi Respawn: Snap platform seketika di bawah karakter baru
	if RespawnConn then RespawnConn:Disconnect() end
	RespawnConn = LocalPlayer.CharacterAdded:Connect(function(newChar)
		local hrp = newChar:WaitForChild("HumanoidRootPart", 10)
		if hrp then
			local plate = EnsurePlatformPart()
			plate.CFrame = CFrame.new(hrp.Position.X, hrp.Position.Y - 3.2, hrp.Position.Z)
			print("🔄 [Safe Platform] Karakter respawn -> Platform di-snap ke posisi spawn baru.")
		end
	end)

	-- B. Heartbeat Per-Frame Tracker (Smart Follow: Mobil vs Player)
	if PlatformConn then PlatformConn:Disconnect() end
	PlatformConn = RunService.Heartbeat:Connect(function()
		local plate = EnsurePlatformPart()

		local char = LocalPlayer.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		local car = GetPlayerCar()

		-- Jangan update jika karakter sedang mati/ragdoll
		if hum and hum.Health <= 0 then return end

		-- Prioritas 1: Jika player sedang menyetir di mobil
		if hum and hum.Sit and car then
			local carPrimary = car.PrimaryPart or car:FindFirstChildWhichIsA("BasePart")
			if carPrimary then
				plate.CFrame = CFrame.new(carPrimary.Position.X, carPrimary.Position.Y - 2.8, carPrimary.Position.Z)
				return
			end
		end

		-- Prioritas 2: Jika player sedang jalan kaki / di luar mobil
		if hrp then
			plate.CFrame = CFrame.new(hrp.Position.X, hrp.Position.Y - 3.2, hrp.Position.Z)
		end
	end)

	print("🛡️ [Safe Platform] Smart Platform 500x500 aktif menopang mobil & player.")
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
	print("🛑 [Safe Platform] Smart Platform dinonaktifkan.")
end

-- ==============================================================================
-- 2. AGGRESSIVE MAP CLEANER (DESTROY MAP, MELAWAI & NON-ESSENTIALS)
-- ==============================================================================
function Utils.DestroyHeavyMaps()
	-- Pastikan platform sudah aktif sebelum map dihapus
	Utils.StartGiantPlatform()

	-- 1. Hapus Total Folder Map
	local map = Workspace:FindFirstChild("Map")
	if map then
		map:Destroy()
		print("🗑️ [Cleaner] Folder Workspace.Map berhasil dihapus total.")
	end

	-- 2. Hapus Total Folder MELAWAI
	local melawai = Workspace:FindFirstChild("MELAWAI") or Workspace:FindFirstChild("Melawai")
	if melawai then
		melawai:Destroy()
		print("🗑️ [Cleaner] Folder Workspace.MELAWAI berhasil dihapus total.")
	end

	-- 3. Hapus Gedung Collab BCA (Kecuali NPC, Job, dan ATM)
	local myBcaCollab = Workspace:FindFirstChild("MY_BCA_COLLAB")
	if myBcaCollab then
		for _, item in ipairs(myBcaCollab:GetChildren()) do
			local name = item.Name:lower()
			if (name:find("building") or name:find("gedung") or name:find("tower")) and not name:find("npc") and not name:find("job") and not name:find("atm") then
				item:Destroy()
			end
		end
	end

	-- 4. Listener jika Map / MELAWAI di-spawn ulang oleh game
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

	-- 5. Optimasi Efek Visual & Lighting
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
-- 3. TELEPORTATION & PROMPT INTERACTION UTILITIES
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

	-- Freeze sesaat selama trigger interaksi
	hrp.Anchored = true

	if fireproximityprompt then
		fireproximityprompt(prompt)
	end

	prompt:InputHoldBegin()
	task.wait(prompt.HoldDuration + 0.1)
	prompt:InputHoldEnd()

	hrp.Anchored = false
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
