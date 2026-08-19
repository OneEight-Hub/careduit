-- ==============================================================================
-- CDID HUB - UTILITIES (MAP & MELAWAI DYNAMIC NO-RENDER MODE)
-- ==============================================================================
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local VirtualUser = game:GetService("VirtualUser")

local Utils = {}
local LocalPlayer = Players.LocalPlayer

-- Fungsi helper untuk membuat part/tekstur transparan tanpa merusak fisik collision
local function MakePartInvisible(obj)
	if obj:IsA("BasePart") then
		obj.Transparency = 1
		obj.CastShadow = false
		obj.Material = Enum.Material.SmoothPlastic
	elseif obj:IsA("Decal") or obj:IsA("Texture") then
		obj.Transparency = 1
	elseif obj:IsA("SurfaceAppearance") then
		pcall(function() obj:Destroy() end)
	end
end

-- Fungsi pemindai dan pemasang listener dinamis pada folder target
local function ApplyNoRenderToFolder(folderInstance, connectionKey)
	if not folderInstance then return end

	-- 1. Scan semua objek yang sudah ada saat ini
	for _, obj in ipairs(folderInstance:GetDescendants()) do
		MakePartInvisible(obj)
	end
	MakePartInvisible(folderInstance)

	-- 2. Listener Realtime (Tangkap streaming/asset baru yang baru di-render)
	if not _G[connectionKey] then
		_G[connectionKey] = folderInstance.DescendantAdded:Connect(function(newObj)
			MakePartInvisible(newObj)
		end)
	end
end

function Utils.EnableNoRenderMode()
	print("⚡ [Performance Mode] Mengaktifkan Dynamic No-Render (Map, Melawai & Collab)...")

	-- 1. Optimasi Lighting Global
	Lighting.GlobalShadows = false
	Lighting.FogEnd = 9e9
	Lighting.Brightness = 1

	for _, effect in ipairs(Lighting:GetChildren()) do
		if effect:IsA("PostProcessEffect") or effect:IsA("BloomEffect") or effect:IsA("BlurEffect") or effect:IsA("SunRaysEffect") or effect:IsA("ColorCorrectionEffect") then
			effect.Enabled = false
		end
	end

	-- 2. Transparankan folder Map (Beserta Realtime Stream Listener)
	local map = Workspace:FindFirstChild("Map")
	if map then
		ApplyNoRenderToFolder(map, "CDID_MapDescendantConn")
	end

	-- 3. Transparankan folder MELAWAI (Beserta Realtime Stream Listener)
	local melawai = Workspace:FindFirstChild("MELAWAI") or Workspace:FindFirstChild("Melawai")
	if melawai then
		ApplyNoRenderToFolder(melawai, "CDID_MelawaiDescendantConn")
	end

	-- 4. Transparankan part collab BCA (Kecuali NPC, Job, dan ATM)
	local myBcaCollab = Workspace:FindFirstChild("MY_BCA_COLLAB")
	if myBcaCollab then
		for _, item in ipairs(myBcaCollab:GetChildren()) do
			local name = item.Name:lower()
			if not name:find("npc") and not name:find("job") and not name:find("atm") then
				ApplyNoRenderToFolder(item, "CDID_BcaItemConn_" .. item.Name)
			end
		end
	end

	-- 5. Tangkap Folder Baru jika MELAWAI / Map baru di-spawn belakangan di Workspace
	if not _G.CDID_WorkspaceFolderListener then
		_G.CDID_WorkspaceFolderListener = Workspace.ChildAdded:Connect(function(child)
			local name = child.Name:upper()
			if name == "MAP" then
				ApplyNoRenderToFolder(child, "CDID_MapDescendantConn")
			elseif name == "MELAWAI" then
				ApplyNoRenderToFolder(child, "CDID_MelawaiDescendantConn")
			end
		end)
	end

	-- 6. Matikan partikel visual di Workspace
	for _, obj in ipairs(Workspace:GetDescendants()) do
		if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Smoke") or obj:IsA("Fire") or obj:IsA("Sparkles") then
			obj.Enabled = false
		end
	end

	if not _G.CDID_ParticlesListener then
		_G.CDID_ParticlesListener = Workspace.DescendantAdded:Connect(function(newObj)
			if newObj:IsA("ParticleEmitter") or newObj:IsA("Trail") or newObj:IsA("Smoke") or newObj:IsA("Fire") or newObj:IsA("Sparkles") then
				newObj.Enabled = false
			end
		end)
	end

	print("✅ [Performance Mode] Map & Melawai berhasil dibuat invisible dinamis.")
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

-- Interaksi Prompt dengan Freezing Anchor (Anti-Void)
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
