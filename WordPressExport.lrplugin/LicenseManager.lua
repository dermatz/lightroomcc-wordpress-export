--[[----------------------------------------------------------------------------

LicenseManager.lua
Lizenz-Verwaltung für WordPress Export Plugin

--------------------------------------------------------------------------------

Verwaltet die Plugin-Lizenzierung über eine sichere Middleware-Proxy.
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

    -- Einfacher JSON-Parser für die benötigten Felder
    if jsonString then
        -- Valid Flag extrahieren
        local validMatch = string.match(jsonString, '"valid"%s*:%s*([^,}]+)')
        if validMatch then
            result.valid = string.lower(validMatch:gsub("%s", "")) == "true"
        end

        -- Status extrahieren
        local status = string.match(jsonString, '"status"%s*:%s*"([^"]*)"')
        if status then
            result.status = status
        end

        -- Fehlermeldungen extrahieren
        local message = string.match(jsonString, '"message"%s*:%s*"([^"]*)"')
        if message then
            result.message = message
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

        -- Verwende LrHttp.get direkt ohne pcall
        local response, headers_response = LrHttp.get(url, headers)

        if response and response ~= "" then
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
                elseif data.status == LICENSE_STATUS.DISABLED then
                    errorMsg = LicenseConfig.MESSAGES.disabledLicense
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

    -- HTTP-Anfrage in korrektem Task-Kontext
    LrTasks.startAsyncTask(function()
        local url = LicenseConfig.getProxyUrl("activate", licenseKey)
        local headers = createHeaders()

        -- Verwende LrHttp.get direkt ohne pcall
        local response, headers_response = LrHttp.get(url, headers)

        if response and response ~= "" then
            local data = parseJsonResponse(response)

            -- Prüfe auf API-Authentifizierungsfehler
            if data.errorCode == "lmfwc_rest_authentication_error" then
                -- Bei API-Auth-Fehlern ist meist der Lizenzschlüssel ungültig
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

                -- Spezifische Fehlermeldungen je nach Status
                if data.status == LICENSE_STATUS.EXPIRED then
                    errorMsg = LicenseConfig.MESSAGES.expiredLicense
                elseif data.status == LICENSE_STATUS.DISABLED then
                    errorMsg = LicenseConfig.MESSAGES.disabledLicense
                end

                -- Spezifische Fehlermeldungen je nach Fehlercode (Fallback)
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

-- Prüfen ob die gespeicherte Lizenz-Validierung noch gültig ist
function LicenseManager.isLicenseValidationCacheValid()
    local prefs = getPrefs()
    local lastValidation = prefs.lastValidation

    if not lastValidation then
        return false
    end

    local currentTime = os.time()
    local timeDifference = currentTime - lastValidation
    local cacheValidityDuration = LicenseConfig.LICENSE.cacheValidityDuration or (24 * 60 * 60)

    return timeDifference < cacheValidityDuration
end

-- Automatische Lizenz-Revalidierung beim Plugin-Start
function LicenseManager.performStartupLicenseCheck(callback)
    local prefs = getPrefs()

    -- Keine Lizenz vorhanden
    if not prefs.licenseKey or prefs.licenseValid ~= true then
        if callback then
            callback(false, "Keine gültige Lizenz gespeichert")
        end
        return
    end

    -- Cache noch gültig - keine Revalidierung nötig
    if LicenseManager.isLicenseValidationCacheValid() then
        if callback then
            callback(true, "Lizenz aus Cache gültig (Status: " .. (prefs.licenseStatus or "unbekannt") .. ")")
        end
        return
    end

    -- Cache abgelaufen - Online-Revalidierung durchführen
    LicenseManager.validateLicense(prefs.licenseKey, function(success, message, data)
        if success then
            if callback then
                callback(true, "Lizenz online revalidiert: " .. message)
            end
        else
            -- Bei fehlgeschlagener Revalidierung: Lizenz als ungültig markieren
            prefs.licenseValid = false
            prefs.licenseStatus = nil

            if callback then
                callback(false, "Lizenz-Revalidierung fehlgeschlagen: " .. message)
            end
        end
    end)
end

-- Erweiterte Lizenz-Status-Prüfung (prüft auch auf Status-Änderungen)
function LicenseManager.checkLicenseStatusChange(callback)
    local prefs = getPrefs()

    if not prefs.licenseKey or prefs.licenseValid ~= true then
        if callback then
            callback(false, "Keine gültige Lizenz gespeichert", nil)
        end
        return
    end

    -- Immer online prüfen um Status-Änderungen zu erkennen
    LicenseManager.validateLicense(prefs.licenseKey, function(success, message, data)
        local statusChanged = false
        local oldStatus = prefs.licenseStatus
        local newStatus = data and data.status

        if oldStatus ~= newStatus then
            statusChanged = true
        end

        if callback then
            callback(success, message, {
                statusChanged = statusChanged,
                oldStatus = oldStatus,
                newStatus = newStatus,
                data = data
            })
        end
    end)
end

-- Stille Startup-Validierung (ohne UI-Feedback)
function LicenseManager.performSilentStartupCheck()
    LicenseManager.performStartupLicenseCheck(nil)
end

-- Intelligente Startup-Validierung mit Status-Change-Detection
function LicenseManager.performIntelligentStartupCheck(callback)
    local prefs = getPrefs()

    -- Keine Lizenz vorhanden
    if not prefs.licenseKey or prefs.licenseValid ~= true then
        if callback then
            callback(false, "Keine gültige Lizenz gespeichert")
        end
        return
    end

    -- Wenn Cache noch gültig ist, trotzdem gelegentlich (bei jedem 10. Start) online prüfen
    -- um Status-Änderungen zu erkennen
    local shouldForceCheck = false
    local startupCount = prefs.startupCount or 0
    startupCount = startupCount + 1
    prefs.startupCount = startupCount

    -- Jeder 10. Start oder bei kritischen Status
    if (startupCount % 10 == 0) or (prefs.licenseStatus == "disabled") then
        shouldForceCheck = true
    end

    if LicenseManager.isLicenseValidationCacheValid() and not shouldForceCheck then
        if callback then
            callback(true, "Lizenz aus Cache gültig (Status: " .. (prefs.licenseStatus or "unbekannt") .. ")")
        end
        return
    end

    -- Online-Validierung durchführen
    LicenseManager.checkLicenseStatusChange(function(success, message, statusInfo)
        if success then
            if statusInfo and statusInfo.statusChanged then
                local changeMsg = "Status geändert: " .. (statusInfo.oldStatus or "unbekannt") .. " → " .. (statusInfo.newStatus or "unbekannt")
                if callback then
                    callback(true, "Lizenz revalidiert. " .. changeMsg)
                end
            else
                if callback then
                    callback(true, "Lizenz online bestätigt: " .. message)
                end
            end
        else
            -- Bei Fehler: Lizenz als ungültig markieren
            prefs.licenseValid = false
            prefs.licenseStatus = nil

            if callback then
                callback(false, "Lizenz-Status geändert - ungültig: " .. message)
            end
        end
    end)
end

-- Cache-Status für Debugging anzeigen
function LicenseManager.getCacheStatus()
    local prefs = getPrefs()
    local currentTime = os.time()

    return {
        licenseKey = prefs.licenseKey,
        licenseValid = prefs.licenseValid,
        licenseStatus = prefs.licenseStatus,
        lastValidation = prefs.lastValidation,
        lastValidationDate = prefs.lastValidation and os.date("%Y-%m-%d %H:%M:%S", prefs.lastValidation) or "Nie",
        currentTime = currentTime,
        currentTimeDate = os.date("%Y-%m-%d %H:%M:%S", currentTime),
        timeSinceLastValidation = prefs.lastValidation and (currentTime - prefs.lastValidation) or nil,
        cacheValidityDuration = LicenseConfig.LICENSE.cacheValidityDuration,
        isCacheValid = LicenseManager.isLicenseValidationCacheValid(),
        startupCount = prefs.startupCount or 0
    }
end

-- Cache forciert invalidieren (für sofortige Revalidierung)
function LicenseManager.forceCacheInvalidation()
    local prefs = getPrefs()
    prefs.lastValidation = 0  -- Cache als abgelaufen markieren
    prefs.startupCount = (prefs.startupCount or 0) + 10  -- Forciert Online-Check
end

-- Aktuelle Proxy-Konfiguration abrufen
function LicenseManager.getProxyConfig()
    return {
        proxyUrl = LicenseConfig.API.proxyUrl,
        configValid = LicenseConfig.validateConfig()
    }
end

return LicenseManager
