-- ==============================================================================
-- CDID HUB - DYNAMIC SERVER & MAP MANAGER
-- ==============================================================================
local ServerManager = {}

function ServerManager.Init(Window, Utils, Context)
	local TeleportService = game:GetService("TeleportService")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local HttpService = game:GetService("HttpService")
	local Players = game:GetService("Players")
	local LocalPlayer = Players.LocalPlayer

	-- 1. LOAD MODUL TELEPORT BAWAAN CDID SECARA DINAMIS
	local CDID_TeleportModule = nil
	local SharedFolder = ReplicatedStorage:WaitForChild("Shared", 5)
	local TeleportScript = SharedFolder and SharedFolder:WaitForChild("Teleport", 5)

	if TeleportScript then
		local ok, mod = pcall(require, TeleportScript)
		if ok and mod then
			CDID_TeleportModule = mod
			print("✅ [Server Manager] Berhasil me-load ReplicatedStorage.Shared.Teleport")
		end
	end

	-- 2. AMBIL LIST MAP RESMI DARI MODUL GAME (DENGAN FALLBACK)
	local MapDictionary = {}      -- { ["JAKARTA"] = { PlaceId = ..., Key = "Jakarta" } }
	local MapNamesDisplay = {}    -- { "BALI", "BANDUNG", "JAKARTA", ... }
	local defaultSelected = ""

	local function RefreshMapData()
		MapDictionary = {}
		MapNamesDisplay = {}

		local rawList = nil
		if CDID_TeleportModule and CDID_TeleportModule.GetMapList then
			pcall(function()
				rawList = CDID_TeleportModule.GetMapList()
			end)
		end

		-- Jika modul CDID berhasil dibaca
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
			-- Fallback hardcoded jika modul gagal di-require
			warn("⚠️ [Server Manager] Gagal require Teleport module, menggunakan data fallback.")
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

	-- ==============================================================================
	-- UI WINDUI TAB SETUP
	-- ==============================================================================
	local ServerTab = Window:Tab({
		Title = "Server Manager",
		Icon = "solar:server-square-bold"
	})

	local MapSection = ServerTab:Section({ Title = "Pilihan & Pindah Map CDID (Dynamic)" })
	local ServerSection = ServerTab:Section({ Title = "Kontrol Server" })

	-- DROPDOWN DINAMIS (Mengambil dari ReplicatedStorage.Shared.Teleport)
	local mapDropdown = MapSection:Dropdown({
		Title = "Pilih Map Tujuan",
		Desc = "Daftar map disinkronkan otomatis langsung dari data CDID.",
		Values = MapNamesDisplay,
		Value = currentSelectedName,
		Callback = function(chosen)
			currentSelectedName = chosen
			local info = MapDictionary[chosen]
			if info then
				print(string.format("🗺️ [Map Manager] Map: %s | Key: %s | PlaceId: %s", chosen, tostring(info.Key), tostring(info.PlaceId)))
			end
		end
	})

	-- TOMBOL PINDAH MAP RESMI
	MapSection:Button({
		Title = "Pindah ke Map Terpilih",
		Desc = "Teleport menggunakan alur resmi bawaan game CDID.",
		Callback = function()
			local targetInfo = MapDictionary[currentSelectedName]
			if not targetInfo then return end

			print("🚀 [Map Manager] Menghubungkan ke map:", currentSelectedName)

			-- Opsi 1: Panggil fungsi asli game (Memunculkan layar loading custom CDID)
			if CDID_TeleportModule and CDID_TeleportModule.TeleporToPublicServer then
				local pGui = LocalPlayer:FindFirstChild("PlayerGui")
				local ok = pcall(function()
					CDID_TeleportModule.TeleporToPublicServer(targetInfo.Key, pGui, LocalPlayer)
				end)
				if ok then return end
			end

			-- Opsi 2: Fallback Teleport Standar Roblox jika metode in-game gagal
			pcall(function()
				TeleportService:Teleport(targetInfo.PlaceId, LocalPlayer)
			end)
		end
	})

	-- TOMBOL REFRESH LIST MAP
	MapSection:Button({
		Title = "Refresh Daftar Map",
		Desc = "Muat ulang daftar map dari game tanpa inject ulang script.",
		Callback = function()
			RefreshMapData()
			if mapDropdown and mapDropdown.SetValues then
				mapDropdown:SetValues(MapNamesDisplay)
			end
			print("🔄 [Map Manager] Daftar map berhasil diperbarui.")
		end
	})

	-- REJOIN SERVER
	ServerSection:Button({
		Title = "Rejoin Server Ini",
		Desc = "Masuk kembali ke server saat ini.",
		Callback = function()
			pcall(function()
				TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
			end)
		end
	})

	-- SERVER HOP
	ServerSection:Button({
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
