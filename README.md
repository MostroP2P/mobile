# Mostro Mobile Client

Super early version of a mobile client for the [Mostro](https://github.com/MostroP2P/mostro) P2P platform.

This project is a mobile interface that facilitates peer-to-peer bitcoin trading over the lightning network ⚡️ using nostr 🦩. The lightning network is a layer 2 scaling solution for bitcoin that enables fast and low-cost transactions.

## Prerequisites

### For the Mobile Client
- Install [Flutter](https://flutter.dev/docs/get-started/install): Follow the official guide for your operating system.
- Install [Android Studio](https://developer.android.com/studio) or [Xcode](https://developer.apple.com/xcode/) (for iOS development)
- Install [VS Code](https://code.visualstudio.com/) (optional but recommended)

### For Mostro Daemon
- Install [Rust](https://www.rust-lang.org/tools/install)
- Install [Docker](https://docs.docker.com/get-docker/)

### For Testing Environment
- Install [Polar](https://lightningpolar.com/): For simulating Lightning Network nodes

## Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/MostroP2P/mobile.git
   cd mobile
   ```

2. Install Flutter dependencies:
   ```bash
   flutter pub get
   ```

## Running the App

### On Emulator/Simulator
```bash
flutter run
```

### On Physical Device
Connect your device and run:
```bash
flutter run
```

## Setting up Mostro Daemon

1. Clone the Mostro repository:
   ```bash
   git clone https://github.com/MostroP2P/mostro.git
   cd mostro
   ```

2. Set up the configuration:
   ```bash
   cp settings.tpl.toml settings.toml
   ```
   Edit `settings.toml` with your specific configurations.

3. Initialize the database:
   ```bash
   ./init_db.sh
   ```

4. Run the Mostro daemon:
   ```bash
   cargo run
   ```

## Setting up Polar for Testing

1. Launch Polar and create a new Lightning Network.
2. Configure at least one node (e.g., "alice").
3. Copy the necessary connection details (cert file, macaroon file) to your Mostro `settings.toml`.

## Development Workflow

1. Ensure Polar is running with your test Lightning Network.
2. Start the Mostro daemon.
3. Run the Flutter app and connect it to your local Mostro instance.

## Contributing

Please take a look at our issues section for areas where you can contribute. We welcome all contributions, big or small! 😊

## License

This project is licensed under the MIT License. See the `LICENSE` file for details.
