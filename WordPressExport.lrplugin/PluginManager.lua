--[[----------------------------------------------------------------------------

PluginManager.lua
Plugin Manager Dialog für WordPress Export Plugin

--------------------------------------------------------------------------------

Stellt Plugin-Informationen, Versionsüberprüfung und Einstellungen
über den Lightroom Zusatzmodul-Manager zur Verfügung.

------------------------------------------------------------------------------]]

local LrView = import 'LrView'
local LrBinding = import 'LrBinding'
local LrDialogs = import 'LrDialogs'
local LrTasks = import 'LrTasks'
local LrFunctionContext = import 'LrFunctionContext'
local LrColor = import 'LrColor'
local LrHttp = import 'LrHttp'

local VersionChecker = require 'VersionChecker'
local DirectVersionCheck = require 'DirectVersionCheck'

-- Plugin Info Provider für Lightroom
local pluginInfoProvider = {}

-- Funktion die vom Lightroom Plugin Manager aufgerufen wird
pluginInfoProvider.sectionsForTopOfDialog = function(f, propertyTable)

	-- Aktuelle Version laden
	local info = require 'Info'
	local function getCurrentVersionString(versionTable)
		if versionTable and versionTable.major and versionTable.minor and versionTable.revision then
			return string.format("%d.%d.%d",
				versionTable.major,
				versionTable.minor,
				versionTable.revision)
		end
		return "1.0.0"
	end

	-- Properties initialisieren falls nicht vorhanden
	if not propertyTable.currentVersion then
		propertyTable.currentVersion = getCurrentVersionString(info.VERSION)
		propertyTable.availableVersion = "Noch nicht geprüft"
		propertyTable.hasUpdate = nil
		propertyTable.isChecking = false
	end

	-- Update Check Funktion
	local function checkForUpdates()
		if propertyTable.isChecking then return end

		propertyTable.isChecking = true
		propertyTable.availableVersion = "Wird geprüft..."
		propertyTable.hasUpdate = nil

		-- Exakt die gleiche Logik wie im funktionierenden DirectVersionCheck
		LrTasks.startAsyncTask(function()
			local LrHttp = import 'LrHttp'

			-- Direkte GitHub API Abfrage (ohne pcall da DirectVersionCheck auch ohne pcall funktioniert)
			local url = "https://api.github.com/repos/dermatz/lightroomcc-wordpress-export/releases/latest"

			local response, headers = LrHttp.get(url, {
				{ field = "User-Agent", value = "Lightroom-Plugin/1.0" }
			})

			if response then
				-- Tag-Name extrahieren
				local tagName = string.match(response, '"tag_name"%s*:%s*"([^"]+)"')
				if tagName then
					propertyTable.currentVersion = getCurrentVersionString(info.VERSION)
					propertyTable.availableVersion = tagName

					-- Version vergleichen (einfach)
					local currentVer = getCurrentVersionString(info.VERSION)
					if tagName ~= currentVer then
						propertyTable.hasUpdate = true
					else
						propertyTable.hasUpdate = false
					end
				else
					propertyTable.availableVersion = "Parse-Fehler"
					propertyTable.hasUpdate = nil
				end
			else
				propertyTable.availableVersion = "Keine Response"
				propertyTable.hasUpdate = nil
			end

			propertyTable.isChecking = false
		end)
	end

	return {
		{
			title = "Plugin-Informationen",

			f:column {
				spacing = f:control_spacing(),

				-- Plugin Header
				f:row {
					f:static_text {
						title = "WordPress Export Plugin für Lightroom Classic",
						font = "<system/bold>",
					},
				},

				f:spacer { height = 10 },

				-- Versionsbereich
				f:group_box {
					title = "Version & Updates",
					fill_horizontal = 1,

					f:column {
						spacing = f:control_spacing(),

						-- Aktuelle Version
						f:row {
							f:static_text {
								title = "Installierte Version:",
								width = 150,
							},

							f:static_text {
								bind_to_object = propertyTable,
								title = LrView.bind 'currentVersion',
								font = "<system/bold>",
								width = 100,
							},
						},

						-- Verfügbare Version
						f:row {
							f:static_text {
								title = "Verfügbare Version:",
								width = 150,
							},

							f:static_text {
								bind_to_object = propertyTable,
								title = LrView.bind 'availableVersion',
								font = LrView.bind {
									key = 'hasUpdate',
									transform = function(hasUpdate)
										if hasUpdate == true then
											return "<system/bold>"  -- Bold wenn Update verfügbar
										else
											return "<system>"       -- Normal
										end
									end
								},
								width = 100,
							},

							f:static_text {
								bind_to_object = propertyTable,
								title = LrView.bind {
									key = 'hasUpdate',
									transform = function(hasUpdate)
										if hasUpdate == true then
											return " 🔄 Update verfügbar!"  -- Indikator für Update
										else
											return ""  -- Nichts
										end
									end
								},
								font = "<system/bold>",
								width = 150,
							},
						},

						f:spacer { height = 15 },

						-- Update Check Button
						f:row {
							f:push_button {
								title = "Nach Updates suchen",
								action = checkForUpdates,
								enabled = LrView.bind {
									key = 'isChecking',
									transform = function(value)
										return not value
									end
								},
								tooltip = "Überprüft auf GitHub nach neuen Plugin-Versionen"
							},

							f:spacer { width = 20 },

							-- GitHub Button
							f:push_button {
								title = "GitHub Repository",
								action = function()
									LrHttp.openUrlInBrowser("https://github.com/dermatz/lightroomcc-wordpress-export")
								end,
								tooltip = "Öffnet die Plugin-Seite auf GitHub"
							},
						},
					},
				},

				f:spacer { height = 15 },

				-- Plugin Beschreibung
				f:group_box {
					title = "Über dieses Plugin",
					fill_horizontal = 1,

					f:column {
						spacing = f:control_spacing(),

						f:static_text {
							title = "Ermöglicht den direkten Upload von Fotos aus Lightroom Classic in die WordPress Mediathek über die WordPress REST API.",
							width_in_chars = 60,
							height_in_lines = 2,
						},

						f:spacer { height = 10 },

						f:static_text {
							title = "Features:",
							font = "<system/bold>",
						},

						f:static_text {
							title = "• Direkter Upload in WordPress Mediathek\n• Unterstützung für Application Passwords\n• Automatische Metadaten-Übertragung\n• Benutzerfreundliche Export-Konfiguration",
							width_in_chars = 60,
							height_in_lines = 4,
						},
					},
				},

				f:spacer { height = 15 },

				-- Support Informationen
				f:group_box {
					title = "Support & Hilfe",
					fill_horizontal = 1,

					f:column {
						spacing = f:control_spacing(),

						f:static_text {
							title = "Bei Problemen oder Fragen:",
							font = "<system/bold>",
						},

						f:row {
							f:push_button {
								title = "Issues melden",
								action = function()
									LrHttp.openUrlInBrowser("https://github.com/dermatz/lightroomcc-wordpress-export/issues")
								end,
								tooltip = "Problem melden oder Hilfe suchen"
							},

							f:spacer { width = 20 },

							f:push_button {
								title = "Dokumentation",
								action = function()
									LrHttp.openUrlInBrowser("https://github.com/dermatz/lightroomcc-wordpress-export")
								end,
								tooltip = "Plugin-Dokumentation öffnen"
							},
						},

						f:spacer { height = 10 },

						f:static_text {
							title = "Entwickler: Mathias Elle | dermatz | Lizenz: MIT",
							font = "<system/small>",
						},
					},
				},
			},
		}
	}
end

-- Initialisierung der Properties
pluginInfoProvider.startDialog = function(propertyTable)
	-- Properties für die Versionsüberprüfung hinzufügen
	propertyTable:addObserver('currentVersion', function() end)
	propertyTable:addObserver('availableVersion', function() end)
	propertyTable:addObserver('hasUpdate', function() end)
	propertyTable:addObserver('isChecking', function() end)
end

return pluginInfoProvider
