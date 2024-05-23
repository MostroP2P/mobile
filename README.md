# Mostro mobile client

Super early version of a mobile client for the [Mostro](https://github.com/MostroP2P/mostro) P2P platform.

This project is a mobile interface that facilitates peer-to-peer bitcoin trading over the lightning network ⚡️ using nostr 🦩. The lightning network is a layer 2 scaling solution for bitcoin that enables fast and low-cost transactions.

## Prerequisites

- Install [Android studio](https://developer.android.com/studio): Capacitor 6 requires a minimum of Android Studio 2023.1.1, detailed info [here](https://capacitorjs.com/docs/getting-started/environment-setup)
- Install [node.js](https://nodejs.org): Minimum version 20.x.0
- Install [ionic](https://ionicframework.com/)
  - `npm i -g @ionic/cli`

## Install

```bash
git clone https://github.com/MostroP2P/mobile.git
cd mobile
npm install
```

## Run the app in the browser:

```bash
ionic serve
```

## Run the app in your mobile device:

```bash
ionic build
ionic cap sync
ionic cap open android
```

## Start building

Please give a look to our issues section :smile:
