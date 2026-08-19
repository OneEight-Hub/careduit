-- ==============================================================================
-- CDID HUB - PRIVATE SERVER MANAGER
-- ==============================================================================
local ServerManager = {}

function ServerManager.Init(Window, Utils, Context)
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Players = game:GetService("Players")
	local LocalPlayer = Players.LocalPlayer

	local CurrentCode = ""
	local ActiveServerData = {}

	-- Safe Listener (Non-blocking lobby check)
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
		end
	end)

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
			local netContainer = ReplicatedStorage:FindFirstChild("NetworkContainer")
			local remoteEvents = netContainer and netContainer:FindFirstChild("RemoteEvents")
			local psRemote = remoteEvents and remoteEvents:FindFirstChild("PrivateServer")
			if psRemote then
				print("📡 [Private Server] Mengirim request kode baru...")
				psRemote:FireServer("Create")
			else
				warn("⚠️ [Private Server] Remote PrivateServer belum siap.")
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
				print("✏️ [Private Server] Kode manual diubah ke:", CurrentCode)
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
					print("📋 [Private Server] Kode disalin!")
				end
			end
		})
	end

	local function JoinMap(mapName)
		if CurrentCode == "" then
			warn("⚠️ Tidak ada kode private server! Buat kode dulu atau input manual.")
			return
		end
		local netContainer = ReplicatedStorage:FindFirstChild("NetworkContainer")
		local remoteEvents = netContainer and netContainer:FindFirstChild("RemoteEvents")
		local psRemote = remoteEvents and remoteEvents:FindFirstChild("PrivateServer")
		if psRemote then
			print(string.format("🚀 [Teleport] Menghubungkan ke %s dengan kode: %s...", mapName, CurrentCode))
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
