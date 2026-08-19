-- ==============================================================================
-- CDID HUB - UTILITIES (NO-RENDER & COLLISION-SAFE MODE)
-- ==============================================================================
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local VirtualUser = game:GetService("VirtualUser")

local Utils = {}
local LocalPlayer = Players.LocalPlayer

-- Solusi 1: Jadikan semua gedung invisible tanpa menghilangkan collision
function Utils.EnableNoRenderMode()
	print("⚡ [Performance Mode] Mengaktifkan No-Render Mode (Collision Tetap Utuh)...")

	-- 1. Matikan Lighting & Efek Berat
	Lighting.GlobalShadows = false
	Lighting.FogEnd = 9e9
	Lighting.Brightness = 1

	for _, effect in ipairs(Lighting:GetChildren()) do
		if effect:IsA("PostProcessEffect") or effect:IsA("BloomEffect") or effect:IsA("BlurEffect") or effect:IsA("SunRaysEffect") or effect:IsA("ColorCorrectionEffect") then
			effect.Enabled = false
		end
	end

	-- 2. Transparankan folder Gedung / Map Dekoratif
	local map = Workspace:FindFirstChild("Map")
	local buildings = map and map:FindFirstChild("Building")
	if buildings then
		for _, obj in ipairs(buildings:GetDescendants()) do
			if obj:IsA("BasePart") then
				obj.Transparency = 1
				obj.CastShadow = false
				obj.Material = Enum.Material.SmoothPlastic
			elseif obj:IsA("Decal") or obj:IsA("Texture") then
				obj.Transparency = 1
			end
		end
	end

	-- 3. Transparankan part dekorasi collab BCA (kecuali NPC, Job, dan ATM)
	local myBcaCollab = Workspace:FindFirstChild("MY_BCA_COLLAB")
	if myBcaCollab then
		for _, item in ipairs(myBcaCollab:GetChildren()) do
			local name = item.Name:lower()
			if (name:find("building") or name:find("gedung") or name:find("tower")) and not name:find("npc") and not name:find("job") and not name:find("atm") then
				for _, p in ipairs(item:GetDescendants()) do
					if p:IsA("BasePart") then
						p.Transparency = 1
						p.CastShadow = false
					elseif p:IsA("Decal") or p:IsA("Texture") then
						p.Transparency = 1
					end
				end
			end
		end
	end

	-- 4. Matikan partikel visual
	for _, obj in ipairs(Workspace:GetDescendants()) do
		if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Smoke") or obj:IsA("Fire") or obj:IsA("Sparkles") then
			obj.Enabled = false
		end
	end

	print("✅ [Performance Mode] GPU rendering diminimalkan, collision aman.")
end

-- Teleport dengan pengamanan anchor
function Utils.SafeTeleportChar(targetCFrame, delayTime)
	local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if hrp then
		hrp.Anchored = false
		hrp.CFrame = targetCFrame + Vector3.new(0, 1.2, 0)
		hrp.AssemblyLinearVelocity = Vector3.zero
		hrp.AssemblyAngularVelocity = Vector3.zero
		if delayTime and delayTime > 0 then task.wait(delayTime) end
	end
end

-- Solusi 2: Interaksi Prompt dengan Freezing Anchor (Anti-Void)
function Utils.TriggerPrompt(prompt, targetPart, isTrunk)
	if not prompt then return false end
	prompt.Enabled = true
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = 35

	local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
	local hrp = char:FindFirstChild("HumanoidRootPart")
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
		task.wait(0.1)
	end

	-- Freeze sesaat selama trigger interaksi
	hrp.Anchored = true

	if fireproximityprompt then
		fireproximityprompt(prompt)
	end

	prompt:InputHoldBegin()
	task.wait(prompt.HoldDuration + 0.1)
	prompt:InputHoldEnd()

	hrp.Anchored = false
	return true
end

function Utils.SetupAntiAFK()
	if _G.AntiAfkConnection then pcall(function() _G.AntiAfkConnection:Disconnect() end) end
	_G.AntiAfkConnection = LocalPlayer.Idled:Connect(function()
		VirtualUser:CaptureController()
		VirtualUser:ClickButton2(Vector2.new(0, 0))
	end)
end

return Utils
