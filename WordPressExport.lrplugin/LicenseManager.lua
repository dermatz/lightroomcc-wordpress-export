--[[----------------------------------------------------------------------------

LicenseManager.lua
Lizenz-Verwaltung für WordPress Export Plugin

--------------------------------------------------------------------------------

Verwaltet die Plugi            local data = parseJsonResponse(response)

            if LicenseConfig.DEBUG.enabled then
                debugMessage("Activate Decision", "data.valid = " .. tostring(data.valid) .. "\ndata.valid == true? " .. tostring(data.valid == true) .. "\nType of data.valid: " .. type(data.valid))
            end

            -- Prüfe auf API-Authentifizierungsfehlerizenzierung über eine sichere Middleware-Proxy.
Die API-Keys sind sicher auf dem Server gespeichert, nicht im Client.

Middleware-Endpunkte:
- GET /license-proxy.php?action=validate&license_key={key} - Lizenz validieren
- GET /license-proxy.php?action=activate&license_key={key} - Lizenz aktivieren

------------------------------------------------------------------------------]]

local LrHttp = import 'LrHttp'
local LrPrefs = import 'LrPrefs'
local LrTasks = import 'LrTasks'
local LrDialogs = import 'LrDialogs'

local LicenseConfig = require 'LicenseConfig'
local LicenseManager = {}

-- Debug-Funktion für sichtbare Meldungen
local function debugMessage(title, message)
    if LicenseConfig.DEBUG.enabled then
        LrDialogs.message("DEBUG: " .. title, message, "info")
    end
end

-- Test-Funktion um zu prüfen ob der LicenseManager geladen ist
function LicenseManager.testConnection()
    debugMessage("Test Connection", "LicenseManager ist geladen und funktioniert!")
    return true
end

-- Lizenz-Status Konstanten
local LICENSE_STATUS = {
    VALID = "valid",
    INVALID = "invalid",
    EXPIRED = "expired",
    DISABLED = "disabled",
    SOLD = "sold"
}

-- Preferences für Lizenzdaten
local function getPrefs()
    return LrPrefs.prefsForPlugin()
end

-- HTTP-Header für Middleware-Proxy erstellen
local function createHeaders()
    return LicenseConfig.getProxyHeaders()
end

-- JSON-Response parsen (einfache Implementierung)
local function parseJsonResponse(jsonString)
    local result = {}

    -- Debug-Logging mit sichtbaren Dialogs
    if LicenseConfig.DEBUG.enabled then
        debugMessage("JSON Parser", "Raw JSON Response: " .. tostring(jsonString))
    end

    -- Einfacher JSON-Parser für die benötigten Felder
    if jsonString then
        -- Valid Flag extrahieren
        local validMatch = string.match(jsonString, '"valid"%s*:%s*([^,}]+)')
        if validMatch then
            result.valid = string.lower(validMatch:gsub("%s", "")) == "true"
            if LicenseConfig.DEBUG.enabled then
                debugMessage("Valid Field", "Found validMatch: " .. tostring(validMatch) .. " -> parsed as: " .. tostring(result.valid))
            end
        end

        -- Status extrahieren
        local status = string.match(jsonString, '"status"%s*:%s*"([^"]*)"')
        if status then
            result.status = status
            if LicenseConfig.DEBUG.enabled then
                debugMessage("Status Field", "Found status: " .. tostring(status))
            end
        end

        -- Fehlermeldungen extrahieren
        local message = string.match(jsonString, '"message"%s*:%s*"([^"]*)"')
        if message then
            result.message = message
            if LicenseConfig.DEBUG.enabled then
                debugMessage("Message Field", "Found message: " .. tostring(message))
            end
        end

        -- Error-Code extrahieren (WooCommerce API Fehler)
        local errorCode = string.match(jsonString, '"code"%s*:%s*"([^"]*)"')
        if errorCode then
            result.errorCode = errorCode
        end

        -- HTTP Status extrahieren (aus data.status)
        local httpStatus = string.match(jsonString, '"data"%s*:%s*{[^}]*"status"%s*:%s*(%d+)')
        if httpStatus then
            result.httpStatus = tonumber(httpStatus)
        end

        -- Aktivierungs-Token extrahieren (falls vorhanden)
        local activationToken = string.match(jsonString, '"activationToken"%s*:%s*"([^"]*)"')
        if activationToken then
            result.activationToken = activationToken
        end

        -- Aktivierungen extrahieren (auch negative Zahlen)
        local activationsLeft = string.match(jsonString, '"activationsLeft"%s*:%s*(-?%d+)')
        if activationsLeft then
            result.activationsLeft = tonumber(activationsLeft)
        end

        if LicenseConfig.DEBUG.enabled then
            debugMessage("Parse Result", "result.valid = " .. tostring(result.valid) .. "\nresult.status = " .. tostring(result.status) .. "\nresult.message = " .. tostring(result.message))
        end
    end

    return result
end

-- Lizenz validieren
function LicenseManager.validateLicense(licenseKey, callback)
    if not licenseKey or licenseKey == "" then
        if callback then
            callback(false, LicenseConfig.MESSAGES.noLicenseKey)
        end
        return
    end

    -- Konfiguration prüfen
    local configValid, configErrors = LicenseConfig.validateConfig()
    if not configValid then
        if callback then
            callback(false, LicenseConfig.MESSAGES.configurationError .. " (" .. table.concat(configErrors, ", ") .. ")")
        end
        return
    end

    -- HTTP-Anfrage in korrektem Task-Kontext
    LrTasks.startAsyncTask(function()
        local url = LicenseConfig.getProxyUrl("validate", licenseKey)
        local headers = createHeaders()

        if LicenseConfig.DEBUG.enabled then
            debugMessage("Validation Start", "License Key: " .. tostring(licenseKey) .. "\nURL: " .. tostring(url))
        end

        -- Verwende LrHttp.get direkt ohne pcall
        local response, headers_response = LrHttp.get(url, headers)

        if response and response ~= "" then
            if LicenseConfig.DEBUG.enabled then
                debugMessage("HTTP Response", "Success! Response length: " .. string.len(response))
            end

            local data = parseJsonResponse(response)        if LicenseConfig.DEBUG.enabled then
            debugMessage("Validation Decision", "data.valid = " .. tostring(data.valid) .. "\ndata.valid == true? " .. tostring(data.valid == true))
        end

        if data.valid == true then
            if LicenseConfig.DEBUG.enabled then
                debugMessage("Validation Result", "SUCCESS - License is valid!")
            end
            -- Gültige Lizenz - in Preferences speichern
            local prefs = getPrefs()
            prefs.licenseKey = licenseKey
            prefs.licenseValid = true
            prefs.licenseStatus = data.status
            prefs.lastValidation = os.time()

            if callback then
                callback(true, LicenseConfig.MESSAGES.validationSuccess, data)
            end
        else
            if LicenseConfig.DEBUG.enabled then
                debugMessage("Validation Result", "FAILED - License is invalid\nReason: data.valid = " .. tostring(data.valid))
            end
            -- Ungültige Lizenz - aus Preferences entfernen
            local prefs = getPrefs()
            prefs.licenseKey = nil
            prefs.licenseValid = false
            prefs.licenseStatus = nil

            local errorMsg = data.message or LicenseConfig.MESSAGES.invalidLicense
            if data.status == LICENSE_STATUS.EXPIRED then
                errorMsg = LicenseConfig.MESSAGES.expiredLicense
            end

            if callback then
                callback(false, errorMsg, data)
            end
        end
        else
            if LicenseConfig.DEBUG.enabled then
                debugMessage("HTTP Error", "FAILED! No response received")
            end
            -- Verbindungsfehler
            if callback then
                callback(false, LicenseConfig.MESSAGES.connectionError)
            end
        end
    end)
end

-- Lizenz aktivieren
function LicenseManager.activateLicense(licenseKey, callback)
    if LicenseConfig.DEBUG.enabled then
        debugMessage("Activate License", "Function called with key: " .. tostring(licenseKey))
    end

    if not licenseKey or licenseKey == "" then
        if callback then
            callback(false, LicenseConfig.MESSAGES.noLicenseKey)
        end
        return
    end

    -- Konfiguration prüfen
    local configValid, configErrors = LicenseConfig.validateConfig()
    if not configValid then
        if callback then
            callback(false, LicenseConfig.MESSAGES.configurationError .. " (" .. table.concat(configErrors, ", ") .. ")")
        end
        return
    end

    -- HTTP-Anfrage in korrektem Task-Kontext
    LrTasks.startAsyncTask(function()
        local url = LicenseConfig.getProxyUrl("activate", licenseKey)
        local headers = createHeaders()

        if LicenseConfig.DEBUG.enabled then
            debugMessage("Activate Start", "License Key: " .. tostring(licenseKey) .. "\nURL: " .. tostring(url))
        end

        -- Verwende LrHttp.get direkt ohne pcall
        local response, headers_response = LrHttp.get(url, headers)

        if response and response ~= "" then
            if LicenseConfig.DEBUG.enabled then
                debugMessage("Activate HTTP Response", "Success! Response length: " .. string.len(response) .. "\nRaw Response: " .. response)
            end

            local data = parseJsonResponse(response)

        -- Prüfe auf API-Authentifizierungsfehler
        if data.errorCode == "lmfwc_rest_authentication_error" then
            -- Bei API-Auth-Fehlern ist meist der Lizenzschlüssel ungültig
            -- (nicht die API-Konfiguration, da wir eine Response bekommen)
            if callback then
                callback(false, LicenseConfig.MESSAGES.invalidLicense)
            end
        elseif data.valid == true then
            -- Aktivierung erfolgreich
            local prefs = getPrefs()
            prefs.licenseKey = licenseKey
            prefs.licenseValid = true
            prefs.licenseStatus = data.status
            prefs.activationToken = data.activationToken
            prefs.lastValidation = os.time()

            if callback then
                callback(true, LicenseConfig.MESSAGES.activationSuccess, data)
            end
        else
            -- Lizenz ungültig oder andere Fehler
            local errorMsg = data.message or LicenseConfig.MESSAGES.invalidLicense

            -- Spezifische Fehlermeldungen je nach Fehlercode
            if data.errorCode then
                if string.find(data.errorCode, "invalid") or string.find(data.errorCode, "not_found") then
                    errorMsg = LicenseConfig.MESSAGES.invalidLicense
                elseif string.find(data.errorCode, "expired") then
                    errorMsg = LicenseConfig.MESSAGES.expiredLicense
                end
            end

            if callback then
                callback(false, errorMsg, data)
            end
        end
        else
            if LicenseConfig.DEBUG.enabled then
                debugMessage("Activate HTTP Error", "FAILED! No response received")
            end
            if callback then
                callback(false, LicenseConfig.MESSAGES.connectionError)
            end
        end
    end)
end

-- Gespeicherte Lizenz prüfen
function LicenseManager.getStoredLicense()
    local prefs = getPrefs()
    return {
        licenseKey = prefs.licenseKey,
        valid = prefs.licenseValid == true,
        status = prefs.licenseStatus,
        lastValidation = prefs.lastValidation,
        activationToken = prefs.activationToken
    }
end

-- Lizenz deaktivieren (lokal)
function LicenseManager.clearLicense()
    local prefs = getPrefs()
    prefs.licenseKey = nil
    prefs.licenseValid = false
    prefs.licenseStatus = nil
    prefs.activationToken = nil
    prefs.lastValidation = nil
end

-- Prüfen ob Plugin lizenziert ist
function LicenseManager.isPluginLicensed()
    local prefs = getPrefs()
    return prefs.licenseValid == true and prefs.licenseKey ~= nil
end

-- Aktuelle Proxy-Konfiguration abrufen
function LicenseManager.getProxyConfig()
    return {
        proxyUrl = LicenseConfig.API.proxyUrl,
        configValid = LicenseConfig.validateConfig()
    }
end

return LicenseManager
