# Dash Cam App 🚗📹

**Dash Cam App** è un'applicazione sviluppata in Flutter che trasforma il tuo smartphone Android o iOS in una dashcam professionale per il tuo veicolo. L'app è progettata per registrare video in modo efficiente, supportando anche il funzionamento in background e la modalità Picture-in-Picture (PiP).

## ✨ Caratteristiche principali

- 🎥 **Registrazione Video**: Acquisizione video ad alta qualità tramite la fotocamera del dispositivo.
- 💥 **Rilevamento Incidenti (G-Sensor)**: Sfrutta l'accelerometro per rilevare frenate brusche o impatti. Se la soglia di decelerazione viene superata, un timer blocca la registrazione per mettere al sicuro il video dell'evento.
- 🔋 **Risparmio Energetico & Schermo Attivo**: Durante la registrazione a tutto schermo, l'app mantiene il display acceso abbassandone la luminosità al minimo. Se passi al navigatore in modalità Picture-in-Picture (PiP), la luminosità si ripristina in automatico.
- 🔄 **Registrazione in Background**: Grazie all'integrazione di `flutter_foreground_task`, l'app continua a registrare anche se è in background.
- 🖼️ **Picture-in-Picture (PiP)**: Visualizza l'anteprima della registrazione (come finestra fluttuante) mentre utilizzi app di navigazione GPS.
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
- **Gestione Schermo ed Energia**: `wakelock_plus`, `screen_brightness`
- **Rilevamento Sensori (G-Sensor)**: `sensors_plus`
- **Gestione Permessi**: `permission_handler`
- **Salvataggio Galleria**: `gal`

## 📄 Licenza

Questo progetto è distribuito ad uso personale e dimostrativo.

---
Sviluppato da [Massimo Pettina](https://github.com/petmax1973)
