-- ==============================================================================
-- CDID AUTO-FARM HUB - LOADER
-- ==============================================================================
local BASE_URL = "https://raw.githubusercontent.com/USERNAME/REPO_NAME/main/"

local function loadModule(path)
	local content = game:HttpGet(BASE_URL .. path)
	local fn, err = loadstring(content)
	if not fn then
		error("[Loader Error] Gagal memuat " .. path .. ": " .. tostring(err))
	end
	return fn()
end

-- Simpan loader di global agar sub-modul bisa saling load via URL
_G.CDID_LoadModule = loadModule
_G.CDID_BaseURL = BASE_URL

-- Jalankan Core Hub
loadModule("init.lua")
