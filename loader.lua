-- ==============================================================================
-- CDID HUB - ENTRY LOADER
-- ==============================================================================
local BASE_URL = "https://raw.githubusercontent.com/OneEight-Hub/careduit/main/"

if not game:IsLoaded() then
	game.Loaded:Wait()
end

local function loadModule(path)
	local url = BASE_URL .. path
	local success, content = pcall(function()
		return game:HttpGet(url .. "?nocache=" .. tostring(math.random(1000, 9999)))
	end)
	
	if not success or not content or content == "404: Not Found" then
		error("[Loader Error] Gagal memuat file dari: " .. url)
	end

	local fn, err = loadstring(content)
	if not fn then
		error("[Syntax Error] Gagal parse " .. path .. ": " .. tostring(err))
	end
	return fn()
end

_G.CDID_LoadModule = loadModule
_G.CDID_BaseURL = BASE_URL

loadModule("init.lua")
