--[[----------------------------------------------------------------------------

DirectVersionCheck.lua
Direkte GitHub API Version Check

------------------------------------------------------------------------------]]

local LrHttp = import 'LrHttp'
local LrDialogs = import 'LrDialogs'
local LrTasks = import 'LrTasks'

local DirectVersionCheck = {}

function DirectVersionCheck.checkNow()
	LrTasks.startAsyncTask(function()

		-- Direkte GitHub API Abfrage
		local url = "https://api.github.com/repos/dermatz/lightroomcc-wordpress-export/releases/latest"

		LrDialogs.message("Test", "Starte Abfrage: " .. url, "info")

		local response, headers = LrHttp.get(url, {
			{ field = "User-Agent", value = "Lightroom-Plugin/1.0" }
		})

		if response then
			LrDialogs.message("Erfolg!",
				"Response erhalten!\n\nLänge: " .. string.len(response) .. " Zeichen\n\nErste 200 Zeichen:\n" .. string.sub(response, 1, 200),
				"info")

			-- Tag-Name extrahieren
			local tagName = string.match(response, '"tag_name"%s*:%s*"([^"]+)"')
			if tagName then
				LrDialogs.message("Version gefunden!",
					"Aktuelle Plugin-Version: 1.0.0\nGitHub-Version: " .. tagName .. "\n\nUpdate verfügbar!",
					"info")
			else
				LrDialogs.message("Parse-Fehler", "Konnte tag_name nicht finden in:\n" .. string.sub(response, 1, 300), "warning")
			end
		else
			LrDialogs.message("Fehler",
				"Keine Response erhalten.\nHeaders: " .. tostring(headers),
				"error")
		end

	end)
end

return DirectVersionCheck
