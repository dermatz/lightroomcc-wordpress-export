--[[----------------------------------------------------------------------------

UploadTask.lua
WordPress Media Upload Task

--------------------------------------------------------------------------------

Implementiert den HTTP Upload zu WordPress über die REST API mit
Base64 Authentication und multipart/form-data.

------------------------------------------------------------------------------]]

local LrHttp = import 'LrHttp'
local LrPathUtils = import 'LrPathUtils'
local LrFileUtils = import 'LrFileUtils'
local LrDate = import 'LrDate'

local UploadTask = {}
UploadTask.__index = UploadTask

--------------------------------------------------------------------------------
-- Base64 Encoding (eigene Implementierung für Lightroom)

local base64chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'

local function encodeBase64(data)
	local result = {}

	for i = 1, #data, 3 do
		local byte1, byte2, byte3 = data:byte(i, i + 2)
		byte2 = byte2 or 0
		byte3 = byte3 or 0

		-- Bit-Operationen mit math.floor und modulo
		local combined = byte1 * 65536 + byte2 * 256 + byte3

		local char1 = math.floor(combined / 262144) + 1  -- combined >> 18
		local char2 = math.floor((combined % 262144) / 4096) + 1  -- (combined >> 12) & 0x3F
		local char3 = math.floor((combined % 4096) / 64) + 1  -- (combined >> 6) & 0x3F
		local char4 = (combined % 64) + 1  -- combined & 0x3F

		result[#result + 1] = base64chars:sub(char1, char1)
		result[#result + 1] = base64chars:sub(char2, char2)
		result[#result + 1] = i + 1 <= #data and base64chars:sub(char3, char3) or '='
		result[#result + 1] = i + 2 <= #data and base64chars:sub(char4, char4) or '='
	end

	return table.concat(result)
end

--------------------------------------------------------------------------------
-- Constructor

function UploadTask.new(exportParams)
	local self = setmetatable({}, UploadTask)

	self.wordpressUrl = exportParams.wordpressUrl
	self.username = exportParams.wordpressUsername
	self.password = exportParams.wordpressPassword

	-- URL normalisieren
	if not string.match(self.wordpressUrl, "^https?://") then
		self.wordpressUrl = "https://" .. self.wordpressUrl
	end

	-- Trailing slash entfernen
	self.wordpressUrl = string.gsub(self.wordpressUrl, "/$", "")

	-- WordPress REST API Endpoint
	self.apiEndpoint = self.wordpressUrl .. "/wp-json/wp/v2/media"

	-- Base64 Authentication String erstellen
	self.authString = self:createBasicAuthString(self.username, self.password)

	return self
end

--------------------------------------------------------------------------------
-- Base64 Encoding für Authentication

function UploadTask:createBasicAuthString(username, password)
	local credentials = username .. ":" .. password
	local encoded = encodeBase64(credentials)
	return "Basic " .. encoded
end

--------------------------------------------------------------------------------
-- Datei zu WordPress hochladen

function UploadTask:uploadPhoto(filePath, photo)

	-- Dateiinfo sammeln
	local fileName = LrPathUtils.leafName(filePath)
	local fileSize = LrFileUtils.fileAttributes(filePath).fileSize or 0

	if fileSize == 0 then
		return false, "Datei ist leer oder kann nicht gelesen werden"
	end

	-- Dateiinhalt lesen
	local fileContent, errorMessage = LrFileUtils.readFile(filePath)
	if not fileContent then
		return false, "Fehler beim Lesen der Datei: " .. (errorMessage or "Unbekannter Fehler")
	end

	-- HTTP Headers vorbereiten
	local headers = {
		{
			field = "Authorization",
			value = self.authString,
		},
		{
			field = "Content-Disposition",
			value = string.format('attachment; filename="%s"', fileName),
		},
		{
			field = "Content-Type",
			value = "image/jpeg",
		},
		{
			field = "Content-Length",
			value = tostring(fileSize),
		},
	}

	-- WordPress spezifische Header hinzufügen
	local title = photo:getFormattedMetadata('title') or LrPathUtils.removeExtension(fileName)
	local caption = photo:getFormattedMetadata('caption') or ""
	local keywords = photo:getFormattedMetadata('keywordTags') or {}

	-- Alt-Text und Beschreibung für WordPress
	if title and title ~= "" then
		table.insert(headers, {
			field = "X-WP-Media-Title",
			value = title,
		})
	end

	if caption and caption ~= "" then
		table.insert(headers, {
			field = "X-WP-Media-Caption",
			value = caption,
		})
	end

	-- HTTP POST Request durchführen
	local result, hdrs = LrHttp.post(self.apiEndpoint, fileContent, headers, "POST", 30) -- 30s timeout

	-- Antwort verarbeiten
	if result then
		-- Prüfen ob WordPress einen Fehler zurückgegeben hat
		if hdrs and hdrs.status then
			local statusCode = tonumber(hdrs.status)

			if statusCode and statusCode >= 200 and statusCode < 300 then
				-- Erfolg
				return true, "Upload erfolgreich"
			elseif statusCode == 401 then
				return false, "Authentifizierung fehlgeschlagen. Prüfen Sie Benutzername und Passwort."
			elseif statusCode == 403 then
				return false, "Zugriff verweigert. Der Benutzer hat keine Berechtigung zum Upload."
			elseif statusCode == 413 then
				return false, "Datei zu groß. Prüfen Sie die WordPress Upload-Limits."
			elseif statusCode >= 400 and statusCode < 500 then
				return false, string.format("Client-Fehler (HTTP %d): %s", statusCode, result or "Unbekannter Fehler")
			elseif statusCode >= 500 then
				return false, string.format("Server-Fehler (HTTP %d). Prüfen Sie die WordPress-Installation.", statusCode)
			else
				return false, string.format("Unerwartete HTTP-Antwort: %d", statusCode)
			end
		else
			-- Kein Status Code - vermutlich Netzwerkfehler
			return false, "Keine gültige HTTP-Antwort erhalten"
		end
	else
		-- HTTP Request komplett fehlgeschlagen
		local errorMsg = hdrs or "Unbekannter Netzwerkfehler"
		return false, "Netzwerkfehler beim Upload: " .. errorMsg
	end
end

--------------------------------------------------------------------------------
-- WordPress REST API Test (optional, für Debugging)

function UploadTask:testConnection()

	local testUrl = self.wordpressUrl .. "/wp-json/wp/v2/users/me"
	local headers = {
		{
			field = "Authorization",
			value = self.authString,
		},
	}

	local result, hdrs = LrHttp.get(testUrl, headers, 10) -- 10s timeout

	if hdrs and hdrs.status then
		local statusCode = tonumber(hdrs.status)
		if statusCode == 200 then
			return true, "Verbindung erfolgreich"
		elseif statusCode == 401 then
			return false, "Authentifizierung fehlgeschlagen"
		else
			return false, string.format("HTTP Fehler: %d", statusCode)
		end
	else
		return false, "Verbindung fehlgeschlagen"
	end
end

--------------------------------------------------------------------------------

return UploadTask
