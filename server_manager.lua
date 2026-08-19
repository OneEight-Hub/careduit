local ServerManager = {}

function ServerManager.Init(Window, Utils, Context)
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Players = game:GetService("Players")
	local LocalPlayer = Players.LocalPlayer

	-- Remotes
	local PrivateServerRemote = ReplicatedStorage:WaitForChild("NetworkContainer"):WaitForChild("RemoteEvents"):WaitForChild("PrivateServer")
	
	-- State
	local CurrentCode = ""
	local ActiveServerData = {}

	-- Hook Replica untuk mendeteksi kode private server milik player
	pcall(function()
		local RC = require(ReplicatedStorage:WaitForChild("ClientContainer"):WaitForChild("Controller"):WaitForChild("ReplicaController"))
		RC.ReplicaOfClassCreated("Player_" .. LocalPlayer.UserId, function(replica)
			local function CheckPS(data)
				local ps = data and data.PrivateServer
				if ps and ps.Code then
					CurrentCode = tostring(ps.Code)
					ActiveServerData = ps
					print("🔑 [Private Server] Kode terdeteksi:", CurrentCode)
				end
			end

			CheckPS(replica.Data)
			replica:ListenToChange({"PrivateServer"}, function(newVal)
				if typeof(newVal) == "table" and newVal.Code then
					CurrentCode = tostring(newVal.Code)
					ActiveServerData = newVal
					print("🔄 [Private Server] Kode diperbarui:", CurrentCode)
				end
			end)
		end)
	end)

	-- Fallback listener via Replica Remote jika ada firesignal masuk
	local ReplicaSetValue = ReplicatedStorage:FindFirstChild("ReplicaRemoteEvents") and ReplicatedStorage.ReplicaRemoteEvents:FindFirstChild("Replica_ReplicaSetValue")
	if ReplicaSetValue then
		local hook = ReplicaSetValue.OnClientEvent:Connect(function(id, path, value)
			if typeof(path) == "table" and path[1] == "PrivateServer" and typeof(value) == "table" then
				if value.Code then
					CurrentCode = tostring(value.Code)
					ActiveServerData = value
					print("🔑 [Replica Event] Private Server Code:", CurrentCode)
				end
			end
		end)
		table.insert(Context.Hooks, hook)
	end

	-- UI Setup
	local ServerTab = Window:Tab({
		Title = "Server Manager",
		Icon = "solar:server-square-bold"
	})

	local CodeSection = ServerTab:Section({ Title = "Kode Private Server" })
	local JoinSection = ServerTab:Section({ Title = "Pilih Map Tujuan (Auto Join)" })

	local codeParagraph = CodeSection:Paragraph({
		Title = "Kode Aktif",
		Desc = "Membaca kode private server...",
		Image = "key"
	})

	-- Loop status kode di UI
	task.spawn(function()
		while task.wait(0.5) do
			if Context.Session ~= _G.MainCoreSession then break end
			pcall(function()
				if CurrentCode ~= "" then
					codeParagraph:SetDesc("🔑 Kode Aktif: " .. CurrentCode)
				else
					codeParagraph:SetDesc("⚠️ Belum ada kode (Klik Generate atau Input manual)")
				end
			end)
		end
	end)

	CodeSection:Button({
		Title = "Generate Kode Server Baru",
		Desc = "Membuat server private baru via Remote.",
		Callback = function()
			print("📡 [Private Server] Mengirim request pembuatan kode baru...")
			PrivateServerRemote:FireServer("Create")
		end
	})

	CodeSection:Input({
		Title = "Input / Ubah Kode Manual",
		Desc = "Tempel kode jika ingin join server teman/kode lama.",
		Value = CurrentCode,
		Placeholder = "Masukkan 16 digit kode...",
		Callback = function(val)
			if val and val ~= "" then
				CurrentCode = val:gsub("%s+", "")
				print("✏️ [Private Server] Kode diubah manual ke:", CurrentCode)
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
					print("📋 [Private Server] Kode berhasil disalin!")
				end
			end
		})
	end

	-- Fungsi helper join server
	local function JoinMap(mapName)
		if CurrentCode == "" then
			warn("⚠️ Tidak ada kode private server! Buat kode dulu atau input manual.")
			return
		end
		print(string.format("🚀 [Teleporting] Menghubungkan ke %s dengan kode: %s...", mapName, CurrentCode))
		PrivateServerRemote:FireServer("Join", CurrentCode, mapName)
	end

	-- Daftar Map CDID
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
