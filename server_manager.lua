-- ==============================================================================
-- CDID HUB - DYNAMIC SERVER & PRIVATE SERVER MANAGER
-- ==============================================================================
local ServerManager = {}

function ServerManager.Init(Window, Utils, Context)
	local TeleportService = game:GetService("TeleportService")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local HttpService = game:GetService("HttpService")
	local Players = game:GetService("Players")
	local LocalPlayer = Players.LocalPlayer

	-- 1. LOAD MODUL TELEPORT & NETWORK BAWAAN CDID
	local CDID_TeleportModule = nil
	local CDID_Network = nil

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

	-- 2. PARSE LIST MAP SECARA DINAMIS
	local MapDictionary = {}   -- { ["JAKARTA"] = { PlaceId = ..., Key = "Jakarta" } }
	local MapNamesDisplay = {} -- { "BALI", "BANDUNG", "JAKARTA", ... }
	local defaultSelected = "JAKARTA"

	local function RefreshMapData()
		MapDictionary = {}
		MapNamesDisplay = {}

		local rawList = nil
		if CDID_TeleportModule and CDID_TeleportModule.GetMapList then
			pcall(function()
				rawList = CDID_TeleportModule.GetMapList()
			end)
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
			-- Fallback hardcoded
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
	local inputPrivateCode = ""

	-- ==============================================================================
	-- UI WINDUI TAB SETUP
	-- ==============================================================================
	local ServerTab = Window:Tab({
		Title = "Server Manager",
		Icon = "solar:server-square-bold"
	})

	local PublicMapSection = ServerTab:Section({ Title = "Public Map Selector (Dynamic)" })
	local PrivateServerSection = ServerTab:Section({ Title = "Private Server System" })
	local ServerControlSection = ServerTab:Section({ Title = "Kontrol Server Umum" })

	-- ==========================================
	-- A. PUBLIC MAP SELECTOR
	-- ==========================================
	local mapDropdown = PublicMapSection:Dropdown({
		Title = "Pilih Map Tujuan",
		Desc = "Daftar map tersinkronisasi langsung dari modul resmi game.",
		Values = MapNamesDisplay,
		Value = currentSelectedName,
		Callback = function(chosen)
			currentSelectedName = chosen
		end
	})

	PublicMapSection:Button({
		Title = "Pindah ke Public Map Terpilih",
		Desc = "Teleport ke server publik map tersebut dengan loading screen resmi.",
		Callback = function()
			local targetInfo = MapDictionary[currentSelectedName]
			if not targetInfo then return end

			print("🚀 [Map Manager] Teleporting ke Public Map:", currentSelectedName)
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

	PublicMapSection:Button({
		Title = "Refresh Daftar Map",
		Desc = "Muat ulang daftar map dari game.",
		Callback = function()
			RefreshMapData()
			if mapDropdown and mapDropdown.SetValues then
				mapDropdown:SetValues(MapNamesDisplay)
			end
			print("🔄 [Map Manager] Daftar map berhasil diperbarui.")
		end
	})

	-- ==========================================
	-- B. PRIVATE SERVER SYSTEM
	-- ==========================================
	PrivateServerSection:Input({
		Title = "Kode Private Server",
		Placeholder = "Masukkan kode private server...",
		Callback = function(val)
			inputPrivateCode = tostring(val or ""):gsub("%s+", "")
		end
	})

	PrivateServerSection:Button({
		Title = "Join Private Server",
		Desc = "Masuk ke server private berdasarkan kode dan map yang dipilih di dropdown atas.",
		Callback = function()
			if inputPrivateCode == "" then
				warn("⚠️ [Private Server] Masukkan kode server terlebih dahulu!")
				return
			end

			local targetInfo = MapDictionary[currentSelectedName]
			local mapKey = targetInfo and targetInfo.Key or "Jakarta"

			print(string.format("🔑 [Private Server] Mencoba Join Server Code: %s (Map: %s)...", inputPrivateCode, mapKey))

			if CDID_Network then
				CDID_Network:FireServer("PrivateServer", "Join", tostring(inputPrivateCode), mapKey)
			else
				warn("⚠️ [Private Server] Module Network tidak ditemukan!")
			end
		end
	})

	PrivateServerSection:Button({
		Title = "Generate Kode Private Server Baru",
		Desc = "Membuat kode server private baru milik akun kamu.",
		Callback = function()
			print("✨ [Private Server] Membuat Private Server baru...")
			if CDID_Network then
				CDID_Network:FireServer("PrivateServer", "Create")
			else
				warn("⚠️ [Private Server] Module Network tidak ditemukan!")
			end
		end
	})

	-- ==========================================
	-- C. KONTROL SERVER UMUM
	-- ==========================================
	ServerControlSection:Button({
		Title = "Rejoin Server Ini",
		Desc = "Masuk kembali ke server saat ini.",
		Callback = function()
			pcall(function()
				TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
			end)
		end
	})

	ServerControlSection:Button({
		Title = "Server Hop (Cari Server Lain)",
		Desc = "Mencari server publik lain yang masih memiliki slot kosong.",
		Callback = function()
			task.spawn(function()
				print("🔍 [Server Manager] Mencari server alternatif...")
				local placeId = game.PlaceId
				local url = string.format("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Desc&limit=100", placeId)
				local success, result = pcall(function()
					return game:HttpGet(url)
				end)

				if success and result then
					local data = HttpService:JSONDecode(result)
					if data and data.data then
						for _, s in ipairs(data.data) do
							if s.playing < s.maxPlayers and s.id ~= game.JobId then
								print("🚀 [Server Manager] Menghubungkan ke Server ID:", s.id)
								TeleportService:TeleportToPlaceInstance(placeId, s.id, LocalPlayer)
								return
							end
						end
					end
				end
				warn("⚠️ [Server Manager] Gagal mencari server via API, melakukan teleport reguler...")
				TeleportService:Teleport(placeId, LocalPlayer)
			end)
		end
	})
end

return ServerManager
