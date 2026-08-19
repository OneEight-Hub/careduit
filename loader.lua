local BASE_URL = "https://raw.githubusercontent.com/OneEight-Hub/careduit/main/"

local function loadModule(path)
	local content = game:HttpGet(BASE_URL .. path)
	local fn, err = loadstring(content)
	if not fn then
		error("[Loader Error] Gagal memuat " .. path .. ": " .. tostring(err))
	end
	return fn()
end

_G.CDID_LoadModule = loadModule
_G.CDID_BaseURL = BASE_URL

loadModule("init.lua")
