local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

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
if _G.KoperLoaderHook then _G.KoperLoaderHook:Disconnect() _G.KoperLoaderHook = nil end
if _G.DeliveryRunnerHook then _G.DeliveryRunnerHook:Disconnect() _G.DeliveryRunnerHook = nil end
if _G.MainCoreHook then _G.MainCoreHook:Disconnect() _G.MainCoreHook = nil end
if _G.MainCoreDialogHook then _G.MainCoreDialogHook:Disconnect() _G.MainCoreDialogHook = nil end
if _G.MainCoreJobHook then _G.MainCoreJobHook:Disconnect() _G.MainCoreJobHook = nil end

-- Guard: reset flag saldo RC agar re-run tidak skip registrasi
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
	TweenSpeed = 140,
	ActionDelay = 0.3,
	LoopWait = 0.5,
	RestartDelay = 2.5
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
	DeliveryActive = false
}

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

local MainTab = Window:Tab({
	Title = "Courier Hub",
	Icon = "solar:home-2-bold"
})

local HomeSection = MainTab:Section({
	Title = "Auto Farm Controls"
})

local SettingsSection = MainTab:Section({
	Title = "Konfigurasi Alur Kecepatan & Jeda"
})

local autoFarmToggle
local statusParagraph
local saldoParagraph

-- Helper Saldo
local function GetSaldoInstance()
	local container = PlayerGui:FindFirstChild("Container")
	if container then
		local holder = container:FindFirstChild("Holder")
		local appContainer = holder and holder:FindFirstChild("AppCountainer")
		local myBca = appContainer and appContainer:FindFirstChild("MyBca")
		local home = myBca and myBca:FindFirstChild("Home")
		local main = home and home:FindFirstChild("Main")
		local frame = main and main:FindFirstChild("Frame")
		local pocket = frame and frame:FindFirstChild("3b_POCKETRUPIAH")
		local balanceFrame = pocket and pocket:FindFirstChild("BalanceFrame")
		local scroll = balanceFrame and balanceFrame:FindFirstChild("ScrolingFrame")
		local eventPocket = scroll and scroll:FindFirstChild("EventPocket")
		local saldo = eventPocket and eventPocket:FindFirstChild("Saldo")
		if saldo then
			return saldo
		end
	end

	for _, child in ipairs(PlayerGui:GetDescendants()) do
		if child:IsA("TextLabel") and child.Name == "Saldo" then
			if child:FindFirstAncestor("3b_POCKETRUPIAH") then
				return child
			end
		end
	end
	return nil
end

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

-- Teleport Karakter Langsung ke Depan NPC
local function SafeTeleportChar(targetCFrame)
	local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
	local hrp = char:WaitForChild("HumanoidRootPart", 5)
	if hrp then
		hrp.CFrame = targetCFrame + Vector3.new(0, 1.2, 0)
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
		if isTrunk then
			hrp.CFrame = CFrame.new(targetPart.Position + (targetPart.CFrame.LookVector * -1.8), targetPart.Position)
		else
			hrp.CFrame = targetPart.CFrame * CFrame.new(0, 0, 1.5)
		end
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

-- Helper Kendaraan
local function GetPlayerCar()
	local vehicles = Workspace:FindFirstChild("Vehicles")
	if not vehicles then return nil end
	return vehicles:FindFirstChild(ExpectedCarName) or vehicles:FindFirstChild(LocalPlayer.Name .. "'sCar")
end

local function GetMuatPrompt(bagasiPoint)
	if not bagasiPoint then return nil end
	local prompt = bagasiPoint:FindFirstChild("MuatPrompt")
	if prompt and prompt:IsA("ProximityPrompt") then
		return prompt
	end
	for _, p in ipairs(bagasiPoint:GetChildren()) do
		if p:IsA("ProximityPrompt") and p.Name ~= "AmbilPrompt" then
			return p
		end
	end
	return nil
end

local function GetAmbilPrompt(bagasiPoint)
	if not bagasiPoint then return nil end
	local prompt = bagasiPoint:FindFirstChild("AmbilPrompt")
	if prompt and prompt:IsA("ProximityPrompt") then
		return prompt
	end
	for _, p in ipairs(bagasiPoint:GetChildren()) do
		if p:IsA("ProximityPrompt") and p.Name ~= "MuatPrompt" then
			return p
		end
	end
	return nil
end

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

	hrp.CFrame = seat.CFrame * CFrame.new(0, 1.2, 1.5)
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
		task.wait(drivePrompt.HoldDuration + Config.ActionDelay / 2)
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
			print("[Physics] Kendaraan berhasil di-anchor.")
		end
	end
end

local function TweenCarTo(car, targetPos, speed)
	speed = speed or Config.TweenSpeed
	local primary = car.PrimaryPart or car:FindFirstChildWhichIsA("BasePart")
	if not primary then return end

	local startCF = car:GetPivot()
	local targetCF = CFrame.new(targetPos + Vector3.new(0, 4, 0))
	local dist = (startCF.Position - targetCF.Position).Magnitude
	local duration = math.max(0.5, dist / speed)

	local wasAnchored = primary.Anchored
	primary.Anchored = true

	local cfVal = Instance.new("CFrameValue")
	cfVal.Value = startCF

	local conn = cfVal.Changed:Connect(function(newCF)
		car:PivotTo(newCF)
	end)

	local tween = TweenService:Create(
		cfVal, 
		TweenInfo.new(duration, Enum.EasingStyle.Linear), 
		{Value = targetCF}
	)

	print(string.format("🚗 Tweening mobil menuju lokasi (Jarak: %.0f stud, Kecepatan: %.0f, Durasi: %.1f dtk)...", dist, speed, duration))
	tween:Play()
	tween.Completed:Wait()

	conn:Disconnect()
	cfVal:Destroy()
	primary.Anchored = wasAnchored

	for _, p in ipairs(car:GetDescendants()) do
		if p:IsA("BasePart") then
			p.AssemblyLinearVelocity = Vector3.zero
			p.AssemblyAngularVelocity = Vector3.zero
		end
	end
	task.wait(Config.ActionDelay)
end

-- ==============================================================================
-- 3. HOOKS EVENT NETWORK & DIALOG SINKRONISASI
-- ==============================================================================
_G.MainCoreDialogHook = NpcDialogEvent.OnClientEvent:Connect(function(action, data)
	if action == "Start" then
		print("💬 [Dialog] Event dialog diterima -> Menyelesaikan ke server & client...")
		task.spawn(function()
			task.wait(0.5)

			-- 1. Beritahu Server bahwa dialog telah disetujui/diselesaikan
			NpcDialogEvent:FireServer("Finish", nil)

			-- 2. Tembak event "Abort" ke OnClientEvent lokal agar LocalScript game mereset kamera & tabel v_u_28
			if firesignal then
				pcall(firesignal, NpcDialogEvent.OnClientEvent, "Abort")
			end

			-- 3. Reset kamera lokal (Fail-safe)
			ResetPlayerCamera()

			-- 4. Paksa nyalakan semua ProximityPrompt NPC
			local Mf = Workspace:FindFirstChild("MY_BCA_COLLAB")
			if Mf then
				for _, p in ipairs(Mf:GetDescendants()) do
					if p:IsA("ProximityPrompt") then
						p.Enabled = true
					end
				end
			end
			print("✅ [Dialog] Dialog selesai, kamera direset, dan ProximityPrompt aktif kembali!")
		end)
	end
end)

_G.MainCoreJobHook = JobRemote.OnClientEvent:Connect(function(action, arg1)
	if action == "SetJob" then
		if arg1 == "BankCourier" then
			State.Phase = "Loading"
			print("💼 [Job State] Karakter sekarang adalah BankCourier (Job Dimulai).")
		elseif arg1 == "Unemployee" then
			State.Phase = "Unemployee"
			State.Loaded = 0
			State.Total = 0
			print("🛑 [Job State] Karakter sekarang adalah Unemployee (Job Berakhir).")
		end
	end
end)

_G.MainCoreHook = Network.OnClientEvent("BankCourier", function(action, arg1, arg2, arg3, arg4)
	if action == "Start" then
		State.Total = (typeof(arg1) == "table" and arg1.totalKoper) or 0
		State.Phase = "Loading"
		print("📋 Total Koper Dibutuhkan:", State.Total)

	elseif action == "Phase" then
		State.Phase = arg1
		if typeof(arg4) == "Vector3" then
			State.TargetPos = arg4
		elseif typeof(arg2) == "Vector3" then
			State.TargetPos = arg2
		elseif arg2 and arg2:IsA("BasePart") then
			State.TargetPos = arg2.Position
		end
		print("🔄 Phase Berganti:", State.Phase, "| Target Pos:", tostring(State.TargetPos))

	elseif action == "Koper" then
		State.Loaded = arg1
		State.Carrying = (arg4 == true)
		print(string.format("📦 Status Koper: %s/%s di mobil | Membawa: %s", tostring(State.Loaded), tostring(State.Total), tostring(State.Carrying)))


	elseif action == "LoadRound" and typeof(arg1) == "table" then
		-- Auto-solve Green Bar minigame: presisi penuh, skip 1 period saja
		local greenSize = arg1.greenSize or arg1.greatSize or 0.15
		local greenStart = arg1.greenStart or 0.5
		local period = math.max(arg1.period or 1, 0.1)

		-- Sample ping 3x, ambil nilai terkecil (paling optimis / worst-case untuk timing awal)
		local ping = math.huge
		for _ = 1, 3 do
			pcall(function() local p = LocalPlayer:GetNetworkPing(); if p < ping then ping = p end end)
			task.wait(0)
		end
		if ping == math.huge or ping ~= ping then ping = 0 end

		-- Target 40% dalam area hijau (lebih safe dari edge kanan)
		local centerGreen = greenStart + (greenSize * 0.4)
		local timeToHit = centerGreen * period

		-- Delay = waktu ke target - ping - 25ms processing lag
		local delayTime = timeToHit - ping - 0.025

		-- Skip 1 period (bukan 2) agar tidak terlalu jauh melewati momen
		local skipCount = 0
		while delayTime < 0.02 do
			delayTime = delayTime + period
			skipCount += 1
		end

		print(string.format("[LoadRound] start=%.2f size=%.2f period=%.2f target=%.2f ping=%.0fms delay=%.3fs skip=%d",
			greenStart, greenSize, period, centerGreen, ping*1000, delayTime, skipCount))

		local mySession = session
		task.delay(delayTime, function()
			if _G.MainCoreSession ~= mySession then return end
			Network:FireServer("BankCourier", "LoadPress")
			print("[LoadRound] LoadPress dikirim!")
		end)
	elseif action == "SkillCheck" and typeof(arg1) == "table" then
		local zoneWidth = arg1.greatSize or arg1.zoneSize or 20
		local targetAngle = arg1.zoneStart + (zoneWidth / 2)
		local speed = arg1.speed or 1
		local warnLead = arg1.warnLead or 0

		local ping = LocalPlayer:GetNetworkPing()
		local timeToHit = warnLead + (targetAngle / speed)
		local delayTime = timeToHit - ping

		local rotations = 0
		while delayTime < 0.05 do
			delayTime = delayTime + (360 / speed)
			rotations = rotations + 1
		end

		local angleToSend = targetAngle + (rotations * 360)

		task.delay(delayTime, function()
			if _G.MainCoreSession ~= session then return end
			Network:FireServer("BankCourier", "SkillPress", angleToSend)
			print("✅ SkillPress terkirim!")
		end)

	elseif action == "Complete" or action == "Returning" then
		State.Phase = "Returning"
		print("🏁 Semua ATM telah berhasil diisi!")

	elseif action == "Stop" then
		State.Phase = "Unemployee"
		State.Loaded = 0
		State.Total = 0
		print("🛑 Job Berhenti / Gaji Diterima (Kembali ke Status Unemployee).")
	end
end)

-- ==============================================================================
-- 4. AUTOFARM SEQUENCES
-- ==============================================================================
local function Action_StartJob()
	local Mf = Workspace:WaitForChild("MY_BCA_COLLAB")
	local StartNpc = Mf:WaitForChild("NPC_START_JOB")

	if State.Phase == "Loading" or State.Phase == "Delivering" then
		print("ℹ️ Job sudah aktif di memori. Melompati pendaftaran.")
		return
	end

	print("[UI] Teleport ke NPC Start...")
	SafeTeleportChar(StartNpc:GetPivot())
	task.wait(1)

	local prompt = StartNpc:FindFirstChildWhichIsA("ProximityPrompt", true)
	if prompt then
		prompt.Enabled = true
	end

	print("[UI] Mengaktifkan ProximityPrompt NPC Start...")
	TriggerPrompt(prompt, StartNpc.PrimaryPart or StartNpc:FindFirstChildWhichIsA("BasePart"))

	-- Tunggu respons pergantian job dari server
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
	task.wait(1)

	local spawnPrompt = CarSpawner:FindFirstChildWhichIsA("ProximityPrompt", true)
	if spawnPrompt then
		spawnPrompt.Enabled = true
	end

	print("[UI] Mengaktifkan ProximityPrompt Spawner Mobil...")
	TriggerPrompt(spawnPrompt, CarSpawner.PrimaryPart or CarSpawner:FindFirstChildWhichIsA("BasePart"))

	task.wait(1.5)
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
				print("[+] Mengambil koper baru dari rak...")
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
					print("[+] Memuat koper ke bagasi mobil...")
					SafeTeleportChar(bagasiPoint.CFrame)
					TriggerPrompt(muatPrompt, bagasiPoint, true)

					local timeout = os.clock()
					while State.Carrying and State.AutoLoading and (os.clock() - timeout < Config.ActionDelay * 13) do
						task.wait(Config.LoopWait / 2)
					end
					State.IsBusy = false
					task.wait(Config.ActionDelay)
				else
					warn("⚠️ Menunggu MuatPrompt di BagasiPoint aktif...")
					task.wait(Config.LoopWait)
				end
			end
			task.wait(Config.LoopWait)
		end
		State.LoadingActive = false
		print("[UI] Auto Load Koper Dihentikan")
	end)
end

local function RunDeliveryLoop()
	if State.DeliveryActive then return end
	State.DeliveryActive = true
	print("[UI] Auto Delivery ATM Diaktifkan")

	task.spawn(function()
		while State.AutoDelivering do
			if _G.MainCoreSession ~= session then break end
			if State.Phase == "Returning" or State.Phase == "Complete" then
				print("✅ Rute pengiriman selesai!")
				State.AutoDelivering = false
				break
			end

			local car = GetPlayerCar()
			local bagasiPoint = car and car:FindFirstChild("BagasiPoint", true)
			local ambilPrompt = GetAmbilPrompt(bagasiPoint)

			if State.Phase == "Delivering" and car and not State.IsBusy then
				local char = LocalPlayer.Character
				local hrp = char and char:FindFirstChild("HumanoidRootPart")
				local distToAtm = (hrp and State.TargetPos) and (hrp.Position - State.TargetPos).Magnitude or 999

				if not State.Carrying and State.TargetPos and distToAtm > 35 then
					State.IsBusy = true
					print("[+] Masuk ke DriverSeat...")
					EnterDriverSeat(car)
					task.wait(Config.ActionDelay)

					if not State.AutoDelivering then State.IsBusy = false break end

					print("[+] Tween mobil menuju lokasi ATM...")
					TweenCarTo(car, State.TargetPos + Vector3.new(0, 0, 10), Config.TweenSpeed)

					print("[+] Keluar dari DriverSeat...")
					ExitDriverSeat(car)
					State.IsBusy = false
				end

				if not State.AutoDelivering then break end

				if not State.Carrying and bagasiPoint and ambilPrompt and distToAtm <= 40 then
					State.IsBusy = true
					print("[+] Mengambil koper dari bagasi...")
					SafeTeleportChar(bagasiPoint.CFrame)
					TriggerPrompt(ambilPrompt, bagasiPoint)

					local waitCarry = os.clock()
					while not State.Carrying and State.AutoDelivering and (os.clock() - waitCarry < Config.ActionDelay * 10) do
						task.wait(Config.LoopWait / 2)
					end
					State.IsBusy = false
				end

				if not State.AutoDelivering then break end

				if State.Carrying and State.TargetPos then
					State.IsBusy = true
					print("[+] Berteleportasi ke ATM & menyetor uang...")
					SafeTeleportChar(CFrame.new(State.TargetPos))
					task.wait(Config.ActionDelay)

					Network:FireServer("BankCourier", "FillStart")

					local waitFill = os.clock()
					while State.Carrying and State.AutoDelivering and (os.clock() - waitFill < Config.ActionDelay * 23) do
						task.wait(Config.LoopWait / 2)
					end
					State.IsBusy = false
					task.wait(Config.ActionDelay)
				end
			end
			task.wait(Config.LoopWait)
		end
		State.DeliveryActive = false
		print("[UI] Auto Delivery ATM Dihentikan")
	end)
end

local function Action_ResetAll()
	if not State.AutoFarmActive and _G.MainCoreSession == session then
		return
	end

	print("[UI] Mereset dan menonaktifkan semua proses...")

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
		pcall(function() statusParagraph:SetText("Phase: Unemployee | Koper: 0/0") end)
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

	print("✅ Semua proses berhasil dihentikan & di-reset.")
end

-- ==============================================================================
-- 5. WINDUI TOGGLE & CONTROLS
-- ==============================================================================
autoFarmToggle = HomeSection:Toggle({
	Title = "Endless Auto Farm",
	Desc = "Mulai/Hentikan siklus farm otomatis pekerjaan Bank Courier.",
	Value = false,
	Callback = function(active)
		if State.AutoFarmActive == active then return end

		State.AutoFarmActive = active
		if active then
			task.spawn(function()
				print("[AutoFarm] Memulai Loop Siklus Pekerjaan...")
				while State.AutoFarmActive do
					if _G.MainCoreSession ~= session then break end

					-- 1. Mulai Pekerjaan
					Action_StartJob()

					local startWait = os.clock()
					while State.Phase == "Unemployee" and (os.clock() - startWait < 8) do
						if _G.MainCoreSession ~= session or not State.AutoFarmActive then return end
						task.wait(Config.LoopWait / 2)
					end
					if not State.AutoFarmActive or _G.MainCoreSession ~= session then break end

					if State.Phase == "Unemployee" then
						warn("⚠️ Pekerjaan gagal dimulai, mengulang pendaftaran...")
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
						warn("⚠️ Mobil tidak berhasil di-spawn, mengulang pendaftaran dari awal...")
						task.wait(Config.RestartDelay)
						continue
					end

					local primary = car.PrimaryPart or car:FindFirstChildWhichIsA("BasePart")
					if primary then
						primary.Anchored = true
						print("[Physics] Mobil baru di-spawn, langsung di-anchor.")
					end

					-- 3. Muat Koper ke Bagasi Mobil
					State.AutoLoading = true
					RunLoadingLoop()

					while State.AutoLoading and State.AutoFarmActive do
						if _G.MainCoreSession ~= session then return end
						task.wait(Config.LoopWait)
					end
					if not State.AutoFarmActive or _G.MainCoreSession ~= session then break end

					-- 4. Kirim Uang ke ATM
					State.AutoDelivering = true
					RunDeliveryLoop()

					while State.AutoDelivering and State.AutoFarmActive do
						if _G.MainCoreSession ~= session then return end
						task.wait(Config.LoopWait)
					end
					if not State.AutoFarmActive or _G.MainCoreSession ~= session then break end

					-- 5. Kembalikan Mobil ke BCA
					print("[AutoFarm] Mengembalikan mobil ke kantor BCA...")
					local returnCar = GetPlayerCar()
					if returnCar then
						EnterDriverSeat(returnCar)
						task.wait(Config.ActionDelay)
						if not State.AutoFarmActive or _G.MainCoreSession ~= session then break end

						local Mf = Workspace:WaitForChild("MY_BCA_COLLAB")
						local CarSpawner = Mf:WaitForChild("CAR_SPAWNER_NPC")
						TweenCarTo(returnCar, CarSpawner:GetPivot().Position, Config.TweenSpeed)
						ExitDriverSeat(returnCar)
					end
					if not State.AutoFarmActive or _G.MainCoreSession ~= session then break end

					-- 6. Teleport ke NPC Start untuk klaim gaji & akhiri job
					print("[AutoFarm] Klaim gaji di NPC Start...")
					local Mf = Workspace:WaitForChild("MY_BCA_COLLAB")
					local StartNpc = Mf:WaitForChild("NPC_START_JOB")
					SafeTeleportChar(StartNpc:GetPivot())
					task.wait(1)

					local prompt = StartNpc:FindFirstChildWhichIsA("ProximityPrompt", true)
					if prompt then
						prompt.Enabled = true
					end

					print("[AutoFarm] Mengaktifkan ProximityPrompt NPC Start untuk klaim gaji...")
					TriggerPrompt(prompt, StartNpc.PrimaryPart or StartNpc:FindFirstChildWhichIsA("BasePart"))

					print("[AutoFarm] Menunggu pergantian status job ke Unemployee...")
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

SettingsSection:Slider({
	Title = "Kecepatan Mobil (Tween Speed)",
	Desc = "Mengatur kecepatan gerak otomatis mobil (studs/detik).",
	Value = { Min = 50, Max = 350, Default = 140 },
	Callback = function(val)
		Config.TweenSpeed = val
		print("⚙️ [Config] Kecepatan Mobil diubah menjadi:", val, "studs/detik")
	end
})

SettingsSection:Slider({
	Title = "Jeda Aksi & Teleport (Action Delay)",
	Desc = "Jeda tunggu setelah teleportasi atau interaksi tombol (detik).",
	Value = { Min = 1, Max = 20, Default = 3 },
	Callback = function(val)
		Config.ActionDelay = val / 10
		print("⚙️ [Config] Jeda Aksi diubah menjadi:", Config.ActionDelay, "detik")
	end
})

SettingsSection:Slider({
	Title = "Jeda Siklus/Loop (Cycle Delay)",
	Desc = "Jeda pengecekan data di dalam loop otomatisasi (detik).",
	Value = { Min = 1, Max = 30, Default = 5 },
	Callback = function(val)
		Config.LoopWait = val / 10
		print("⚙️ [Config] Jeda Loop diubah menjadi:", Config.LoopWait, "detik")
	end
})

SettingsSection:Slider({
	Title = "Jeda Restart Siklus (Restart Delay)",
	Desc = "Jeda tunggu sebelum mengulangi siklus pekerjaan baru (detik).",
	Value = { Min = 10, Max = 100, Default = 25 },
	Callback = function(val)
		Config.RestartDelay = val / 10
		print("⚙️ [Config] Jeda Ulang Siklus diubah menjadi:", Config.RestartDelay, "detik")
	end
})

Window.Frame.Destroying:Connect(function()
	if _G.MainCoreHook then _G.MainCoreHook:Disconnect() _G.MainCoreHook = nil end
	if _G.MainCoreDialogHook then _G.MainCoreDialogHook:Disconnect() _G.MainCoreDialogHook = nil end
	if _G.MainCoreJobHook then _G.MainCoreJobHook:Disconnect() _G.MainCoreJobHook = nil end
end)

-- Cache TextLabel internal WindUI Paragraph (terpercaya, edit .Text langsung)
local _statusLabel = nil
local _saldoLabel  = nil

local function ScanWindUILabels()
	for _, sg in ipairs(PlayerGui:GetChildren()) do
		if sg:IsA('ScreenGui') then
			for _, obj in ipairs(sg:GetDescendants()) do
				if obj:IsA('TextLabel') then
					if obj.Text == 'Phase: Unemployee | Koper: 0/0' then
						_statusLabel = obj
					elseif obj.Text == 'Membaca data...' then
						_saldoLabel = obj
					end
				end
			end
		end
	end
	print('[UI] Label scan: statusLabel=', _statusLabel~=nil, 'saldoLabel=', _saldoLabel~=nil)
end

local function SetLabel(label, para, text)
	if label and label.Parent then
		label.Text = text
		return
	end
	-- Fallback: coba semua API WindUI
	if para then
		pcall(function() para:SetDesc(text) end)
		pcall(function() para:SetText(text) end)
	end
end

-- Jalankan scan setelah WindUI selesai render (delay 1 detik)
task.delay(1, ScanWindUILabels)

-- Update Status Pekerjaan (real-time dari State, setiap 0.25 dtk)
task.spawn(function()
	while task.wait(0.25) do
		if _G.MainCoreSession ~= session then break end
		local text = string.format('Phase: %s | Koper: %s/%s',
			tostring(State.Phase), tostring(State.Loaded), tostring(State.Total))
		-- Scan ulang jika label belum ditemukan
		if not _statusLabel or not _statusLabel.Parent then
			ScanWindUILabels()
		end
		SetLabel(_statusLabel, statusParagraph, text)
	end
end)

-- Update Saldo BCA Pocket
task.spawn(function()
	-- Cara 1: Langsung akses GUI TextLabel BCA Pocket (paling andal)
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

	-- Cara 2: ReplicaController (jika Cara 1 gagal)
	local ok, RC = pcall(function()
		return require(ReplicatedStorage
			:WaitForChild('ClientContainer')
			:WaitForChild('Controller')
			:WaitForChild('ReplicaController'))
	end)

	local function FormatRupiah(val)
		if type(val) ~= 'number' then return tostring(val or '?') end
		local r = string.format('%d', math.floor(val)):reverse():gsub('%d%d%d','%1.'):reverse():gsub('^%.',''  )
		return 'Rp ' .. r
	end

	-- Pasang RC listener jika belum
	if ok and not _G.MainCoreSaldoRegistered then
		_G.MainCoreSaldoRegistered = true
		RC.ReplicaOfClassCreated('Player_' .. LocalPlayer.UserId, function(replica)
			local function GetPocket()
				local c = replica.Data and replica.Data.Collab
				return c and c.MyBca2026 and c.MyBca2026.PocketRupiah
			end
			if not _saldoLabel or not _saldoLabel.Parent then ScanWindUILabels() end
			SetLabel(_saldoLabel, saldoParagraph, FormatRupiah(GetPocket()))
			print('[Saldo RC] Nilai awal:', GetPocket())
			replica:ListenToChange({'Collab'}, function()
				if not _saldoLabel or not _saldoLabel.Parent then ScanWindUILabels() end
				SetLabel(_saldoLabel, saldoParagraph, FormatRupiah(GetPocket()))
				print('[Saldo RC] Update:', GetPocket())
			end)
		end)
	end

	-- Polling fallback: update saldo setiap 1 dtk dari GUI langsung
	while task.wait(1) do
		if _G.MainCoreSession ~= session then break end
		local guiText = GetSaldoText()
		if guiText then
			if not _saldoLabel or not _saldoLabel.Parent then ScanWindUILabels() end
			SetLabel(_saldoLabel, saldoParagraph, guiText)
		end
	end
end)

print("🎉 MainCore Autofarm Stabil & Siap Digunakan!")
