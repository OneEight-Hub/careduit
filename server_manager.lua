-- ==============================================================================
-- CDID HUB - DYNAMIC SERVER & PRIVATE SERVER MANAGER (AUTO-SYNC FIX)
-- ==============================================================================
local ServerManager = {}

function ServerManager.Init(Window, Utils, Context)
	local TeleportService = game:GetService("TeleportService")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local HttpService = game:GetService("HttpService")
	local Players = game:GetService("Players")
	local LocalPlayer = Players.LocalPlayer

	-- 1. LOAD MODUL CDID
	local CDID_TeleportModule = nil
	local CDID_Network = nil
	local CDID_UIAnimation = nil

	local SharedFolder = ReplicatedStorage:WaitForChild("Shared", 5)
	if SharedFolder then
		local TeleportScript = SharedFolder:WaitForChild("Teleport", 5)
		if TeleportScript then
			local ok, mod = pcall(require, TeleportScript)
			if ok and mod then CDID_TeleportModule = mod end
		end

		local NetworkScript = SharedFolder:WaitForChild("Network", 5)
		if NetworkScript then
			local ok, net = pcall(require, NetworkScript)
			if ok and net then CDID_Network = net end
		end
	end

	local ControllerFolder = ReplicatedStorage:WaitForChild("Controller", 5)
	if ControllerFolder then
		local uiAnimScript = ControllerFolder:WaitForChild("UIAnimation", 5)
		if uiAnimScript then
			local ok, uiMod = pcall(require, uiAnimScript)
			if ok and uiMod then CDID_UIAnimation = uiMod end
		end
	end

	-- 2. MAP DICTIONARY
	local MapDictionary = {}
	local MapNamesDisplay = {}
	local defaultSelected = "JAKARTA"

	local function RefreshMapData()
		MapDictionary = {}
		MapNamesDisplay = {}

		local rawList = nil
		if CDID_TeleportModule and CDID_TeleportModule.GetMapList then
			pcall(function() rawList = CDID_TeleportModule.GetMapList() end)
		end

		if rawList and type(rawList) == "table" then
			for mapKey, mapInfo in pairs(rawList) do
				local displayName = mapInfo.Name or mapKey:upper()
				MapDictionary[displayName] = {
					Key = mapKey,
					PlaceId = mapInfo.PlaceId,
					Image = mapInfo.Image
				}
				table.insert(MapNamesDisplay, displayName)
			end
		else
			local fallbackMaps = {
				["JAKARTA"]     = { Key = "Jakarta", PlaceId = 14005966837 },
				["BANDUNG"]     = { Key = "Bandung", PlaceId = 79488788685813 },
				["JAWA BARAT"]  = { Key = "JawaBarat", PlaceId = 9233343468 },
				["JAWA TENGAH"] = { Key = "JawaTengah", PlaceId = 9508940498 },
				["BALI"]        = { Key = "Bali", PlaceId = 118108582994420 },
				["JAWA TIMUR"]  = { Key = "JawaTimur", PlaceId = 110369730911937 },
				["SEASONAL"]    = { Key = "Seasonal", PlaceId = 132986577553100 }
			}
			for name, data in pairs(fallbackMaps) do
				MapDictionary[name] = data
				table.insert(MapNamesDisplay, name)
			end
		end

		table.sort(MapNamesDisplay)
		defaultSelected = MapNamesDisplay[1] or "JAKARTA"
	end

	RefreshMapData()

	local currentSelectedName = defaultSelected
	local activeServerCode = ""

	local codeInputControl = nil
	local serverCodeParagraph = nil

	-- ==============================================================================
	-- 3. DETEKSI & SINKRONISASI KODE INSTAN
	-- ==============================================================================
	local function IsValidServerCode(text)
		if not text or type(text) ~= "string" then return false end
		local clean = text:gsub("%s+", "")
		if clean == "" or clean == "ServerLabel" or clean == "nil" or clean == "InsertHere" then return false end

		local lower = clean:lower()
		if lower:find("ms") or lower:find("fps") or lower:find("singapore") 
			or lower:find("unitedstates") or lower:find("indonesia") or lower:find(",") then
			return false
		end

		return (clean:len() >= 4 and clean:len() <= 35)
	end

	local function ApplyServerCode(code)
		if not IsValidServerCode(code) then return end
		local clean = tostring(code):gsub("%s+", "")
		activeServerCode = clean

		-- Update Paragraph Status
		if serverCodeParagraph then
			pcall(function()
				if serverCodeParagraph.SetDesc then
					serverCodeParagraph:SetDesc("Kode Server Akun: " .. activeServerCode)
				elseif serverCodeParagraph.Set then
					serverCodeParagraph:Set({
						Title = "Status Private Server",
						Desc = "Kode Server Akun: " .. activeServerCode
					})
				end
			end)
		end

		-- Update Input Box
		if codeInputControl then
			pcall(function()
				if codeInputControl.SetInput then
					codeInputControl:SetInput(activeServerCode)
				elseif codeInputControl.SetValue then
					codeInputControl:SetValue(activeServerCode)
				elseif codeInputControl.Set then
					codeInputControl:Set(activeServerCode)
				end
			end)
		end
	end

	local function ScanServerCodeFromGame()
		-- 1. Cek dari WindowModule UIAnimation
		if CDID_UIAnimation and CDID_UIAnimation.WindowModule and CDID_UIAnimation.WindowModule.PrivateServer then
			local ps = CDID_UIAnimation.WindowModule.PrivateServer
			if ps.ServerLabel and IsValidServerCode(ps.ServerLabel.Text) then
				ApplyServerCode(ps.ServerLabel.Text)
				return true
			end
		end

		-- 2. Cek dari Hierarki PlayerGui
		local pGui = LocalPlayer:FindFirstChild("PlayerGui")
		if pGui then
			for _, inst in ipairs(pGui:GetDescendants()) do
				if inst:IsA("TextLabel") and inst.Name == "ServerLabel" and IsValidServerCode(inst.Text) then
					ApplyServerCode(inst.Text)
					return true
				end
			end
		end
		return false
	end

	-- Hook Remote Network PrivateServer
	if CDID_Network and CDID_Network.OnClientEvent then
		local psHook = CDID_Network.OnClientEvent("PrivateServer", function(action, arg1)
			if IsValidServerCode(arg1) then
				ApplyServerCode(arg1)
			elseif IsValidServerCode(action) then
				ApplyServerCode(action)
			end
		end)
		table.insert(Context.Hooks, psHook)
	end

	-- Auto Sync Loop (Memantau perubahan kode secara real-time)
	task.spawn(function()
		while task.wait(0.5) do
			if _G.MainCoreSession ~= Context.Session then break end
			ScanServerCodeFromGame()
		end
	end)

	-- ==============================================================================
	-- UI WINDUI SETUP
	-- ==============================================================================
	local ServerTab = Window:Tab({
		Title = "Server Manager",
		Icon = "solar:server-square-bold"
	})

	local PublicMapSection = ServerTab:Section({ Title = "Public Map Selector" })
	local PrivateServerSection = ServerTab:Section({ Title = "Private Server System" })
	local ServerControlSection = ServerTab:Section({ Title = "Kontrol Server Umum" })

	-- A. PUBLIC MAP
	local mapDropdown = PublicMapSection:Dropdown({
		Title = "Pilih Map Tujuan",
		Desc = "Map tujuan untuk Public / Private Server.",
		Values = MapNamesDisplay,
		Value = currentSelectedName,
		Callback = function(chosen)
			currentSelectedName = chosen
		end
	})

	PublicMapSection:Button({
		Title = "Pindah ke Public Map Terpilih",
		Callback = function()
			local targetInfo = MapDictionary[currentSelectedName]
			if not targetInfo then return end

			if CDID_TeleportModule and CDID_TeleportModule.TeleporToPublicServer then
				local pGui = LocalPlayer:FindFirstChild("PlayerGui")
				local ok = pcall(function()
					CDID_TeleportModule.TeleporToPublicServer(targetInfo.Key, pGui, LocalPlayer)
				end)
				if ok then return end
			end

			pcall(function()
				TeleportService:Teleport(targetInfo.PlaceId, LocalPlayer)
			end)
		end
	})

	-- B. PRIVATE SERVER
	serverCodeParagraph = PrivateServerSection:Paragraph({
		Title = "Status Private Server",
		Desc = "Kode Server Akun: Belum dibuat / Belum terdeteksi",
		Image = "key"
	})

	codeInputControl = PrivateServerSection:Input({
		Title = "Kode Private Server",
		Placeholder = "Masukkan / tunggu kode terdeteksi...",
		Value = activeServerCode,
		Callback = function(val)
			activeServerCode = tostring(val or ""):gsub("%s+", "")
		end
	})

	PrivateServerSection:Button({
		Title = "Join Private Server",
		Desc = "Join menggunakan kode di atas dan map terpilih.",
		Callback = function()
			if activeServerCode == "" then
				ScanServerCodeFromGame()
			end

			if activeServerCode == "" then
				warn("⚠️ [Private Server] Kode server belum terisi!")
				return
			end

			local targetInfo = MapDictionary[currentSelectedName]
			local mapKey = targetInfo and targetInfo.Key or (CDID_UIAnimation and CDID_UIAnimation.SelectedMap) or "Jakarta"

			print(string.format("🔑 [Private Server] Join Server Code: %s (Map: %s)...", activeServerCode, mapKey))

			if CDID_Network then
				CDID_Network:FireServer("PrivateServer", "Join", tostring(activeServerCode), mapKey)
			end
		end
	})

	PrivateServerSection:Button({
		Title = "Ambil / Generate Kode Server",
		Desc = "Meminta server membuatkan kode baru untuk akunmu.",
		Callback = function()
			print("🔄 [Private Server] Request generate kode baru...")
			if CDID_Network then
				CDID_Network:FireServer("PrivateServer", "Create")
			end
			task.spawn(function()
				for _ = 1, 8 do
					task.wait(0.4)
					if ScanServerCodeFromGame() then break end
				end
			end)
		end
	})

	PrivateServerSection:Button({
		Title = "Salin Kode ke Clipboard",
		Callback = function()
			if activeServerCode ~= "" and setclipboard then
				setclipboard(activeServerCode)
				print("📋 [Clipboard] Berhasil disalin:", activeServerCode)
			else
				warn("⚠️ [Clipboard] Belum ada kode yang terdeteksi.")
			end
		end
	})

	-- C. KONTROL UMUM
	ServerControlSection:Button({
		Title = "Rejoin Server Ini",
		Callback = function()
			pcall(function()
				TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
			end)
		end
	})

	ServerControlSection:Button({
		Title = "Server Hop (Cari Server Lain)",
		Callback = function()
			task.spawn(function()
				local placeId = game.PlaceId
				local url = string.format("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Desc&limit=100", placeId)
				local success, result = pcall(function() return game:HttpGet(url) end)

				if success and result then
					local data = HttpService:JSONDecode(result)
					if data and data.data then
						for _, s in ipairs(data.data) do
							if s.playing < s.maxPlayers and s.id ~= game.JobId then
								TeleportService:TeleportToPlaceInstance(placeId, s.id, LocalPlayer)
								return
							end
						end
					end
				end
				TeleportService:Teleport(placeId, LocalPlayer)
			end)
		end
	})

	-- Inisialisasi awal
	task.spawn(function()
		task.wait(1.0)
		ScanServerCodeFromGame()
	end)
end

return ServerManager
