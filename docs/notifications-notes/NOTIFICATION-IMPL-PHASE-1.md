# Fase 1 - Implementación FCM Android

## Resultado

La fase 1 está implementada. Este archivo queda como guía de despliegue y
verificación; ya no contiene pasos de desarrollo pendientes.

Componentes:

- Firebase Android: `com.antonionatusch.flutter_ia_edge`.
- FlutterFire: `firebase_core` y `firebase_messaging`.
- Backend: `firebase-admin==7.1.0`.
- Planificador: `APScheduler==3.11.0`.
- Persistencia: SQLite en el volumen Docker `notification-data`.
- Zona horaria: `America/La_Paz`.

## Archivos principales

Backend:

- `app/firebase_service.py`: inicialización y envío FCM.
- `app/notification_devices.py`: esquema y operaciones SQLite.
- `app/rounds.py`: cinco muestras, mayoría, debug y notificación.
- `app/main.py`: endpoints y ciclo de vida de APScheduler.
- `app/config.py`: variables de configuración.

Flutter:

- `lib/services/notification_registration_service.dart`: permisos, token,
  renovación y recepción de mensajes.
- `lib/services/backend_api.dart`: rondas y endpoint debug.
- `lib/providers/feeder_provider.dart`: estado, historial y eventos FCM.
- `lib/screens/dashboard_screen.dart`: rondas recientes.

## Preparar el servidor

La cuenta de servicio nunca debe entrar al repositorio ni a la imagen Docker.

1. Copiar la clave al servidor:

   ```bash
   scp ia-edge-pet-feeder-firebase-adminsdk-*.json \
     USUARIO@SERVIDOR:/tmp/firebase.json
   ```

2. Instalarla con permisos restringidos:

   ```bash
   sudo install -d -m 700 /opt/pet-feeder/secrets
   sudo install -m 600 /tmp/firebase.json \
     /opt/pet-feeder/secrets/firebase.json
   rm /tmp/firebase.json
   ```

3. Agregar a `project/server/.env`:

   ```dotenv
   FIREBASE_CREDENTIALS_HOST_PATH=/opt/pet-feeder/secrets/firebase.json
   ROUND_SCHEDULER_ENABLED=true
   ROUND_TIMEZONE=America/La_Paz
   ROUND_SAMPLE_COUNT=5
   ROUND_SAMPLE_INTERVAL_SECONDS=45
   NOTIFICATION_DEBUG_ENABLED=true
   NOTIFICATION_DEBUG_DELAY_SECONDS=5
   ```

`docker-compose.yml` monta la clave como
`/run/secrets/firebase.json:ro` y configura internamente
`FIREBASE_CREDENTIALS_PATH`. No se debe agregar esa ruta interna al `.env`.

## Desplegar

Desde `project/server` en Ubuntu:

```bash
docker compose build --no-cache
docker compose up -d
docker compose logs -f pet-feeder
```

El volumen `notification-data` conserva SQLite cuando se reemplaza el
contenedor.

## Verificar backend

```bash
curl -H "X-API-Key: TOKEN_BACKEND" \
  http://SERVIDOR:7890/api/v1/notifications/status
```

Resultado esperado después de abrir la app:

```json
{
  "firebase_configured": true,
  "registered_devices": 1,
  "scheduler_enabled": true,
  "scheduler_running": true,
  "debug_enabled": true,
  "debug_delay_seconds": 5.0
}
```

Consultar rondas:

```bash
curl -H "X-API-Key: TOKEN_BACKEND" \
  "http://SERVIDOR:7890/api/v1/rounds?limit=10"
```

## Prueba debug desde Flutter

1. Instalar el APK nuevo.
2. Abrir la app y aceptar notificaciones.
3. Confirmar `registered_devices: 1`.
4. Seleccionar `Manual encendido`.
5. Abrir Cámara.
6. Pulsar `Capturar y clasificar`.
7. Esperar aproximadamente cinco segundos.
8. Validar la notificación y la ronda marcada con el icono de debug.

Probar estos estados:

- App abierta: aparece un `SnackBar` y se actualiza el historial.
- App en segundo plano: Android muestra la notificación.
- App cerrada: Android muestra la notificación; al tocarla abre el panel.

Después de la prueba:

```dotenv
NOTIFICATION_DEBUG_ENABLED=false
```

Recrear el contenedor para aplicar el cambio.

## Ronda automática

- Horas: 08:00 a 22:00, cada hora.
- Inicio backend: `hh:00:00`.
- Ventana del maestro: preencendido `hh:59:30`, apagado `hh:05:20`.
- Muestras: cinco, separadas por 45 segundos.
- Resultado: mayoría; empate o ninguna muestra válida produce `unknown`.

Cada ronda y entrega queda en SQLite. Los tokens que FCM reporte como no
registrados se deshabilitan automáticamente.

## Seguridad

- No registrar tokens FCM ni el contenido de la cuenta de servicio en logs.
- No commitear `.env`, la base SQLite ni claves JSON.
- Mantener un solo proceso del scheduler. El despliegue actual ejecuta un solo
  worker Uvicorn.
- Mantener el backend dentro de LAN/Tailscale mientras use una API key
  compartida.
