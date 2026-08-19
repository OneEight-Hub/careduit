local JobModule = {}

function JobModule.Init(Window, Utils, Context)
	-- 1. Tambah Tab Baru di Window Hub
	local Tab = Window:Tab({
		Title = "Job Baru (Template)",
		Icon = "solar:delivery-bold"
	})
	
	local Section = Tab:Section({ Title = "Kontrol Job" })

	-- 2. Tambahkan Toggles / Buttons
	Section:Toggle({
		Title = "Auto Farm Job",
		Desc = "Deskripsi pekerjaan baru...",
		Value = false,
		Callback = function(active)
			if active then
				print("[Job Baru] Mulai...")
			else
				print("[Job Baru] Berhenti.")
			end
		end
	})
end

return JobModule
