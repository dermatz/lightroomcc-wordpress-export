--[[----------------------------------------------------------------------------

SimpleVersionChecker.lua
Vereinfachter Version Checker für Tests

------------------------------------------------------------------------------]]

local LrHttp = import 'LrHttp'
local LrTasks = import 'LrTasks'
local LrDialogs = import 'LrDialogs'

local SimpleVersionChecker = {}

function SimpleVersionChecker.checkVersion(callback)
	LrTasks.startAsyncTask(function()

		-- Test 1: Einfache HTTP Verbindung
		LrDialogs.message("Test 1", "Starte HTTP Test...", "info")

		local success, result = pcall(function()
			return LrHttp.get("https://httpbin.org/json")
		end)

		if success and result then
			LrDialogs.message("Test 1 Erfolg", "HTTP funktioniert! Response: " .. string.sub(result, 1, 100), "info")
		else
			LrDialogs.message("Test 1 Fehler", "HTTP Fehler: " .. tostring(result), "warning")
			if callback then callback("1.0.0", "HTTP-Fehler", nil) end
			return
		end

		-- Test 2: GitHub API Test
		LrDialogs.message("Test 2", "Starte GitHub API Test...", "info")

		local success2, result2 = pcall(function()
			return LrHttp.get("https://api.github.com/repos/dermatz/lightroomcc-wordpress-export/releases/latest")
		end)

		if success2 and result2 then
			LrDialogs.message("Test 2 Erfolg", "GitHub API funktioniert! Response: " .. string.sub(result2, 1, 100), "info")

			-- Einfache JSON Parsing
			local tagName = string.match(result2, '"tag_name"%s*:%s*"([^"]+)"')
			if tagName then
				if callback then callback("1.0.0", tagName, true) end
			else
				if callback then callback("1.0.0", "Parse-Fehler", nil) end
			end
		else
			LrDialogs.message("Test 2 Fehler", "GitHub API Fehler: " .. tostring(result2), "warning")
			if callback then callback("1.0.0", "GitHub-Fehler", nil) end
		end

	end)
end

return SimpleVersionChecker
