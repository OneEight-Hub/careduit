local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local VirtualUser = game:GetService("VirtualUser")

local Utils = {}
local LocalPlayer = Players.LocalPlayer

function Utils.DestroyBuildingInstances()
	print("[Startup Cleaner] Membersihkan asset berat...")
	local map = Workspace:FindFirstChild("Map")
	local building = map and map:FindFirstChild("Building")
	if building then
		local bcaTower = building:FindFirstChild("BCA Tower Thamrin")
		if bcaTower then bcaTower:Destroy() end
	end

	for _, obj in ipairs(Workspace:GetDescendants()) do
		if obj.Name == "BCA Tower Thamrin" then obj:Destroy() end
	end

	local myBcaCollab = Workspace:FindFirstChild("MY_BCA_COLLAB")
	if myBcaCollab then
		for _, item in ipairs(myBcaCollab:GetChildren()) do
			local name = item.Name:lower()
			if (name:find("building") or name:find("gedung") or name:find("tower")) and not name:find("npc") and not name:find("job") and not name:find("atm") then
				item:Destroy()
			end
		end
	end
end

function Utils.EnablePerformanceMode()
	Lighting.GlobalShadows = false
	Lighting.FogEnd = 9e9
	Lighting.Brightness = 1
	pcall(function()
		for _, effect in ipairs(Lighting:GetChildren()) do
			if effect:IsA("PostProcessEffect") or effect:IsA("BloomEffect") or effect:IsA("BlurEffect") or effect:IsA("SunRaysEffect") or effect:IsA("ColorCorrectionEffect") then
				effect.Enabled = false
			end
		end
	end)

	for _, obj in ipairs(Workspace:GetDescendants()) do
		if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Smoke") or obj:IsA("Fire") or obj:IsA("Sparkles") then
			obj.Enabled = false
		elseif obj:IsA("BasePart") then
			obj.CastShadow = false
		end
	end
end

function Utils.SafeTeleportChar(targetCFrame, delayTime)
	delayTime = delayTime or 0.3
	local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
	local hrp = char:WaitForChild("HumanoidRootPart", 5)
	if hrp then
		hrp.Anchored = false
		hrp.CFrame = targetCFrame + Vector3.new(0, 1.2, 0)
		hrp.AssemblyLinearVelocity = Vector3.zero
		hrp.AssemblyAngularVelocity = Vector3.zero
		task.wait(delayTime)
	end
end

function Utils.TriggerPrompt(prompt, targetPart, isTrunk)
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

	if fireproximityprompt then fireproximityprompt(prompt) end
	prompt:InputHoldBegin()
	task.wait(prompt.HoldDuration + 0.1)
	prompt:InputHoldEnd()
	return true
end

function Utils.SetupAntiAFK()
	if _G.AntiAfkConnection then
		pcall(function() _G.AntiAfkConnection:Disconnect() end)
	end
	_G.AntiAfkConnection = LocalPlayer.Idled:Connect(function()
		VirtualUser:CaptureController()
		VirtualUser:ClickButton2(Vector2.new(0, 0))
		print("🛡️ [Anti-AFK] VirtualUser input sent.")
	end)
end

return Utils
