-- ==============================================================================
-- CDID HUB - AUTO FARM MERDEKA RACE EVENT (SAFE DRIVE MOBIL)
-- ==============================================================================
local MerdekaFarm = {}

function MerdekaFarm.Init(Window, Utils, Context, UICreate)
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Workspace = game:GetService("Workspace")
	local RunService = game:GetService("RunService")
	local LocalPlayer = Players.LocalPlayer

	-- CONFIGURABLE VALUES
	local Config = {
		DriveSpeed = 190,
		MinTravelDuration = 8,
		ActionDelay = 0.3,
		LoopWait = 0.5,
		RestartDelay = 3.0,
		DefaultLobbyName = "CDID_AutoMerdeka"
	}

	-- STATE & STATS
	local State = {
		AutoFarmActive = false,
		InLobby = false,
		IsHost = false,
		IsRacing = false,
		IsCarryingFlag = false,

		LobbyId = nil,
		SelectedCar = "None",
		AvailableCars = {},

		-- Target Waypoints dari Server
		CurrentTargetPos = nil,
		FlagPos = nil,
		BasePos = nil,
		FlagName = "",

		-- Financial & Race Stats
		PlantedCount = 0,
		TotalFlags = 0,
		RacesCompleted = 0,
		MerdekaPoints = 0,
		LastReward = 0
	}

	local isDrivingActive = false
	local autoFarmToggle
	local statusParagraph
	local FloatingDash = nil

	-- ==============================================================================
	-- HELPER FUNCTIONS
	-- ==============================================================================
	local function FormatNumber(val)
		if type(val) ~= "number" then return tostring(val or 0) end
		local r = string.format("%d", math.floor(val)):reverse():gsub("%d%d%d", "%1."):reverse():gsub("^%.", "")
		return r
	end

	local function GetValidHumanoid()
		local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum and hum.Health > 0 then
			return hum, char:FindFirstChild("HumanoidRootPart")
		end
		return nil, nil
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

	local function EnsurePlayerSeated(car)
		local hum, hrp = GetValidHumanoid()
		if not hum or not hrp or not car then return false end

		local seat = car:FindFirstChildWhichIsA("VehicleSeat", true) 
			or car:FindFirstChild("DriveSeat", true) 
			or car:FindFirstChild("DriverSeat", true)

		if not seat then return false end
		if hum.SeatPart == seat or hum.Sit then return true end

		local primary = car.PrimaryPart or car:FindFirstChildWhichIsA("BasePart")
		if primary then primary.Anchored = false end

		hrp.CFrame = seat.CFrame * CFrame.new(0, 1.2, 1.2)
		task.wait(Config.ActionDelay)

		local drivePrompt = seat:FindFirstChild("PromptDriveSeat", true)
			or seat:FindFirstChildWhichIsA("ProximityPrompt", true)
			or car:FindFirstChild("PromptDriveSeat", true)

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

	-- ==============================================================================
	-- SAFE DRIVE (SMOOTHSTEP PATHING ANTI-RUBBERBAND)
	-- ==============================================================================
	local function DriveCarNaturallyTo(targetPos, speed)
		if isDrivingActive or not targetPos then return end
		isDrivingActive = true

		local car = GetPlayerCar()
		if not car then
			isDrivingActive = false
			return
		end

		speed = speed or Config.DriveSpeed
		local primary = car.PrimaryPart or car:FindFirstChildWhichIsA("BasePart")
		local seat = car:FindFirstChildWhichIsA("VehicleSeat", true)
		if not primary then
			isDrivingActive = false
			return
		end

		EnsurePlayerSeated(car)

		local startCF = car:GetPivot()
		local dirToTarget = (targetPos - startCF.Position).Unit
		local flatDir = Vector3.new(dirToTarget.X, 0, dirToTarget.Z).Unit
		local stopPos = targetPos + Vector3.new(0, 1.5, 0)
		local targetCF = CFrame.new(stopPos, stopPos + flatDir)

		local dist = (startCF.Position - stopPos).Magnitude
		local duration = math.max(Config.MinTravelDuration, dist / speed)

		primary.Anchored = false

		-- Nonaktifkan tabrakan body mobil agar tidak nyangkut part tak terlihat
		for _, p in ipairs(car:GetDescendants()) do
			if p:IsA("BasePart") and p.Name ~= "VehicleSeat" and p ~= primary then
				p.CanCollide = false
			end
		end

		local startTime = os.clock()
		print(string.format("🏎️ [Merdeka Drive] Meluncur ke target (Jarak: %.0f studs | Estimasi: %.1f dtk)...", dist, duration))

		while State.AutoFarmActive and State.IsRacing do
			if _G.MainCoreSession ~= Context.Session then break end

			local elapsed = os.clock() - startTime
			local alpha = math.clamp(elapsed / duration, 0, 1)

			-- Smoothstep interpolation
			local smoothAlpha = alpha * alpha * (3 - 2 * alpha)
			local currentCF = startCF:Lerp(targetCF, smoothAlpha)

			local hum = GetValidHumanoid()
			if hum and not hum.Sit and seat then
				pcall(function() seat:Sit(hum) end)
			end

			car:PivotTo(currentCF)
			primary.AssemblyLinearVelocity = Vector3.zero
			primary.AssemblyAngularVelocity = Vector3.zero

			if alpha >= 1 then break end
			RunService.Heartbeat:Wait()
		end

		car:PivotTo(targetCF)
		for _, p in ipairs(car:GetDescendants()) do
			if p:IsA("BasePart") then
				p.AssemblyLinearVelocity = Vector3.zero
				p.AssemblyAngularVelocity = Vector3.zero
			end
		end

		task.wait(0.2)
		primary.Anchored = true
		task.wait(Config.ActionDelay)

		isDrivingActive = false
	end

	-- ==============================================================================
	-- FETCH DATA MOBIL & SHOP MERDEKA
	-- ==============================================================================
	local function FetchOwnedCars()
		State.AvailableCars = {}
		local success, dataRep = pcall(function()
			return require(ReplicatedStorage.Services.DataReplication)
		end)

		if success and dataRep and dataRep.GetVehicleData then
			local ok, vehData = pcall(dataRep.GetVehicleData, dataRep)
			if ok and type(vehData) == "table" then
				for carName, _ in pairs(vehData) do
					table.insert(State.AvailableCars, carName)
				end
			end
		end

		if #State.AvailableCars == 0 and ReplicatedStorage:FindFirstChild("CarData") then
			for _, car in ipairs(ReplicatedStorage.CarData:GetChildren()) do
				table.insert(State.AvailableCars, car.Name)
			end
		end

		table.sort(State.AvailableCars)
		if #State.AvailableCars > 0 and State.SelectedCar == "None" then
			State.SelectedCar = State.AvailableCars[1]
		end
	end

	local function FetchMerdekaShopData()
		task.spawn(function()
			local netModule = ReplicatedStorage:FindFirstChild("Modules") and ReplicatedStorage.Modules:FindFirstChild("Network")
			if not netModule then return end
			local ok, Net = pcall(require, netModule)
			if not ok or not Net then return end

			local data = Net:InvokeServer("MerdekaShopData")
			if type(data) == "table" and data.Points then
				State.MerdekaPoints = data.Points
				if FloatingDash then
					FloatingDash.UpdateSaldo(string.format("%s Pts", FormatNumber(State.MerdekaPoints)))
				end
			end
		end)
	end

	FetchOwnedCars()

	-- ==============================================================================
	-- REMOTES & NETWORK HOOKS
	-- ==============================================================================
	local RaceRemotes = ReplicatedStorage:WaitForChild("RaceRemotes", 10)
	local CreateLobbyRemote = RaceRemotes and RaceRemotes:WaitForChild("CreateLobby", 5)
	local JoinLobbyRemote   = RaceRemotes and RaceRemotes:WaitForChild("JoinLobby", 5)
	local LeaveLobbyRemote  = RaceRemotes and RaceRemotes:WaitForChild("LeaveLobby", 5)
	local ToggleReadyRemote = RaceRemotes and RaceRemotes:WaitForChild("ToggleReady", 5)
	local StartRaceRemote   = RaceRemotes and RaceRemotes:WaitForChild("StartRace", 5)
	local SelectCarRemote   = RaceRemotes and RaceRemotes:WaitForChild("SelectCar", 5)
	local GetLobbiesFunc    = RaceRemotes and RaceRemotes:WaitForChild("GetLobbies", 5)
	local LobbyUpdatedEvent = RaceRemotes and RaceRemotes:WaitForChild("LobbyUpdated", 5)

	-- 1. Hook Status Lobi
	if LobbyUpdatedEvent then
		local lobbyHook = LobbyUpdatedEvent.OnClientEvent:Connect(function(lobbyData)
			if typeof(lobbyData) ~= "table" or lobbyData.mode ~= "merdeka" then return end

			State.LobbyId = lobbyData.id
			State.InLobby = true

			local isReady = false
			local allReady = true

			if lobbyData.players then
				for _, p in ipairs(lobbyData.players) do
					if p.userId == LocalPlayer.UserId then
						isReady = p.ready
						if p.isHost then State.IsHost = true end
					end
					if not p.ready then
						allReady = false
					end
				end
			end

			-- Auto Ready
			if State.AutoFarmActive and not isReady and State.SelectedCar ~= "None" then
				task.wait(0.5)
				if ToggleReadyRemote then ToggleReadyRemote:FireServer() end
			end

			-- Auto Start Race jika Host
			if State.AutoFarmActive and State.IsHost and allReady and (lobbyData.playerCount >= (lobbyData.minPlayers or 1)) then
				task.wait(1.5)
				if StartRaceRemote then StartRaceRemote:FireServer() end
			end
		end)
		table.insert(Context.Hooks, lobbyHook)
	end

	-- 2. Hook Gameplay MerdekaHUD
	local NetworkModule = ReplicatedStorage:FindFirstChild("Modules") and ReplicatedStorage.Modules:FindFirstChild("Network")
	if NetworkModule then
		local ok, Net = pcall(require, NetworkModule)
		if ok and Net and Net.OnClientEvent then
			local hudHook = Net.OnClientEvent("MerdekaHUD", function(action, payload)
				payload = payload or {}

				if action == "Init" or action == "Briefing" or action == "Countdown" then
					State.IsRacing = true

					-- Bypass / Tutup UI Briefing bawaan
					local pGui = LocalPlayer:FindFirstChild("PlayerGui")
					local eventGui = pGui and pGui:FindFirstChild("MerdekaEvent")
					if eventGui then
						local container = eventGui:FindFirstChild("Container")
						if container then
							for _, name in ipairs({"Briefing", "Lobby", "LobbyMenu", "Countdown", "Overlay"}) do
								local frame = container:FindFirstChild(name)
								if frame then frame.Visible = false end
							end
						end
					end

				elseif action == "Start" then
					State.IsRacing = true
					State.IsCarryingFlag = false
					State.FlagPos = payload.FlagPos
					State.FlagName = payload.FlagName or "Flag"
					State.TotalFlags = payload.Total or 0
					State.CurrentTargetPos = payload.FlagPos
					print(string.format("🚩 [MerdekaHUD] Race Mulai! Target Bendera: %s", tostring(State.FlagName)))

				elseif action == "Picked" then
					State.IsCarryingFlag = true
					State.BasePos = payload.BasePos
					State.CurrentTargetPos = payload.BasePos
					print("📦 [MerdekaHUD] Bendera terambil! Mengantar kembali ke Base...")

				elseif action == "Planted" then
					State.IsCarryingFlag = false
					State.PlantedCount = State.PlantedCount + 1
					print(string.format("🎯 [MerdekaHUD] Bendera berhasil ditancapkan! (Total: %d)", State.PlantedCount))

				elseif action == "Tick" then
					if payload.Planted then State.PlantedCount = payload.Planted end
					if payload.Total then State.TotalFlags = payload.Total end

				elseif action == "Result" then
					State.IsRacing = false
					State.InLobby = false
					State.IsCarryingFlag = false
					isDrivingActive = false
					State.RacesCompleted = State.RacesCompleted + 1
					State.LastReward = payload.Reward or 0

					print(string.format("🏆 [MerdekaHUD] Balapan Selesai! Reward: +%s", FormatNumber(State.LastReward)))

					-- Bypass / Tutup UI Result
					local pGui = LocalPlayer:FindFirstChild("PlayerGui")
					local eventGui = pGui and pGui:FindFirstChild("MerdekaEvent")
					if eventGui then
						local resFrame = eventGui:FindFirstChild("Container") and eventGui.Container:FindFirstChild("Result")
						if resFrame then resFrame.Visible = false end
					end

					FetchMerdekaShopData()

				elseif action == "Left" or action == "Reset" then
					State.IsRacing = false
					State.InLobby = false
					State.IsCarryingFlag = false
					isDrivingActive = false
				end
			end)
			table.insert(Context.Hooks, hudHook)
		end
	end

	-- ==============================================================================
	-- CORE AUTOFARM LOOP (SAFE DRIVE EXECUTION)
	-- ==============================================================================
	local function StartAutoFarmLoop()
		task.spawn(function()
			print("🚀 [Merdeka Farm] Loop Auto Farm Dimulai...")
			FetchMerdekaShopData()

			while State.AutoFarmActive do
				if _G.MainCoreSession ~= Context.Session then break end

				-- A. JIKA SEDANG BALAPAN: GERAKKAN MOBIL KE TARGET WAYPOINT
				if State.IsRacing then
					local car = GetPlayerCar()
					if car and State.CurrentTargetPos and not isDrivingActive then
						DriveCarNaturallyTo(State.CurrentTargetPos, Config.DriveSpeed)
					end
					task.wait(Config.LoopWait)
					continue
				end

				-- B. JIKA BELUM MASUK LOBI: CARI ATAU BUAT LOBI BARU
				if not State.InLobby and not State.IsRacing then
					local targetLobbyId = nil

					if GetLobbiesFunc then
						local ok, lobbies = pcall(function() return GetLobbiesFunc:InvokeServer() end)
						if ok and type(lobbies) == "table" then
							for _, l in ipairs(lobbies) do
								if l.mode == "merdeka" and l.status == "waiting" and (l.playerCount < (l.maxPlayers or 4)) then
									targetLobbyId = l.id
									break
								end
							end
						end
					end

					if targetLobbyId and JoinLobbyRemote then
						print("🚪 [Merdeka Farm] Bergabung ke lobi publik ID:", targetLobbyId)
						JoinLobbyRemote:FireServer(targetLobbyId)
						task.wait(1.0)
					elseif CreateLobbyRemote then
						print("✨ [Merdeka Farm] Membuat lobi Merdeka baru...")
						CreateLobbyRemote:FireServer(Config.DefaultLobbyName, "merdeka")
						State.IsHost = true
						task.wait(1.0)
					end

					-- Pilih mobil
					if State.SelectedCar ~= "None" and SelectCarRemote then
						task.wait(0.5)
						SelectCarRemote:FireServer(State.SelectedCar)
					end
				end

				-- C. JIKA DI DALAM LOBI: KUNCI STATUS READY
				if State.InLobby and ToggleReadyRemote and not State.IsRacing then
					ToggleReadyRemote:FireServer()
					task.wait(1.0)
				end

				task.wait(Config.LoopWait)
			end

			-- Reset Saat OFF
			if LeaveLobbyRemote and State.InLobby then
				LeaveLobbyRemote:FireServer()
			end
			State.InLobby = false
			State.IsRacing = false
			isDrivingActive = false
		end)
	end

	-- ==============================================================================
	-- UI WINDUI TAB SETUP
	-- ==============================================================================
	local MerdekaTab = Window:Tab({
		Title = "Merdeka Event",
		Icon = "solar:flag-bold"
	})

	local ControlsSection = MerdekaTab:Section({ Title = "Kontrol Auto Farm Merdeka" })
	local CarSection      = MerdekaTab:Section({ Title = "Pilihan Mobil Balap" })
	local SettingsSection = MerdekaTab:Section({ Title = "Konfigurasi Kecepatan Safe Drive" })
	local StatusSection   = MerdekaTab:Section({ Title = "Live Monitor & Shop Points" })

	StatusSection:Button({
		Title = "Toggle Floating Monitor (Merdeka Points)",
		Desc = "Buka overlay mini untuk memantau status balapan dan poin reward.",
		Callback = function()
			if not FloatingDash then
				FloatingDash = UICreate.CreateFloatingDashboard("Merdeka Race Monitor")
				FloatingDash.UpdateSaldo(string.format("%s Pts", FormatNumber(State.MerdekaPoints)))
				FloatingDash.UpdateStatus("Status: Standby")
				FloatingDash.UpdateTrips(State.RacesCompleted)
				FetchMerdekaShopData()
			else
				FloatingDash.Destroy()
				FloatingDash = nil
			end
		end
	})

	-- DROPDOWN MOBIL
	local carDropdown = CarSection:Dropdown({
		Title = "Pilih Mobil Balap",
		Desc = "Mobil yang akan otomatis dipilih saat masuk lobi.",
		Values = #State.AvailableCars > 0 and State.AvailableCars or { "None" },
		Value = State.SelectedCar,
		Callback = function(chosen)
			State.SelectedCar = chosen
			print("🚗 [Merdeka Farm] Mobil dipilih:", chosen)
			if State.InLobby and SelectCarRemote and chosen ~= "None" then
				SelectCarRemote:FireServer(chosen)
			end
		end
	})

	CarSection:Button({
		Title = "Refresh Daftar Mobil",
		Callback = function()
			FetchOwnedCars()
			if carDropdown and carDropdown.SetValues then
				carDropdown:SetValues(State.AvailableCars)
			end
			print("🔄 [Merdeka Farm] Daftar mobil diperbarui.")
		end
	})

	-- TOGGLE AUTO FARM
	autoFarmToggle = ControlsSection:Toggle({
		Title = "Auto Farm Merdeka Race (Safe Drive)",
		Desc = "Lobi Otomatis -> Safe Drive Ambil Bendera -> Antar ke Base -> Endless Loop.",
		Value = false,
		Callback = function(active)
			if State.AutoFarmActive == active then return end
			State.AutoFarmActive = active

			if active then
				print("🚀 [Merdeka Farm] Mengaktifkan Auto Farm...")
				if Utils.DestroyHeavyMaps then
					Utils.DestroyHeavyMaps()
				elseif Utils.StartGiantPlatform then
					Utils.StartGiantPlatform()
				end
				StartAutoFarmLoop()
			else
				print("🛑 [Merdeka Farm] Mematikan Auto Farm...")
				if Utils.StopGiantPlatform then
					Utils.StopGiantPlatform()
				end
			end
		end
	})

	statusParagraph = ControlsSection:Paragraph({
		Title = "Status Pekerjaan",
		Desc = "Status: Idle | Bendera: 0/0 | Selesai: 0",
		Image = "flag"
	})

	task.spawn(function()
		while task.wait(0.4) do
			if _G.MainCoreSession ~= Context.Session then break end
			local stateText = "Idle"
			if State.IsRacing then
				if State.IsCarryingFlag then
					stateText = "Mengantar Bendera ke Base 📦"
				else
					stateText = "Meluncur ke Titik Bendera 🚩"
				end
			elseif State.InLobby then
				stateText = "Di Lobi (Menunggu Ready/Start) ⏳"
			end

			local fullDesc = string.format("Status: %s | Bendera: %d/%d | Selesai: %d", stateText, State.PlantedCount, State.TotalFlags, State.RacesCompleted)
			pcall(function()
				if statusParagraph then statusParagraph:SetDesc(fullDesc) end
				if FloatingDash then
					FloatingDash.UpdateStatus(stateText)
					FloatingDash.UpdateTrips(State.RacesCompleted)
				end
			end)
		end
	end)

	SettingsSection:Input({
		Title = "Kecepatan Safe Drive Mobil",
		Value = tostring(Config.DriveSpeed),
		Callback = function(val)
			local num = tonumber(val)
			if num then Config.DriveSpeed = num end
		end
	})

	SettingsSection:Slider({
		Title = "Durasi Minimum Perjalanan",
		Value = { Min = 5, Max = 30, Default = 8 },
		Callback = function(val) Config.MinTravelDuration = val end
	})
end

return MerdekaFarm
