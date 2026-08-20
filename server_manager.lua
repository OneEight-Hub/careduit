-- ==============================================================================
-- CDID HUB - DYNAMIC SERVER & PRIVATE SERVER MANAGER (AUTO-SYNC GAME CODE)
-- ==============================================================================
local ServerManager = {}

function ServerManager.Init(Window, Utils, Context)
	local TeleportService = game:GetService("TeleportService")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local HttpService = game:GetService("HttpService")
	local Players = game:GetService("Players")
	local LocalPlayer = Players.LocalPlayer

	-- 1. LOAD MODUL TELEPORT & NETWORK CDID
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
			-- Fallback data
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

	-- UI Elements Referensi
	local codeInputControl = nil
	local serverCodeParagraph = nil

	-- ==============================================================================
	-- 3. FUNGSI AUTO-DETECT KODE DARI GAME (TANPA SIMPAN FILE)
	-- ==============================================================================
	local function ApplyServerCode(code)
		if not code or code == "" or code == "ServerLabel" or code == "nil" then return end
		activeServerCode = tostring(code):gsub("%s+", "")

		print("🔑 [Private Server] Kode aktif akun terdeteksi dari game:", activeServerCode)

		if serverCodeParagraph then
			pcall(function()
				serverCodeParagraph:SetDesc("Kode Aktif Akun: " .. activeServerCode)
			end)
		end

		if codeInputControl and codeInputControl.Set then
			pcall(function()
				codeInputControl:Set(activeServerCode)
			end)
		end
	end

	local function ScanExistingGameCode()
		local pGui = LocalPlayer:FindFirstChild("PlayerGui")
		if not pGui then return false end

		-- Scan ServerLabel di PlayerGui
		for _, desc in ipairs(pGui:GetDescendants()) do
			if desc.Name == "ServerLabel" and desc:IsA("TextLabel") and desc.Text ~= "" and desc.Text ~= "ServerLabel" then
				ApplyServerCode(desc.Text)
				return true
			end
		end
		return false
	end

	-- Hook Client Event dari Network CDID untuk menerima update kode realtime
	if CDID_Network and CDID_Network.OnClientEvent then
		local psHook = CDID_Network.OnClientEvent("PrivateServer", function(action, arg1)
			if typeof(arg1) == "string" and arg1 ~= "" then
				ApplyServerCode(arg1)
			elseif typeof(action) == "string" and action:len() > 3 and not action:find("Join") then
				ApplyServerCode(action)
			end
		end)
		table.insert(Context.Hooks, psHook)
	end

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
		Desc = "Daftar map tersinkronisasi langsung dari modul game.",
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
	serverCodeParagraph = PrivateServerSection:Paragraph({
		Title = "Status Private Server",
		Desc = "Kode Aktif Akun: Memeriksa dari game...",
		Image = "key"
	})

	codeInputControl = PrivateServerSection:Input({
		Title = "Kode Private Server",
		Placeholder = "Masukkan / tunggu kode otomatis...",
		Value = activeServerCode,
		Callback = function(val)
			activeServerCode = tostring(val or ""):gsub("%s+", "")
		end
	})

	PrivateServerSection:Button({
		Title = "Join Private Server",
		Desc = "Masuk ke private server menggunakan kode di atas & map terpilih.",
		Callback = function()
			if activeServerCode == "" then
				warn("⚠️ [Private Server] Kode server belum ada! Silakan ambil atau buat terlebih dahulu.")
				return
			end

			local targetInfo = MapDictionary[currentSelectedName]
			local mapKey = targetInfo and targetInfo.Key or "Jakarta"

			print(string.format("🔑 [Private Server] Join Server Code: %s (Map: %s)...", activeServerCode, mapKey))

			if CDID_Network then
				CDID_Network:FireServer("PrivateServer", "Join", tostring(activeServerCode), mapKey)
			else
				warn("⚠️ [Private Server] Module Network tidak ditemukan!")
			end
		end
	})

	PrivateServerSection:Button({
		Title = "Ambil / Buat Kode Server Milik Sendiri",
		Desc = "Minta kode server akunmu dari game (otomatis buat baru jika belum pernah).",
		Callback = function()
			print("🔄 [Private Server] Mengambil/Generate kode private server dari server CDID...")
			if CDID_Network then
				CDID_Network:FireServer("PrivateServer", "Create")
			else
				warn("⚠️ [Private Server] Module Network tidak ditemukan!")
			end
		end
	})

	PrivateServerSection:Button({
		Title = "Salin Kode ke Clipboard",
		Desc = "Copy kode private server yang sedang aktif.",
		Callback = function()
			if activeServerCode ~= "" and setclipboard then
				setclipboard(activeServerCode)
				print("📋 [Clipboard] Kode server berhasil disalin:", activeServerCode)
			else
				warn("⚠️ [Clipboard] Belum ada kode server untuk disalin!")
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

	-- Jalankan pemindaian kode game di background saat tab diinisialisasi
	task.spawn(function()
		task.wait(1.0)
		local found = ScanExistingGameCode()
		if not found and serverCodeParagraph then
			serverCodeParagraph:SetDesc("Kode Aktif Akun: Belum dibuat / Belum terdeteksi")
		end
	end)
end

return ServerManager
