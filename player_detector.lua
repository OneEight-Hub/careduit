-- ==============================================================================
-- CDID HUB - ADVANCED PLAYER DETECTOR & PANIC EVACUATION
-- ==============================================================================
local PlayerDetector = {}

function PlayerDetector.Init(Window, Utils, Context)
	local Players = game:GetService("Players")
	local TeleportService = game:GetService("TeleportService")
	local SoundService = game:GetService("SoundService")
	local LocalPlayer = Players.LocalPlayer

	-- CONFIGURASI SAFETY
	local Config = {
		NotifyOnJoin = true,
		IgnoreFriends = true,
		EmergencyAction = "Kick", -- Pilihan: "None", "Warn Only", "Kick", "Server Hop"
		OnlyWhenFarming = true     -- Hanya bertindak jika sesi farm sedang aktif
	}

	-- Play sound alert
	local function PlayWarningSound()
		local sound = Instance.new("Sound")
		sound.SoundId = "rbxassetid://4590662766"
		sound.Volume = 2.5
		sound.Parent = SoundService
		sound:Play()
		game:GetService("Debris"):AddItem(sound, 3)
	end

	local function IsFriend(player)
		if not Config.IgnoreFriends then return false end
		local ok, friend = pcall(function()
			return LocalPlayer:IsFriendsWith(player.UserId)
		end)
		return ok and friend
	end

	-- EKSEKUSI PENYELAMATAN INSTAN
	local function TriggerPanicEvacuation(intruder)
		print(string.format("🚨 [Safety Alert] Terdeteksi orang asing: %s (@%s)", intruder.DisplayName, intruder.Name))

		-- 1. Matikan Sesi Global agar Farm Berhenti Seketika
		_G.MainCoreSession = os.clock()
		if Utils and Utils.StopGiantPlatform then
			Utils.StopGiantPlatform()
		end

		PlayWarningSound()

		-- 2. Tindakan Berdasarkan Pilihan
		if Config.EmergencyAction == "Kick" then
			warn("🛑 [Safety] Melakukan Self-Kick darurat demi keamanan akun...")
			task.wait(0.2)
			LocalPlayer:Kick(string.format("[CDID Hub Safety]\nPlayer asing masuk: %s (@%s)\nClient otomatis diputus demi mencegah report.", intruder.DisplayName, intruder.Name))

		elseif Config.EmergencyAction == "Server Hop" then
			warn("🚀 [Safety] Melakukan Server Hop darurat...")
			Window:Notify({
				Title = "🚨 PLAYER ASING MASUK!",
				Content = "Pindah server otomatis untuk menghindari pantauan...",
				Duration = 5
			})
			task.wait(0.5)
			TeleportService:Teleport(game.PlaceId, LocalPlayer)

		elseif Config.EmergencyAction == "Warn Only" then
			Window:Notify({
				Title = "⚠️ PERINGATAN PLAYER ASING!",
				Content = string.format("%s (@%s) bergabung ke server!", intruder.DisplayName, intruder.Name),
				Duration = 8
			})
		end
	end

	-- ==============================================================================
	-- REALTIME EVENT: PLAYER MASUK SAAT RUNNING
	-- ==============================================================================
	local joinHook = Players.PlayerAdded:Connect(function(newPlayer)
		if newPlayer == LocalPlayer then return end

		task.wait(0.8) -- Beri waktu pengecekan status pertemanan

		if IsFriend(newPlayer) then
			Window:Notify({
				Title = "👋 Teman Masuk",
				Content = newPlayer.DisplayName .. " telah bergabung.",
				Duration = 4
			})
			return
		end

		-- Jika player asing masuk
		TriggerPanicEvacuation(newPlayer)
	end)
	table.insert(Context.Hooks, joinHook)

	-- ==============================================================================
	-- INITIAL SCAN SAAT EKSEKUSI PERTAMA
	-- ==============================================================================
	local function CheckInitialServerStatus()
		local strangers = {}
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= LocalPlayer and not IsFriend(p) then
				table.insert(strangers, p)
			end
		end

		if #strangers > 0 then
			PlayWarningSound()
			Window:Notify({
				Title = "⚠️ Server Tidak Kosong!",
				Content = string.format("Ada %d orang asing di map ini. Disarankan gunakan private server!", #strangers),
				Duration = 7
			})
		else
			print("✅ [Safety] Server aman (Solo/Teman).")
		end
	end

	-- ==============================================================================
	-- UI WINDUI TAB SETUP
	-- ==============================================================================
	local SafetyTab = Window:Tab({
		Title = "Safety & Radar",
		Icon = "solar:shield-warning-bold"
	})

	local Section = SafetyTab:Section({ Title = "Anti-Report & Panic System" })

	Section:Dropdown({
		Title = "Aksi Saat Player Asing Masuk",
		Desc = "Tindakan otomatis yang diambil jika ada orang tak dikenal bergabung.",
		Values = { "Kick (Self-Disconnect)", "Server Hop", "Warn Only", "None" },
		Value = "Kick (Self-Disconnect)",
		Callback = function(choice)
			if choice:find("Kick") then
				Config.EmergencyAction = "Kick"
			elseif choice:find("Hop") then
				Config.EmergencyAction = "Server Hop"
			elseif choice:find("Warn") then
				Config.EmergencyAction = "Warn Only"
			else
				Config.EmergencyAction = "None"
			end
		end
	})

	Section:Toggle({
		Title = "Whitelist Teman (Abaikan Teman)",
		Desc = "Tidak memicu kick/hop jika yang masuk adalah teman Roblox kamu.",
		Value = Config.IgnoreFriends,
		Callback = function(val)
			Config.IgnoreFriends = val
		end
	})

	Section:Button({
		Title = "Pindai Player Sekarang",
		Desc = "Periksa kembali daftar orang yang ada di server saat ini.",
		Callback = function()
			CheckInitialServerStatus()
		end
	})

	Section:Button({
		Title = "Panic Button (Paksa Kick Client Sendiri)",
		Desc = "Gunakan tombol ini jika ada situasi darurat / admin masuk.",
		Callback = function()
			LocalPlayer:Kick("[CDID Hub] Emergency Manual Disconnect.")
		end
	})

	task.spawn(function()
		task.wait(2.0)
		CheckInitialServerStatus()
	end)
end

return PlayerDetector
