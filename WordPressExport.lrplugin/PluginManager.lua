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
local LrPrefs = import 'LrPrefs'

local VersionChecker = require 'VersionChecker'
local DirectVersionCheck = require 'DirectVersionCheck'
local LicenseManager = require 'LicenseManager'

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

	-- Lizenz Properties initialisieren
	if not propertyTable.licenseKey then
		propertyTable.licenseKey = ""
		propertyTable.licenseStatus = "Nicht aktiviert"
		propertyTable.licenseValid = false
		propertyTable.isValidatingLicense = false
		propertyTable.licenseMessage = ""
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

	-- Lizenz-Aktivierung Funktion
	local function activateLicense(licenseKey)
		if propertyTable.isValidatingLicense then return end
		if not licenseKey or licenseKey == "" then
			propertyTable.licenseMessage = "Bitte geben Sie einen Lizenzschlüssel ein."
			return
		end

		propertyTable.isValidatingLicense = true
		propertyTable.licenseStatus = "Wird aktiviert..."
		propertyTable.licenseMessage = ""

		-- Verwende den LicenseManager für die Aktivierung
		LicenseManager.activateLicense(licenseKey, function(success, message, data)
			if success then
				propertyTable.licenseValid = true
				propertyTable.licenseStatus = "✓ Aktiviert"
				propertyTable.licenseMessage = message
			else
				propertyTable.licenseValid = false
				propertyTable.licenseStatus = "✗ Ungültig"
				propertyTable.licenseMessage = message
			end

			propertyTable.isValidatingLicense = false
		end)
	end

	-- Funktion zum Entfernen der Lizenz
	local function removeLicense()
		LicenseManager.clearLicense()
		propertyTable.licenseKey = ""
		propertyTable.licenseValid = nil
		propertyTable.licenseStatus = "Nicht aktiviert"
		propertyTable.licenseMessage = "Lizenz wurde entfernt"
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

				-- Lizenzbereich
				f:group_box {
					title = "Plugin-Lizenz",
					fill_horizontal = 1,

					f:column {
						spacing = f:control_spacing(),

						-- Lizenz Status
						f:row {
							f:static_text {
								title = "Status:",
								width = 120,
							},

							f:static_text {
								bind_to_object = propertyTable,
								title = LrView.bind 'licenseStatus',
								font = LrView.bind {
									key = 'licenseValid',
									transform = function(valid)
										if valid == true then
											return "<system/bold>"
										else
											return "<system>"
										end
									end
								},
								text_color = LrView.bind {
									key = 'licenseValid',
									transform = function(valid)
										if valid == true then
											return LrColor(0, 0.7, 0)  -- Grün für gültig
										elseif valid == false then
											return LrColor(0.8, 0, 0)  -- Rot für ungültig
										else
											return LrColor(0.5, 0.5, 0.5)  -- Grau für unbekannt
										end
									end
								},
								width = 150,
							},
						},

						f:spacer { height = 10 },

						-- Lizenzschlüssel Eingabe
						f:row {
							f:static_text {
								title = "Lizenzschlüssel:",
								width = 120,
							},

							f:edit_field {
								bind_to_object = propertyTable,
								value = LrView.bind 'licenseKey',
								width_in_chars = 40,
								enabled = LrView.bind {
									key = 'isValidatingLicense',
									transform = function(value)
										return not value
									end
								},
								tooltip = "Geben Sie hier Ihren Lizenzschlüssel ein"
							},
						},

						f:spacer { height = 10 },

						-- Aktivierungs-Button und Status
						f:row {
							f:push_button {
								title = "Lizenz aktivieren",
								action = function()
									activateLicense(propertyTable.licenseKey)
								end,
								enabled = LrView.bind {
									keys = { 'isValidatingLicense', 'licenseKey' },
									operation = 'and',
									transform = function(value, bind)
										local isValidating = bind.isValidatingLicense
										local hasKey = bind.licenseKey and bind.licenseKey ~= ""
										return not isValidating and hasKey
									end
								},
								tooltip = "Validiert den eingegebenen Lizenzschlüssel"
							},

							f:spacer { width = 10 },

							f:push_button {
								title = "Lizenz entfernen",
								action = function()
									removeLicense()
								end,
								enabled = LrView.bind {
									keys = { 'isValidatingLicense', 'licenseValid' },
									operation = 'and',
									transform = function(value, bind)
										local isValidating = bind.isValidatingLicense
										local hasValidLicense = bind.licenseValid == true
										return not isValidating and hasValidLicense
									end
								},
								tooltip = "Entfernt die aktuelle Lizenz aus dem Plugin"
							},

							f:spacer { width = 20 },

							f:static_text {
								bind_to_object = propertyTable,
								title = LrView.bind 'licenseMessage',
								width_in_chars = 50,
								height_in_lines = 2,
								text_color = LrView.bind {
									key = 'licenseValid',
									transform = function(valid)
										if valid == true then
											return LrColor(0, 0.7, 0)  -- Grün für Erfolg
										elseif valid == false then
											return LrColor(0.8, 0, 0)  -- Rot für Fehler
										else
											return LrColor(0.5, 0.5, 0.5)  -- Grau für neutral
										end
									end
								},
							},
						},

						f:spacer { height = 10 },

						-- Lizenz-Hinweise
						f:static_text {
							title = "Hinweis: Eine gültige Lizenz ist erforderlich, um das Plugin zu verwenden. Sie können eine Lizenz auf unserer Website erwerben.",
							width_in_chars = 60,
							height_in_lines = 2,
							font = "<system/small>",
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

	-- Properties für die Lizenz-Verwaltung hinzufügen
	propertyTable:addObserver('licenseKey', function() end)
	propertyTable:addObserver('licenseStatus', function() end)
	propertyTable:addObserver('licenseValid', function() end)
	propertyTable:addObserver('isValidatingLicense', function() end)
	propertyTable:addObserver('licenseMessage', function() end)

	-- Gespeicherte Lizenz aus Preferences laden
	local storedLicense = LicenseManager.getStoredLicense()
	if storedLicense.valid and storedLicense.licenseKey then
		propertyTable.licenseKey = storedLicense.licenseKey
		propertyTable.licenseValid = storedLicense.valid
		propertyTable.licenseStatus = "✓ Aktiviert"
		propertyTable.licenseMessage = "Lizenz aus Einstellungen geladen (Status: " .. (storedLicense.status or "unbekannt") .. ")"

		-- Automatische intelligente Lizenz-Revalidierung beim Plugin-Manager Start
		propertyTable.licenseMessage = "Lizenz wird überprüft..."
		LicenseManager.performIntelligentStartupCheck(function(success, message)
			if success then
				propertyTable.licenseStatus = "✓ Aktiviert"
				propertyTable.licenseValid = true
				propertyTable.licenseMessage = message
			else
				propertyTable.licenseStatus = "✗ Ungültig"
				propertyTable.licenseValid = false
				propertyTable.licenseMessage = message
			end
		end)
	else
		-- Auch bei fehlender Lizenz eine stille Startup-Prüfung durchführen (falls Daten inkonsistent sind)
		LicenseManager.performSilentStartupCheck()
	end
end

return pluginInfoProvider
