--[[----------------------------------------------------------------------------

VersionChecker.lua
Version Check Modul für WordPress Export Plugin

--------------------------------------------------------------------------------

Überprüft auf GitHub nach neuen Plugin-Versionen und informiert den Benutzer
über verfügbare Updates.

------------------------------------------------------------------------------]]

local LrHttp = import 'LrHttp'
local LrTasks = import 'LrTasks'
local LrDialogs = import 'LrDialogs'
local LrLogger = import 'LrLogger'
local LrProgressScope = import 'LrProgressScope'
local LrFunctionContext = import 'LrFunctionContext'

-- JSON Parser für API Response (vereinfacht)
local function parseJSON(jsonString)
	-- Vereinfachter JSON Parser für GitHub API Response
	-- Sucht nach der "tag_name" Eigenschaft
	local tagName = string.match(jsonString, '"tag_name"%s*:%s*"([^"]+)"')
	local name = string.match(jsonString, '"name"%s*:%s*"([^"]+)"')
	local body = string.match(jsonString, '"body"%s*:%s*"([^"]*)"')
	local htmlUrl = string.match(jsonString, '"html_url"%s*:%s*"([^"]+)"')
	local publishedAt = string.match(jsonString, '"published_at"%s*:%s*"([^"]+)"')

	if tagName then
		return {
			tag_name = tagName,
			name = name or tagName,
			body = body or "",
			html_url = htmlUrl or "",
			published_at = publishedAt or ""
		}
	end

	return nil
end

-- Version String zu numerischen Werten konvertieren für Vergleich
local function parseVersion(versionString)
	-- Entfernt "v" Prefix falls vorhanden
	local cleanVersion = string.gsub(versionString, "^v", "")

	-- Teilt Version in major.minor.patch auf
	local major, minor, patch = string.match(cleanVersion, "(%d+)%.(%d+)%.(%d+)")

	if major and minor and patch then
		return {
			major = tonumber(major),
			minor = tonumber(minor),
			patch = tonumber(patch)
		}
	end

	return nil
end

-- Vergleicht zwei Versionen
local function compareVersions(current, remote)
	local currentParts = parseVersion(current)
	local remoteParts = parseVersion(remote)

	if not currentParts or not remoteParts then
		return 0 -- Kann nicht vergleichen
	end

	-- Major Version Vergleich
	if remoteParts.major > currentParts.major then
		return 1 -- Remote ist neuer
	elseif remoteParts.major < currentParts.major then
		return -1 -- Current ist neuer
	end

	-- Minor Version Vergleich
	if remoteParts.minor > currentParts.minor then
		return 1 -- Remote ist neuer
	elseif remoteParts.minor < currentParts.minor then
		return -1 -- Current ist neuer
	end

	-- Patch Version Vergleich
	if remoteParts.patch > currentParts.patch then
		return 1 -- Remote ist neuer
	elseif remoteParts.patch < currentParts.patch then
		return -1 -- Current ist neuer
	end

	return 0 -- Versionen sind gleich
end

-- Erstellt Version String aus Info.lua VERSION Tabelle
local function getCurrentVersionString(versionTable)
	if versionTable and versionTable.major and versionTable.minor and versionTable.revision then
		return string.format("%d.%d.%d",
			versionTable.major,
			versionTable.minor,
			versionTable.revision)
	end

	return "1.0.0" -- Fallback
end

-- VersionChecker Klasse
local VersionChecker = {}

function VersionChecker.new()
	local self = {}

	-- GitHub Repository Details
	self.githubOwner = "dermatz"
	self.githubRepo = "lightroomcc-wordpress-export"
	self.githubApiUrl = string.format("https://api.github.com/repos/%s/%s/releases/latest",
		self.githubOwner, self.githubRepo)

	-- Logger für Debugging
	self.logger = LrLogger('WordPressExport.VersionChecker')
	self.logger:enable("logfile")

	-- Aktuelle Version aus Info.lua laden
	local info = require 'Info'
	self.currentVersion = getCurrentVersionString(info.VERSION)

	self.logger:info("VersionChecker initialisiert. Aktuelle Version: " .. self.currentVersion)

	return self
end

-- Überprüft auf neue Version
function VersionChecker:checkForUpdate()
	self:checkForUpdateWithCallback(nil)
end

-- Überprüft auf neue Version mit Callback-Unterstützung
function VersionChecker:checkForUpdateWithCallback(callback)

	LrFunctionContext.callWithContext("VersionChecker", function(context)

		local progressScope = LrProgressScope({
			title = "Version wird überprüft...",
			caption = "Verbindung zu GitHub...",
			functionContext = context,
		})

		LrTasks.startAsyncTask(function()

			self.logger:info("Starte Versionsüberprüfung...")

			-- Timeout für HTTP Request
			local success, response, headers = pcall(function()
				return LrHttp.get(self.githubApiUrl, {
					{ field = "User-Agent", value = "Lightroom-WordPress-Export-Plugin/1.0" },
					{ field = "Accept", value = "application/vnd.github.v3+json" }
				})
			end)

			progressScope:setCaption("Antwort wird verarbeitet...")

			-- Fehlerbehandlung für HTTP Request
			if not success then
				self.logger:error("HTTP Request Fehler: " .. tostring(response))
				progressScope:done()

				-- Callback bei Fehler aufrufen
				if callback then
					callback(self.currentVersion, "HTTP-Fehler", nil)
				end

				LrDialogs.message("Versionsüberprüfung fehlgeschlagen",
					"HTTP Request Fehler: " .. tostring(response),
					"warning")
				return
			end

			if not response then
				self.logger:error("Keine Antwort von GitHub API erhalten")
				progressScope:done()

				-- Callback bei Fehler aufrufen
				if callback then
					callback(self.currentVersion, "Keine Antwort", nil)
				end

				LrDialogs.message("Versionsüberprüfung fehlgeschlagen",
					"Konnte keine Verbindung zu GitHub herstellen. Bitte überprüfen Sie Ihre Internetverbindung.",
					"warning")
				return
			end

			-- Debug: Response loggen
			self.logger:info("GitHub API Response erhalten. Länge: " .. string.len(response))
			self.logger:info("Response Start: " .. string.sub(response, 1, 200))

			-- HTTP Status überprüfen
			if headers and headers.status and headers.status >= 400 then
				self.logger:error(string.format("GitHub API Fehler: HTTP %d", headers.status))
				progressScope:done()

				-- Callback bei Fehler aufrufen
				if callback then
					callback(self.currentVersion, "Fehler", nil)
				end

				LrDialogs.message("Versionsüberprüfung fehlgeschlagen",
					string.format("GitHub API Fehler (HTTP %d). Bitte versuchen Sie es später erneut.",
						headers.status),
					"warning")
				return
			end			self.logger:info("GitHub API Response erhalten: " .. string.sub(response, 1, 200) .. "...")

			-- JSON Response parsen
			local releaseInfo = parseJSON(response)

			if not releaseInfo or not releaseInfo.tag_name then
				self.logger:error("Konnte Release-Informationen nicht parsen")
				progressScope:done()

				-- Callback bei Fehler aufrufen
				if callback then
					callback(self.currentVersion, "Fehler", nil)
				end

				LrDialogs.message("Versionsüberprüfung fehlgeschlagen",
					"Konnte Release-Informationen nicht verarbeiten.",
					"warning")
				return
			end

			progressScope:setCaption("Versionen werden verglichen...")

			local remoteVersion = releaseInfo.tag_name
			local versionComparison = compareVersions(self.currentVersion, remoteVersion)

			self.logger:info(string.format("Version Vergleich: Aktuell=%s, Remote=%s, Ergebnis=%d",
				self.currentVersion, remoteVersion, versionComparison))

			progressScope:done()

			-- Callback aufrufen falls vorhanden
			if callback then
				local hasUpdate = (versionComparison > 0)
				callback(self.currentVersion, remoteVersion, hasUpdate)
			end

			-- Ergebnis anzeigen
			if versionComparison > 0 then
				-- Neue Version verfügbar
				local message = string.format(
					"Eine neue Version ist verfügbar!\n\n" ..
					"Aktuelle Version: %s\n" ..
					"Neue Version: %s\n\n" ..
					"Release: %s\n\n" ..
					"Möchten Sie die Download-Seite öffnen?",
					self.currentVersion,
					remoteVersion,
					releaseInfo.name or remoteVersion
				)

				local action = LrDialogs.confirm(message, "Neue Version verfügbar", "Herunterladen", "Später")

				if action == "ok" then
					-- Öffne GitHub Release Seite
					LrHttp.openUrlInBrowser(releaseInfo.html_url)
				end

			elseif versionComparison == 0 then
				-- Aktuelle Version ist auf dem neuesten Stand
				LrDialogs.message("Versionsüberprüfung",
					string.format("Sie verwenden bereits die neueste Version (%s).", self.currentVersion),
					"info")

			else
				-- Aktuelle Version ist neuer als die auf GitHub (Development Build)
				LrDialogs.message("Versionsüberprüfung",
					string.format(
						"Sie verwenden eine neuere Version als die auf GitHub verfügbare.\n\n" ..
						"Ihre Version: %s\n" ..
						"GitHub Version: %s\n\n" ..
						"Dies ist wahrscheinlich eine Entwicklungsversion.",
						self.currentVersion, remoteVersion),
					"info")
			end

		end)

	end)
end

return VersionChecker
