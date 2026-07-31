# Plan de implementación de notificaciones

## Estado

La implementación está completa en código y pendiente de despliegue/prueba con
el servidor y el teléfono reales.

Implementado:

- Registro y renovación de tokens FCM por `installation_id`.
- Firebase Admin con credencial montada fuera de la imagen Docker.
- Persistencia SQLite de dispositivos, rondas, muestras y entregas FCM.
- Planificador automático con zona horaria `America/La_Paz`.
- Cinco clasificaciones por ronda y voto mayoritario.
- Historial de rondas en Flutter.
- Recepción de mensajes en primer plano, segundo plano y app cerrada.
- Modo debug que notifica cinco segundos después de una clasificación manual.
- Desactivación de tokens que Firebase reporte como no registrados.

## Rondas automáticas

1. APScheduler dispara una ronda a las `hh:00:00`, desde las 08:00 hasta las
   22:00, hora Bolivia.
2. El maestro ya debe haber activado el relé a `hh:59:30`.
3. El backend confirma que el modo sea `automatic` y que `relay_enabled` sea
   verdadero.
4. Ejecuta cinco operaciones atómicas `capture-classify`, separadas por 45
   segundos.
5. Guarda cada resultado o error individual.
6. Calcula el voto mayoritario. Un empate o la ausencia de muestras válidas se
   resuelve como `unknown`.
7. Guarda el resultado final y envía FCM a todos los dispositivos habilitados.

La clave única `scheduled_at` evita duplicar una ronda. Si el contenedor se
reinicia durante los primeros dos minutos de una ventana activa, intenta
recuperar la ronda. Una ronda interrumpida vuelve a empezar sus muestras; una
ronda completada no se vuelve a clasificar.

## Modo debug

El modo debug permite verificar FCM sin esperar una ronda automática:

1. Seleccionar `Manual encendido` en Flutter.
2. Entrar a Cámara y pulsar `Capturar y clasificar`.
3. Flutter envía el resultado a `POST /api/v1/notifications/debug`.
4. El backend guarda una ronda con `source=debug`.
5. Cinco segundos después envía una notificación con el resultado.

Configuración:

```dotenv
NOTIFICATION_DEBUG_ENABLED=true
NOTIFICATION_DEBUG_DELAY_SECONDS=5
```

Después de validar el sistema, desactivar el modo sin retirar código:

```dotenv
NOTIFICATION_DEBUG_ENABLED=false
```

Un error al programar la notificación debug no invalida la clasificación
manual.

## API

- `POST /api/v1/notifications/devices`: registra o renueva un token.
- `GET /api/v1/notifications/status`: estado de Firebase, scheduler y debug.
- `POST /api/v1/notifications/debug`: programa la prueba manual.
- `GET /api/v1/rounds`: historial paginado por límite.
- `GET /api/v1/rounds/{id}`: ronda y muestras individuales.

Todos requieren `X-API-Key`, excepto `/health`.

## Flutter Android

- Las notificaciones con la app en segundo plano o cerrada son mostradas por
  Android mediante el payload `notification` de FCM.
- En primer plano, Flutter recibe `FirebaseMessaging.onMessage`, actualiza el
  historial y muestra un `SnackBar` dentro de la app.
- Al tocar una notificación, la aplicación vuelve al panel y actualiza las
  rondas recientes.
- No se usa `flutter_local_notifications`; por eso no aparece un banner del
  sistema mientras la app está abierta.

## Pendiente después del despliegue

1. Copiar la cuenta de servicio al servidor y reconstruir el contenedor.
2. Instalar el APK actualizado y aceptar el permiso de notificaciones.
3. Confirmar que `/api/v1/notifications/status` reporte Firebase configurado y
   al menos un dispositivo.
4. Ejecutar una clasificación manual y validar la notificación a los cinco
   segundos.
5. Ejecutar una ronda automática real y validar cinco muestras, mayoría e
   historial.
6. Desactivar `NOTIFICATION_DEBUG_ENABLED` al finalizar las pruebas.

## Mejoras futuras

- Preferencias por dispositivo para elegir qué resultados notifican.
- Endpoint para retirar dispositivos.
- Pantalla detallada de muestras de cada ronda.
- Métricas de latencia y panel de entregas fallidas.
- Autenticación por usuario si el backend se expone fuera de la red privada.
