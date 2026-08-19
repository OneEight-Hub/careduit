-- ==============================================================================
-- CDID HUB - BCA COURIER (FULL FINANCIAL ANALYTICS)
-- ==============================================================================
local BCA = {}

function BCA.Init(Window, Utils, Context, UICreate)
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

	-- STATE & FINANCIAL STATS
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

		TotalTrips = 0,

		-- Finansial Saldo BCA Pocket
		StartSaldo = nil,
		CurrentSaldo = 0,
		LastGaji = 0,
		EarnedSaldo = 0,

		CurrentSaldoText = "Membaca...",
		StartSaldoText = "Membaca...",
		LastGajiText = "Rp 0",
		EarnedText = "+Rp 0"
	}

	local autoFarmToggle
	local statusParagraph
	local Network = nil
	local FloatingDash = nil

	-- ==============================================================================
	-- HELPER FUNCTIONS
	-- ==============================================================================
	local function FormatRupiah(val)
		if type(val) ~= "number" then return tostring(val or "Rp 0") end
		local r = string.format("%d", math.floor(val)):reverse():gsub("%d%d%d", "%1."):reverse():gsub("^%.", "")
		return "Rp " .. r
	end

	local function ParseRupiahToNumber(str)
		if type(str) == "number" then return str end
		if type(str) ~= "string" then return 0 end
		local clean = str:gsub("[^%d]", "")
		return tonumber(clean) or 0
	end

	local function GetBcaFolder()
		return Workspace:FindFirstChild("MY_BCA_COLLAB") 
			or Workspace:FindFirstChild("MyBcaCollab") 
			or Workspace:FindFirstChild("my_bca_collab")
	end

	local function GetValidHumanoid()
		local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum and hum.Health > 0 then
			return hum, char:FindFirstChild("HumanoidRootPart")
		end
		return nil, nil
	end

	local function ResetPlayerCamera()
		local hum = GetValidHumanoid()
		local camera = Workspace.CurrentCamera
		if camera and hum then
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
		local hum, hrp = GetValidHumanoid()
		if not hum or not hrp then return false end

		local seat = car:FindFirstChildWhichIsA("VehicleSeat", true) 
			or car:FindFirstChild("DriveSeat", true) 
			or car:FindFirstChild("DriverSeat", true)

		if not seat then return false end

		local primary = car.PrimaryPart or car:FindFirstChildWhichIsA("BasePart")
		if primary then primary.Anchored = false end
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
				pcall(function() seat:Sit(hum) end)
			end
			drivePrompt:InputHoldBegin()
			task.wait(drivePrompt.HoldDuration + 0.1)
			drivePrompt:InputHoldEnd()
		else
			pcall(function() seat:Sit(hum) end)
		end

		local timeout = os.clock()
		while not hum.Sit and (os.clock() - timeout < 2.5) do task.wait(0.1) end
		return hum.Sit
	end

	local function ExitDriverSeat(car)
		local hum = GetValidHumanoid()
		if hum and hum.Sit then
			hum.Sit = false
			task.wait(Config.ActionDelay)
		end
		if car and car.PrimaryPart then
			car.PrimaryPart.Anchored = true
		end
	end

	local function DriveCarNaturallyTo(car, targetPos, speed)
		speed = speed or Config.TweenSpeed
		local primary = car.PrimaryPart or car:FindFirstChildWhichIsA("BasePart")
		local seat = car:FindFirstChildWhichIsA("VehicleSeat", true)
		if not primary then return end

		local startCF = car:GetPivot()
		local dirToAtm = (targetPos - startCF.Position).Unit
		local flatDir = Vector3.new(dirToAtm.X, 0, dirToAtm.Z).Unit
		local parkPos = targetPos - (flatDir * 14) + Vector3.new(0, 1.2, 0)
		local targetCF = CFrame.new(parkPos, parkPos + flatDir)

		local dist = (startCF.Position - parkPos).Magnitude
		local duration = math.max(Config.MinTravelDuration, dist / speed)

		primary.Anchored = false
		local startTime = os.clock()
		print(string.format("🚗 [Safe Park] Menyetir ke titik parkir ATM (Jarak: %.0f stud | Durasi: %.1f dtk)...", dist, duration))

		while (os.clock() - startTime) < duration and State.AutoDelivering do
			local hum = GetValidHumanoid()
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
				if seat then pcall(function() seat.ThrottleFloat = 0; seat.Throttle = 0 end) end
			else
				if seat then pcall(function() seat.ThrottleFloat = 1; seat.Throttle = 1 end) end
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
		task.wait(Config.ActionDelay)
	end

	-- ==============================================================================
	-- POCKET SALDO FETCHER DENGAN KALKULASI EARNED & GAJI TERAKHIR
	-- ==============================================================================
	local function FetchPocketSaldo()
		task.spawn(function()
			-- 1. Trigger Remote Buka App MyBCA
			local netContainer = ReplicatedStorage:FindFirstChild("NetworkContainer")
			local remoteEvents = netContainer and netContainer:FindFirstChild("RemoteEvents")
			local appOpened = remoteEvents and remoteEvents:FindFirstChild("MyBcaAppOpened")

			if appOpened then
				pcall(function() appOpened:FireServer() end)
			end

			task.wait(0.4)

			-- 2. Ambil nilai Saldo Text dari ACTUAL NEW PHONE
			local pGui = LocalPlayer:FindFirstChild("PlayerGui")
			if not pGui then return end

			local phoneGui = pGui:FindFirstChild("ACTUAL NEW PHONE")
			if not phoneGui then return end

			local saldoLabel = nil
			pcall(function()
				local container = phoneGui:FindFirstChild("Container")
				local holder = container and container:FindFirstChild("Holder")
				local appCont = holder and (holder:FindFirstChild("AppContainer") or holder:FindFirstChild("AppCountainer"))
				local myBca = appCont and appCont:FindFirstChild("MyBca")
				local home = myBca and myBca:FindFirstChild("Home")
				local main = home and home:FindFirstChild("Main")
				local frame = main and main:FindFirstChild("Frame")
				local pocket = frame and (frame:FindFirstChild("3b_POCKETRUPPIAH") or frame:FindFirstChild("3b_POCKETRUPIAH"))
				local balFr = pocket and pocket:FindFirstChild("BalanceFrame")
				local scroll = balFr and (balFr:FindFirstChild("ScrollingFrame") or balFr:FindFirstChild("ScrolingFrame"))
				local ep = scroll and scroll:FindFirstChild("EventPocket")
				local btn = ep and ep:FindFirstChild("Button")
				saldoLabel = (btn and btn:FindFirstChild("Saldo")) or (ep and ep:FindFirstChild("Saldo"))
			end)

			if not saldoLabel then
				for _, desc in ipairs(phoneGui:GetDescendants()) do
					if desc:IsA("TextLabel") and desc.Name == "Saldo" and desc.Text:find("Rp") then
						saldoLabel = desc
						break
					end
				end
			end

			if saldoLabel and saldoLabel.Text and saldoLabel.Text ~= "" then
				local rawText = saldoLabel.Text
				local parsedNum = ParseRupiahToNumber(rawText)

				if parsedNum > 0 then
					-- Saldo Awal (Pertama kali membaca)
					if not State.StartSaldo then
						State.StartSaldo = parsedNum
						State.StartSaldoText = FormatRupiah(parsedNum)
					else
						-- Hitung gaji yang baru masuk jika saldo bertambah
						if parsedNum > State.CurrentSaldo and State.CurrentSaldo > 0 then
							State.LastGaji = parsedNum - State.CurrentSaldo
							State.LastGajiText = "+" .. FormatRupiah(State.LastGaji)
						end
					end

					State.CurrentSaldo = parsedNum
					State.CurrentSaldoText = FormatRupiah(parsedNum)

					-- Hitung Total Profit / Earned
					if State.StartSaldo then
						State.EarnedSaldo = math.max(0, State.CurrentSaldo - State.StartSaldo)
						State.EarnedText = "+" .. FormatRupiah(State.EarnedSaldo)
					end

					-- Update ke Floating Dashboard
					if FloatingDash then
						FloatingDash.UpdateSaldoAwal(State.StartSaldoText)
						FloatingDash.UpdateCurrentSaldo(State.CurrentSaldoText)
						FloatingDash.UpdateEarned(State.EarnedText)
						FloatingDash.UpdateGajiTerakhir(State.LastGajiText)
					end
				end
			end

			-- 3. Sembunyikan GUI HP
			pcall(function()
				phoneGui.Enabled = false
			end)
		end)
	end

	-- ==============================================================================
	-- LAZY INITIALIZER & NETWORK HOOKS
	-- ==============================================================================
	task.spawn(function()
		while not GetBcaFolder() do
			task.wait(1.5)
			if Context.Session ~= _G.MainCoreSession then return end
		end

		-- Panggil 1x saat pertama kali modul siap
		FetchPocketSaldo()

		local modules = ReplicatedStorage:WaitForChild("Modules", 15)
		local netModule = modules and modules:WaitForChild("Network", 15)
		if netModule then Network = require(netModule) end

		local netContainer = ReplicatedStorage:WaitForChild("NetworkContainer", 15)
		local remoteEvents = netContainer and netContainer:WaitForChild("RemoteEvents", 15)
		local NpcDialogEvent = remoteEvents and remoteEvents:WaitForChild("NpcDialog", 15)
		local JobRemote = remoteEvents and remoteEvents:WaitForChild("Job", 15)

		if not Network or not NpcDialogEvent or not JobRemote then return end

		local dialogHook = NpcDialogEvent.OnClientEvent:Connect(function(action)
			if action == "Start" then
				task.spawn(function()
					task.wait(0.5)
					NpcDialogEvent:FireServer("Finish", nil)
					if firesignal then pcall(firesignal, NpcDialogEvent.OnClientEvent, "Abort") end
					ResetPlayerCamera()
				end)
			end
		end)
		table.insert(Context.Hooks, dialogHook)

		local jobHook = JobRemote.OnClientEvent:Connect(function(action, arg1)
			if action == "SetJob" then
				if arg1 == "BankCourier" then
					State.Phase = "Loading"
				elseif arg1 == "Unemployee" then
					State.Phase = "Unemployee"
					State.Loaded = 0
					State.Total = 0
				end
			end
		end)
		table.insert(Context.Hooks, jobHook)

		local bankHook = Network.OnClientEvent("BankCourier", function(action, arg1, arg2, arg3, arg4)
			if action == "Start" then
				State.Total = (typeof(arg1) == "table" and arg1.totalKoper) or 0
				State.Phase = "Loading"

			elseif action == "Phase" then
				State.Phase = arg1
				if typeof(arg4) == "Vector3" then State.TargetPos = arg4
				elseif typeof(arg2) == "Vector3" then State.TargetPos = arg2
				elseif arg2 and arg2:IsA("BasePart") then State.TargetPos = arg2.Position end

			elseif action == "Koper" then
				State.Loaded = arg1
				State.Carrying = (arg4 == true)

			elseif action == "LoadRound" and typeof(arg1) == "table" then
				local greenSize = arg1.greenSize or arg1.greatSize or 0.18
				local greenStart = arg1.greenStart or 0.5
				local period = math.max(arg1.period or 1, 0.1)
				local centerGreen = greenStart + (greenSize / 2)
				local ping = 0
				pcall(function() ping = (LocalPlayer:GetNetworkPing() or 0) / 2 end)
				local delayTime = (centerGreen * period) - ping - 0.01
				if centerGreen > 0.65 then delayTime = delayTime + (period * 0.04) end
				while delayTime < 0.03 do delayTime = delayTime + (2 * period) end

				local curSession = Context.Session
				task.delay(delayTime, function()
					if _G.MainCoreSession ~= curSession then return end
					Network:FireServer("BankCourier", "LoadPress")
				end)

			elseif action == "SkillCheck" and typeof(arg1) == "table" then
				local zoneWidth = arg1.greatSize or arg1.zoneSize or 20
				local targetAngle = arg1.zoneStart + (zoneWidth / 2)
				local speed = arg1.speed or 1
				local warnLead = arg1.warnLead or 0
				local ping = 0
				pcall(function() ping = (LocalPlayer:GetNetworkPing() or 0) / 2 end)
				local delayTime = warnLead + (targetAngle / speed) - ping
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
				end)

			elseif action == "Complete" or action == "Returning" then
				State.Phase = "Returning"

			elseif action == "Stop" then
				State.Phase = "Unemployee"
				State.Loaded = 0
				State.Total = 0
				State.TotalTrips = State.TotalTrips + 1
				if FloatingDash then FloatingDash.UpdateTrips(State.TotalTrips) end

				-- Update saldo & hitung gaji
				FetchPocketSaldo()
			end
		end)
		table.insert(Context.Hooks, bankHook)
	end)

	-- ==============================================================================
	-- AUTOFARM SEQUENCES
	-- ==============================================================================
	local function Action_StartJob()
		local Mf = GetBcaFolder()
		if not Mf then return end
		local StartNpc = Mf:FindFirstChild("NPC_START_JOB")
		if not StartNpc or State.Phase == "Loading" or State.Phase == "Delivering" then return end

		print("📍 [Step 1] Teleport ke NPC Start Job...")
		Utils.SafeTeleportChar(StartNpc:GetPivot(), Config.ActionDelay)
		task.wait(0.5)
		local prompt = StartNpc:FindFirstChildWhichIsA("ProximityPrompt", true)
		if prompt then prompt.Enabled = true end
		Utils.TriggerPrompt(prompt, StartNpc.PrimaryPart or StartNpc:FindFirstChildWhichIsA("BasePart"))

		local dialogWait = os.clock()
		while State.Phase == "Unemployee" and (os.clock() - dialogWait < 4) do task.wait(0.1) end
		task.wait(Config.ActionDelay)
	end

	local function Action_SpawnVehicle()
		local Mf = GetBcaFolder()
		if not Mf then return end
		local CarSpawner = Mf:FindFirstChild("CAR_SPAWNER_NPC")
		if not CarSpawner then return end

		print("🚗 [Step 2] Teleport ke Spawner Mobil...")
		Utils.SafeTeleportChar(CarSpawner:GetPivot(), Config.ActionDelay)
		task.wait(0.5)
		local spawnPrompt = CarSpawner:FindFirstChildWhichIsA("ProximityPrompt", true)
		if spawnPrompt then spawnPrompt.Enabled = true end
		Utils.TriggerPrompt(spawnPrompt, CarSpawner.PrimaryPart or CarSpawner:FindFirstChildWhichIsA("BasePart"))
		task.wait(1.2)
	end

	local function RunLoadingLoop()
		if State.LoadingActive then return end
		State.LoadingActive = true
		local Mf = GetBcaFolder()
		if not Mf then return end
		local jobFolder = Mf:FindFirstChild("Job")
		local bankCourierFolder = jobFolder and jobFolder:FindFirstChild("BankCourier")
		local KoperSpawn = bankCourierFolder and bankCourierFolder:FindFirstChild("KoperSpawn")
		if not KoperSpawn then return end

		task.spawn(function()
			print("📦 [Step 3] Memuat koper ke bagasi...")
			while State.AutoLoading do
				if _G.MainCoreSession ~= Context.Session then break end
				if State.Phase == "Delivering" or (State.Total > 0 and State.Loaded >= State.Total) then
					State.AutoLoading = false
					break
				end

				local car = GetPlayerCar()
				local bagasiPoint = car and car:FindFirstChild("BagasiPoint", true)
				local muatPrompt = GetMuatPrompt(bagasiPoint)
				local koperPrompt = KoperSpawn:FindFirstChildWhichIsA("ProximityPrompt", true)

				if not State.Carrying and not State.IsBusy then
					State.IsBusy = true
					Utils.SafeTeleportChar(KoperSpawn:GetPivot(), Config.ActionDelay)
					Utils.TriggerPrompt(koperPrompt, KoperSpawn.PrimaryPart or KoperSpawn:FindFirstChildWhichIsA("BasePart"))
					local timeout = os.clock()
					while not State.Carrying and State.AutoLoading and (os.clock() - timeout < Config.ActionDelay * 10) do task.wait(Config.LoopWait / 2) end
					State.IsBusy = false
				elseif State.Carrying and not State.IsBusy then
					if bagasiPoint and muatPrompt then
						State.IsBusy = true
						Utils.SafeTeleportChar(bagasiPoint.CFrame, Config.ActionDelay)
						Utils.TriggerPrompt(muatPrompt, bagasiPoint, true)
						local timeout = os.clock()
						while State.Carrying and State.AutoLoading and (os.clock() - timeout < Config.ActionDelay * 13) do task.wait(Config.LoopWait / 2) end
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

		task.spawn(function()
			print("🏧 [Step 4] Memulai pengantaran ATM...")
			while State.AutoDelivering do
				if _G.MainCoreSession ~= Context.Session then break end
				if (State.Loaded <= 0 and not State.Carrying) or (State.Phase == "Returning" and State.Loaded <= 0) then
					State.AutoDelivering = false
					break
				end

				local car = GetPlayerCar()
				local bagasiPoint = car and car:FindFirstChild("BagasiPoint", true)
				local ambilPrompt = GetAmbilPrompt(bagasiPoint)

				if car and not State.IsBusy then
					local hum, hrp = GetValidHumanoid()
					local distToAtm = (hrp and State.TargetPos) and (hrp.Position - State.TargetPos).Magnitude or 999

					if not State.Carrying and State.TargetPos and distToAtm > 25 then
						State.IsBusy = true
						EnterDriverSeat(car)
						task.wait(Config.ActionDelay)
						if not State.AutoDelivering then State.IsBusy = false break end
						DriveCarNaturallyTo(car, State.TargetPos, Config.TweenSpeed)
						ExitDriverSeat(car)
						State.IsBusy = false
					end

					if not State.AutoDelivering then break end

					if not State.Carrying and bagasiPoint and ambilPrompt and distToAtm <= 40 then
						State.IsBusy = true
						Utils.SafeTeleportChar(bagasiPoint.CFrame * CFrame.new(0, 0, 1.8), Config.ActionDelay)
						task.wait(0.2)
						Utils.TriggerPrompt(ambilPrompt, bagasiPoint, true)
						local waitCarry = os.clock()
						while not State.Carrying and State.AutoDelivering and (os.clock() - waitCarry < Config.ActionDelay * 12) do task.wait(Config.LoopWait / 2) end
						State.IsBusy = false
					end

					if not State.AutoDelivering then break end

					if State.Carrying and State.TargetPos then
						State.IsBusy = true
						Utils.SafeTeleportChar(CFrame.new(State.TargetPos + Vector3.new(0, 0, 1.5)), Config.ActionDelay)
						task.wait(Config.ActionDelay)

						local curHum, curHrp = GetValidHumanoid()
						if curHrp then curHrp.Anchored = true end

						if Network then Network:FireServer("BankCourier", "FillStart") end
						local waitFill = os.clock()
						while State.Carrying and State.AutoDelivering and (os.clock() - waitFill < Config.ActionDelay * 25) do task.wait(Config.LoopWait / 2) end

						if curHrp then curHrp.Anchored = false end
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
		if autoFarmToggle then pcall(function() autoFarmToggle:Set(false) end) end
		if statusParagraph then pcall(function() statusParagraph:SetDesc("Phase: Unemployee | Koper: 0/0") end) end

		pcall(function()
			local hum, hrp = GetValidHumanoid()
			if hum and hum.Sit then hum.Sit = false end
			if hrp then hrp.Anchored = false end
			local car = GetPlayerCar()
			if car and car.PrimaryPart then car.PrimaryPart.Anchored = false end
		end)
	end

	-- ==============================================================================
	-- UI WINDUI TAB SETUP
	-- ==============================================================================
	local BCATab = Window:Tab({
		Title = "BCA Courier",
		Icon = "solar:box-minimalistic-bold"
	})

	local ControlsSection = BCATab:Section({ Title = "Auto Farm Controls" })
	local DashboardSection = BCATab:Section({ Title = "Floating Mini Dashboard" })
	local SettingsSection = BCATab:Section({ Title = "Konfigurasi Kecepatan & Anti-Nerf" })
	local ShortcutsSection = BCATab:Section({ Title = "Pintasan Teleport" })

	DashboardSection:Button({
		Title = "Toggle Floating Dashboard (BCA Pocket)",
		Desc = "Buka/Tutup overlay monitor Saldo Awal, Current, Earned & Gaji Terakhir.",
		Callback = function()
			if not FloatingDash then
				FloatingDash = UICreate.CreateFloatingDashboard("BCA Courier Live Monitor")
				FloatingDash.UpdateSaldoAwal(State.StartSaldoText)
				FloatingDash.UpdateCurrentSaldo(State.CurrentSaldoText)
				FloatingDash.UpdateEarned(State.EarnedText)
				FloatingDash.UpdateGajiTerakhir(State.LastGajiText)
				FloatingDash.UpdateStatus(string.format("%s | Koper: %s/%s", tostring(State.Phase), tostring(State.Loaded), tostring(State.Total)))
				FloatingDash.UpdateTrips(State.TotalTrips)
				FetchPocketSaldo()
			else
				FloatingDash.Destroy()
				FloatingDash = nil
			end
		end
	})

	ShortcutsSection:Button({
		Title = "Teleport ke NPC Start (Lobby)",
		Callback = function()
			local Mf = GetBcaFolder()
			local StartNpc = Mf and Mf:FindFirstChild("NPC_START_JOB")
			if StartNpc then Utils.SafeTeleportChar(StartNpc:GetPivot(), Config.ActionDelay) end
		end
	})

	ShortcutsSection:Button({
		Title = "Teleport ke Spawner Mobil",
		Callback = function()
			local Mf = GetBcaFolder()
			local CarSpawner = Mf and Mf:FindFirstChild("CAR_SPAWNER_NPC")
			if CarSpawner then Utils.SafeTeleportChar(CarSpawner:GetPivot(), Config.ActionDelay) end
		end
	})

	ShortcutsSection:Button({
		Title = "Teleport ke Rak Koper",
		Callback = function()
			local Mf = GetBcaFolder()
			local jobFolder = Mf and Mf:FindFirstChild("Job")
			local bankCourier = jobFolder and jobFolder:FindFirstChild("BankCourier")
			local KoperSpawn = bankCourier and bankCourier:FindFirstChild("KoperSpawn")
			if KoperSpawn then Utils.SafeTeleportChar(KoperSpawn:GetPivot(), Config.ActionDelay) end
		end
	})

	autoFarmToggle = ControlsSection:Toggle({
		Title = "Endless Auto Farm",
		Desc = "Mulai/Hentikan siklus kurir dengan simulasi perjalanan natural.",
		Value = false,
		Callback = function(active)
			if State.AutoFarmActive == active then return end

			local bcaFolder = GetBcaFolder()
			if active and not bcaFolder then
				warn("⚠️ [BCA Courier] Kamu belum berada di area BCA / Map Gameplay!")
				task.spawn(function()
					task.wait(0.1)
					if autoFarmToggle then pcall(function() autoFarmToggle:Set(false) end) end
				end)
				return
			end

			State.AutoFarmActive = active
			if active then
				print("🚀 [AutoFarm] Memulai Safe Platform & Membersihkan Map...")
				if Utils.DestroyHeavyMaps then
					Utils.DestroyHeavyMaps()
				elseif Utils.StartGiantPlatform then
					Utils.StartGiantPlatform()
				end

				task.spawn(function()
					print("▶️ [AutoFarm] Siklus Loop BCA Courier Dimulai...")
					while State.AutoFarmActive do
						if _G.MainCoreSession ~= Context.Session then break end

						Action_StartJob()
						local startWait = os.clock()
						while State.Phase == "Unemployee" and (os.clock() - startWait < 8) do
							if _G.MainCoreSession ~= Context.Session or not State.AutoFarmActive then return end
							task.wait(Config.LoopWait / 2)
						end
						if not State.AutoFarmActive or State.Phase == "Unemployee" then task.wait(Config.RestartDelay) continue end

						Action_SpawnVehicle()
						local carWait = os.clock()
						local car = nil
						while os.clock() - carWait < 10 do
							if _G.MainCoreSession ~= Context.Session or not State.AutoFarmActive then return end
							car = GetPlayerCar()
							if car then break end
							task.wait(Config.LoopWait / 2)
						end
						if not car or not State.AutoFarmActive then task.wait(Config.RestartDelay) continue end

						State.AutoLoading = true
						RunLoadingLoop()
						local loadTimeout = os.clock()
						while State.AutoLoading and State.AutoFarmActive and (os.clock() - loadTimeout < 60) do
							if _G.MainCoreSession ~= Context.Session then return end
							task.wait(Config.LoopWait)
						end
						if not State.AutoFarmActive then break end

						State.AutoDelivering = true
						RunDeliveryLoop()
						local deliverTimeout = os.clock()
						while State.AutoDelivering and State.AutoFarmActive and (os.clock() - deliverTimeout < 300) do
							if _G.MainCoreSession ~= Context.Session then return end
							task.wait(Config.LoopWait)
						end
						if not State.AutoFarmActive then break end

						local returnCar = GetPlayerCar()
						if returnCar then
							EnterDriverSeat(returnCar)
							task.wait(Config.ActionDelay)
							if not State.AutoFarmActive then break end
							local Mf = GetBcaFolder()
							local CarSpawner = Mf and Mf:FindFirstChild("CAR_SPAWNER_NPC")
							if CarSpawner then
								DriveCarNaturallyTo(returnCar, CarSpawner:GetPivot().Position, Config.TweenSpeed)
							end
							ExitDriverSeat(returnCar)
						end
						if not State.AutoFarmActive then break end

						local Mf = GetBcaFolder()
						local StartNpc = Mf and Mf:FindFirstChild("NPC_START_JOB")
						if StartNpc then
							Utils.SafeTeleportChar(StartNpc:GetPivot(), Config.ActionDelay)
							task.wait(0.5)

							local prompt = StartNpc:FindFirstChildWhichIsA("ProximityPrompt", true)
							if prompt then prompt.Enabled = true end
							Utils.TriggerPrompt(prompt, StartNpc.PrimaryPart or StartNpc:FindFirstChildWhichIsA("BasePart"))
						end

						local endWait = os.clock()
						while State.Phase ~= "Unemployee" and (os.clock() - endWait < 10) do
							if _G.MainCoreSession ~= Context.Session or not State.AutoFarmActive then return end
							task.wait(Config.LoopWait / 2)
						end

						-- Fetch update saldo & earned setelah klaim gaji
						FetchPocketSaldo()

						task.wait(Config.RestartDelay)
					end

					Action_ResetAll()
				end)
			else
				print("🛑 [AutoFarm] Menghentikan botting & platform.")
				Action_ResetAll()
				if Utils.StopGiantPlatform then
					Utils.StopGiantPlatform()
				end
			end
		end
	})

	statusParagraph = ControlsSection:Paragraph({
		Title = "Status Pekerjaan",
		Desc = "Phase: Unemployee | Koper: 0/0",
		Image = "info"
	})

	task.spawn(function()
		while task.wait(0.3) do
			if _G.MainCoreSession ~= Context.Session then break end
			local statusText = string.format("Phase: %s | Koper: %s/%s", tostring(State.Phase), tostring(State.Loaded), tostring(State.Total))
			pcall(function()
				if statusParagraph then statusParagraph:SetDesc(statusText) end
				if FloatingDash then FloatingDash.UpdateStatus(statusText) end
			end)
		end
	end)

	SettingsSection:Input({
		Title = "Kecepatan Mengemudi (Speed)",
		Value = tostring(Config.TweenSpeed),
		Callback = function(val)
			local num = tonumber(val)
			if num then Config.TweenSpeed = num end
		end
	})

	SettingsSection:Slider({
		Title = "Durasi Minimum Perjalanan",
		Value = { Min = 10, Max = 45, Default = 20 },
		Callback = function(val) Config.MinTravelDuration = val end
	})

	SettingsSection:Slider({
		Title = "Jeda Aksi (Action Delay)",
		Value = { Min = 2, Max = 20, Default = 3 },
		Callback = function(val) Config.ActionDelay = val / 10 end
	})

	SettingsSection:Input({
		Title = "Jeda Mengulang (Restart Delay)",
		Value = tostring(Config.RestartDelay),
		Callback = function(val)
			local num = tonumber(val)
			if num then Config.RestartDelay = num end
		end
	})

	SettingsSection:Button({
		Title = "Paksa Reset Bot (Emergency Reset)",
		Callback = function() Action_ResetAll() end
	})
end

return BCA
