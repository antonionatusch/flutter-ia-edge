# Plan de implementación de notificaciones

## Estado actual

El sistema todavía no está preparado para enviar notificaciones durante las rondas automáticas:

- El backend solo actúa como proxy y no ejecuta rondas de clasificación programadas.
- No existe persistencia para resultados, rondas ni dispositivos móviles.
- No hay integración con Firebase Cloud Messaging (FCM).
- La aplicación Flutter no registra un token FCM ni gestiona permisos o apertura de notificaciones.

## Comportamiento propuesto

1. En cada ronda automática, el backend espera a que el maestro encienda la cámara.
2. Ejecuta cinco capturas y clasificaciones separadas durante la ventana activa.
3. Obtiene el resultado final mediante voto mayoritario, guardando también las puntuaciones y los errores.
4. Envía una notificación únicamente cuando el resultado final sea relevante:
   - `vacío`: avisar que puede faltar alimento.
   - `alimento disponible`: registrar la ronda sin alerta urgente, salvo preferencia del usuario.
   - `desconocido` o `sin clasificar`: avisar solo después de varias rondas consecutivas inconclusas.
5. La notificación abre el detalle de la ronda dentro de la aplicación.

## Backend

1. Añadir una base de datos, inicialmente SQLite con migraciones, para almacenar:
   - rondas y sus horarios;
   - clasificaciones individuales;
   - resultado por voto mayoritario;
   - tokens FCM por dispositivo;
   - preferencias de notificación;
   - historial de envíos y errores.
2. Implementar un planificador persistente, por ejemplo APScheduler, con zona horaria `America/La_Paz`.
3. Evitar duplicados usando una clave única por fecha y hora de ronda.
4. Crear un trabajador de ronda que confirme `relay_enabled`, espere a la cámara y ejecute cinco clasificaciones con reintentos limitados.
5. Integrar Firebase Admin SDK y almacenar sus credenciales fuera del repositorio.
6. Añadir endpoints autenticados:
   - `POST /api/v1/notifications/devices` para registrar o renovar un token FCM;
   - `DELETE /api/v1/notifications/devices/{id}` para cerrar sesión o retirar un dispositivo;
   - `GET/PUT /api/v1/notifications/preferences`;
   - `GET /api/v1/rounds` y `GET /api/v1/rounds/{id}`.
7. Eliminar tokens inválidos cuando FCM indique que ya no están registrados.

## Flutter Android

1. Configurar un proyecto Firebase Android y añadir `google-services.json` fuera de datos sensibles.
2. Incorporar `firebase_core`, `firebase_messaging` y `flutter_local_notifications`.
3. Solicitar permiso de notificaciones en Android 13 o superior con una explicación previa.
4. Registrar el token FCM en el backend y actualizarlo mediante `onTokenRefresh`.
5. Mostrar notificaciones recibidas en primer plano mediante notificaciones locales.
6. Implementar navegación profunda al detalle de la ronda al tocar una notificación.
7. Añadir una pantalla de preferencias para activar o desactivar categorías de alertas.

## Fiabilidad y pruebas

1. Probar el voto mayoritario, reintentos, rondas duplicadas y cámara fuera de línea.
2. Probar tokens FCM inválidos y fallos temporales de Firebase.
3. Verificar reinicios del contenedor durante una ronda sin repetir notificaciones.
4. Probar recepción con la aplicación abierta, en segundo plano y cerrada.
5. Registrar métricas mínimas: duración de ronda, número de capturas válidas y estado de entrega.

## Orden recomendado

1. Persistencia e historial de rondas.
2. Planificador y clasificación por voto mayoritario.
3. Registro de dispositivos y preferencias.
4. Integración FCM en backend.
5. Integración Android y navegación profunda.
6. Pruebas de extremo a extremo con hardware real.
