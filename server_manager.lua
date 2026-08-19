-- ==============================================================================
-- CDID HUB - PRIVATE SERVER MANAGER (INSTANT REPLICA HOOK)
-- ==============================================================================
local ServerManager = {}

function ServerManager.Init(Window, Utils, Context)
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Players = game:GetService("Players")
	local LocalPlayer = Players.LocalPlayer

	local CurrentCode = ""
	local ServerMapData = {}
	local codeParagraph

	-- ==============================================================================
	-- 1. INSTANT REPLICA REMOTE EVENT LISTENER (LOBBY & IN-GAME)
	-- ==============================================================================
	local function UpdateServerData(data)
		if typeof(data) ~= "table" then return end
		
		if data.Code and tostring(data.Code) ~= "" then
			CurrentCode = tostring(data.Code)
			ServerMapData = data
			print("🔑 [Private Server] Kode berhasil diperbarui:", CurrentCode)
			if codeParagraph then
				pcall(function()
					codeParagraph:SetDesc("🔑 Kode Aktif: " .. CurrentCode)
				end)
			end
		end
	end

	-- Hook langsung ke ReplicaRemoteEvents (Sangat cepat menangkap hasil Generate/Join)
	local replicaEvents = ReplicatedStorage:WaitForChild("ReplicaRemoteEvents", 10)
	if replicaEvents then
		local setValueEvent = replicaEvents:WaitForChild("Replica_ReplicaSetValue", 10)
		if setValueEvent then
			local hook1 = setValueEvent.OnClientEvent:Connect(function(replicaId, path, value)
				if typeof(path) == "table" and path[1] == "PrivateServer" then
					UpdateServerData(value)
				end
			end)
			table.insert(Context.Hooks, hook1)
		end

		local setValuesEvent = replicaEvents:FindFirstChild("Replica_ReplicaSetValues")
		if setValuesEvent then
			local hook2 = setValuesEvent.OnClientEvent:Connect(function(replicaId, path, values)
				if typeof(path) == "table" and path[1] == "PrivateServer" then
					UpdateServerData(values)
				end
			end)
			table.insert(Context.Hooks, hook2)
		end
	end

	-- Backup via ReplicaController bila sudah masuk gameplay
	task.spawn(function()
		while not ReplicatedStorage:FindFirstChild("ClientContainer") do
			task.wait(2)
			if Context.Session ~= _G.MainCoreSession then return end
		end

		local ok, RC = pcall(function()
			return require(ReplicatedStorage.ClientContainer.Controller.ReplicaController)
		end)

		if ok and RC then
			RC.ReplicaOfClassCreated("Player_" .. LocalPlayer.UserId, function(replica)
				if replica.Data and replica.Data.PrivateServer then
					UpdateServerData(replica.Data.PrivateServer)
				end

				replica:ListenToChange({"PrivateServer"}, function(newVal)
					UpdateServerData(newVal)
				end)
			end)
		end
	end)

	-- ==============================================================================
	-- 2. UI SETUP
	-- ==============================================================================
	local ServerTab = Window:Tab({
		Title = "Server Manager",
		Icon = "solar:server-square-bold"
	})

	local CodeSection = ServerTab:Section({ Title = "Kode Private Server" })
	local JoinSection = ServerTab:Section({ Title = "Pilih Map Tujuan (Auto Join)" })

	codeParagraph = CodeSection:Paragraph({
		Title = "Kode Aktif",
		Desc = "⚠️ Belum ada kode (Klik Generate atau Input manual)",
		Image = "key"
	})

	CodeSection:Button({
		Title = "Generate Kode Server Baru",
		Desc = "Membuat server private baru via Remote.",
		Callback = function()
			local netContainer = ReplicatedStorage:FindFirstChild("NetworkContainer")
			local remoteEvents = netContainer and netContainer:FindFirstChild("RemoteEvents")
			local psRemote = remoteEvents and remoteEvents:FindFirstChild("PrivateServer")
			if psRemote then
				print("📡 [Private Server] Mengirim request pembuatan kode baru...")
				psRemote:FireServer("Create")
			else
				warn("⚠️ [Private Server] Remote PrivateServer belum ditemukan.")
			end
		end
	})

	CodeSection:Input({
		Title = "Input / Ubah Kode Manual",
		Desc = "Tempel kode jika ingin join server teman/kode lama.",
		Value = CurrentCode,
		Placeholder = "Masukkan kode private server...",
		Callback = function(val)
			if val and val ~= "" then
				CurrentCode = val:gsub("%s+", "")
				print("✏️ [Private Server] Kode manual diset ke:", CurrentCode)
				if codeParagraph then
					codeParagraph:SetDesc("🔑 Kode Aktif: " .. CurrentCode)
				end
			end
		end
	})

	if setclipboard then
		CodeSection:Button({
			Title = "Salin Kode Aktif ke Clipboard",
			Desc = "Copy kode untuk dibagikan ke teman.",
			Callback = function()
				if CurrentCode ~= "" then
					setclipboard(CurrentCode)
					print("📋 [Private Server] Kode berhasil disalin:", CurrentCode)
				else
					warn("⚠️ [Private Server] Tidak ada kode untuk disalin.")
				end
			end
		})
	end

	-- ==============================================================================
	-- 3. JOIN ACTION
	-- ==============================================================================
	local function JoinMap(mapName)
		if CurrentCode == "" or CurrentCode == nil then
			warn("⚠️ Tidak ada kode private server! Klik 'Generate Kode' atau masukkan kode secara manual.")
			return
		end

		local netContainer = ReplicatedStorage:FindFirstChild("NetworkContainer")
		local remoteEvents = netContainer and netContainer:FindFirstChild("RemoteEvents")
		local psRemote = remoteEvents and remoteEvents:FindFirstChild("PrivateServer")
		if psRemote then
			print(string.format("🚀 [Teleport] Menghubungkan ke %s | Kode: %s", mapName, CurrentCode))
			psRemote:FireServer("Join", CurrentCode, mapName)
		else
			warn("⚠️ [Private Server] Remote PrivateServer tidak ditemukan.")
		end
	end

	local Maps = {
		{ Name = "Jakarta", Desc = "Server Kota Jakarta & Sekitarnya" },
		{ Name = "JawaBarat", Desc = "Server Jawa Barat" },
		{ Name = "JawaTengah", Desc = "Server Jawa Tengah" },
		{ Name = "JawaTimur", Desc = "Server Jawa Timur" },
		{ Name = "Bali", Desc = "Server Pulau Bali" },
		{ Name = "Seasonal", Desc = "Server Event / Musiman" }
	}

	for _, map in ipairs(Maps) do
		JoinSection:Button({
			Title = "Join Map: " .. map.Name,
			Desc = map.Desc,
			Callback = function()
				JoinMap(map.Name)
			end
		})
	end
end

return ServerManager
