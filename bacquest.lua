local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local VirtualUser = game:GetService("VirtualUser")
local StatsService = game:GetService("Stats")

-- ==============================================================================
-- 1. PENGHAPUSAN LANGSUNG (DESTROY) GEDUNG BCA SAAT AWAL EKSEKUSI
-- ==============================================================================
local function DestroyBuildingInstances()
	print("[Startup Cleaner] Menghancurkan (Destroy) BCA Tower / Gedung MyBCA...")

	local map = Workspace:FindFirstChild("Map")
	local building = map and map:FindFirstChild("Building")
	if building then
		local bcaTower = building:FindFirstChild("BCA Tower Thamrin")
		if bcaTower then
			bcaTower:Destroy()
			print("💥 Workspace.Map.Building['BCA Tower Thamrin'] berhasil di-DESTROY!")
		end
	end

	for _, obj in ipairs(Workspace:GetDescendants()) do
		if obj.Name == "BCA Tower Thamrin" then
			obj:Destroy()
			print("💥 Instance BCA Tower Thamrin berhasil di-DESTROY!")
		end
	end

	local myBcaCollab = Workspace:FindFirstChild("MY_BCA_COLLAB")
	if myBcaCollab then
		for _, item in ipairs(myBcaCollab:GetChildren()) do
			local name = item.Name:lower()
			if (name:find("building") or name:find("gedung") or name:find("tower")) and not name:find("npc") and not name:find("job") and not name:find("atm") then
				item:Destroy()
				print("💥 Gedung collab:", item.Name, "berhasil di-DESTROY!")
			end
		end
	end
end

DestroyBuildingInstances()

-- ==============================================================================
-- 2. CLEANUP HOOKS & UI LAMA
-- ==============================================================================
if not _G.BCACourierHooks then _G.BCACourierHooks = {} end
for _, conn in ipairs(_G.BCACourierHooks) do
	pcall(function() conn:Disconnect() end)
end
_G.BCACourierHooks = {}

if _G.AntiAfkConnection then
	pcall(function() _G.AntiAfkConnection:Disconnect() end)
	_G.AntiAfkConnection = nil
end

if _G.KoperLoaderHook then _G.KoperLoaderHook:Disconnect() _G.KoperLoaderHook = nil end
if _G.DeliveryRunnerHook then _G.DeliveryRunnerHook:Disconnect() _G.DeliveryRunnerHook = nil end
if _G.MainCoreHook then _G.MainCoreHook:Disconnect() _G.MainCoreHook = nil end
if _G.MainCoreDialogHook then _G.MainCoreDialogHook:Disconnect() _G.MainCoreDialogHook = nil end
if _G.MainCoreJobHook then _G.MainCoreJobHook:Disconnect() _G.MainCoreJobHook = nil end

if _G.MainCoreSaldoRegistered then _G.MainCoreSaldoRegistered = false end

local PlayerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local oldUI = PlayerGui:FindFirstChild("BCACourierUI")
if oldUI then oldUI:Destroy() end

local session = os.clock()
_G.MainCoreSession = session

local LocalPlayer = Players.LocalPlayer
local Network = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Network"))
local NpcDialogEvent = ReplicatedStorage:WaitForChild("NetworkContainer"):WaitForChild("RemoteEvents"):WaitForChild("NpcDialog")
local JobRemote = ReplicatedStorage:WaitForChild("NetworkContainer"):WaitForChild("RemoteEvents"):WaitForChild("Job")

local ExpectedCarName = LocalPlayer.Name .. "sCar"

-- CONFIGURABLE VALUES
local Config = {
	TweenSpeed = 180,        -- Kecepatan wajar CDID (~60-70 km/jam)
	MinTravelDuration = 20, -- Durasi minimal anti-nerf (detik)
	ActionDelay = 0.3,
	LoopWait = 0.4,
	RestartDelay = 2.0
}

-- State
local State = {
	Total = 0,
	Loaded = 0,
	Carrying = false,
	Phase = "Unemployee",
	TargetPos = nil,
	IsBusy = false,

	AutoFarmActive = false,
	AutoLoading = false,
	AutoDelivering = false,
	LoadingActive = false,
	DeliveryActive = false,
	AntiAfkActive = true
}

-- ==============================================================================
-- 3. FITUR ANTI-AFK OTOMATIS (VIRTUALUSER HOOK)
-- ==============================================================================
_G.AntiAfkConnection = LocalPlayer.Idled:Connect(function()
	if State.AntiAfkActive then
		VirtualUser:CaptureController()
		VirtualUser:ClickButton2(Vector2.new(0, 0))
		print("🛡️ [Anti-AFK] Berhasil menembak VirtualUser input pencegah idle kick.")
	end
end)

-- ─── LOAD WINDUI LIBRARY ───
local WindUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"))()

local Window = WindUI:CreateWindow({
	Title = "BCA Courier Auto-Farm",
	Author = "by ASRock",
	Folder = "bca_courier",
	Icon = "solar:folder-2-bold-duotone",
	NewElements = true,
	HideSearchBar = true,
	OpenButton = {
		Title = "Open Auto-Farm",
		Enabled = true,
		Draggable = true,
		Scale = 0.5
	}
})

-- TAB 1: MAIN COURIER HUB
local MainTab = Window:Tab({
	Title = "Courier Hub",
	Icon = "solar:home-2-bold"
})
local HomeSection = MainTab:Section({ Title = "Auto Farm Controls" })
local SettingsSection = MainTab:Section({ Title = "Konfigurasi Kecepatan & Anti-Nerf" })

-- TAB 2: PINTASAN TELEPORT
local TeleportTab = Window:Tab({
	Title = "Pintasan Teleport",
	Icon = "solar:map-point-bold-duotone"
})
local TeleportSection = TeleportTab:Section({ Title = "Shortcuts Teleport Karakter" })

-- TAB 3: SYSTEM INFO & ANTI-AFK
local InfoTab = Window:Tab({
	Title = "Status & Anti-AFK",
	Icon = "solar:shield-check-bold-duotone"
})
local AntiAfkSection = InfoTab:Section({ Title = "Status Anti-AFK" })
local StatsSection = InfoTab:Section({ Title = "Statistik Performa & Runtime" })

local SafeTeleportChar

TeleportSection:Button({
	Title = "Teleport ke NPC Start (Lobby)",
	Desc = "Teleport instan ke dekat NPC pendaftaran kurir.",
	Callback = function()
		local StartNpc = Workspace:WaitForChild("MY_BCA_COLLAB"):WaitForChild("NPC_START_JOB")
		SafeTeleportChar(StartNpc:GetPivot())
		print("📍 Teleportasi ke NPC Start selesai.")
	end
})

TeleportSection:Button({
	Title = "Teleport ke Spawner Mobil",
	Desc = "Teleport instan ke petugas parkir kendaraan bank.",
	Callback = function()
		local CarSpawner = Workspace:WaitForChild("MY_BCA_COLLAB"):WaitForChild("CAR_SPAWNER_NPC")
		SafeTeleportChar(CarSpawner:GetPivot())
		print("📍 Teleportasi ke Spawner Mobil selesai.")
	end
})

TeleportSection:Button({
	Title = "Teleport ke Rak Koper",
	Desc = "Teleport instan ke area tumpukan koper BCA.",
	Callback = function()
		local KoperSpawn = Workspace:WaitForChild("MY_BCA_COLLAB"):WaitForChild("Job"):WaitForChild("BankCourier"):WaitForChild("KoperSpawn")
		SafeTeleportChar(KoperSpawn:GetPivot())
		print("📍 Teleportasi ke Rak Koper selesai.")
	end
})

local autoFarmToggle
local statusParagraph
local saldoParagraph

-- Info Tab Elements
local antiAfkParagraph = AntiAfkSection:Paragraph({
	Title = "Status Sistem Anti-AFK",
	Desc = "🛡️ Status: AKTIF (Auto VirtualUser Input)",
	Image = "shield"
})

local pingParagraph = StatsSection:Paragraph({
	Title = "Ping Jaringan",
	Desc = "Membaca...",
	Image = "wifi"
})

local fpsParagraph = StatsSection:Paragraph({
	Title = "Frame Rate (FPS)",
	Desc = "Membaca...",
	Image = "monitor"
})

local runtimeParagraph = StatsSection:Paragraph({
	Title = "Total Runtime Script",
	Desc = "00:00:00",
	Image = "clock"
})

-- Helper Reset Kamera
local function ResetPlayerCamera()
	local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
	local hum = char:WaitForChild("Humanoid", 5)
	local camera = Workspace.CurrentCamera
	if camera then
		camera.CameraType = Enum.CameraType.Custom
		camera.CameraSubject = hum
		camera.FieldOfView = 70
	end
end

-- Helper Teleport Halus
SafeTeleportChar = function(targetCFrame)
	local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
	local hrp = char:WaitForChild("HumanoidRootPart", 5)
	if hrp then
		hrp.Anchored = false
		hrp.CFrame = targetCFrame + Vector3.new(0, 1.2, 0)
		hrp.AssemblyLinearVelocity = Vector3.zero
		hrp.AssemblyAngularVelocity = Vector3.zero
		task.wait(Config.ActionDelay)
	end
end

-- Proximity Prompt Trigger
local function TriggerPrompt(prompt, targetPart, isTrunk)
	if not prompt then return false end

	prompt.Enabled = true
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = 35

	local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
	local hrp = char:WaitForChild("HumanoidRootPart", 5)
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
		task.wait(0.2)
	end

	if fireproximityprompt then
		fireproximityprompt(prompt)
	end

	prompt:InputHoldBegin()
	task.wait(prompt.HoldDuration + 0.1)
	prompt:InputHoldEnd()
	return true
end

-- Helper Temukan Mobil
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

local function GetMuatPrompt(bagasiPoint)
	if not bagasiPoint then return nil end
	local prompt = bagasiPoint:FindFirstChild("MuatPrompt")
	if prompt and prompt:IsA("ProximityPrompt") then return prompt end
	for _, p in ipairs(bagasiPoint:GetChildren()) do
		if p:IsA("ProximityPrompt") and p.Name ~= "AmbilPrompt" then return p end
	end
	return nil
end

local function GetAmbilPrompt(bagasiPoint)
	if not bagasiPoint then return nil end
	local prompt = bagasiPoint:FindFirstChild("AmbilPrompt")
	if prompt and prompt:IsA("ProximityPrompt") then return prompt end
	for _, p in ipairs(bagasiPoint:GetChildren()) do
		if p:IsA("ProximityPrompt") and p.Name ~= "MuatPrompt" then return p end
	end
	return nil
end

-- Helper Duduk di Driver Seat
local function EnterDriverSeat(car)
	local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
	local hrp = char:WaitForChild("HumanoidRootPart", 5)
	local hum = char:WaitForChild("Humanoid", 5)

	local seat = car:FindFirstChildWhichIsA("VehicleSeat", true) 
		or car:FindFirstChild("DriveSeat", true) 
		or car:FindFirstChild("DriverSeat", true)

	if not seat then return false end

	local primary = car.PrimaryPart or car:FindFirstChildWhichIsA("BasePart")
	if primary then
		primary.Anchored = false
	end

	if hum.SeatPart == seat or hum.Sit then return true end

	hrp.CFrame = seat.CFrame * CFrame.new(0, 1.2, 1.2)
	task.wait(Config.ActionDelay)

	local drivePrompt = seat:FindFirstChild("PromptDriveSeat", true)
		or seat:FindFirstChildWhichIsA("ProximityPrompt", true)
		or car:FindFirstChild("PromptDriveSeat", true)
		or car:FindFirstChild("ProximityPrompt", true)

	if drivePrompt and drivePrompt.Enabled then
		drivePrompt.RequiresLineOfSight = false
		drivePrompt.MaxActivationDistance = 25
		if fireproximityprompt then 
			fireproximityprompt(drivePrompt) 
		else
			seat:Sit(hum)
		end
		drivePrompt:InputHoldBegin()
		task.wait(drivePrompt.HoldDuration + 0.1)
		drivePrompt:InputHoldEnd()
	else
		seat:Sit(hum)
	end

	local timeout = os.clock()
	while not hum.Sit and (os.clock() - timeout < 2.5) do
		task.wait(0.1)
	end

	return hum.Sit
end

local function ExitDriverSeat(car)
	local char = LocalPlayer.Character
	local hum = char and char:FindFirstChild("Humanoid")
	if hum and hum.Sit then
		hum.Sit = false
		task.wait(Config.ActionDelay)
	end

	if car then
		local primary = car.PrimaryPart or car:FindFirstChildWhichIsA("BasePart")
		if primary then
			primary.Anchored = true
		end
	end
end

-- ==============================================================================
-- SIMULASI MENGEMUDI HUMANIZED (ANTI-CRASH & ANTI-NERF)
-- ==============================================================================
local function DriveCarNaturallyTo(car, targetPos, speed)
	speed = speed or Config.TweenSpeed
	local primary = car.PrimaryPart or car:FindFirstChildWhichIsA("BasePart")
	local seat = car:FindFirstChildWhichIsA("VehicleSeat", true)
	if not primary then return end

	local char = LocalPlayer.Character
	local hum = char and char:FindFirstChild("Humanoid")

	local startCF = car:GetPivot()

	-- Berhenti 14 stud sebelum titik ATM agar mobil tidak menabrak trotoar/bilik
	local dirToAtm = (targetPos - startCF.Position).Unit
	local flatDir = Vector3.new(dirToAtm.X, 0, dirToAtm.Z).Unit
	local parkPos = targetPos - (flatDir * 14) + Vector3.new(0, 1.2, 0)
	local targetCF = CFrame.new(parkPos, parkPos + flatDir)

	local dist = (startCF.Position - parkPos).Magnitude
	local calculatedDuration = dist / speed
	local duration = math.max(Config.MinTravelDuration, calculatedDuration)

	primary.Anchored = false

	local startTime = os.clock()
	print(string.format("🚗 [Safe Park] Menyetir ke titik parkir ATM (Jarak: %.0f stud | Durasi: %.1f dtk)...", dist, duration))

	while (os.clock() - startTime) < duration and State.AutoDelivering do
		if hum and not hum.Sit and seat then
			pcall(function() seat:Sit(hum) end)
		end

		local elapsed = os.clock() - startTime
		local alpha = math.clamp(elapsed / duration, 0, 1)
		local currentCF = startCF:Lerp(targetCF, alpha)

		local currentSpeed = speed
		if alpha > 0.85 then
			local brakeFactor = (1 - alpha) / 0.15
			currentSpeed = math.max(8, speed * brakeFactor)
			if seat then
				pcall(function() seat.ThrottleFloat = 0; seat.Throttle = 0 end)
			end
		else
			if seat then
				pcall(function() seat.ThrottleFloat = 1; seat.Throttle = 1 end)
			end
		end

		car:PivotTo(currentCF)
		primary.AssemblyLinearVelocity = currentCF.LookVector * currentSpeed
		primary.AssemblyAngularVelocity = Vector3.zero

		RunService.Heartbeat:Wait()
	end

	if seat then
		pcall(function()
			seat.ThrottleFloat = 0
			seat.Throttle = 0
			seat.SteerFloat = 0
			seat.Steer = 0
		end)
	end

	for _, p in ipairs(car:GetDescendants()) do
		if p:IsA("BasePart") then
			p.AssemblyLinearVelocity = Vector3.zero
			p.AssemblyAngularVelocity = Vector3.zero
		end
	end

	task.wait(0.15)
	primary.Anchored = true

	for _, p in ipairs(car:GetDescendants()) do
		if p:IsA("BasePart") then
			p.AssemblyLinearVelocity = Vector3.zero
			p.AssemblyAngularVelocity = Vector3.zero
		end
	end

	task.wait(Config.ActionDelay)
end

-- ==============================================================================
-- 4. HOOKS EVENT NETWORK & AUTO PERFECT MINIGAMES
-- ==============================================================================
_G.MainCoreDialogHook = NpcDialogEvent.OnClientEvent:Connect(function(action, data)
	if action == "Start" then
		print("💬 [Dialog] Event dialog diterima -> Menyelesaikan...")
		task.spawn(function()
			task.wait(0.5)
			NpcDialogEvent:FireServer("Finish", nil)

			if firesignal then
				pcall(firesignal, NpcDialogEvent.OnClientEvent, "Abort")
			end

			ResetPlayerCamera()

			local Mf = Workspace:FindFirstChild("MY_BCA_COLLAB")
			if Mf then
				for _, p in ipairs(Mf:GetDescendants()) do
					if p:IsA("ProximityPrompt") then
						p.Enabled = true
					end
				end
			end
		end)
	end
end)
table.insert(_G.BCACourierHooks, _G.MainCoreDialogHook)

_G.MainCoreJobHook = JobRemote.OnClientEvent:Connect(function(action, arg1)
	if action == "SetJob" then
		if arg1 == "BankCourier" then
			State.Phase = "Loading"
			print("💼 [Job State] BankCourier Dimulai.")
		elseif arg1 == "Unemployee" then
			State.Phase = "Unemployee"
			State.Loaded = 0
			State.Total = 0
			print("🛑 [Job State] Kembali ke Unemployee.")
		end
	end
end)
table.insert(_G.BCACourierHooks, _G.MainCoreJobHook)

_G.MainCoreHook = Network.OnClientEvent("BankCourier", function(action, arg1, arg2, arg3, arg4)
	if action == "Start" then
		State.Total = (typeof(arg1) == "table" and arg1.totalKoper) or 0
		State.Phase = "Loading"
		print("📋 Total Koper:", State.Total)

	elseif action == "Phase" then
		State.Phase = arg1
		if typeof(arg4) == "Vector3" then
			State.TargetPos = arg4
		elseif typeof(arg2) == "Vector3" then
			State.TargetPos = arg2
		elseif arg2 and arg2:IsA("BasePart") then
			State.TargetPos = arg2.Position
		end
		print("🔄 Phase:", State.Phase, "| Target ATM:", tostring(State.TargetPos))

	elseif action == "Koper" then
		State.Loaded = arg1
		State.Carrying = (arg4 == true)
		print(string.format("📦 Status Koper: %s/%s | Membawa: %s", tostring(State.Loaded), tostring(State.Total), tostring(State.Carrying)))

	-- ─── 1. AUTO PERFECT MINIGAME: MUAT KOPER (GREEN BAR) ───
	elseif action == "LoadRound" and typeof(arg1) == "table" then
		local greenSize = arg1.greenSize or arg1.greatSize or 0.18
		local greenStart = arg1.greenStart or 0.5
		local period = math.max(arg1.period or 1, 0.1)

		local centerGreen = greenStart + (greenSize / 2)
		local timeToHit = centerGreen * period

		local ping = 0
		pcall(function() ping = (LocalPlayer:GetNetworkPing() or 0) / 2 end)

		local delayTime = timeToHit - ping

		while delayTime < 0.04 do
			delayTime = delayTime + (2 * period)
		end

		local mySession = session
		task.delay(delayTime, function()
			if _G.MainCoreSession ~= mySession then return end
			Network:FireServer("BankCourier", "LoadPress")
			print("✅ [Minigame Koper] LoadPress PERFECT terkirim!")
		end)

	-- ─── 2. AUTO PERFECT MINIGAME: SETOR ATM (SKILL CHECK CIRCLE) ───
	elseif action == "SkillCheck" and typeof(arg1) == "table" then
		local zoneWidth = arg1.greatSize or arg1.zoneSize or 20
		local targetAngle = arg1.zoneStart + (zoneWidth / 2)
		local speed = arg1.speed or 1
		local warnLead = arg1.warnLead or 0

		local ping = 0
		pcall(function() ping = (LocalPlayer:GetNetworkPing() or 0) / 2 end)

		local timeToHit = warnLead + (targetAngle / speed)
		local delayTime = timeToHit - ping

		local rotations = 0
		while delayTime < 0.03 do
			delayTime = delayTime + (360 / speed)
			rotations = rotations + 1
		end

		local angleToSend = targetAngle + (rotations * 360)

		local currentSession = session
		task.delay(delayTime, function()
			if _G.MainCoreSession ~= currentSession then return end
			Network:FireServer("BankCourier", "SkillPress", angleToSend)
			print("✅ [Minigame ATM] SkillPress PERFECT terkirim!")
		end)

	elseif action == "Complete" or action == "Returning" then
		State.Phase = "Returning"
		print("🏁 Semua ATM telah berhasil diisi!")

	elseif action == "Stop" then
		State.Phase = "Unemployee"
		State.Loaded = 0
		State.Total = 0
		print("🛑 Job Berhenti / Gaji Diterima.")
	end
end)
table.insert(_G.BCACourierHooks, _G.MainCoreHook)

-- ==============================================================================
-- 5. AUTOFARM SEQUENCES
-- ==============================================================================
local function Action_StartJob()
	local Mf = Workspace:WaitForChild("MY_BCA_COLLAB")
	local StartNpc = Mf:WaitForChild("NPC_START_JOB")

	if State.Phase == "Loading" or State.Phase == "Delivering" then
		return
	end

	print("[UI] Teleport ke NPC Start...")
	SafeTeleportChar(StartNpc:GetPivot())
	task.wait(0.5)

	local prompt = StartNpc:FindFirstChildWhichIsA("ProximityPrompt", true)
	if prompt then prompt.Enabled = true end

	print("[UI] Mengambil Pekerjaan di NPC Start...")
	TriggerPrompt(prompt, StartNpc.PrimaryPart or StartNpc:FindFirstChildWhichIsA("BasePart"))

	local dialogWait = os.clock()
	while State.Phase == "Unemployee" and (os.clock() - dialogWait < 4) do
		task.wait(0.1)
	end
	task.wait(Config.ActionDelay)
end

local function Action_SpawnVehicle()
	local Mf = Workspace:WaitForChild("MY_BCA_COLLAB")
	local CarSpawner = Mf:WaitForChild("CAR_SPAWNER_NPC")
	print("[UI] Teleport ke Spawner Mobil...")
	SafeTeleportChar(CarSpawner:GetPivot())
	task.wait(0.5)

	local spawnPrompt = CarSpawner:FindFirstChildWhichIsA("ProximityPrompt", true)
	if spawnPrompt then spawnPrompt.Enabled = true end

	print("[UI] Mengeluarkan Kendaraan...")
	TriggerPrompt(spawnPrompt, CarSpawner.PrimaryPart or CarSpawner:FindFirstChildWhichIsA("BasePart"))

	task.wait(1.2)
end

local function RunLoadingLoop()
	if State.LoadingActive then return end
	State.LoadingActive = true
	print("[UI] Auto Load Koper Diaktifkan")

	local Mf = Workspace:WaitForChild("MY_BCA_COLLAB")
	local KoperSpawn = Mf:WaitForChild("Job"):WaitForChild("BankCourier"):WaitForChild("KoperSpawn")

	task.spawn(function()
		while State.AutoLoading do
			if _G.MainCoreSession ~= session then break end
			if State.Phase == "Delivering" or (State.Total > 0 and State.Loaded >= State.Total) then
				print("✅ Semua koper telah berhasil dimuat!")
				State.AutoLoading = false
				break
			end

			local car = GetPlayerCar()
			local bagasiPoint = car and car:FindFirstChild("BagasiPoint", true)
			local muatPrompt = GetMuatPrompt(bagasiPoint)
			local koperPrompt = KoperSpawn:FindFirstChildWhichIsA("ProximityPrompt", true)

			if not State.Carrying and not State.IsBusy then
				State.IsBusy = true
				print("[+] Mengambil koper dari rak...")
				SafeTeleportChar(KoperSpawn:GetPivot())
				TriggerPrompt(koperPrompt, KoperSpawn.PrimaryPart or KoperSpawn:FindFirstChildWhichIsA("BasePart"))

				local timeout = os.clock()
				while not State.Carrying and State.AutoLoading and (os.clock() - timeout < Config.ActionDelay * 10) do
					task.wait(Config.LoopWait / 2)
				end
				State.IsBusy = false
			elseif State.Carrying and not State.IsBusy then
				if bagasiPoint and muatPrompt then
					State.IsBusy = true
					print("[+] Memuat koper ke bagasi...")
					SafeTeleportChar(bagasiPoint.CFrame)
					TriggerPrompt(muatPrompt, bagasiPoint, true)

					local timeout = os.clock()
					while State.Carrying and State.AutoLoading and (os.clock() - timeout < Config.ActionDelay * 13) do
						task.wait(Config.LoopWait / 2)
					end
					State.IsBusy = false
					task.wait(Config.ActionDelay)
				else
					task.wait(Config.LoopWait)
				end
			end
			task.wait(Config.LoopWait)
		end
		State.LoadingActive = false
	end)
end

local function RunDeliveryLoop()
	if State.DeliveryActive then return end
	State.DeliveryActive = true
	print("[UI] Auto Delivery ATM Diaktifkan")

	task.spawn(function()
		while State.AutoDelivering do
			if _G.MainCoreSession ~= session then break end

			-- HANYA BERHENTI JIKA KOPER SUDAH BENAR-BENAR HABIS (ANTI-TURUN DI TENGAH JALAN)
			if (State.Loaded <= 0 and not State.Carrying) or (State.Phase == "Returning" and State.Loaded <= 0) then
				print("✅ Semua koper di bagasi telah selesai disetor ke ATM!")
				State.AutoDelivering = false
				break
			end

			local car = GetPlayerCar()
			local bagasiPoint = car and car:FindFirstChild("BagasiPoint", true)
			local ambilPrompt = GetAmbilPrompt(bagasiPoint)

			if car and not State.IsBusy then
				local char = LocalPlayer.Character
				local hrp = char and char:FindFirstChild("HumanoidRootPart")
				local distToAtm = (hrp and State.TargetPos) and (hrp.Position - State.TargetPos).Magnitude or 999

				-- 1. Naik mobil dan kendarai ke target ATM berikutnya jika jarak masih jauh
				if not State.Carrying and State.TargetPos and distToAtm > 25 then
					State.IsBusy = true
					print(string.format("[+] Menuju target ATM berikutnya (Sisa koper di bagasi: %d)...", State.Loaded))
					EnterDriverSeat(car)
					task.wait(Config.ActionDelay)

					if not State.AutoDelivering then State.IsBusy = false break end

					DriveCarNaturallyTo(car, State.TargetPos, Config.TweenSpeed)

					print("[+] Tiba di parkiran ATM, turun dari kursi kemudi...")
					ExitDriverSeat(car)
					State.IsBusy = false
				end

				if not State.AutoDelivering then break end

				-- 2. Ambil koper dari bagasi
				if not State.Carrying and bagasiPoint and ambilPrompt and distToAtm <= 40 then
					State.IsBusy = true
					print("[+] Mengambil koper dari bagasi...")
					SafeTeleportChar(bagasiPoint.CFrame * CFrame.new(0, 0, 1.8))
					task.wait(0.2)

					TriggerPrompt(ambilPrompt, bagasiPoint, true)

					local waitCarry = os.clock()
					while not State.Carrying and State.AutoDelivering and (os.clock() - waitCarry < Config.ActionDelay * 12) do
						task.wait(Config.LoopWait / 2)
					end
					State.IsBusy = false
				end

				if not State.AutoDelivering then break end

				-- 3. Berpindah tepat ke depan ATM dan setor
				if State.Carrying and State.TargetPos then
					State.IsBusy = true
					print("[+] Berpindah tepat ke depan mesin ATM...")
					SafeTeleportChar(CFrame.new(State.TargetPos + Vector3.new(0, 0, 1.5)))
					task.wait(Config.ActionDelay)

					print("[+] Memulai pengisian ATM...")
					Network:FireServer("BankCourier", "FillStart")

					local waitFill = os.clock()
					while State.Carrying and State.AutoDelivering and (os.clock() - waitFill < Config.ActionDelay * 25) do
						task.wait(Config.LoopWait / 2)
					end
					State.IsBusy = false
					task.wait(Config.ActionDelay)
				end
			end
			task.wait(Config.LoopWait)
		end
		State.DeliveryActive = false
	end)
end

local function Action_ResetAll()
	if not State.AutoFarmActive and _G.MainCoreSession == session then
		return
	end

	print("[UI] Mereset semua proses...")

	session = os.clock()
	_G.MainCoreSession = session

	State.AutoFarmActive = false
	State.AutoLoading = false
	State.AutoDelivering = false
	State.LoadingActive = false
	State.DeliveryActive = false
	State.IsBusy = false
	State.Phase = "Unemployee"
	State.Loaded = 0
	State.Total = 0

	ResetPlayerCamera()

	if autoFarmToggle then 
		pcall(function() autoFarmToggle:Set(false) end)
		pcall(function() autoFarmToggle:SetValue(false) end)
	end
	if statusParagraph then 
		pcall(function() statusParagraph:SetDesc("Phase: Unemployee | Koper: 0/0") end)
	end

	pcall(function()
		local char = LocalPlayer.Character
		local hum = char and char:FindFirstChild("Humanoid")
		if hum and hum.Sit then
			hum.Sit = false
		end
		local car = GetPlayerCar()
		if car then
			local primary = car.PrimaryPart or car:FindFirstChildWhichIsA("BasePart")
			if primary then
				primary.Anchored = false
			end
		end
	end)

	print("✅ Semua proses berhasil di-reset.")
end

-- ==============================================================================
-- 6. WINDUI TOGGLE & CONTROLS
-- ==============================================================================
autoFarmToggle = HomeSection:Toggle({
	Title = "Endless Auto Farm",
	Desc = "Mulai/Hentikan siklus kurir dengan simulasi perjalanan natural.",
	Value = false,
	Callback = function(active)
		if State.AutoFarmActive == active then return end

		State.AutoFarmActive = active
		if active then
			task.spawn(function()
				print("[AutoFarm] Memulai Siklus Pengantaran...")
				while State.AutoFarmActive do
					if _G.MainCoreSession ~= session then break end

					-- 1. Ambil Job
					Action_StartJob()

					local startWait = os.clock()
					while State.Phase == "Unemployee" and (os.clock() - startWait < 8) do
						if _G.MainCoreSession ~= session or not State.AutoFarmActive then return end
						task.wait(Config.LoopWait / 2)
					end
					if not State.AutoFarmActive or _G.MainCoreSession ~= session then break end

					if State.Phase == "Unemployee" then
						warn("⚠️ Gagal mengambil job, mengulang...")
						task.wait(Config.RestartDelay)
						continue
					end

					-- 2. Spawn Mobil
					Action_SpawnVehicle()

					local carWait = os.clock()
					local car = nil
					while os.clock() - carWait < 10 do
						if _G.MainCoreSession ~= session or not State.AutoFarmActive then return end
						car = GetPlayerCar()
						if car then break end
						task.wait(Config.LoopWait / 2)
					end
					if not State.AutoFarmActive or _G.MainCoreSession ~= session then break end

					if not car then
						warn("⚠️ Mobil tidak muncul, mengulang...")
						task.wait(Config.RestartDelay)
						continue
					end

					-- 3. Muat Koper dengan Timeout Safety
					State.AutoLoading = true
					RunLoadingLoop()

					local loadTimeout = os.clock()
					while State.AutoLoading and State.AutoFarmActive and (os.clock() - loadTimeout < 60) do
						if _G.MainCoreSession ~= session then return end
						task.wait(Config.LoopWait)
					end
					if not State.AutoFarmActive or _G.MainCoreSession ~= session then break end

					-- 4. Antar Koper ke ATM (Berdasarkan jumlah sisa koper)
					State.AutoDelivering = true
					RunDeliveryLoop()

					local deliverTimeout = os.clock()
					while State.AutoDelivering and State.AutoFarmActive and (os.clock() - deliverTimeout < 300) do
						if _G.MainCoreSession ~= session then return end
						task.wait(Config.LoopWait)
					end
					if not State.AutoFarmActive or _G.MainCoreSession ~= session then break end

					-- 5. Kembalikan Mobil ke BCA
					print("[AutoFarm] Mengemudikan mobil kembali ke BCA...")
					local returnCar = GetPlayerCar()
					if returnCar then
						EnterDriverSeat(returnCar)
						task.wait(Config.ActionDelay)
						if not State.AutoFarmActive or _G.MainCoreSession ~= session then break end

						local Mf = Workspace:WaitForChild("MY_BCA_COLLAB")
						local CarSpawner = Mf:WaitForChild("CAR_SPAWNER_NPC")
						DriveCarNaturallyTo(returnCar, CarSpawner:GetPivot().Position, Config.TweenSpeed)
						ExitDriverSeat(returnCar)
					end
					if not State.AutoFarmActive or _G.MainCoreSession ~= session then break end

					-- 6. Klaim Gaji di NPC Start
					print("[AutoFarm] Mengambil upah penuh di NPC Start...")
					local Mf = Workspace:WaitForChild("MY_BCA_COLLAB")
					local StartNpc = Mf:WaitForChild("NPC_START_JOB")
					SafeTeleportChar(StartNpc:GetPivot())
					task.wait(0.5)

					local prompt = StartNpc:FindFirstChildWhichIsA("ProximityPrompt", true)
					if prompt then prompt.Enabled = true end

					TriggerPrompt(prompt, StartNpc.PrimaryPart or StartNpc:FindFirstChildWhichIsA("BasePart"))

					print("[AutoFarm] Menunggu pencairan gaji selesai...")
					local endWait = os.clock()
					while State.Phase ~= "Unemployee" and (os.clock() - endWait < 10) do
						if _G.MainCoreSession ~= session or not State.AutoFarmActive then return end
						task.wait(Config.LoopWait / 2)
					end

					task.wait(Config.RestartDelay)
				end

				Action_ResetAll()
				print("[AutoFarm] Siklus dihentikan secara penuh.")
			end)
		else
			Action_ResetAll()
		end
	end
})

statusParagraph = HomeSection:Paragraph({
	Title = "Status Pekerjaan",
	Desc = "Phase: Unemployee | Koper: 0/0",
	Image = "info"
})

saldoParagraph = HomeSection:Paragraph({
	Title = "Saldo BCA Pocket",
	Desc = "Membaca data...",
	Image = "wallet"
})

SettingsSection:Input({
	Title = "Kecepatan Mengemudi (Speed)",
	Desc = "Masukkan kecepatan wajar CDID (studs/detik).",
	Value = tostring(Config.TweenSpeed),
	Placeholder = "Contoh: 70",
	Callback = function(val)
		local num = tonumber(val)
		if num then
			Config.TweenSpeed = num
			print("⚙️ [Config] Kecepatan diubah:", num, "studs/detik")
		end
	end
})

SettingsSection:Slider({
	Title = "Durasi Minimum Perjalanan",
	Desc = "Batas minimal detik perjalanan per rute (Anti-Nerf).",
	Value = { Min = 10, Max = 45, Default = 20 },
	Callback = function(val)
		Config.MinTravelDuration = val
		print("⚙️ [Config] Min Travel Time:", val, "detik")
	end
})

SettingsSection:Slider({
	Title = "Jeda Aksi (Action Delay)",
	Desc = "Jeda waktu interaksi tombol (detik).",
	Value = { Min = 2, Max = 20, Default = 3 },
	Callback = function(val)
		Config.ActionDelay = val / 10
	end
})

SettingsSection:Input({
	Title = "Jeda Mengulang (Restart Delay)",
	Desc = "Jeda waktu tunggu sebelum mencoba kembali setelah gagal (detik).",
	Value = tostring(Config.RestartDelay),
	Placeholder = "Contoh: 2.0",
	Callback = function(val)
		local num = tonumber(val)
		if num then
			Config.RestartDelay = num
			print("⚙️ [Config] Jeda mengulang diubah:", num, "detik")
		end
	end
})

SettingsSection:Button({
	Title = "Paksa Reset Bot (Emergency Reset)",
	Desc = "Menghentikan total semua loop dan melepas semua anchor.",
	Callback = function()
		Action_ResetAll()
		print("⚙️ [Config] Reset manual dipicu dari UI.")
	end
})

Window.Frame.Destroying:Connect(function()
	if _G.MainCoreHook then _G.MainCoreHook:Disconnect() _G.MainCoreHook = nil end
	if _G.MainCoreDialogHook then _G.MainCoreDialogHook:Disconnect() _G.MainCoreDialogHook = nil end
	if _G.MainCoreJobHook then _G.MainCoreJobHook:Disconnect() _G.MainCoreJobHook = nil end
	if _G.AntiAfkConnection then _G.AntiAfkConnection:Disconnect() _G.AntiAfkConnection = nil end
end)

-- ==============================================================================
-- 7. REAL-TIME WINDUI STATUS & SALDO UPDATER
-- ==============================================================================
task.spawn(function()
	while task.wait(0.25) do
		if _G.MainCoreSession ~= session then break end
		
		local statusText = string.format("Phase: %s | Koper: %s/%s", tostring(State.Phase), tostring(State.Loaded), tostring(State.Total))
		pcall(function()
			if statusParagraph then
				statusParagraph:SetDesc(statusText)
			end
		end)
	end
end)

task.spawn(function()
	local function GetSaldoText()
		local container = PlayerGui:FindFirstChild('Container')
		local holder = container and container:FindFirstChild('Holder')
		local appCont = holder and holder:FindFirstChild('AppCountainer')
		local myBca = appCont and appCont:FindFirstChild('MyBca')
		local home = myBca and myBca:FindFirstChild('Home')
		local main = home and home:FindFirstChild('Main')
		local frame = main and main:FindFirstChild('Frame')
		local pocket = frame and frame:FindFirstChild('3b_POCKETRUPIAH')
		local balFr = pocket and pocket:FindFirstChild('BalanceFrame')
		local scroll = balFr and balFr:FindFirstChild('ScrolingFrame')
		local ep = scroll and scroll:FindFirstChild('EventPocket')
		local saldo = ep and ep:FindFirstChild('Saldo')
		return saldo and saldo.Text or nil
	end

	local ok, RC = pcall(function()
		return require(ReplicatedStorage
			:WaitForChild('ClientContainer')
			:WaitForChild('Controller')
			:WaitForChild('ReplicaController'))
	end)

	local function FormatRupiah(val)
		if type(val) ~= 'number' then return tostring(val or '?') end
		local r = string.format('%d', math.floor(val)):reverse():gsub('%d%d%d','%1.'):reverse():gsub('^%.','')
		return 'Rp ' .. r
	end

	if ok and not _G.MainCoreSaldoRegistered then
		_G.MainCoreSaldoRegistered = true
		RC.ReplicaOfClassCreated('Player_' .. LocalPlayer.UserId, function(replica)
			local function GetPocket()
				local c = replica.Data and replica.Data.Collab
				return c and c.MyBca2026 and c.MyBca2026.PocketRupiah
			end
			
			pcall(function()
				if saldoParagraph then
					saldoParagraph:SetDesc(FormatRupiah(GetPocket()))
				end
			end)
			
			replica:ListenToChange({'Collab'}, function()
				pcall(function()
					if saldoParagraph then
						saldoParagraph:SetDesc(FormatRupiah(GetPocket()))
					end
				end)
			end)
		end)
	end

	while task.wait(1) do
		if _G.MainCoreSession ~= session then break end
		local guiText = GetSaldoText()
		if guiText then
			pcall(function()
				if saldoParagraph then
					saldoParagraph:SetDesc(guiText)
				end
			end)
		end
	end
end)

-- ==============================================================================
-- 8. REAL-TIME STATS & RUNTIME MONITOR (FPS, PING, TIMER)
-- ==============================================================================
task.spawn(function()
	local FPS = {}
	local sec = tick()
	local currentFps = 60

	RunService.RenderStepped:Connect(function()
		local fr = tick()
		for index = #FPS, 1, -1 do
			FPS[index + 1] = (FPS[index] >= fr - 1) and FPS[index] or nil
		end
		FPS[1] = fr
		local fpsCalc = (tick() - sec >= 1 and #FPS) or (#FPS / (tick() - sec))
		currentFps = math.floor(fpsCalc)
	end)

	local startTime = os.clock()

	while task.wait(1) do
		if _G.MainCoreSession ~= session then break end

		-- Update Ping
		local pingVal = 0
		pcall(function()
			local perf = StatsService:FindFirstChild("PerformanceStats")
			if perf and perf:FindFirstChild("Ping") then
				pingVal = math.floor(perf.Ping:GetValue())
			else
				pingVal = math.floor((LocalPlayer:GetNetworkPing() or 0) * 1000)
			end
		end)
		
		pcall(function()
			if pingParagraph then
				pingParagraph:SetDesc(string.format("%d ms", pingVal))
			end
		end)

		-- Update FPS
		pcall(function()
			if fpsParagraph then
				fpsParagraph:SetDesc(string.format("%d FPS", currentFps))
			end
		end)

		-- Update Runtime Timer
		local elapsed = math.floor(os.clock() - startTime)
		local hours = math.floor(elapsed / 3600)
		local mins = math.floor((elapsed % 3600) / 60)
		local secs = elapsed % 60
		local timeStr = string.format("%02d:%02d:%02d", hours, mins, secs)

		pcall(function()
			if runtimeParagraph then
				runtimeParagraph:SetDesc(timeStr)
			end
		end)
	end
end)

print("🎉 MainCore Stable Auto-Farm Berhasil Diperbarui!")
