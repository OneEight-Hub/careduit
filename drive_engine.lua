-- ==============================================================================
-- CDID HUB - UNIVERSAL SAFE DRIVE ENGINE
-- ==============================================================================
local DriveEngine = {}

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- Global Defaults (Dapat diubah via config)
DriveEngine.Defaults = {
	Speed = 190,
	MinDuration = 8,
	ActionDelay = 0.3,
	FreezeCamera = true
}

local isDrivingActive = false

-- ==============================================================================
-- INTERNAL HELPERS
-- ==============================================================================
local function GetValidHumanoid()
	local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum and hum.Health > 0 then
		return hum, char:FindFirstChild("HumanoidRootPart")
	end
	return nil, nil
end

function DriveEngine.GetPlayerCar()
	local vehicles = Workspace:FindFirstChild("Vehicles")
	if not vehicles then return nil end
	for _, v in ipairs(vehicles:GetChildren()) do
		if v.Name:find(LocalPlayer.Name, 1, true) then
			return v
		end
	end
	return nil
end

function DriveEngine.EnsureSeated(car)
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
	task.wait(DriveEngine.Defaults.ActionDelay)

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

function DriveEngine.FreezeCamera(enable)
	if not Camera then return end
	if enable then
		Camera.CameraType = Enum.CameraType.Scriptable
		Camera.CFrame = CFrame.new(0, 600, 0) * CFrame.Angles(-math.rad(90), 0, 0)
	else
		local hum = GetValidHumanoid()
		Camera.CameraType = Enum.CameraType.Custom
		if hum then Camera.CameraSubject = hum end
	end
end

-- ==============================================================================
-- CORE DRIVE FUNCTION
-- ==============================================================================
-- options: { Speed = 190, MinDuration = 8, StopCondition = function() return false end, FreezeCam = true }
function DriveEngine.DriveTo(targetPos, options)
	if isDrivingActive or not targetPos then return false end
	isDrivingActive = true

	options = options or {}
	local speed = options.Speed or DriveEngine.Defaults.Speed
	local minDuration = options.MinDuration or DriveEngine.Defaults.MinDuration
	local freezeCam = (options.FreezeCam ~= nil) and options.FreezeCam or DriveEngine.Defaults.FreezeCamera
	local stopCondition = options.StopCondition or function() return false end

	local car = DriveEngine.GetPlayerCar()
	if not car then
		isDrivingActive = false
		return false
	end

	local primary = car.PrimaryPart or car:FindFirstChildWhichIsA("BasePart")
	local seat = car:FindFirstChildWhichIsA("VehicleSeat", true)
	if not primary then
		isDrivingActive = false
		return false
	end

	DriveEngine.EnsureSeated(car)

	local startCF = car:GetPivot()
	local dirToTarget = (targetPos - startCF.Position).Unit
	local flatDir = Vector3.new(dirToTarget.X, 0, dirToTarget.Z).Unit
	local stopPos = targetPos + Vector3.new(0, 1.5, 0)
	local targetCF = CFrame.new(stopPos, stopPos + flatDir)

	local dist = (startCF.Position - stopPos).Magnitude
	local duration = math.max(minDuration, dist / speed)

	primary.Anchored = false

	-- Nonaktifkan part body mobil agar tidak nyangkut
	for _, p in ipairs(car:GetDescendants()) do
		if p:IsA("BasePart") and p.Name ~= "VehicleSeat" and p ~= primary then
			p.CanCollide = false
		end
	end

	if freezeCam then
		DriveEngine.FreezeCamera(true)
	end

	local startTime = os.clock()

	while true do
		-- Hentikan paksa jika ada stop condition dari modul pemanggil
		if stopCondition() then break end

		local elapsed = os.clock() - startTime
		local alpha = math.clamp(elapsed / duration, 0, 1)

		-- Smoothstep Interpolation
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
	task.wait(DriveEngine.Defaults.ActionDelay)

	if freezeCam then
		DriveEngine.FreezeCamera(false)
	end

	isDrivingActive = false
	return true
end

function DriveEngine.IsDriving()
	return isDrivingActive
end

return DriveEngine
