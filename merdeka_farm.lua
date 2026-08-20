-- ==============================================================================
-- CDID HUB - AUTO FARM MERDEKA RACE EVENT (INSTANT TELEPORT SYNC MODE)
-- ==============================================================================
local MerdekaFarm = {}

function MerdekaFarm.Init(Window, Utils, Context, UICreate, DriveEngine)
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Workspace = game:GetService("Workspace")
	local LocalPlayer = Players.LocalPlayer

	-- CONFIGURABLE VALUES
	local Config = {
		TeleportDelay = 0.35, -- Jeda kestabilan fisika setelah teleport (detik)
		LoopWait = 0.25,
		DefaultLobbyName = "CDID_InstantMerdeka"
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

		-- Target Waypoints
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
		if DriveEngine and DriveEngine.GetPlayerCar then
			local c = DriveEngine.GetPlayerCar()
			if c then return c end
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

	-- EKSEKUTOR INSTANT TELEPORT MOBIL + DRIVER SEAT SYNC
	local function InstantTeleportCarWithPlayer(targetPos)
		if not targetPos then return end
		local car = GetPlayerCar()
		local hum, hrp = GetValidHumanoid()
		if not hum or not hrp then return end

		local driveSeat = car and (car:FindFirstChildWhichIsA("VehicleSeat", true) or car:FindFirstChild("DriveSeat", true))

		-- 1. Pindahkan Mobil jika ada
		if car and car.PrimaryPart then
			car.PrimaryPart.AssemblyLinearVelocity = Vector3.zero
			car.PrimaryPart.AssemblyAngularVelocity = Vector3.zero
			
			local targetCF = CFrame.new(targetPos + Vector3.new(0, 2.5, 0))
			car:SetPrimaryPartCFrame(targetCF)
		end

		-- 2. Sinkronkan Karakter Duduk di Kursi
		if driveSeat then
			hrp.CFrame = driveSeat.CFrame + Vector3.new(0, 1.0, 0)
			if not hum.Sit then
				driveSeat:Sit(hum)
			end
		else
			-- Fallback jika mobil belum spawn / tanpa vehicle seat
			hrp.CFrame = CFrame.new(targetPos + Vector3.new(0, 1.5, 0))
		end

		task.wait(Config.TeleportDelay)
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
			if type(data) == "table" then
				State.MerdekaPoints = data.Points or data.Point or 0
				if FloatingDash then
					FloatingDash.UpdateSaldo(string.format("%s PTS", FormatNumber(State.MerdekaPoints)))
				end
			end
		end)
	end

	local function OpenMerdekaShopDirect()
		task.spawn(function()
			local pGui = LocalPlayer:FindFirstChild("PlayerGui")
			local eventGui = pGui and pGui:FindFirstChild("MerdekaEvent")
			local modules = eventGui and eventGui:FindFirstChild("Modules")
			local shopModObj = modules and modules:FindFirstChild("MerdekaShopModule")
			local netModule = ReplicatedStorage:FindFirstChild("Modules") and ReplicatedStorage.Modules:FindFirstChild("Network")

			if shopModObj and netModule then
				local okShop, ShopModule = pcall(require, shopModObj)
				local okNet, Net = pcall(require, netModule)

				if okShop and ShopModule and okNet and Net then
					local shopData = Net:InvokeServer("MerdekaShopData")
					if type(shopData) == "table" and shopData.Rewards then
						local owned = shopData.Owned or {}
						local formattedData = {
							["Point"] = shopData.Points or 0
						}
						for _, reward in ipairs(shopData.Rewards) do
							formattedData[reward.dataKey] = owned[reward.dataKey] and 1 or 0
						end

						ShopModule.SetCatalog(shopData.Rewards)
						ShopModule.UpdateData(formattedData)
						ShopModule.Open()

						State.MerdekaPoints = shopData.Points or 0
						if FloatingDash then
							FloatingDash.UpdateSaldo(string.format("%s PTS", FormatNumber(State.MerdekaPoints)))
						end
					end
				end
			end
		end)
	end

	FetchOwnedCars()
	FetchMerdekaShopData()

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
				task.wait(0.3)
				if ToggleReadyRemote then ToggleReadyRemote:FireServer() end
			end

			-- Auto Start Race jika Host
			if State.AutoFarmActive and State.IsHost and allReady and (lobbyData.playerCount >= (lobbyData.minPlayers or 1)) then
				task.wait(1.0)
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
					print(string.format("🚩 [MerdekaHUD] Race Mulai! Menuju Bendera: %s", tostring(State.FlagName)))

				elseif action == "Picked" then
					State.IsCarryingFlag = true
					State.BasePos = payload.BasePos
					State.CurrentTargetPos = payload.BasePos
					print("📦 [MerdekaHUD] Bendera terambil! Teleport balik ke Base...")

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
				end
			end)
			table.insert(Context.Hooks, hudHook)
		end
	end

	-- ==============================================================================
	-- CORE INSTANT AUTOFARM LOOP
	-- ==============================================================================
	local function StartAutoFarmLoop()
		task.spawn(function()
			print("🚀 [Merdeka Farm] Loop Instant Teleport Dimulai...")
			FetchMerdekaShopData()

			while State.AutoFarmActive do
				if _G.MainCoreSession ~= Context.Session then break end

				-- A. SAAT SEDANG BALAPAN: INSTANT TELEPORT MOBIL KE TARGET
				if State.IsRacing then
					if State.CurrentTargetPos then
						InstantTeleportCarWithPlayer(State.CurrentTargetPos)
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
						print("🚪 [Merdeka Farm] Bergabung ke lobi ID:", targetLobbyId)
						JoinLobbyRemote:FireServer(targetLobbyId)
						task.wait(0.8)
					elseif CreateLobbyRemote then
						print("✨ [Merdeka Farm] Membuat lobi Merdeka baru...")
						CreateLobbyRemote:FireServer(Config.DefaultLobbyName, "merdeka")
						State.IsHost = true
						task.wait(0.8)
					end

					-- Pilih mobil
					if State.SelectedCar ~= "None" and SelectCarRemote then
						task.wait(0.3)
						SelectCarRemote:FireServer(State.SelectedCar)
					end
				end

				-- C. JIKA DI DALAM LOBI: KUNCI READY
				if State.InLobby and ToggleReadyRemote and not State.IsRacing then
					ToggleReadyRemote:FireServer()
					task.wait(0.8)
				end

				task.wait(Config.LoopWait)
			end

			-- Reset Saat OFF
			if LeaveLobbyRemote and State.InLobby then
				LeaveLobbyRemote:FireServer()
			end
			State.InLobby = false
			State.IsRacing = false
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
	local StatusSection   = MerdekaTab:Section({ Title = "Live Monitor & Shop Points" })
	local SettingsSection = MerdekaTab:Section({ Title = "Pengaturan Delay" })

	StatusSection:Button({
		Title = "Toggle Floating Monitor (Merdeka Points)",
		Desc = "Buka overlay mini untuk memantau status balapan dan poin reward.",
		Callback = function()
			if not FloatingDash then
				FloatingDash = UICreate.CreateFloatingDashboard("Merdeka Race Monitor")
				FloatingDash.UpdateSaldo(string.format("%s PTS", FormatNumber(State.MerdekaPoints)))
				FloatingDash.UpdateStatus("Status: Standby")
				FloatingDash.UpdateTrips(State.RacesCompleted)
				FetchMerdekaShopData()
			else
				FloatingDash.Destroy()
				FloatingDash = nil
			end
		end
	})

	StatusSection:Button({
		Title = "Buka Merdeka Shop UI",
		Desc = "Buka katalog Merdeka Event Shop langsung tanpa ke NPC.",
		Callback = function()
			OpenMerdekaShopDirect()
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
		Title = "Auto Farm Merdeka Race (Instant Teleport)",
		Desc = "Auto Matchmaking -> Instant TP Mobil & Driver Seat -> Fast Flag Loop.",
		Value = false,
		Callback = function(active)
			if State.AutoFarmActive == active then return end
			State.AutoFarmActive = active

			if active then
				print("🚀 [Merdeka Farm] Mengaktifkan Instant Auto Farm...")
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

	-- Live status, Stopwatch & Points Polling Loop
	task.spawn(function()
		local pollCounter = 0
		while task.wait(0.5) do
			if _G.MainCoreSession ~= Context.Session then break end

			pollCounter = pollCounter + 1
			if pollCounter >= 20 then
				pollCounter = 0
				FetchMerdekaShopData()
			end

			local stateText = "Idle"
			if State.IsRacing then
				if State.IsCarryingFlag then
					stateText = "⚡ Instant TP ke Base (Planted)"
				else
					stateText = "⚡ Instant TP ke Bendera 🚩"
				end
			elseif State.InLobby then
				stateText = "Di Lobi (Menunggu Ready/Start) ⏳"
			end

			local fullDesc = string.format("Status: %s | Bendera: %d/%d | Selesai: %d | Poin: %s PTS", stateText, State.PlantedCount, State.TotalFlags, State.RacesCompleted, FormatNumber(State.MerdekaPoints))
			pcall(function()
				if statusParagraph then statusParagraph:SetDesc(fullDesc) end
				if FloatingDash then
					FloatingDash.UpdateStatus(stateText)
					FloatingDash.UpdateTrips(State.RacesCompleted)
					FloatingDash.UpdateSaldo(string.format("%s PTS", FormatNumber(State.MerdekaPoints)))
				end
			end)
		end
	end)

	SettingsSection:Slider({
		Title = "Jeda Stabilitas Teleport (Detik)",
		Value = { Min = 1, Max = 10, Default = 4 },
		Callback = function(val)
			Config.TeleportDelay = val / 10
		end
	})
end

return MerdekaFarm
