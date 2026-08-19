-- ==============================================================================
-- CDID HUB - BCA COURIER AUTO FARM
-- ==============================================================================
local BCA = {}

function BCA.Init(Window, Utils, Context)
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Workspace = game:GetService("Workspace")
	local RunService = game:GetService("RunService")

	local LocalPlayer = Players.LocalPlayer

	-- CONFIGURABLE VALUES
	local Config = {
		TweenSpeed = 180,
		MinTravelDuration = 20,
		ActionDelay = 0.3,
		LoopWait = 0.4,
		RestartDelay = 2.0
	}

	-- STATE
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
		IsReady = false
	}

	local autoFarmToggle
	local statusParagraph
	local Network = nil

	-- ==============================================================================
	-- HELPER FUNCTIONS
	-- ==============================================================================
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

	local function DriveCarNaturallyTo(car, targetPos, speed)
		speed = speed or Config.TweenSpeed
		local primary = car.PrimaryPart or car:FindFirstChildWhichIsA("BasePart")
		local seat = car:FindFirstChildWhichIsA("VehicleSeat", true)
		if not primary then return end

		local char = LocalPlayer.Character
		local hum = char and char:FindFirstChild("Humanoid")

		local startCF = car:GetPivot()

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
	-- LAZY INITIALIZER FOR MAP GAMEPLAY
	-- ==============================================================================
	task.spawn(function()
		while not Workspace:FindFirstChild("MY_BCA_COLLAB") do
			task.wait(1.5)
			if Context.Session ~= _G.MainCoreSession then return end
		end

		local modules = ReplicatedStorage:WaitForChild("Modules", 15)
		local netModule = modules and modules:WaitForChild("Network", 15)
		if netModule then
			Network = require(netModule)
		end

		local netContainer = ReplicatedStorage:WaitForChild("NetworkContainer", 15)
		local remoteEvents = netContainer and netContainer:WaitForChild("RemoteEvents", 15)
		local NpcDialogEvent = remoteEvents and remoteEvents:WaitForChild("NpcDialog", 15)
		local JobRemote = remoteEvents and remoteEvents:WaitForChild("Job", 15)

		if not Network or not NpcDialogEvent or not JobRemote then
			warn("⚠️ [BCA Courier] Remotes Network belum siap.")
			return
		end

		local dialogHook = NpcDialogEvent.OnClientEvent:Connect(function(action, data)
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
		table.insert(Context.Hooks, dialogHook)

		local jobHook = JobRemote.OnClientEvent:Connect(function(action, arg1)
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
		table.insert(Context.Hooks, jobHook)

		local bankHook = Network.OnClientEvent("BankCourier", function(action, arg1, arg2, arg3, arg4)
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

			-- 1. Minigame: Muat Koper
			elseif action == "LoadRound" and typeof(arg1) == "table" then
				local greenSize = arg1.greenSize or arg1.greatSize or 0.18
				local greenStart = arg1.greenStart or 0.5
				local period = math.max(arg1.period or 1, 0.1)

				local centerGreen = greenStart + (greenSize / 2)
				local timeToHit = centerGreen * period

				local ping = 0
				pcall(function() ping = (LocalPlayer:GetNetworkPing() or 0) / 2 end)

				local delayTime = timeToHit - ping - 0.01

				if centerGreen > 0.65 then
					delayTime = delayTime + (period * 0.04)
				end

				while delayTime < 0.03 do
					delayTime = delayTime + (2 * period)
				end

				print(string.format("🎯 [Minigame Koper] Target: %.3f | Ping: %.0fms | Mengirim LoadPress dlm: %.3fs", centerGreen, ping * 2000, delayTime))

				local curSession = Context.Session
				task.delay(delayTime, function()
					if _G.MainCoreSession ~= curSession then return end
					Network:FireServer("BankCourier", "LoadPress")
					print("✅ [Minigame Koper] LoadPress PERFECT terkirim!")
				end)

			-- 2. Minigame: Setor ATM
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

				local curSession = Context.Session
				task.delay(delayTime, function()
					if _G.MainCoreSession ~= curSession then return end
					Network:FireServer("BankCourier", "SkillPress", angleToSend)
					print("✅ [Minigame ATM] SkillPress PERFECT terkirim!")
				end)

			elseif action == "Complete" or action == "Returning" then
				State.Phase = "Returning"
				print("🏁 Semua ATM telah diisi!")

			elseif action == "Stop" then
				State.Phase = "Unemployee"
				State.Loaded = 0
				State.Total = 0
				print("🛑 Job Berhenti / Gaji Diterima.")
			end
		end)
		table.insert(Context.Hooks, bankHook)

		State.IsReady = true
		print("✅ [BCA Courier] Event Listeners & Network Hook aktif.")
	end)

	-- ==============================================================================
	-- AUTOFARM SEQUENCES
	-- ==============================================================================
	local function Action_StartJob()
		local Mf = Workspace:WaitForChild("MY_BCA_COLLAB")
		local StartNpc = Mf:WaitForChild("NPC_START_JOB")

		if State.Phase == "Loading" or State.Phase == "Delivering" then
			return
		end

		print("[UI] Teleport ke NPC Start...")
		Utils.SafeTeleportChar(StartNpc:GetPivot(), Config.ActionDelay)
		task.wait(0.5)

		local prompt = StartNpc:FindFirstChildWhichIsA("ProximityPrompt", true)
		if prompt then prompt.Enabled = true end

		print("[UI] Mengambil Pekerjaan di NPC Start...")
		Utils.TriggerPrompt(prompt, StartNpc.PrimaryPart or StartNpc:FindFirstChildWhichIsA("BasePart"))

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
		Utils.SafeTeleportChar(CarSpawner:GetPivot(), Config.ActionDelay)
		task.wait(0.5)

		local spawnPrompt = CarSpawner:FindFirstChildWhichIsA("ProximityPrompt", true)
		if spawnPrompt then spawnPrompt.Enabled = true end

		print("[UI] Mengeluarkan Kendaraan...")
		Utils.TriggerPrompt(spawnPrompt, CarSpawner.PrimaryPart or CarSpawner:FindFirstChildWhichIsA("BasePart"))

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
				if _G.MainCoreSession ~= Context.Session then break end
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
					Utils.SafeTeleportChar(KoperSpawn:GetPivot(), Config.ActionDelay)
					Utils.TriggerPrompt(koperPrompt, KoperSpawn.PrimaryPart or KoperSpawn:FindFirstChildWhichIsA("BasePart"))

					local timeout = os.clock()
					while not State.Carrying and State.AutoLoading and (os.clock() - timeout < Config.ActionDelay * 10) do
						task.wait(Config.LoopWait / 2)
					end
					State.IsBusy = false
				elseif State.Carrying and not State.IsBusy then
					if bagasiPoint and muatPrompt then
						State.IsBusy = true
						print("[+] Memuat koper ke bagasi...")
						Utils.SafeTeleportChar(bagasiPoint.CFrame, Config.ActionDelay)
						Utils.TriggerPrompt(muatPrompt, bagasiPoint, true)

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
				if _G.MainCoreSession ~= Context.Session then break end

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

					if not State.Carrying and bagasiPoint and ambilPrompt and distToAtm <= 40 then
						State.IsBusy = true
						print("[+] Mengambil koper dari bagasi...")
						Utils.SafeTeleportChar(bagasiPoint.CFrame * CFrame.new(0, 0, 1.8), Config.ActionDelay)
						task.wait(0.2)

						Utils.TriggerPrompt(ambilPrompt, bagasiPoint, true)

						local waitCarry = os.clock()
						while not State.Carrying and State.AutoDelivering and (os.clock() - waitCarry < Config.ActionDelay * 12) do
							task.wait(Config.LoopWait / 2)
						end
						State.IsBusy = false
					end

					if not State.AutoDelivering then break end

					if State.Carrying and State.TargetPos then
						State.IsBusy = true
						print("[+] Berpindah tepat ke depan mesin ATM...")
						Utils.SafeTeleportChar(CFrame.new(State.TargetPos + Vector3.new(0, 0, 1.5)), Config.ActionDelay)
						task.wait(Config.ActionDelay)

						print("[+] Memulai pengisian ATM...")
						if Network then
							Network:FireServer("BankCourier", "FillStart")
						end

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
		if not State.AutoFarmActive and _G.MainCoreSession == Context.Session then
			return
		end

		print("[UI] Mereset semua proses...")

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
	-- UI TAB & ELEMENTS
	-- ==============================================================================
	local BCATab = Window:Tab({
		Title = "BCA Courier",
		Icon = "solar:box-minimalistic-bold"
	})

	local ControlsSection = BCATab:Section({ Title = "Auto Farm Controls" })
	local SettingsSection = BCATab:Section({ Title = "Konfigurasi Kecepatan & Anti-Nerf" })
	local ShortcutsSection = BCATab:Section({ Title = "Pintasan Teleport Karakter" })

	ShortcutsSection:Button({
		Title = "Teleport ke NPC Start (Lobby)",
		Desc = "Teleport instan ke dekat NPC pendaftaran kurir.",
		Callback = function()
			local StartNpc = Workspace:WaitForChild("MY_BCA_COLLAB"):WaitForChild("NPC_START_JOB")
			Utils.SafeTeleportChar(StartNpc:GetPivot(), Config.ActionDelay)
			print("📍 Teleportasi ke NPC Start selesai.")
		end
	})

	ShortcutsSection:Button({
		Title = "Teleport ke Spawner Mobil",
		Desc = "Teleport instan ke petugas parkir kendaraan bank.",
		Callback = function()
			local CarSpawner = Workspace:WaitForChild("MY_BCA_COLLAB"):WaitForChild("CAR_SPAWNER_NPC")
			Utils.SafeTeleportChar(CarSpawner:GetPivot(), Config.ActionDelay)
			print("📍 Teleportasi ke Spawner Mobil selesai.")
		end
	})

	ShortcutsSection:Button({
		Title = "Teleport ke Rak Koper",
		Desc = "Teleport instan ke area tumpukan koper BCA.",
		Callback = function()
			local KoperSpawn = Workspace:WaitForChild("MY_BCA_COLLAB"):WaitForChild("Job"):WaitForChild("BankCourier"):WaitForChild("KoperSpawn")
			Utils.SafeTeleportChar(KoperSpawn:GetPivot(), Config.ActionDelay)
			print("📍 Teleportasi ke Rak Koper selesai.")
		end
	})

	autoFarmToggle = ControlsSection:Toggle({
		Title = "Endless Auto Farm",
		Desc = "Mulai/Hentikan siklus kurir dengan simulasi perjalanan natural.",
		Value = false,
		Callback = function(active)
			if State.AutoFarmActive == active then return end

			if active and not Workspace:FindFirstChild("MY_BCA_COLLAB") then
				warn("⚠️ [BCA Courier] Kamu belum berada di map gameplay! Silakan pilih server/map terlebih dahulu.")
				task.spawn(function()
					task.wait(0.1)
					if autoFarmToggle then
						pcall(function() autoFarmToggle:Set(false) end)
						pcall(function() autoFarmToggle:SetValue(false) end)
					end
				end)
				return
			end

			State.AutoFarmActive = active
			if active then
				-- Jalankan optimasi & cleaner hanya saat autofarm aktif
				Utils.DestroyBuildingInstances()
				Utils.EnablePerformanceMode()

				task.spawn(function()
					print("[AutoFarm] Memulai Siklus Pengantaran...")
					while State.AutoFarmActive do
						if _G.MainCoreSession ~= Context.Session then break end

						-- 1. Ambil Job
						Action_StartJob()

						local startWait = os.clock()
						while State.Phase == "Unemployee" and (os.clock() - startWait < 8) do
							if _G.MainCoreSession ~= Context.Session or not State.AutoFarmActive then return end
							task.wait(Config.LoopWait / 2)
						end
						if not State.AutoFarmActive or _G.MainCoreSession ~= Context.Session then break end

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
							if _G.MainCoreSession ~= Context.Session or not State.AutoFarmActive then return end
							car = GetPlayerCar()
							if car then break end
							task.wait(Config.LoopWait / 2)
						end
						if not State.AutoFarmActive or _G.MainCoreSession ~= Context.Session then break end

						if not car then
							warn("⚠️ Mobil tidak muncul, mengulang...")
							task.wait(Config.RestartDelay)
							continue
						end

						-- 3. Muat Koper
						State.AutoLoading = true
						RunLoadingLoop()

						local loadTimeout = os.clock()
						while State.AutoLoading and State.AutoFarmActive and (os.clock() - loadTimeout < 60) do
							if _G.MainCoreSession ~= Context.Session then return end
							task.wait(Config.LoopWait)
						end
						if not State.AutoFarmActive or _G.MainCoreSession ~= Context.Session then break end

						-- 4. Antar Koper ke ATM
						State.AutoDelivering = true
						RunDeliveryLoop()

						local deliverTimeout = os.clock()
						while State.AutoDelivering and State.AutoFarmActive and (os.clock() - deliverTimeout < 300) do
							if _G.MainCoreSession ~= Context.Session then return end
							task.wait(Config.LoopWait)
						end
						if not State.AutoFarmActive or _G.MainCoreSession ~= Context.Session then break end

						-- 5. Kembalikan Mobil ke BCA
						print("[AutoFarm] Mengemudikan mobil kembali ke BCA...")
						local returnCar = GetPlayerCar()
						if returnCar then
							EnterDriverSeat(returnCar)
							task.wait(Config.ActionDelay)
							if not State.AutoFarmActive or _G.MainCoreSession ~= Context.Session then break end

							local Mf = Workspace:WaitForChild("MY_BCA_COLLAB")
							local CarSpawner = Mf:WaitForChild("CAR_SPAWNER_NPC")
							DriveCarNaturallyTo(returnCar, CarSpawner:GetPivot().Position, Config.TweenSpeed)
							ExitDriverSeat(returnCar)
						end
						if not State.AutoFarmActive or _G.MainCoreSession ~= Context.Session then break end

						-- 6. Klaim Gaji di NPC Start
						print("[AutoFarm] Mengambil upah penuh di NPC Start...")
						local Mf = Workspace:WaitForChild("MY_BCA_COLLAB")
						local StartNpc = Mf:WaitForChild("NPC_START_JOB")
						Utils.SafeTeleportChar(StartNpc:GetPivot(), Config.ActionDelay)
						task.wait(0.5)

						local prompt = StartNpc:FindFirstChildWhichIsA("ProximityPrompt", true)
						if prompt then prompt.Enabled = true end

						Utils.TriggerPrompt(prompt, StartNpc.PrimaryPart or StartNpc:FindFirstChildWhichIsA("BasePart"))

						print("[AutoFarm] Menunggu pencairan gaji selesai...")
						local endWait = os.clock()
						while State.Phase ~= "Unemployee" and (os.clock() - endWait < 10) do
							if _G.MainCoreSession ~= Context.Session or not State.AutoFarmActive then return end
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

	statusParagraph = ControlsSection:Paragraph({
		Title = "Status Pekerjaan",
		Desc = "Phase: Unemployee | Koper: 0/0",
		Image = "info"
	})

	task.spawn(function()
		while task.wait(0.25) do
			if _G.MainCoreSession ~= Context.Session then break end
			local statusText = string.format("Phase: %s | Koper: %s/%s", tostring(State.Phase), tostring(State.Loaded), tostring(State.Total))
			pcall(function()
				if statusParagraph then
					statusParagraph:SetDesc(statusText)
				end
			end)
		end
	end)

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
end

return BCA
