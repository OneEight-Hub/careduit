local BCA = {}

function BCA.Init(Window, Utils, Context)
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Workspace = game:GetService("Workspace")
	local RunService = game:GetService("RunService")

	local LocalPlayer = Players.LocalPlayer
	local Network = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Network"))
	local NpcDialogEvent = ReplicatedStorage:WaitForChild("NetworkContainer"):WaitForChild("RemoteEvents"):WaitForChild("NpcDialog")
	local JobRemote = ReplicatedStorage:WaitForChild("NetworkContainer"):WaitForChild("RemoteEvents"):WaitForChild("Job")

	local Config = {
		TweenSpeed = 180,
		MinTravelDuration = 20,
		ActionDelay = 0.3,
		LoopWait = 0.4,
		RestartDelay = 2.0
	}

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

	local function GetPlayerCar()
		local vehicles = Workspace:FindFirstChild("Vehicles")
		if not vehicles then return nil end
		for _, v in ipairs(vehicles:GetChildren()) do
			if v.Name:find(LocalPlayer.Name, 1, true) then return v end
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
		local seat = car:FindFirstChildWhichIsA("VehicleSeat", true) or car:FindFirstChild("DriveSeat", true) or car:FindFirstChild("DriverSeat", true)
		if not seat then return false end

		local primary = car.PrimaryPart or car:FindFirstChildWhichIsA("BasePart")
		if primary then primary.Anchored = false end
		if hum.SeatPart == seat or hum.Sit then return true end

		hrp.CFrame = seat.CFrame * CFrame.new(0, 1.2, 1.2)
		task.wait(Config.ActionDelay)

		local drivePrompt = seat:FindFirstChildWhichIsA("ProximityPrompt", true) or car:FindFirstChildWhichIsA("ProximityPrompt", true)
		if drivePrompt and drivePrompt.Enabled then
			drivePrompt.RequiresLineOfSight = false
			drivePrompt.MaxActivationDistance = 25
			if fireproximityprompt then fireproximityprompt(drivePrompt) else seat:Sit(hum) end
			drivePrompt:InputHoldBegin()
			task.wait(drivePrompt.HoldDuration + 0.1)
			drivePrompt:InputHoldEnd()
		else
			seat:Sit(hum)
		end

		local timeout = os.clock()
		while not hum.Sit and (os.clock() - timeout < 2.5) do task.wait(0.1) end
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
			if primary then primary.Anchored = true end
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
		local duration = math.max(Config.MinTravelDuration, dist / speed)

		primary.Anchored = false
		local startTime = os.clock()

		while (os.clock() - startTime) < duration and State.AutoDelivering do
			if hum and not hum.Sit and seat then pcall(function() seat:Sit(hum) end) end
			local elapsed = os.clock() - startTime
			local alpha = math.clamp(elapsed / duration, 0, 1)
			local currentCF = startCF:Lerp(targetCF, alpha)
			local currentSpeed = speed

			if alpha > 0.85 then
				currentSpeed = math.max(8, speed * ((1 - alpha) / 0.15))
				if seat then pcall(function() seat.ThrottleFloat = 0; seat.Throttle = 0 end) end
			else
				if seat then pcall(function() seat.ThrottleFloat = 1; seat.Throttle = 1 end) end
			end

			car:PivotTo(currentCF)
			primary.AssemblyLinearVelocity = currentCF.LookVector * currentSpeed
			primary.AssemblyAngularVelocity = Vector3.zero
			RunService.Heartbeat:Wait()
		end

		if seat then pcall(function() seat.Throttle = 0; seat.Steer = 0 end) end
		task.wait(0.15)
		primary.Anchored = true
		task.wait(Config.ActionDelay)
	end

	-- Remote Event Listeners
	local dialogHook = NpcDialogEvent.OnClientEvent:Connect(function(action)
		if action == "Start" then
			task.spawn(function()
				task.wait(0.5)
				NpcDialogEvent:FireServer("Finish", nil)
				if firesignal then pcall(firesignal, NpcDialogEvent.OnClientEvent, "Abort") end
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
				if Context.Session ~= curSession then return end
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
			local curSession = Context.Session
			task.delay(delayTime, function()
				if Context.Session ~= curSession then return end
				Network:FireServer("BankCourier", "SkillPress", targetAngle + (rotations * 360))
			end)
		elseif action == "Complete" or action == "Returning" then
			State.Phase = "Returning"
		elseif action == "Stop" then
			State.Phase = "Unemployee"
			State.Loaded = 0
			State.Total = 0
		end
	end)
	table.insert(Context.Hooks, bankHook)

	-- UI Setup di Tab Hub
	local BCATab = Window:Tab({ Title = "BCA Courier", Icon = "solar:box-minimalistic-bold" })
	local ControlsSection = BCATab:Section({ Title = "Auto Farm Controls" })
	local SettingsSection = BCATab:Section({ Title = "Konfigurasi Kecepatan" })
	local ShortcutsSection = BCATab:Section({ Title = "Pintasan Teleport" })

	ShortcutsSection:Button({
		Title = "Teleport NPC Start",
		Callback = function()
			local npc = Workspace:WaitForChild("MY_BCA_COLLAB"):WaitForChild("NPC_START_JOB")
			Utils.SafeTeleportChar(npc:GetPivot(), Config.ActionDelay)
		end
	})

	ShortcutsSection:Button({
		Title = "Teleport Spawner Mobil",
		Callback = function()
			local spawner = Workspace:WaitForChild("MY_BCA_COLLAB"):WaitForChild("CAR_SPAWNER_NPC")
			Utils.SafeTeleportChar(spawner:GetPivot(), Config.ActionDelay)
		end
	})

	local statusParagraph = ControlsSection:Paragraph({
		Title = "Status Kurir",
		Desc = "Phase: Unemployee | Koper: 0/0"
	})

	-- Loop status teks
	task.spawn(function()
		while task.wait(0.3) do
			if Context.Session ~= _G.MainCoreSession then break end
			pcall(function()
				statusParagraph:SetDesc(string.format("Phase: %s | Koper: %s/%s", tostring(State.Phase), tostring(State.Loaded), tostring(State.Total)))
			end)
		end
	end)

	ControlsSection:Toggle({
		Title = "Endless Auto Farm",
		Desc = "Otomatisasi siklus kurir BCA.",
		Value = false,
		Callback = function(active)
			State.AutoFarmActive = active
			if active then
				task.spawn(function()
					while State.AutoFarmActive do
						if Context.Session ~= _G.MainCoreSession then break end

						-- 1. Start Job
						local Mf = Workspace:WaitForChild("MY_BCA_COLLAB")
						local startNpc = Mf:WaitForChild("NPC_START_JOB")
						Utils.SafeTeleportChar(startNpc:GetPivot(), Config.ActionDelay)
						Utils.TriggerPrompt(startNpc:FindFirstChildWhichIsA("ProximityPrompt", true), startNpc.PrimaryPart or startNpc:FindFirstChildWhichIsA("BasePart"))
						
						local waitJob = os.clock()
						while State.Phase == "Unemployee" and (os.clock() - waitJob < 6) do task.wait(0.2) end
						if not State.AutoFarmActive or State.Phase == "Unemployee" then task.wait(Config.RestartDelay) continue end

						-- 2. Spawn Car
						local spawner = Mf:WaitForChild("CAR_SPAWNER_NPC")
						Utils.SafeTeleportChar(spawner:GetPivot(), Config.ActionDelay)
						Utils.TriggerPrompt(spawner:FindFirstChildWhichIsA("ProximityPrompt", true), spawner.PrimaryPart or spawner:FindFirstChildWhichIsA("BasePart"))

						local waitCar = os.clock()
						local car = nil
						while os.clock() - waitCar < 10 do
							car = GetPlayerCar()
							if car then break end
							task.wait(0.3)
						end
						if not car or not State.AutoFarmActive then task.wait(Config.RestartDelay) continue end

						-- 3. Muat Koper
						State.AutoLoading = true
						task.spawn(function()
							local rack = Mf:WaitForChild("Job"):WaitForChild("BankCourier"):WaitForChild("KoperSpawn")
							while State.AutoLoading do
								if State.Loaded >= State.Total and State.Total > 0 then break end
								local bagasi = car:FindFirstChild("BagasiPoint", true)
								if not State.Carrying then
									Utils.SafeTeleportChar(rack:GetPivot(), Config.ActionDelay)
									Utils.TriggerPrompt(rack:FindFirstChildWhichIsA("ProximityPrompt", true), rack.PrimaryPart or rack:FindFirstChildWhichIsA("BasePart"))
								else
									if bagasi then
										Utils.SafeTeleportChar(bagasi.CFrame, Config.ActionDelay)
										Utils.TriggerPrompt(GetMuatPrompt(bagasi), bagasi, true)
									end
								end
								task.wait(Config.LoopWait)
							end
							State.AutoLoading = false
						end)

						while State.AutoLoading and State.AutoFarmActive do task.wait(0.5) end
						if not State.AutoFarmActive then break end

						-- 4. Kirim ke ATM
						State.AutoDelivering = true
						task.spawn(function()
							while State.AutoDelivering do
								if State.Loaded <= 0 and not State.Carrying then break end
								local bagasi = car:FindFirstChild("BagasiPoint", true)
								local char = LocalPlayer.Character
								local hrp = char and char:FindFirstChild("HumanoidRootPart")
								local dist = (hrp and State.TargetPos) and (hrp.Position - State.TargetPos).Magnitude or 999

								if not State.Carrying and dist > 25 then
									EnterDriverSeat(car)
									DriveCarNaturallyTo(car, State.TargetPos, Config.TweenSpeed)
									ExitDriverSeat(car)
								elseif not State.Carrying and dist <= 40 then
									if bagasi then
										Utils.SafeTeleportChar(bagasi.CFrame * CFrame.new(0, 0, 1.8), Config.ActionDelay)
										Utils.TriggerPrompt(GetAmbilPrompt(bagasi), bagasi, true)
									end
								elseif State.Carrying and State.TargetPos then
									Utils.SafeTeleportChar(CFrame.new(State.TargetPos + Vector3.new(0, 0, 1.5)), Config.ActionDelay)
									Network:FireServer("BankCourier", "FillStart")
									local t = os.clock()
									while State.Carrying and (os.clock() - t < 10) do task.wait(0.2) end
								end
								task.wait(Config.LoopWait)
							end
							State.AutoDelivering = false
						end)

						while State.AutoDelivering and State.AutoFarmActive do task.wait(0.5) end
						if not State.AutoFarmActive then break end

						-- 5. Pulang & Klaim Gaji
						local returnCar = GetPlayerCar()
						if returnCar then
							EnterDriverSeat(returnCar)
							DriveCarNaturallyTo(returnCar, spawner:GetPivot().Position, Config.TweenSpeed)
							ExitDriverSeat(returnCar)
						end

						Utils.SafeTeleportChar(startNpc:GetPivot(), Config.ActionDelay)
						Utils.TriggerPrompt(startNpc:FindFirstChildWhichIsA("ProximityPrompt", true), startNpc.PrimaryPart or startNpc:FindFirstChildWhichIsA("BasePart"))
						task.wait(Config.RestartDelay)
					end
				end)
			end
		end
	})

	SettingsSection:Input({
		Title = "Kecepatan Menyetir",
		Value = tostring(Config.TweenSpeed),
		Callback = function(val)
			local n = tonumber(val)
			if n then Config.TweenSpeed = n end
		end
	})

	SettingsSection:Slider({
		Title = "Durasi Minimum (Anti-Nerf)",
		Value = { Min = 10, Max = 45, Default = 20 },
		Callback = function(val) Config.MinTravelDuration = val end
	})
end

return BCA
