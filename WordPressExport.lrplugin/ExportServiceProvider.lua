--[[----------------------------------------------------------------------------

ExportServiceProvider.lua
WordPress Export Service Provider

--------------------------------------------------------------------------------

Definiert die Benutzeroberfläche im Export-Dialog und orchestriert den
Export-Prozess mit WordPress Upload.

------------------------------------------------------------------------------]]

local LrView = import 'LrView'
local LrBinding = import 'LrBinding'
local LrDialogs = import 'LrDialogs'
local LrPrefs = import 'LrPrefs'
local LrPathUtils = import 'LrPathUtils'
local LrFileUtils = import 'LrFileUtils'
local LrFunctionContext = import 'LrFunctionContext'
local LrTasks = import 'LrTasks'

local UploadTask = require 'UploadTask'
local PluginInfoDialog = require 'PluginInfoDialog'

local exportServiceProvider = {}

-- Plugin Einstellungen speichern
local prefs = LrPrefs.prefsForPlugin()

--------------------------------------------------------------------------------
-- Exportdialog Sections

exportServiceProvider.sectionsForTopOfDialog = function(f, propertyTable)

	return {
		{
			title = "WordPress Einstellungen",

			f:column {
				spacing = f:control_spacing(),

				-- WordPress URL Feld
				f:row {
					f:static_text {
						title = "WordPress URL:",
						alignment = 'right',
						width = LrView.share 'label_width'
					},

					f:edit_field {
						bind_to_object = propertyTable,
						value = LrView.bind 'wordpressUrl',
						immediate = true,
						width_in_chars = 35,
						tooltip = "Die vollständige URL zu Ihrer WordPress-Installation (z.B. https://meineblog.de)"
					},
				},

				-- Hilfstext für WordPress URL
				f:row {
					f:static_text {
						title = "",
						width = LrView.share 'label_width'
					},

					f:static_text {
						title = "Beispiel: https://meineblog.de",
						font = "<system/small>",
						width_in_chars = 50,
					},
				},

				f:spacer { height = 10 },

				-- Benutzername Feld
				f:row {
					f:static_text {
						title = "Benutzername:",
						alignment = 'right',
						width = LrView.share 'label_width'
					},

					f:edit_field {
						bind_to_object = propertyTable,
						value = LrView.bind 'wordpressUsername',
						immediate = true,
						width_in_chars = 25,
						tooltip = "Ihr WordPress-Benutzername (Administrator oder Editor)"
					},
				},

				-- Hilfstext für Benutzername
				f:row {
					f:static_text {
						title = "",
						width = LrView.share 'label_width'
					},

					f:static_text {
						title = "Benötigt Administrator- oder Editor-Rechte für Media-Upload",
						font = "<system/small>",
						width_in_chars = 50,
					},
				},

				f:spacer { height = 10 },

				-- Passwort Feld
				f:row {
					f:static_text {
						title = "Passwort:",
						alignment = 'right',
						width = LrView.share 'label_width'
					},

					f:password_field {
						bind_to_object = propertyTable,
						value = LrView.bind 'wordpressPassword',
						immediate = true,
						width_in_chars = 25,
						tooltip = "Application Password (empfohlen) oder WordPress-Passwort"
					},
				},

				-- Hilfstext für Passwort
				f:row {
					f:static_text {
						title = "",
						width = LrView.share 'label_width'
					},

					f:static_text {
						title = "Erstellen Sie ein Application Password unter: Benutzer → Profil → Anwendungspasswörter",
						font = "<system/small>",
						width_in_chars = 50,
						height_in_lines = 2,
					},
				},

				f:spacer { height = 15 },

				-- Allgemeiner Hinweis
				f:row {
					f:static_text {
						title = "",
						width = LrView.share 'label_width'
					},

					f:static_text {
						title = "💡 Tipp: Application Passwords sind sicherer als normale Passwörter und können jederzeit widerrufen werden.",
						font = "<system/small>",
						width_in_chars = 55,
						height_in_lines = 2,
					},
				},

				f:spacer { height = 15 },

				-- Plugin Info Button
				f:row {
					f:static_text {
						title = "",
						width = LrView.share 'label_width'
					},

					f:push_button {
						title = "🔧 Plugin-Informationen & Updates",
						action = function()
							PluginInfoDialog.showDialog()
						end,
						tooltip = "Zeigt Plugin-Informationen und Versionsüberprüfung an"
					},
				},

				-- Plugin Info Hinweis
				f:row {
					f:static_text {
						title = "",
						width = LrView.share 'label_width'
					},

					f:static_text {
						title = "Versionsüberprüfung, Support und Plugin-Details",
						font = "<system/small>",
						width_in_chars = 50,
					},
				},
			},
		}
	}
end

--------------------------------------------------------------------------------
-- Export Process

exportServiceProvider.processRenderedPhotos = function(functionContext, exportContext)

	LrFunctionContext.callWithContext('WordPressExport', function(context)

		local exportSession = exportContext.exportSession
		local exportParams = exportContext.propertyTable
		local nPhotos = exportSession:countRenditions()

		-- DEBUG: Werte ausgeben zum Testen
		LrDialogs.message("Debug Info",
			string.format("URL: '%s'\nUsername: '%s'\nPassword: '%s'",
				exportParams.wordpressUrl or "NIL",
				exportParams.wordpressUsername or "NIL",
				exportParams.wordpressPassword and "***" or "NIL"), "info")

		-- Einstellungen bereinigen (Whitespace entfernen)
		local wordpressUrl = exportParams.wordpressUrl and string.gsub(exportParams.wordpressUrl, "^%s*(.-)%s*$", "%1") or ""
		local wordpressUsername = exportParams.wordpressUsername and string.gsub(exportParams.wordpressUsername, "^%s*(.-)%s*$", "%1") or ""
		local wordpressPassword = exportParams.wordpressPassword and string.gsub(exportParams.wordpressPassword, "^%s*(.-)%s*$", "%1") or ""

		-- Einstellungen validieren
		if wordpressUrl == "" then
			LrDialogs.message("WordPress Export Fehler", "Bitte geben Sie eine WordPress-URL ein.", "critical")
			return
		end

		if wordpressUsername == "" then
			LrDialogs.message("WordPress Export Fehler", "Bitte geben Sie einen Benutzernamen ein.", "critical")
			return
		end

		if wordpressPassword == "" then
			LrDialogs.message("WordPress Export Fehler", "Bitte geben Sie ein Passwort ein.", "critical")
			return
		end

		-- Bereinigte Werte zurück in exportParams schreiben
		exportParams.wordpressUrl = wordpressUrl
		exportParams.wordpressUsername = wordpressUsername
		exportParams.wordpressPassword = wordpressPassword

		-- Einstellungen für späteren Gebrauch speichern (ohne Passwort!)
		prefs.wordpressUrl = wordpressUrl
		prefs.wordpressUsername = wordpressUsername

		-- Progress Setup
		local progressScope = exportContext:configureProgress {
			title = "WordPress Upload",
		}

		local uploadTask = UploadTask.new(exportParams)
		local success = 0
		local failures = 0

		-- Jedes gerenderte Bild verarbeiten
		for i, rendition in exportContext:renditions() do

			if progressScope:isCanceled() then break end

			progressScope:setPortionComplete((i - 1) / nPhotos)
			progressScope:setCaption(string.format("Lade Bild %d von %d hoch...", i, nPhotos))

			local success_flag, pathOrMessage = rendition:waitForRender()

			if success_flag then

				-- Upload zu WordPress
				local result, message = uploadTask:uploadPhoto(pathOrMessage, rendition.photo)

				if result then
					success = success + 1
					-- Temporäre Datei löschen
					LrFileUtils.delete(pathOrMessage)
				else
					failures = failures + 1
					LrDialogs.message("Upload Fehler",
						string.format("Fehler beim Upload von '%s': %s",
							rendition.photo:getFormattedMetadata('fileName'),
							message or "Unbekannter Fehler"),
						"warning")
				end

			else
				failures = failures + 1
				LrDialogs.message("Render Fehler",
					string.format("Fehler beim Rendern: %s", pathOrMessage or "Unbekannter Fehler"),
					"warning")
			end
		end

		progressScope:done()

		-- Ergebnis-Dialog
		if failures == 0 then
			LrDialogs.message("WordPress Export abgeschlossen",
				string.format("%d Bild(er) erfolgreich in WordPress hochgeladen.", success),
				"info")
		else
			LrDialogs.message("WordPress Export abgeschlossen",
				string.format("%d erfolgreich, %d fehlgeschlagen.", success, failures),
				"warning")
		end

	end)
end

--------------------------------------------------------------------------------
-- Property Initialization

exportServiceProvider.startDialog = function(propertyTable)

	-- Properties explizit initialisieren
	propertyTable:addObserver('wordpressUrl', function() end)
	propertyTable:addObserver('wordpressUsername', function() end)
	propertyTable:addObserver('wordpressPassword', function() end)

	-- Gespeicherte Einstellungen laden
	propertyTable.wordpressUrl = prefs.wordpressUrl or ""
	propertyTable.wordpressUsername = prefs.wordpressUsername or ""
	propertyTable.wordpressPassword = "" -- Passwort nie speichern

	-- DEBUG: Prüfen ob Properties gesetzt werden
	-- LrDialogs.message("StartDialog Debug",
	--	string.format("Loaded:\nURL: '%s'\nUsername: '%s'",
	--		propertyTable.wordpressUrl, propertyTable.wordpressUsername), "info")

end

exportServiceProvider.sectionsForBottomOfDialog = function(f, propertyTable)
	return {}
end

exportServiceProvider.hideSections = function(propertyTable)
	return {}
end

exportServiceProvider.hideIfEmpty = function()
	return false
end

-- Validierung vor dem Export
exportServiceProvider.updateExportSettings = function(propertyTable)
	-- Diese Funktion wird vor dem Export aufgerufen
	-- Hier können wir die Eingaben validieren und bereinigen

	-- Sicherstellen dass Properties existieren
	propertyTable.wordpressUrl = propertyTable.wordpressUrl or ""
	propertyTable.wordpressUsername = propertyTable.wordpressUsername or ""
	propertyTable.wordpressPassword = propertyTable.wordpressPassword or ""

	-- Trimming der Eingaben
	if propertyTable.wordpressUrl then
		propertyTable.wordpressUrl = string.gsub(propertyTable.wordpressUrl, "^%s*(.-)%s*$", "%1")
	end

	if propertyTable.wordpressUsername then
		propertyTable.wordpressUsername = string.gsub(propertyTable.wordpressUsername, "^%s*(.-)%s*$", "%1")
	end

	if propertyTable.wordpressPassword then
		propertyTable.wordpressPassword = string.gsub(propertyTable.wordpressPassword, "^%s*(.-)%s*$", "%1")
	end
end

-- Preset-Unterstützung
exportServiceProvider.exportPresetFields = function()
	return {
		{ key = 'wordpressUrl', default = "" },
		{ key = 'wordpressUsername', default = "" },
		{ key = 'wordpressPassword', default = "" },
	}
end

-- Validierung und Property-Behandlung
exportServiceProvider.didFinishDialog = function(propertyTable, why)
	-- Beim OK klicken - Properties speichern
	if why == "ok" then
		prefs.wordpressUrl = propertyTable.wordpressUrl or ""
		prefs.wordpressUsername = propertyTable.wordpressUsername or ""
		-- Passwort nie speichern
	end
end

exportServiceProvider.endDialog = function(propertyTable, why)
	-- Cleanup wenn nötig
end

--------------------------------------------------------------------------------

return exportServiceProvider
