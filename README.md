# IA Edge Feeder

Android-first Flutter dashboard for the IA Edge pet feeder. It uses Provider and connects only to the FastAPI backend, not directly to either ESP32.

## Features

- Master and camera status dashboard
- Automatic, manual-on, and manual-off controls
- BMP capture and Edge Impulse classification
- Live 320x240 RGB565 debug stream with periodic classifications
- Persisted backend URL and API token settings

## Run

Connect an Android device with USB debugging enabled, then run:

```bash
source .env && flutter run \
  --dart-define=BACKEND_URL=$BACKEND_URL \
  --dart-define=BACKEND_API_TOKEN=$BACKEND_API_TOKEN
```

Copy `.env.example` to `.env` and fill in your values:

```bash
cp .env.example .env
```

The URL and token can also be entered later from the Settings page. Android cleartext HTTP access is enabled because the backend currently runs over HTTP on the trusted LAN/Tailscale network.

## Verify

```bash
flutter analyze
flutter test
```
