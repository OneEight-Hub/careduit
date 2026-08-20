-- ==============================================================================
-- CDID HUB - DYNAMIC SERVER & PRIVATE SERVER MANAGER (DIRECT HOOK SYSTEM)
-- ==============================================================================
local ServerManager = {}

function ServerManager.Init(Window, Utils, Context)
	local TeleportService = game:GetService("TeleportService")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local HttpService = game:GetService("HttpService")
	local Players = game:GetService("Players")
	local LocalPlayer = Players.LocalPlayer

	-- 1. LOAD MODUL CDID DARI PATH ASLI
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
	local function ApplyServerCode(code)
		if not code or type(code) ~= "string" then return end
		local clean = code:gsub("%s+", "")
		if clean == "" or clean == "ServerLabel" or clean == "nil" or clean == "InsertHere" then return end

		activeServerCode = clean
		print("🔑 [Private Server] Kode aktif tersinkronisasi:", activeServerCode)

		if serverCodeParagraph then
			pcall(function()
				serverCodeParagraph:SetDesc("Kode Server Akun: " .. activeServerCode)
			end)
		end

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

	-- Hook langsung ke fungsi UpdateServerCode asli dari decompile
	local function SetupDirectEngineHook()
		task.spawn(function()
			for _ = 1, 20 do
				if CDID_UIAnimation and CDID_UIAnimation.WindowModule and CDID_UIAnimation.WindowModule.PrivateServer then
					local ps = CDID_UIAnimation.WindowModule.PrivateServer
					
					-- Cek nilai teks label yang sudah ada
					if ps.ServerLabel and ps.ServerLabel.Text ~= "" and ps.ServerLabel.Text ~= "ServerLabel" then
						ApplyServerCode(ps.ServerLabel.Text)
					end

					-- Pasang hook pada fungsi UpdateServerCode
					if ps.UpdateServerCode and not ps._HookedByHub then
						ps._HookedByHub = true
						local oldUpdate = ps.UpdateServerCode
						ps.UpdateServerCode = function(self, newCode)
							ApplyServerCode(newCode)
							return oldUpdate(self, newCode)
						end
						print("🎯 [Private Server] Direct Hook UpdateServerCode berhasil dipasang!")
					end
					break
				end
				task.wait(0.5)
			end
		end)
	end

	SetupDirectEngineHook()

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
			-- Fallback jika input masih kosong: ambil langsung dari ServerLabel game
			if activeServerCode == "" and CDID_UIAnimation and CDID_UIAnimation.WindowModule and CDID_UIAnimation.WindowModule.PrivateServer then
				local ps = CDID_UIAnimation.WindowModule.PrivateServer
				if ps.ServerLabel and ps.ServerLabel.Text ~= "" and ps.ServerLabel.Text ~= "ServerLabel" then
					activeServerCode = ps.ServerLabel.Text:gsub("%s+", "")
				end
			end

			if activeServerCode == "" then
				warn("⚠️ [Private Server] Kode server belum terisi!")
				return
			end

			local targetInfo = MapDictionary[currentSelectedName]
			local mapKey = targetInfo and targetInfo.Key or (CDID_UIAnimation and CDID_UIAnimation.SelectedMap) or "Jakarta"

			print(string.format("🔑 [Private Server] Mengirim join remote -> Code: %s | Map: %s", activeServerCode, mapKey))

			if CDID_Network then
				CDID_Network:FireServer("PrivateServer", "Join", tostring(activeServerCode), mapKey)
			end
		end
	})

	PrivateServerSection:Button({
		Title = "Ambil / Generate Kode Server",
		Desc = "Meminta server membuatkan kode baru untuk akunmu.",
		Callback = function()
			print("🔄 [Private Server] Meminta Generate Kode...")
			if CDID_Network then
				CDID_Network:FireServer("PrivateServer", "Create")
			end
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
end

return ServerManager
