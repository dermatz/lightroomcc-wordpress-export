# WordPress Export Plugin - Lizenzierungssystem

## Übersicht

Das WordPress Export Plugin für Lightroom Classic wurde um ein robustes Lizenzierungssystem erweitert, das auf dem **License Manager for WooCommerce** Plugin basiert. Dieses System ermöglicht es, Plugin-Lizenzen zu verkaufen, zu verwalten und zu validieren.

## Voraussetzungen

### WooCommerce Setup
1. **WordPress & WooCommerce**: Eine funktionierende WordPress-Installation mit WooCommerce
2. **License Manager for WooCommerce Plugin**:
   - Download: [License Manager for WooCommerce](https://wordpress.org/plugins/license-manager-for-woocommerce/)
   - Installation über WordPress Admin: Plugins > Plugin hinzufügen

### API-Zugriff konfigurieren
1. **WooCommerce REST API Keys erstellen**:
   - WooCommerce > Einstellungen > Erweitert > REST API
   - "Schlüssel hinzufügen" klicken
   - Benutzer auswählen und Berechtigung auf "Lesen/Schreiben" setzen
   - Consumer Key und Consumer Secret notieren

## Plugin-Konfiguration

### 1. API-Einstellungen anpassen

Bearbeiten Sie die Datei `LicenseConfig.lua` und passen Sie die folgenden Werte an:

```lua
-- WooCommerce REST API Konfiguration
LicenseConfig.API = {
    -- Basis-URL Ihrer WordPress/WooCommerce Installation
    baseUrl = "https://ihre-domain.com/wp-json/lmfwc/v2",

    -- WooCommerce REST API Schlüssel
    consumerKey = "ck_IHR_CONSUMER_KEY_HIER",
    consumerSecret = "cs_IHR_CONSUMER_SECRET_HIER",

    -- HTTP-Timeout in Sekunden
    timeout = 30,

    -- Retry-Versuche bei Netzwerkfehlern
    maxRetries = 3
}
```

### 2. Lizenzprodukt in WooCommerce erstellen

1. **Neues Produkt erstellen**:
   - WooCommerce > Produkte > Neues Produkt hinzufügen
   - Produktname: z.B. "Lightroom WordPress Export Plugin Lizenz"
   - Produkttyp: "Einfaches Produkt"

2. **License Manager Einstellungen**:
   - Im Produkt-Editor zum Tab "License Manager" wechseln
   - "Lizenz beim Kauf erstellen" aktivieren
   - Lizenzoptionen nach Bedarf konfigurieren:
     - Gültigkeitsdauer (z.B. 1 Jahr)
     - Maximale Aktivierungen (z.B. 1 für Einzellizenz)
     - Status beim Kauf (normalerweise "Aktiv")

### 3. Lizenzgenerierung testen

1. **Testbestellung durchführen**:
   - Produkt in den Warenkorb legen und Bestellung abschließen
   - Nach erfolgreichem Kauf sollte automatisch eine Lizenz generiert werden

2. **Lizenz in WooCommerce prüfen**:
   - License Manager > Lizenzen
   - Die neue Lizenz sollte in der Liste erscheinen

## Benutzeranleitung

### Für Endbenutzer

1. **Plugin installieren**:
   - Lightroom Classic öffnen
   - Datei > Zusatzmodul-Manager
   - "Hinzufügen" klicken und Plugin-Ordner auswählen

2. **Lizenz aktivieren**:
   - Im Zusatzmodul-Manager "WordPress Export" auswählen
   - Unter "Plugin-Lizenz" den erhaltenen Lizenzschlüssel eingeben
   - "Lizenz aktivieren" klicken
   - Bei erfolgreicher Aktivierung wird "✓ Aktiviert" angezeigt

3. **Export verwenden**:
   - Fotos in Lightroom auswählen
   - Datei > Exportieren
   - "WordPress Upload" als Export-Service wählen
   - WordPress-Einstellungen konfigurieren und exportieren

### Lizenz-Status

- **✓ Aktiviert**: Lizenz ist gültig und Plugin kann verwendet werden
- **✗ Ungültig**: Lizenzschlüssel ist nicht korrekt oder abgelaufen
- **✗ Verbindungsfehler**: Keine Verbindung zum Lizenzserver möglich
- **Wird validiert...**: Lizenz wird gerade überprüft

## Fehlerbehebung

### Häufige Probleme

1. **"API-Konfiguration ist unvollständig"**
   - Überprüfen Sie die Einstellungen in `LicenseConfig.lua`
   - Stellen Sie sicher, dass Consumer Key und Secret korrekt eingetragen sind

2. **"Verbindung zum Lizenzserver fehlgeschlagen"**
   - Internetverbindung prüfen
   - Firewall-Einstellungen überprüfen
   - WordPress-URL und API-Endpunkte testen

3. **"Lizenz ungültig"**
   - Lizenzschlüssel auf Tippfehler überprüfen
   - Status der Lizenz in WooCommerce prüfen
   - Eventuell wurde die maximale Anzahl an Aktivierungen erreicht

### Debug-Modus aktivieren

In `LicenseConfig.lua` können Sie den Debug-Modus aktivieren:

```lua
LicenseConfig.DEBUG = {
    enabled = true,
    logHttpRequests = true,
    useTestLicense = false,
}
```

### API-Endpunkte testen

Sie können die API-Endpunkte manuell testen:

```bash
# Lizenz validieren
curl -X GET "https://ihre-domain.com/wp-json/lmfwc/v2/licenses/validate/IHR_LIZENZ_KEY" \
  -u "consumer_key:consumer_secret"

# Lizenz aktivieren
curl -X GET "https://ihre-domain.com/wp-json/lmfwc/v2/licenses/activate/IHR_LIZENZ_KEY" \
  -u "consumer_key:consumer_secret"
```

## Sicherheitshinweise

1. **Consumer Keys schützen**: Bewahren Sie Consumer Key und Secret sicher auf
2. **HTTPS verwenden**: Nutzen Sie immer HTTPS für die WordPress-Installation
3. **Regelmäßige Backups**: Sichern Sie regelmäßig Ihre WooCommerce-Datenbank
4. **Updates**: Halten Sie WordPress, WooCommerce und das License Manager Plugin aktuell

## Support

Bei Problemen oder Fragen:

1. **GitHub Issues**: [Plugin-Repository](https://github.com/dermatz/lightroomcc-wordpress-export/issues)
2. **Dokumentation**: Ausführliche Dokumentation im Repository README
3. **WooCommerce Dokumentation**: [License Manager for WooCommerce Docs](https://pluginrepublic.com/license-manager-for-woocommerce/)

## Lizenz

Das Plugin steht unter der MIT-Lizenz. Das Lizenzierungssystem ist optional und kann bei Bedarf entfernt oder angepasst werden.
