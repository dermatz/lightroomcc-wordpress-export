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
	end

	-- Lizenz Properties initialisieren
	if not propertyTable.licenseKey then
		propertyTable.licenseKey = ""
		propertyTable.licenseStatus = "Nicht aktiviert"
		propertyTable.licenseValid = false
		propertyTable.isValidatingLicense = false
		propertyTable.licenseMessage = ""
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

				-- Plugin Beschreibung
				f:group_box {
					title = "Über dieses Plugin",
					fill_horizontal = 1,

					f:column {
						spacing = f:control_spacing(),

						-- Plugin Banner-Bild
						f:row {
							f:picture {
								value = _PLUGIN.path .. "/assets/plugin-banner.jpg",
								width = 700,
								height = 190,
								frame_width = 0,
								frame_color = LrColor(0.7, 0.7, 0.7),
							},
						},

						f:static_text {
							title = "Features:",
							font = "<system/bold>",
						},

						f:static_text {
							title = "Ermöglicht den direkten Upload von Fotos aus Lightroom Classic in die WordPress Mediathek über die WordPress REST API.",
							width_in_chars = 80,
							height_in_lines = 1,
						},

						f:spacer { height = 1 },



						f:static_text {
							title = "• Direkter Upload in WordPress Mediathek\n• Bulk Upload (mehrere Dateien gleichzeitig)\n• Unterstützung für Application Passwords\n• Automatische Metadaten-Übertragung\n• Benutzerfreundliche Export-Konfiguration",
							width_in_chars = 60,
							height_in_lines = 4,
						},
					},
				},

				f:spacer { height = 2 },

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

						f:spacer { height = 1 },

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

						f:spacer { height = 1 },

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

							f:spacer { width = 2 },

							f:push_button {
								title = "Lizenz kaufen",
								action = function()
									LrHttp.openUrlInBrowser("https://dermatz.de/produkt/lightroom-classic-to-wordpress-exporter")
								end,
								tooltip = "Produkt-Website öffnen"
							},

							f:spacer { width = 2 },

							f:push_button {
								title = "Zurücksetzen",
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

						f:spacer { height = 1 },

						-- Lizenz-Hinweise
						f:static_text {
							title = "Hinweis: Eine gültige Lizenz ist erforderlich, um das Plugin zu verwenden. Sie können eine Lizenz auf unserer Website https://dermatz.de erwerben.",
							width_in_chars = 44,
							height_in_lines = 2,
							font = "<system/small>",
						},
					},
				},

				f:spacer { height = 15 },

				-- Support Informationen
				f:group_box {
					title = "Service und Hilfe",
					fill_horizontal = 1,

					f:column {
						spacing = f:control_spacing(),

						f:static_text {
							title = "Bei Problemen oder Fragen:",
							font = "<system/bold>",
						},

						f:row {
							f:push_button {
								title = "Fehler melden",
								action = function()
									LrHttp.openUrlInBrowser("https://github.com/dermatz/lightroomcc-wordpress-export/issues")
								end,
								tooltip = "Problem melden oder Hilfe suchen"
							},

							f:spacer { width = 2 },

							f:push_button {
								title = "Dokumentation",
								action = function()
									LrHttp.openUrlInBrowser("https://github.com/dermatz/lightroomcc-wordpress-export")
								end,
								tooltip = "Plugin-Dokumentation öffnen"
							},

							f:spacer { width = 2 },

							f:push_button {
								title = "Lizenz kaufen",
								action = function()
									LrHttp.openUrlInBrowser("https://dermatz.de/produkt/lightroom-classic-to-wordpress-exporter")
								end,
								tooltip = "Produkt-Website öffnen"
							},
						},

						f:spacer { height = 2 },

						f:static_text {
							title = "Entwickler: Mathias Elle | Support: hello@dermatz.de",
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
