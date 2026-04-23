# Dash Cam App 🚗📹

**Dash Cam App** è un'applicazione sviluppata in Flutter che trasforma il tuo smartphone Android o iOS in una dashcam professionale per il tuo veicolo. L'app è progettata per registrare video in modo efficiente, supportando anche il funzionamento in background e la modalità Picture-in-Picture (PiP).

## ✨ Caratteristiche principali

- 🎥 **Registrazione Video**: Acquisizione video ad alta qualità tramite la fotocamera del dispositivo.
- 🔄 **Registrazione in Background**: Grazie all'integrazione di `flutter_foreground_task`, l'app continua a registrare anche se è in background o se lo schermo è spento.
- 🖼️ **Picture-in-Picture (PiP)**: Visualizza l'anteprima della registrazione mentre utilizzi altre app (es. navigatori GPS).
- 💾 **Gestione Archiviazione**: Salvataggio automatico delle sessioni di registrazione e possibilità di esportare i video nella galleria del telefono tramite `gal`.
- ⚙️ **Configurazione Flessibile**: Imposta la durata delle sessioni di registrazione e gestisci lo spazio occupato.
- 📱 **Interfaccia Moderna**: Design pulito e intuitivo realizzato con Google Fonts.

## 🚀 Come iniziare

Segui questi passaggi per configurare il progetto localmente sul tuo computer.

### Prerequisiti

Assicurati di avere installato:
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (versione >= 3.10.8)
- [Dart SDK](https://dart.dev/get-started/sdk)
- Un editor di codice (VS Code o Android Studio)
- Un dispositivo fisico (consigliato per testare la fotocamera e i servizi in background)

### Installazione

1. **Clona il repository:**
   ```bash
   git clone https://github.com/petmax1973/dash_cam.git
   cd dash_cam
   ```

2. **Installa le dipendenze:**
   ```bash
   flutter pub get
   ```

3. **Configura i permessi (Android/iOS):**
   L'app richiede l'accesso a:
   - Fotocamera
   - Microfono
   - Archiviazione (per salvare i video)
   - Notifiche e servizi in background

4. **Esegui l'applicazione:**
   ```bash
   flutter run
   ```

## 🛠️ Tecnologie utilizzate

- **Framework**: [Flutter](https://flutter.dev)
- **Gestione Camera**: `camera`
- **Servizi Background**: `flutter_foreground_task`
- **Riproduzione Video**: `video_player`
- **Gestione Permessi**: `permission_handler`
- **Salvataggio Galleria**: `gal`

## 📄 Licenza

Questo progetto è distribuito ad uso personale e dimostrativo.

---
Sviluppato da [Massimo Pettina](https://github.com/petmax1973)
