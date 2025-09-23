--[[----------------------------------------------------------------------------

LicenseConfig.lua
Konfiguration für das Lizenzierungssystem

--------------------------------------------------------------------------------

Zentrale Konfigurationsdatei für die WooCommerce License Manager API.
Hier können die API-Endpunkte und Authentifizierungsdaten angepasst werden.

WICHTIG: Passen Sie die Werte an Ihre WooCommerce Installation an!

------------------------------------------------------------------------------]]

local LicenseConfig = {}

-- WooCommerce REST API Konfiguration
-- Diese Konfiguration ist bereits für das Plugin eingerichtet
LicenseConfig.API = {
    -- Basis-URL für die Lizenz-API
    baseUrl = "https://dermatz.de/wp-json/lmfwc/v2",

    -- WooCommerce REST API Schlüssel (vorkonfiguriert für Plugin-Lizenzierung)
    consumerKey = "ck_a43a3b182ce64f5bf42d122b3c254d5fe2d4a586",
    consumerSecret = "cs_cba0648c5c09122578635b481e3460cd8ab088c9",

    -- HTTP-Timeout in Sekunden
    timeout = 30,

    -- Retry-Versuche bei Netzwerkfehlern
    maxRetries = 3
}

-- Plugin-Lizenz Konfiguration
LicenseConfig.LICENSE = {
    -- Produkt-ID in WooCommerce (optional für erweiterte Validierung)
    productId = nil,

    -- Mindest-Gültigkeitsdauer einer Lizenz-Validierung (in Sekunden)
    -- Nach dieser Zeit wird eine erneute Online-Validierung durchgeführt
    cacheValidityDuration = 24 * 60 * 60, -- 24 Stunden

    -- Erlaubt Offline-Nutzung wenn letzte Validierung erfolgreich war
    allowOfflineUsage = true,

    -- Maximale Offline-Nutzungsdauer (in Sekunden)
    maxOfflineDuration = 7 * 24 * 60 * 60, -- 7 Tage
}

-- UI-Texte und Meldungen
LicenseConfig.MESSAGES = {
    -- Erfolgreiche Validierung
    validationSuccess = "Lizenz erfolgreich validiert!",
    activationSuccess = "Lizenz erfolgreich aktiviert!",

    -- Fehlermeldungen
    noLicenseKey = "Bitte geben Sie einen Lizenzschlüssel ein.",
    invalidLicense = "Der eingegebene Lizenzschlüssel ist ungültig.",
    expiredLicense = "Ihre Lizenz ist abgelaufen. Bitte erneuern Sie Ihre Lizenz.",
    connectionError = "Verbindung zum Lizenzserver fehlgeschlagen. Bitte überprüfen Sie Ihre Internetverbindung.",
    configurationError = "API-Konfiguration ist unvollständig. Bitte kontaktieren Sie den Support.",

    -- Status-Meldungen
    validating = "Wird validiert...",
    activating = "Wird aktiviert...",

    -- Lizenz-Status
    statusActive = "✓ Aktiviert",
    statusInactive = "Nicht aktiviert",
    statusInvalid = "✗ Ungültig",
    statusExpired = "✗ Abgelaufen",
    statusConnectionError = "✗ Verbindungsfehler",
}

-- Entwickler-Optionen
LicenseConfig.DEBUG = {
    -- Aktiviert erweiterte Protokollierung
    enabled = false,

    -- Protokolliert HTTP-Anfragen und -Antworten
    logHttpRequests = false,

    -- Verwendet Test-Lizenzschlüssel für Entwicklung
    useTestLicense = false,
    testLicenseKey = "test-license-key-12345"
}

-- Methode zum Validieren der Konfiguration
function LicenseConfig.validateConfig()
    local errors = {}

    if not LicenseConfig.API.baseUrl or LicenseConfig.API.baseUrl == "" then
        table.insert(errors, "Basis-URL der API ist nicht konfiguriert")
    end

    if not LicenseConfig.API.consumerKey or LicenseConfig.API.consumerKey == "" then
        table.insert(errors, "Consumer Key ist nicht konfiguriert")
    end

    if not LicenseConfig.API.consumerSecret or LicenseConfig.API.consumerSecret == "" then
        table.insert(errors, "Consumer Secret ist nicht konfiguriert")
    end

    return #errors == 0, errors
end

-- Methode zum Abrufen der konfigurierten API-URL für einen bestimmten Endpunkt
function LicenseConfig.getApiUrl(endpoint)
    return LicenseConfig.API.baseUrl .. "/" .. endpoint
end


-- Lua base64-Encode Funktion
local b='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
function base64Encode(data)
    return ((data:gsub('.', function(x)
        local r,b='',x:byte()
        for i=8,1,-1 do r=r..(b%2^i-b%2^(i-1)>0 and '1' or '0') end
        return r
    end)..'0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
        if #x < 6 then return '' end
        local c=0
        for i=1,6 do c=c+(x:sub(i,i)=='1' and 2^(6-i) or 0) end
        return b:sub(c+1,c+1)
    end)..({ '', '==', '=' })[#data%3+1])
end

function LicenseConfig.getAuthHeaders()
    local credentials = LicenseConfig.API.consumerKey .. ":" .. LicenseConfig.API.consumerSecret
    local encoded = base64Encode(credentials)

    return {
        { field = "Authorization", value = "Basic " .. encoded },
        { field = "User-Agent", value = "Lightroom-WordPress-Plugin/1.0" },
        { field = "Content-Type", value = "application/json" },
        { field = "Accept", value = "application/json" }
    }
end

return LicenseConfig
