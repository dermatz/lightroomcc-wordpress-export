local LicenseConfig = {}

LicenseConfig.API = {

    -- Middleware Proxy URL
    proxyUrl = "https://dermatz.de/middleware/license-proxy.php",

    -- HTTP-Timeout in Sekunden
    timeout = 30,

    -- Retry-Versuche bei Netzwerkfehlern
    maxRetries = 3
}

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
    disabledLicense = "Ihr Lizenzschlüssel wurde deaktiviert. Bitte kontaktieren Sie den Support.",
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

    if not LicenseConfig.API.proxyUrl or LicenseConfig.API.proxyUrl == "" then
        table.insert(errors, "Proxy-URL ist nicht konfiguriert")
    end

    -- Prüfe ob URL das richtige Format hat
    if LicenseConfig.API.proxyUrl and not string.match(LicenseConfig.API.proxyUrl, "^https?://") then
        table.insert(errors, "Proxy-URL muss mit http:// oder https:// beginnen")
    end

    return #errors == 0, errors
end

-- Methode zum Erstellen der Proxy-URL für eine bestimmte Aktion
function LicenseConfig.getProxyUrl(action, licenseKey)
    if not LicenseConfig.API.proxyUrl then
        return nil
    end

    local url = LicenseConfig.API.proxyUrl .. "?action=" .. action
    if licenseKey and licenseKey ~= "" then
        url = url .. "&license_key=" .. licenseKey
    end

    return url
end


-- HTTP-Header für Proxy-Anfragen
function LicenseConfig.getProxyHeaders()
    return {
        { field = "User-Agent", value = "Lightroom-Plugin-Proxy/1.0" },
        { field = "Content-Type", value = "application/json" },
        { field = "Accept", value = "application/json" }
    }
end

return LicenseConfig
