--[[----------------------------------------------------------------------------

PluginInfoDialog.lua
Eigenständiger Plugin-Info-Dialog für WordPress Export Plugin

--------------------------------------------------------------------------------

Zeigt Plugin-Informationen und Versionsüberprüfung in einem separaten Dialog an.

------------------------------------------------------------------------------]]

local LrView = import 'LrView'
local LrBinding = import 'LrBinding'
local LrDialogs = import 'LrDialogs'
local LrTasks = import 'LrTasks'
local LrFunctionContext = import 'LrFunctionContext'
local LrColor = import 'LrColor'
local LrHttp = import 'LrHttp'

local VersionChecker = require 'VersionChecker'
local SimpleVersionChecker = require 'SimpleVersionChecker'
local DirectVersionCheck = require 'DirectVersionCheck'

local PluginInfoDialog = {}

-- Plugin Info Dialog anzeigen
function PluginInfoDialog.showDialog()

	LrFunctionContext.callWithContext('PluginInfoDialog', function(context)

		local f = LrView.osFactory()
		local properties = LrBinding.makePropertyTable(context)

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

		-- Properties initialisieren
		properties.currentVersion = getCurrentVersionString(info.VERSION)
		properties.availableVersion = "Noch nicht geprüft"
		properties.hasUpdate = nil
		properties.isChecking = false

		-- Update Check Funktion
		local function checkForUpdates()
			if properties.isChecking then return end

			properties.isChecking = true
			properties.availableVersion = "Wird geprüft..."
			properties.hasUpdate = nil

			-- Einfacher Test: Setze nach 3 Sekunden ein Testergebnis
			LrTasks.startAsyncTask(function()
				-- Kurze Verzögerung für User-Feedback
				LrTasks.sleep(1)

				local versionChecker = VersionChecker.new()
				versionChecker:checkForUpdateWithCallback(function(currentVersion, remoteVersion, hasUpdate)
					properties.currentVersion = currentVersion
					properties.availableVersion = remoteVersion or "Unbekannt"
					properties.hasUpdate = hasUpdate
					properties.isChecking = false
				end)

				-- Fallback: Nach 30 Sekunden Timeout
				LrTasks.sleep(30)
				if properties.isChecking then
					properties.availableVersion = "Timeout"
					properties.hasUpdate = nil
					properties.isChecking = false
				end
			end)
		end

		-- Test-Funktion für einfachen Verbindungstest
		local function testConnection()
			properties.availableVersion = "Verbindungstest..."
			properties.isChecking = true

			SimpleVersionChecker.checkVersion(function(currentVersion, remoteVersion, hasUpdate)
				properties.currentVersion = currentVersion
				properties.availableVersion = remoteVersion or "Test-Fehler"
				properties.hasUpdate = hasUpdate
				properties.isChecking = false
			end)
		end

		-- Dialog Inhalt
		local dialogContent = f:column {
			spacing = f:dialog_spacing(),
			margin = 20,

			-- Plugin Header
			f:row {
				f:static_text {
					title = "WordPress Export Plugin",
					font = "<system/bold/24>",
					text_color = LrColor("blue"),
				},
			},

			f:spacer { height = 15 },

			-- Plugin Informationen
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
							font = "<system/bold>",
						},

						f:static_text {
							bind_to_object = properties,
							title = LrView.bind 'currentVersion',
							font = "<system/16>",
							text_color = LrColor("darkGreen"),
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
							bind_to_object = properties,
							title = LrView.bind 'availableVersion',
							font = "<system>",
							width = 150,
						},
					},

					-- Update Status
					f:row {
						f:static_text {
							title = "Status:",
							width = 150,
						},

						f:static_text {
							bind_to_object = properties,
							title = LrView.bind {
								keys = { 'hasUpdate', 'isChecking' },
								transform = function(hasUpdate, isChecking)
									if isChecking then
										return "🔄 Überprüfung läuft..."
									elseif hasUpdate == true then
										return "🔄 Update verfügbar"
									elseif hasUpdate == false then
										return "✅ Aktuell"
									else
										return "❓ Status unbekannt"
									end
								end
							},
							font = "<system>",
							width = 200,
						},
					},

					f:spacer { height = 20 },

					-- Update Check Buttons
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

						f:spacer { width = 5 },

						f:push_button {
							title = "🧪 Test",
							action = testConnection,
							tooltip = "Testet die Plugin-Funktionalität"
						},

						f:spacer { width = 5 },

						f:push_button {
							title = "⚡ Direkt",
							action = function()
								DirectVersionCheck.checkNow()
							end,
							tooltip = "Direkter GitHub API Test"
						},
					},

					f:spacer { height = 10 },

					f:row {
						-- GitHub Button
						f:push_button {
							title = "GitHub Repository öffnen",
							action = function()
								LrHttp.openUrlInBrowser("https://github.com/dermatz/lightroomcc-wordpress-export")
							end,
							tooltip = "Öffnet die Plugin-Seite auf GitHub"
						},
					},
				},
			},

			f:spacer { height = 20 },

			-- Plugin Beschreibung
			f:group_box {
				title = "Über dieses Plugin",
				fill_horizontal = 1,

				f:column {
					spacing = f:control_spacing(),

					f:static_text {
						title = "Ermöglicht den direkten Upload von Fotos aus Lightroom Classic in die WordPress Mediathek über die WordPress REST API.",
						width_in_chars = 65,
						height_in_lines = 2,
						font = "<system>",
					},

					f:spacer { height = 15 },

					f:static_text {
						title = "🎯 Features:",
						font = "<system/bold>",
					},

					f:static_text {
						title = "• Direkter Upload in WordPress Mediathek\n• Unterstützung für Application Passwords\n• Automatische Metadaten-Übertragung\n• Benutzerfreundliche Export-Konfiguration\n• Integrierte Versionsüberprüfung",
						width_in_chars = 65,
						height_in_lines = 5,
						font = "<system>",
					},
				},
			},

			f:spacer { height = 20 },

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

					f:spacer { height = 10 },

					f:row {
						f:push_button {
							title = "🐛 Issues melden",
							action = function()
								LrHttp.openUrlInBrowser("https://github.com/dermatz/lightroomcc-wordpress-export/issues")
							end,
							tooltip = "Problem melden oder Hilfe suchen"
						},

						f:spacer { width = 20 },

						f:push_button {
							title = "📖 Dokumentation",
							action = function()
								LrHttp.openUrlInBrowser("https://github.com/dermatz/lightroomcc-wordpress-export")
							end,
							tooltip = "Plugin-Dokumentation öffnen"
						},
					},

					f:spacer { height = 15 },

					f:static_text {
						title = "👨‍💻 Entwickler: Mathias Elle | dermatz | 📜 Lizenz: MIT",
						font = "<system/small>",
					},
				},
			},
		}

		-- Dialog anzeigen
		local result = LrDialogs.presentModalDialog {
			title = "WordPress Export - Plugin-Informationen",
			contents = dialogContent,
			actionVerb = "Schließen",
		}

	end)
end

return PluginInfoDialog
