# WordPress Export Plugin für Lightroom Classic

![License](https://img.shields.io/github/license/dermatz/lightroomcc-wordpress-export)
![Release](https://img.shields.io/github/v/release/dermatz/lightroomcc-wordpress-export)
![WordPress](https://img.shields.io/badge/WordPress-%3E%3D5.6-blue?logo=wordpress)
![Lightroom Classic](https://img.shields.io/badge/Lightroom%20Classic-%3E%3D10.0-blue?logo=adobe)

Dieses Plugin ermöglicht den direkten Export von Bildern aus Lightroom Classic in die WordPress Mediathek über die WordPress REST API.

## Voraussetzungen

- **Adobe Lightroom Classic** Version 10.0 oder neuer
- **WordPress** Version 5.6 oder neuer (für Application Password Unterstützung)
- **PHP** Version 7.4 oder neuer
- Aktivierte WordPress REST API
- Benutzer mit Medien-Upload-Berechtigung (Rolle: Autor oder höher)

## Installation

1. Laden Sie die neueste Version aus den [GitHub Releases](https://github.com/dermatz/lightroomcc-wordpress-export/releases) herunter und entpacken Sie sie
2. Kopieren Sie den `WordPressExport.lrplugin` Ordner an einen gewünschten Ort
3. Öffnen Sie Lightroom Classic
4. Gehen Sie zu `Datei > Zusatzmodulmanager`
5. Klicken Sie auf `Hinzufügen`
6. Navigieren Sie zum `WordPressExport.lrplugin` Ordner und wählen Sie ihn aus
7. Klicken Sie auf `OK`

> **Hinweis:** Dieses Plugin ist Open Source und kostenlos nutzbar. Es ist keine Lizenz oder Aktivierung erforderlich.

## Konfiguration

### WordPress Application Password erstellen (empfohlen)

1. Melden Sie sich in WordPress als Administrator an
2. Gehen Sie zu `Benutzer > Profil`
3. Scrollen Sie zum Abschnitt "Anwendungspasswörter"
4. Geben Sie einen Namen ein (z.B. "Lightroom Export")
5. Klicken Sie auf "Neues Anwendungspasswort hinzufügen"
6. Kopieren Sie das generierte Passwort (es wird nur einmal angezeigt!)

## Verwendung

1. Wählen Sie in Lightroom die gewünschten Bilder aus
2. Drücken Sie `Strg+Shift+E` oder gehen Sie zu `Datei > Exportieren`
3. Wählen Sie im Export-Dialog unter "Exportieren nach:" die Option **"WordPress"**
4. Füllen Sie die WordPress-Einstellungen aus:
   - **WordPress URL**: Die vollständige URL Ihrer WordPress-Installation (z.B. `https://meineblog.de`)
   - **Benutzername**: Ihr WordPress-Benutzername
   - **Passwort**: Das Application Password oder Ihr normales WordPress-Passwort
5. Konfigurieren Sie die übrigen Export-Einstellungen wie gewohnt
6. Klicken Sie auf "Exportieren"

## Features

- ✅ Direkter Upload in WordPress Mediathek
- ✅ Sichere Authentifizierung über Application Password
- ✅ Automatische Übertragung von Titel und Beschreibung
- ✅ Fortschrittsanzeige während des Uploads
- ✅ Detaillierte Fehlermeldungen
- ✅ Automatische Bereinigung temporärer Dateien

## Fehlerbehebung

### "Authentifizierung fehlgeschlagen"
- Überprüfen Sie Benutzername und Passwort
- Stellen Sie sicher, dass der Benutzer Administrator-Rechte hat
- Verwenden Sie ein Application Password statt des normalen Passworts

### "Zugriff verweigert"
- Der Benutzer hat keine Berechtigung zum Upload von Medien
- Überprüfen Sie die Benutzerrolle in WordPress

### "Verbindung fehlgeschlagen"
- Überprüfen Sie die WordPress-URL
- Stellen Sie sicher, dass die WordPress REST API aktiviert ist
- Prüfen Sie Firewall und SSL-Zertifikat

## Technische Details

- Verwendet WordPress REST API v2 (`/wp-json/wp/v2/media`)
- Unterstützt Basic Authentication mit Application Passwords
- Überträgt Metadaten wie Titel, Beschreibung und Schlüsselwörter
- Automatische JPEG-Kompression und Größenanpassung über Lightroom

## Support

Bei Problemen oder Fragen erstellen Sie bitte ein Issue im GitHub Repository:
[GitHub Issues](https://github.com/dermatz/lightroomcc-wordpress-export/issues)