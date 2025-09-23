--[[----------------------------------------------------------------------------

LicenseManager.lua
Lizenz-Verwaltung für WordPress Export Plugin

--------------------------------------------------------------------------------

Verwaltet die Plugin-Lizenzierung über WooCommerce "License Manager for WooCommerce"
API. Ermöglicht Validierung, Aktivierung und Speicherung von Lizenzschlüsseln.

API-Endpunkte:
- GET /v2/licenses/validate/{license_key} - Lizenz validieren
- GET /v2/licenses/activate/{license_key} - Lizenz aktivieren
- GET /v2/licenses/deactivate/{activation_token} - Lizenz deaktivieren

------------------------------------------------------------------------------]]

local LrHttp = import 'LrHttp'
local LrPrefs = import 'LrPrefs'
local LrTasks = import 'LrTasks'
local LrDialogs = import 'LrDialogs'

local LicenseConfig = require 'LicenseConfig'
local LicenseManager = {}

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

-- HTTP-Header für WooCommerce API erstellen
local function createHeaders()
    return LicenseConfig.getAuthHeaders()
end

-- JSON-Response parsen (einfache Implementierung)
local function parseJsonResponse(jsonString)
    local result = {}

    -- Einfacher JSON-Parser für die benötigten Felder
    if jsonString then
        -- Error-Code extrahieren (WooCommerce API Fehler)
        local errorCode = string.match(jsonString, '"code"%s*:%s*"([^"]*)"')
        if errorCode then
            result.errorCode = errorCode
        end

        -- Status extrahieren
        local status = string.match(jsonString, '"status"%s*:%s*"([^"]*)"')
        if status then
            result.status = status
        end

        -- HTTP Status extrahieren (aus data.status)
        local httpStatus = string.match(jsonString, '"data"%s*:%s*{[^}]*"status"%s*:%s*(%d+)')
        if httpStatus then
            result.httpStatus = tonumber(httpStatus)
        end

        -- Valid Flag extrahieren
        local validMatch = string.match(jsonString, '"valid"%s*:%s*([^,}]+)')
        if validMatch then
            result.valid = string.lower(validMatch:gsub("%s", "")) == "true"
        end

        -- Aktivierungs-Token extrahieren (falls vorhanden)
        local activationToken = string.match(jsonString, '"activationToken"%s*:%s*"([^"]*)"')
        if activationToken then
            result.activationToken = activationToken
        end

        -- Fehlermeldungen extrahieren
        local message = string.match(jsonString, '"message"%s*:%s*"([^"]*)"')
        if message then
            result.message = message
        end

        -- Aktivierungen extrahieren
        local activationsLeft = string.match(jsonString, '"activationsLeft"%s*:%s*(%d+)')
        if activationsLeft then
            result.activationsLeft = tonumber(activationsLeft)
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

    LrTasks.startAsyncTask(function()
        local url = LicenseConfig.getApiUrl("licenses/validate/" .. licenseKey)
        local headers = createHeaders()

        local success, response = pcall(LrHttp.get, url, headers)

        if success and response then
            local data = parseJsonResponse(response)

            if data.valid == true then
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
            -- Verbindungsfehler
            if callback then
                callback(false, LicenseConfig.MESSAGES.connectionError)
            end
        end
    end)
end

-- Lizenz aktivieren
function LicenseManager.activateLicense(licenseKey, callback)
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

    LrTasks.startAsyncTask(function()
        local url = LicenseConfig.getApiUrl("licenses/activate/" .. licenseKey)
        local headers = createHeaders()

        local LrLogger = import 'LrLogger'
        local logger = LrLogger('LicenseManager')
        logger:info("Attempting to connect to: " .. url)

        local success, response = pcall(LrHttp.get, url, headers)

        if success and response then
            local data = parseJsonResponse(response)
            logger:info("Server response: " .. tostring(response))

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
            logger:error("Connection failed to: " .. url)
            if callback then
                callback(false, LicenseConfig.MESSAGES.connectionError .. " (URL: " .. url .. ")")
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

-- API-Konfiguration setzen (für Setup)
function LicenseManager.configureAPI(baseUrl, consumerKey, consumerSecret)
    LicenseConfig.API.baseUrl = baseUrl
    LicenseConfig.API.consumerKey = consumerKey
    LicenseConfig.API.consumerSecret = consumerSecret
end

-- Aktuelle API-Konfiguration abrufen
function LicenseManager.getAPIConfig()
    return {
        baseUrl = LicenseConfig.API.baseUrl,
        consumerKey = LicenseConfig.API.consumerKey,
        consumerSecret = LicenseConfig.API.consumerSecret ~= "" and "***CONFIGURED***" or "",
        configValid = LicenseConfig.validateConfig()
    }
end

return LicenseManager
