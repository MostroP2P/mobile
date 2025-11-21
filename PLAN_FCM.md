Plan de Implementación: Firebase Cloud Messaging (FCM)
Objetivo
Implementar notificaciones push cuando la app está completamente cerrada usando Firebase Cloud Messaging, manteniendo la privacidad y seguridad del sistema actual.
Arquitectura Propuesta
1. Modelo de Seguridad
FCM Payload: Solo event_id + recipient_pubkey (datos públicos)
Decryption: Siempre en el dispositivo usando trade keys
Privacy: Nunca enviar contenido sensible vía FCM
2. Flujo de Notificaciones
Mostro publica evento → Backend detecta → Envía FCM minimal payload →
Dispositivo recibe → Carga sesión desde Sembast → Fetch evento desde relay →
Decrypta con trade key → Muestra notificación local
Fases de Implementación
Fase 1: Configuración Firebase (Requiere acceso a Firebase Console)
Crear proyecto Firebase (o usar existente)
Agregar app Android (network.mostro.app)
Agregar app iOS (bundle ID desde Xcode)
Descargar configuraciones:
google-services.json → /android/app/
GoogleService-Info.plist → /ios/Runner/
Configurar APNs para iOS (certificado/key)
Fase 2: Dependencias y Configuración Flutter
Agregar a pubspec.yaml:
firebase_core: ^3.8.0
firebase_messaging: ^15.1.4
Actualizar /android/build.gradle (agregar google-services plugin)
Actualizar /android/app/build.gradle (aplicar plugin, agregar dependencies)
Actualizar /ios/Podfile si es necesario
Fase 3: Servicio FCM
Crear /lib/services/fcm_service.dart:
Inicializar Firebase
Solicitar permisos de notificación
Obtener y almacenar FCM token
Manejar refresh de token
Handler para foreground messages
Crear top-level function firebaseMessagingBackgroundHandler en main.dart:
Cargar Sembast database
Buscar sesión por recipient_pubkey
Fetch evento desde relay usando event_id
Decryptar con trade key de sesión
Mostrar notificación local usando BackgroundNotificationService
Fase 4: Integración con App
Modificar main.dart:
Inicializar Firebase antes de runApp
Registrar background handler
Inicializar FCM service
Modificar appInitializerProvider:
Agregar inicialización de FCM
Solicitar permisos de notificación
Obtener token inicial
Modificar BackgroundNotificationService:
Agregar deduplicación con EventStorage
Mejorar navigation payload para tap actions
Unificar handlers (background service vs FCM)
Fase 5: Token Management
Crear storage para FCM token en SharedPreferences
Implementar listener de token refresh
Enviar token a backend Mostro (si hay endpoint disponible)
Manejar casos de token inválido/expirado
Fase 6: Testing y Validación
Test con Firebase Console (envío manual)
Test app terminada (killed)
Test app en background
Test app en foreground
Test tap en notificación
Test múltiples sesiones activas
Verificar no duplicación de notificaciones
Archivos a Crear/Modificar
Crear:
/lib/services/fcm_service.dart - Servicio principal FCM
/android/app/google-services.json - Config Firebase Android
/ios/Runner/GoogleService-Info.plist - Config Firebase iOS
Modificar:
pubspec.yaml - Agregar dependencias Firebase
/android/build.gradle - Plugin google-services
/android/app/build.gradle - Aplicar plugin, dependencies
lib/main.dart - Inicializar Firebase, background handler
lib/shared/providers/app_init_provider.dart - Init FCM
lib/features/notifications/services/background_notification_service.dart - Mejorar handlers
Consideraciones Importantes
Backend/Server Required
⚠️ CRÍTICO: Necesitas un backend que:
Escuche eventos Mostro en relays
Detecte eventos tipo 1059 (gift-wrapped)
Envíe payload FCM minimal a dispositivos registrados
Mapee recipient_pubkey → FCM tokens
Eventos Prioritarios para Notificaciones
Alta prioridad: buyerTookOrder, payInvoice, addInvoice, canceled, disputeInitiatedByPeer Media prioridad: holdInvoicePaymentAccepted, fiatSentOk, released, purchaseCompleted
Deduplicación
Usar EventStorage existente para evitar duplicados
Coordinar con background service actual
FCM solo para app terminada, background service para backgrounded
Privacy & Security
✅ Solo datos públicos en FCM payload
✅ Decryption siempre local
✅ Trade keys nunca salen del dispositivo
❌ Nunca incluir amounts, nombres, direcciones en FCM
Preguntas Clave
Antes de implementar, necesito saber:
¿Tienes acceso a Firebase Console para crear el proyecto?
¿Existe un backend/server que pueda enviar mensajes FCM? Si no existe, habría que implementarlo
¿El backend Mostro está bajo tu control o es de terceros?
¿Prefieres que el token FCM se envíe a un backend tuyo o directamente al Mostro instance?
¿Quieres implementar Firebase Analytics/Crashlytics también, o solo FCM?
Estimación
Con backend existente: 2-3 días de desarrollo + 1 día testing
Sin backend: +3-5 días para backend FCM relay listener
Complejidad: Media-Alta (manejo de isolates, crypto en background)