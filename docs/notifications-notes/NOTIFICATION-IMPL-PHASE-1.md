# Fase 1 — Notificaciones Android (FCM)

## Estado actual

- Firebase Android está configurado para `com.antonionatusch.flutter_ia_edge`.
- La app solicita permiso, obtiene el token FCM y registra sus renovaciones.
- El backend guarda instalaciones y tokens en SQLite e inicializa Firebase Admin.
- Todavía no se ejecutan rondas, no se guardan resultados y no se envían mensajes.

## Prerrequisitos

- Cuenta de Google activa.
- Acceso al repositorio y al servidor Ubuntu donde corre el backend.
- Android Studio o VS Code con Flutter instalado.
- Dispositivo Android de prueba o emulador con Google Play Services.

## 1. Configurar Firebase Console

### 1.1 Crear el proyecto Firebase

1. Abrir [console.firebase.google.com](https://console.firebase.google.com).
2. Clic en **Crear proyecto**.
3. Nombre del proyecto: `ia-edge-pet-feeder` (o el que prefieras).
4. Desactivar Google Analytics si no lo necesitas (opcional).
5. Esperar a que se cree el proyecto.

### 1.2 Registrar la app Android

1. Dentro del proyecto Firebase, clic en el ícono de Android.
2. **Nombre de paquete Android**: `com.antonionatusch.flutter_ia_edge`
   - Verificar el package name real en `android/app/build.gradle` dentro de `namespace` o en `AndroidManifest.xml`.
3. **Nombre de la app**: `IA Edge Pet Feeder`.
4. **SHA-1** (opcional para FCM, necesario para Dynamic Links): ejecutar:
   ```bash
   keytool -list -v -alias androiddebugkey -keystore ~/.android/debug.keystore -storepass android
   ```
5. Clic en **Registrar app**.

### 1.3 Descargar google-services.json

1. Después de registrar, Firebase ofrece descargar `google-services.json`.
2. Guardarlo en: `flutter-ia-edge/android/app/google-services.json`.
3. El proyecto lo excluye mediante `.gitignore`.

### 1.4 Activar Cloud Messaging

1. En Firebase Console, ir a **Project Settings** → **Cloud Messaging**.
2. Verificar que la API de Cloud Messaging esté habilitada.
3. El backend usa la API HTTP v1 mediante Firebase Admin; no necesita una Server Key legacy.

---

## 2. Configurar el proyecto Android para Firebase

### 2.1 Plugin Google Services

El proyecto usa Kotlin DSL. `android/app/build.gradle.kts` aplica:

```kotlin
plugins {
    id("com.google.gms.google-services")
}
```

No agregar manualmente Firebase BoM ni dependencias nativas como
`firebase-analytics`. Los plugins FlutterFire resuelven versiones nativas
compatibles; el BoM manual provocó un conflicto en `FirebaseOptions`.

### 2.3 Verificar google-services.json

El archivo debe contener:
- `project_number`: número del proyecto Firebase (se usa como sender ID).
- `project_id`: ID del proyecto Firebase.
- `package_name`: debe coincidir con el package name de tu app.

---

## 3. Integrar Firebase en Flutter

### 3.1 Agregar dependencias en pubspec.yaml

```yaml
dependencies:
  firebase_core: ^4.12.1
  firebase_messaging: ^16.4.3
  logger: ^2.7.0
```

Ejecutar:
```bash
flutter pub get
```

### 3.2 Inicializar Firebase en main.dart

```dart
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const FeederApp());
}
```

### 3.3 Solicitar permisos y obtener token FCM

```dart
final messaging = FirebaseMessaging.instance;

// Solicitar permiso (Android 13+)
final settings = await messaging.requestPermission(
  alert: true,
  badge: true,
  sound: true,
);

// Obtener token FCM
final token = await messaging.getToken();

// Escuchar actualizaciones del token
messaging.onTokenRefresh.listen(registerTokenInBackend);
```

La implementación real está en
`lib/services/notification_registration_service.dart`. Genera una
`installation_id` persistente para reemplazar el token anterior cuando FCM lo
renueva, sin registrar duplicados.

### 3.4 Manejar mensajes recibidos (pendiente)

```dart
// Primer plano
FirebaseMessaging.onMessage.listen((RemoteMessage message) {
  // Actualizar la interfaz cuando la app esté abierta.
});

// Segundo plano / app abierta
FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
  // Navegar al detalle de la ronda
});
```

---

## 4. Backend — Firebase Admin SDK (Python)

### 4.1 Instalar firebase-admin

```bash
pip install firebase-admin
```

Agregar a `requirements.txt`:
```
firebase-admin>=6.5.0
```

### 4.2 Configurar credenciales

1. Descargar la clave de servicio JSON desde Firebase Console → Project Settings → Service Accounts.
2. Guardarla fuera del repositorio, por ejemplo en el servidor como
   `/opt/pet-feeder/secrets/firebase.json`.
3. En `.env` usado por Docker Compose:
   ```
   FIREBASE_CREDENTIALS_HOST_PATH=/opt/pet-feeder/secrets/firebase.json
   ```

Compose la monta como `/run/secrets/firebase.json` de solo lectura. Nunca se
copia dentro de la imagen Docker.

### 4.3 Inicializar Firebase Admin

```python
import firebase_admin
from firebase_admin import credentials, messaging

cred = credentials.Certificate(os.getenv("FIREBASE_CREDENTIALS_PATH"))
firebase_admin.initialize_app(cred)
```

El backend encapsula este patrón oficial en `app/firebase_service.py` y usa un
nombre de app fijo para impedir inicializaciones duplicadas.

### 4.4 Enviar notificación

```python
def send_notification(token: str, title: str, body: str, data: dict = None):
    message = messaging.Message(
        notification=messaging.Notification(
            title=title,
            body=body,
        ),
        data=data or {},
        token=token,
    )
    response = messaging.send(message)
    return response
```

### 4.5 Registrar dispositivos (endpoint)

```python
@app.post("/api/v1/notifications/devices")
async def register_device(request: Request, db: Session = Depends(get_db)):
    body = await request.json()
    token = body.get("fcm_token")
    device_name = body.get("device_name", "unknown")
    
    # Guardar o actualizar token en BD
    device = db.query(Device).filter_by(fcm_token=token).first()
    if not device:
        device = Device(fcm_token=token, device_name=device_name)
        db.add(device)
    else:
        device.device_name = device_name
    db.commit()
    return {"status": "ok", "device_id": device.id}
```

---

## 5. Flujo completo de una ronda

1. El cron del backend detecta que es hora de una ronda (ej. 08:59:30).
2. Verifica que `relay_enabled == true` y `mode != 'manual_off'`.
3. Espera a que el maestro encienda la cámara (polling a `/master/status`).
4. Ejecuta 5 capturas + clasificaciones via `/camera/capture-classify`.
5. Calcula el voto mayoritario.
6. Guarda el resultado en SQLite.
7. Envía notificación FCM a todos los dispositivos registrados si el resultado es relevante.

---

## 6. Estructura de la base de datos SQLite

```sql
CREATE TABLE notification_devices (
    installation_id TEXT PRIMARY KEY,
    fcm_token TEXT UNIQUE NOT NULL,
    device_name TEXT,
    platform TEXT NOT NULL,
    enabled INTEGER NOT NULL DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE rounds (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    scheduled_at TIMESTAMP NOT NULL,
    completed_at TIMESTAMP,
    status TEXT DEFAULT 'pending',  -- pending, running, completed, failed
    result TEXT,                     -- empty, food_available, unknown
    votes_json TEXT,                 -- JSON con los 5 votos
    error_message TEXT
);

CREATE TABLE notifications (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    round_id INTEGER REFERENCES rounds(id),
    device_id INTEGER REFERENCES devices(id),
    sent_at TIMESTAMP,
    status TEXT,  -- sent, failed, delivered
    error TEXT
);

CREATE TABLE preferences (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    device_id INTEGER REFERENCES devices(id),
    notify_empty BOOLEAN DEFAULT 1,
    notify_food BOOLEAN DEFAULT 0,
    notify_unknown BOOLEAN DEFAULT 1
);
```

---

## 7. Pasos de implementación ordenados

| Paso | Descripción | Dependencia |
|------|-------------|-------------|
| 1 | Crear proyecto Firebase + registrar app Android (completado) | Ninguna |
| 2 | Descargar `google-services.json` al proyecto Flutter (completado) | Paso 1 |
| 3 | Configurar plugin Google Services (completado) | Paso 2 |
| 4 | Integrar `firebase_core` y `firebase_messaging` (completado) | Paso 3 |
| 5 | Solicitar permisos, registrar token y renovaciones (completado) | Paso 4 |
| 6 | Crear persistencia SQLite de dispositivos (completado) | Ninguna |
| 7 | Implementar endpoint de registro de dispositivos (completado) | Paso 6 |
| 8 | Configurar Firebase Admin SDK (código completado; falta desplegar la clave) | Paso 1 |
| 9 | Implementar envío de notificaciones | Paso 7 + 8 |
| 10 | Implementar planificador de rondas con APScheduler | Paso 6 |
| 11 | Probar flujo completo end-to-end | Todos |

---

## 8. Notas importantes

- `google-services.json` identifica la app Firebase y está excluido del repositorio en este proyecto.
- **serviceAccountKey.json** permite enviar notificaciones en tu nombre. Guardarla fuera del repositorio y montarla en el contenedor como archivo de solo lectura; nunca incorporarla a la imagen.
- **FCM V1 API** es el estándar actual; evitar usar la API legacy.
- **Tokens FCM** pueden expirar o cambiarse; el backend debe detectar tokens inválidos y eliminarlos.
- **Android 13+** requiere permiso explícito de notificaciones (`POST_NOTIFICATIONS`).
- **Notificaciones en primer plano** no se muestran como alerta del sistema automáticamente. Por ahora se actualizará la interfaz directamente, sin `flutter_local_notifications`.
