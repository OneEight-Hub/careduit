-- ==============================================================================
-- CDID HUB - BCA COURIER (STABLE HYBRID SCRIPT)
-- ==============================================================================
local BCA = {}

function BCA.Init(Window, Utils, Context, UICreate, DriveEngine)
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Workspace = game:GetService("Workspace")
	local LocalPlayer = Players.LocalPlayer

	-- CONFIGURABLE VALUES
	local Config = {
		DriveSpeed = 180,
		MinTravelDuration = 20,
		ActionDelay = 0.3,
		LoopWait = 0.4,
		RestartDelay = 2.0,
		FreezeCamera = true
	}

	-- STATE & FINANCIAL STATS & STOPWATCH
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

		-- Stopwatch / Timer Debugger
		TripStartTime = nil,
		CurrentTripElapsed = 0,
		LastTripDuration = 0,
		LastTripText = "Belum Ada",

		-- Financial Analytics
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
	local timerParagraph
	local Network = nil
	local NpcDialogEvent = nil
	local JobRemote = nil
	local FloatingDash = nil

	-- ==============================================================================
	-- HELPER FUNCTIONS
	-- ==============================================================================
	local function FormatRupiah(val)
		if type(val) ~= "number" then return tostring(val or "Rp 0") end
		local r = string.format("%d", math.floor(val)):reverse():gsub("%d%d%d", "%1."):reverse():gsub("^%.", "")
		return "Rp " .. r
	end

	local function FormatTime(seconds)
		seconds = math.floor(seconds or 0)
		local m = math.floor(seconds / 60)
		local s = seconds % 60
		return string.format("%02d:%02d (%d dtk)", m, s, seconds)
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

	local function TeleportNear(targetCF, offsetDist)
		offsetDist = offsetDist or 4.0
		local hum, hrp = GetValidHumanoid()
		if not hrp then return end
		local lookDir = targetCF.LookVector
		hrp.CFrame = CFrame.new(targetCF.Position + (lookDir * offsetDist), targetCF.Position)
		task.wait(Config.ActionDelay)
	end

	local function TriggerPrompt(prompt)
		if not prompt or not prompt:IsA("ProximityPrompt") then return end
		prompt.RequiresLineOfSight = false
		prompt.MaxActivationDistance = math.huge
		prompt.Enabled = true

		if fireproximityprompt then
			fireproximityprompt(prompt)
		else
			prompt:InputHoldBegin()
			task.wait((prompt.HoldDuration or 0.2) + 0.1)
			prompt:InputHoldEnd()
		end
	end

	local function ResetPlayerCamera()
		if DriveEngine and DriveEngine.FreezeCamera then
			DriveEngine.FreezeCamera(false)
		end
		local hum = GetValidHumanoid()
		local camera = Workspace.CurrentCamera
		if camera and hum then
			camera.CameraType = Enum.CameraType.Custom
			camera.CameraSubject = hum
			camera.FieldOfView = 70
		end
	end

	local function GetPlayerCar()
		if DriveEngine and DriveEngine.GetPlayerCar then
			return DriveEngine.GetPlayerCar()
		end
		local vehicles = Workspace:FindFirstChild("Vehicles")
		if not vehicles then return nil end
		for _, v in ipairs(vehicles:GetChildren()) do
			if v.Name:find(LocalPlayer.Name, 1, true) then
				return v
			end
		end
		return nil
	end

	local function GetPromptBagasi(bagasiPoint)
		if not bagasiPoint then return nil end
		return bagasiPoint:FindFirstChild("AmbilPrompt") 
			or bagasiPoint:FindFirstChild("MuatPrompt") 
			or bagasiPoint:FindFirstChildWhichIsA("ProximityPrompt", true)
	end

	-- ==============================================================================
	-- POCKET SALDO FETCHER
	-- ==============================================================================
	local function FetchPocketSaldo()
		task.spawn(function()
			local netContainer = ReplicatedStorage:FindFirstChild("NetworkContainer")
			local remoteEvents = netContainer and netContainer:FindFirstChild("RemoteEvents")
			local appOpened = remoteEvents and remoteEvents:FindFirstChild("MyBcaAppOpened")

			if appOpened then
				pcall(function() appOpened:FireServer() end)
			end

			task.wait(0.4)

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
					if not State.StartSaldo then
						State.StartSaldo = parsedNum
						State.StartSaldoText = FormatRupiah(parsedNum)
					else
						if parsedNum > State.CurrentSaldo and State.CurrentSaldo > 0 then
							State.LastGaji = parsedNum - State.CurrentSaldo
							State.LastGajiText = "+" .. FormatRupiah(State.LastGaji)
						end
					end

					State.CurrentSaldo = parsedNum
					State.CurrentSaldoText = FormatRupiah(parsedNum)

					if State.StartSaldo then
						State.EarnedSaldo = math.max(0, State.CurrentSaldo - State.StartSaldo)
						State.EarnedText = "+" .. FormatRupiah(State.EarnedSaldo)
					end

					if FloatingDash then
						FloatingDash.UpdateSaldoAwal(State.StartSaldoText)
						FloatingDash.UpdateCurrentSaldo(State.CurrentSaldoText)
						FloatingDash.UpdateEarned(State.EarnedText)
						FloatingDash.UpdateGajiTerakhir(State.LastGajiText)
					end
				end
			end

			pcall(function() phoneGui.Enabled = false end)
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

		FetchPocketSaldo()

		local modules = ReplicatedStorage:WaitForChild("Modules", 15)
		local netModule = modules and modules:WaitForChild("Network", 15)
		if netModule then Network = require(netModule) end

		local netContainer = ReplicatedStorage:WaitForChild("NetworkContainer", 15)
		local remoteEvents = netContainer and netContainer:WaitForChild("RemoteEvents", 15)
		NpcDialogEvent = remoteEvents and remoteEvents:WaitForChild("NpcDialog", 15)
		JobRemote = remoteEvents and remoteEvents:WaitForChild("Job", 15)

		if not Network or not NpcDialogEvent or not JobRemote then return end

		local dialogHook = NpcDialogEvent.OnClientEvent:Connect(function(action)
			if action == "Start" then
				task.spawn(function()
					task.wait(0.2)
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
					if not State.TripStartTime then
						State.TripStartTime = os.clock()
					end
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
				State.TripStartTime = os.clock()

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

				if State.TripStartTime then
					State.LastTripDuration = os.clock() - State.TripStartTime
					State.LastTripText = FormatTime(State.LastTripDuration)
					print(string.format("⏱️ [BCA Timer] Trip #%d selesai dalam durasi: %s", State.TotalTrips, State.LastTripText))
					State.TripStartTime = nil
				end

				if FloatingDash then FloatingDash.UpdateTrips(State.TotalTrips) end
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
		if not Mf or State.Phase == "Loading" or State.Phase == "Delivering" then return end
		local StartNpc = Mf:FindFirstChild("NPC_START_JOB")
		if not StartNpc then return end

		print("⚡ [Step 1] Memulai Job di NPC...")
		State.TripStartTime = os.clock()

		TeleportNear(StartNpc:GetPivot(), 4.0)

		local prompt = StartNpc:FindFirstChildWhichIsA("ProximityPrompt", true)
		if prompt then
			TriggerPrompt(prompt)
		end

		if NpcDialogEvent then
			NpcDialogEvent:FireServer("Finish", nil)
		end

		local dialogWait = os.clock()
		while State.Phase == "Unemployee" and (os.clock() - dialogWait < 4) do task.wait(0.1) end
		task.wait(Config.ActionDelay)
	end

	local function Action_SpawnVehicle()
		local Mf = GetBcaFolder()
		if not Mf then return end
		local CarSpawner = Mf:FindFirstChild("CAR_SPAWNER_NPC")
		if not CarSpawner then return end

		print("🚗 [Step 2] Memunculkan Mobil dari Spawner...")
		TeleportNear(CarSpawner:GetPivot(), 4.0)

		local spawnPrompt = CarSpawner:FindFirstChildWhichIsA("ProximityPrompt", true)
		if spawnPrompt then
			TriggerPrompt(spawnPrompt)
		end
		task.wait(1.0)
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
				local bagasiPrompt = GetPromptBagasi(bagasiPoint)
				local koperPrompt = KoperSpawn:FindFirstChildWhichIsA("ProximityPrompt", true)

				if not State.Carrying and not State.IsBusy then
					State.IsBusy = true
					TeleportNear(KoperSpawn:GetPivot(), 2.5)
					TriggerPrompt(koperPrompt)
					local timeout = os.clock()
					while not State.Carrying and State.AutoLoading and (os.clock() - timeout < 2.5) do task.wait(0.1) end
					State.IsBusy = false
				elseif State.Carrying and not State.IsBusy then
					if bagasiPoint and bagasiPrompt then
						State.IsBusy = true
						local hum, hrp = GetValidHumanoid()
						if hrp then hrp.CFrame = CFrame.new(bagasiPoint.Position + Vector3.new(0, 1.2, 0)) end
						task.wait(0.15)
						TriggerPrompt(bagasiPrompt)
						local timeout = os.clock()
						while State.Carrying and State.AutoLoading and (os.clock() - timeout < 2.5) do task.wait(0.1) end
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
			print("🏧 [Step 4] Memulai siklus pengantaran koper ke ATM...")
			while State.AutoDelivering do
				if _G.MainCoreSession ~= Context.Session then break end
				if (State.Loaded <= 0 and not State.Carrying) or (State.Phase == "Returning" and State.Loaded <= 0) then
					State.AutoDelivering = false
					break
				end

				local car = GetPlayerCar()
				local bagasiPoint = car and car:FindFirstChild("BagasiPoint", true)
				local ambilPrompt = GetPromptBagasi(bagasiPoint)

				if car and not State.IsBusy then
					local hum, hrp = GetValidHumanoid()
					local distToAtm = (hrp and State.TargetPos) and (hrp.Position - State.TargetPos).Magnitude or 999

					-- 1. FASE MENYETIR KE ATM
					if not State.Carrying and State.TargetPos and distToAtm > 45 then
						State.IsBusy = true

						if DriveEngine and not DriveEngine.IsDriving() then
							DriveEngine.DriveTo(State.TargetPos, {
								Speed = Config.DriveSpeed,
								MinDuration = Config.MinTravelDuration,
								FreezeCam = Config.FreezeCamera,
								StopCondition = function()
									return not State.AutoDelivering or not State.AutoFarmActive or (_G.MainCoreSession ~= Context.Session)
								end
							})
						end

						local curHum = GetValidHumanoid()
						if curHum and curHum.Sit then
							curHum.Sit = false
							task.wait(Config.ActionDelay)
						end

						State.IsBusy = false
					end

					if not State.AutoDelivering then break end

					-- 2. FASE AMBIL KOPER DARI BAGASI
					if not State.Carrying and bagasiPoint and ambilPrompt and distToAtm <= 75 then
						State.IsBusy = true

						local curHum, curHrp = GetValidHumanoid()
						if curHum and curHum.Sit then
							curHum.Sit = false
							task.wait(0.2)
						end
						if curHrp then
							curHrp.CFrame = CFrame.new(bagasiPoint.Position + Vector3.new(0, 1.2, 0))
						end
						task.wait(0.15)

						TriggerPrompt(ambilPrompt)

						local waitCarry = os.clock()
						while not State.Carrying and State.AutoDelivering and (os.clock() - waitCarry < 2.5) do 
							task.wait(0.1) 
						end
						State.IsBusy = false
						task.wait(Config.ActionDelay)
					end

					if not State.AutoDelivering then break end

					-- 3. FASE ISI KOPER KE ATM
					if State.Carrying then
						State.IsBusy = true
						task.wait(0.2)

						if Network then 
							Network:FireServer("BankCourier", "FillStart") 
						end

						local waitFill = os.clock()
						while State.Carrying and State.AutoDelivering and (os.clock() - waitFill < 8.0) do 
							task.wait(0.2) 
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
		State.AutoFarmActive = false
		State.AutoLoading = false
		State.AutoDelivering = false
		State.LoadingActive = false
		State.DeliveryActive = false
		State.IsBusy = false
		State.Phase = "Unemployee"
		State.Loaded = 0
		State.Total = 0
		State.TripStartTime = nil

		ResetPlayerCamera()
		if autoFarmToggle then pcall(function() autoFarmToggle:Set(false) end) end
		if statusParagraph then pcall(function() statusParagraph:SetDesc("Phase: Unemployee | Koper: 0/0") end) end
		if timerParagraph then pcall(function() timerParagraph:SetDesc("Stopwatch: 00:00 (0 dtk) | Terakhir: " .. State.LastTripText) end) end

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

	local ControlsSection = BCATab:Section({ Title = "Auto Farm Controls", Opened = true })
	local DashboardSection = BCATab:Section({ Title = "Floating Mini Dashboard", Opened = true })
	local SettingsSection = BCATab:Section({ Title = "Konfigurasi Drive Engine", Opened = true })

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

	autoFarmToggle = ControlsSection:Toggle({
		Title = "Endless Auto Farm",
		Desc = "Mulai siklus kurir instan dan stabil.",
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
				print("🚀 [AutoFarm] Memulai Auto Farm BCA Courier...")
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

						-- Kembali ke Spawner
						local returnCar = GetPlayerCar()
						local Mf = GetBcaFolder()
						local CarSpawner = Mf and Mf:FindFirstChild("CAR_SPAWNER_NPC")
						if returnCar and CarSpawner and DriveEngine then
							DriveEngine.DriveTo(CarSpawner:GetPivot().Position, {
								Speed = Config.DriveSpeed,
								MinDuration = 10,
								FreezeCam = Config.FreezeCamera,
								StopCondition = function()
									return not State.AutoFarmActive or (_G.MainCoreSession ~= Context.Session)
								end
							})
							local curHum = GetValidHumanoid()
							if curHum and curHum.Sit then curHum.Sit = false end
						end
						if not State.AutoFarmActive then break end

						-- Finish Job
						local StartNpc = Mf and Mf:FindFirstChild("NPC_START_JOB")
						if StartNpc then
							TeleportNear(StartNpc:GetPivot(), 4.0)
							local prompt = StartNpc:FindFirstChildWhichIsA("ProximityPrompt", true)
							if prompt then TriggerPrompt(prompt) end
							if NpcDialogEvent then NpcDialogEvent:FireServer("Finish", nil) end
						end

						local endWait = os.clock()
						while State.Phase ~= "Unemployee" and (os.clock() - endWait < 10) do
							if _G.MainCoreSession ~= Context.Session or not State.AutoFarmActive then return end
							task.wait(Config.LoopWait / 2)
						end

						FetchPocketSaldo()
						task.wait(Config.RestartDelay)
					end

					Action_ResetAll()
				end)
			else
				print("🛑 [AutoFarm] Menghentikan botting.")
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

	timerParagraph = ControlsSection:Paragraph({
		Title = "Stopwatch Trip (Debug Timer)",
		Desc = "Stopwatch: 00:00 (0 dtk) | Terakhir: Belum Ada",
		Image = "clock"
	})

	-- Live status & Stopwatch updater
	task.spawn(function()
		while task.wait(0.5) do
			if _G.MainCoreSession ~= Context.Session then break end
			
			local currentElapsed = 0
			if State.TripStartTime and State.AutoFarmActive and State.Phase ~= "Unemployee" then
				currentElapsed = os.clock() - State.TripStartTime
			end

			local statusText = string.format("Phase: %s | Koper: %s/%s", tostring(State.Phase), tostring(State.Loaded), tostring(State.Total))
			local timerText = string.format("Sedang Berjalan: %s | Trip Sebelumnya: %s", FormatTime(currentElapsed), State.LastTripText)

			pcall(function()
				if statusParagraph then statusParagraph:SetDesc(statusText) end
				if timerParagraph then timerParagraph:SetDesc(timerText) end
				if FloatingDash then 
					FloatingDash.UpdateStatus(string.format("%s | %s", statusText, FormatTime(currentElapsed))) 
				end
			end)
		end
	end)

	SettingsSection:Toggle({
		Title = "Freeze Camera Saat Melaju (FPS Boost)",
		Desc = "Mengunci kamera saat mobil bergerak untuk menurunkan beban render GPU.",
		Value = Config.FreezeCamera,
		Callback = function(val)
			Config.FreezeCamera = val
		end
	})

	SettingsSection:Input({
		Title = "Kecepatan Mengemudi (Speed)",
		Value = tostring(Config.DriveSpeed),
		Callback = function(val)
			local num = tonumber(val)
			if num then Config.DriveSpeed = num end
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
