# Session Deletion Management Issue & Solutions

## Problem Description

Hola equipo,

Tenemos un problema de UX con la eliminación automática de sesiones que está afectando la experiencia del usuario. Actualmente, la app elimina automáticamente las sesiones de trading después de 36 horas sin notificar al usuario ni darle control. Los usuarios están perdiendo su historial de órdenes inesperadamente y se frustran porque no pueden revisar sus trades pasados.

Sin embargo, no podemos simplemente eliminar este mecanismo de limpieza. Sin eliminación automática, tendríamos problemas serios: el rendimiento de la app se degradaría con miles de sesiones acumuladas, el consumo de memoria se dispararía causando crashes en dispositivos limitados, datos sensibles (claves, info de contrapartes) se almacenarían indefinidamente creando riesgos de seguridad, la base de datos crecería descontroladamente haciendo las consultas lentas, y la UI se saturaría con órdenes irrelevantes de meses/años atrás volviendo la app esencialmente inutilizable.

He identificado tres soluciones posibles:

Primero, control basado en tiempo donde los usuarios eligen el período de retención (7 días, 1 mes, 6 meses, nunca). Esto es intuitivo y predecible pero riesgoso si los usuarios eligen "nunca" o períodos muy largos.

Segundo, control basado en número donde los usuarios establecen máximo de órdenes a mantener (50, 200, 500 órdenes). Esto da rendimiento predecible pero es menos intuitivo y la pérdida temporal es impredecible.

Tercero, un sistema híbrido combinando ambos con presets inteligentes como "Básico: 1 mes O 50 órdenes", "Estándar: 3 meses O 200 órdenes", "Extendido: 6 meses O 500 órdenes". Esto protege el rendimiento siendo flexible y fácil de usar, con presets que previenen configuraciones extremas.

Recomiendo el enfoque híbrido ya que balancea UX, rendimiento y control del usuario. ¿Qué opinan?

---

## Análisis Completo: Eliminación de Sesiones (No es 72 horas)

### Hallazgo Principal: NO hay eliminación a las 72 horas

La expiración de sesiones es de **36 horas**, no 72 horas.

### Configuración Real

**Archivo:** `lib/core/config.dart`
```dart
static const int sessionExpirationHours = 36;  // 36 horas, NO 72
static const int cleanupIntervalMinutes = 30;   // Limpieza cada 30 minutos
```

### Implementación Principal

**Archivo:** `lib/shared/notifiers/session_notifier.dart`

#### A. Limpieza en Inicio de App (líneas 38-52)
- Se ejecuta al arrancar la app
- Elimina inmediatamente sesiones expiradas (>36 horas)
- Mantiene solo sesiones activas

#### B. Limpieza Periódica (líneas 62-86)
- Timer que se ejecuta **cada 30 minutos**
- Busca sesiones creadas hace más de 36 horas
- Las elimina de memoria y base de datos

### Cómo Funciona

#### Triggers
1. **Inicio de app:** Limpieza inmediata
2. **Timer periódico:** Cada 30 minutos
3. **Timeouts en tiempo real:** Elimina sesiones de takers que no responden
4. **Prevención de huérfanos:** Timer de 10 segundos para crear órdenes

#### Qué se elimina
- Sesiones con `startTime` anterior a 36 horas
- Sesiones pendientes (`_pendingChildSessions`)
- Datos asociados en base de datos Sembast

### Archivos Clave

| Archivo | Función |
|---------|---------|
| `session_notifier.dart` | Lógica principal de limpieza |
| `config.dart` | Configuración (36 horas) |
| `session_storage.dart` | Interfaz de base de datos |
| `order_notifier.dart` | Detección de timeouts |
| `abstract_mostro_notifier.dart` | Prevención de huérfanos |

### Servicios Background

Los servicios en `background/` **NO** hacen limpieza de sesiones. Solo manejan notificaciones Nostr.

### Discrepancia

- **Documentación dice:** 72 horas
- **Código implementa:** 36 horas

La documentación está desactualizada respecto al código real.

---

## Propósito de la Eliminación de Sesiones

La eliminación de sesiones después de 36 horas tiene varios propósitos críticos:

### 1. Gestión de Memoria y Performance
- **Problema sin limpieza:** Las sesiones se acumulan infinitamente en memoria
- **Impacto:** La app se volvería más lenta y consumiría más RAM con el tiempo
- **Solución:** Limitar sesiones activas evita memory leaks y mantiene performance

### 2. Seguridad y Privacidad
- **Problema sin limpieza:** Claves criptográficas y datos sensibles permanecen en dispositivo indefinidamente
- **Riesgo:** Si el dispositivo es comprometido, atacantes accederían a historial completo de trading
- **Solución:** Limitar retención reduce superficie de ataque

### 3. Relevancia de Datos
- **Problema sin limpieza:** UI muestra órdenes muy antiguas mezcladas con actuales
- **Experiencia:** Usuario ve cientos/miles de trades antiguos irrelevantes
- **Solución:** Solo mostrar trades recientes mejora UX

### 4. Gestión de Estado de Trading

Cada sesión mantiene:
```dart
class Session {
  final String orderId;
  final Role role;           // buyer/seller
  final DateTime startTime;
  final Peer? peer;         // información del contraparte
  final String? sharedKey;  // clave para chat encriptado
}
```

**Sin limpieza:**
- Información de contrapartes se mantiene para siempre
- Estados de órdenes viejas interfieren con lógica nueva
- Claves de chat antigas quedan expuestas

### 5. ¿Qué Pasaría Sin Eliminación?

#### Inmediato (días/semanas)
- App funciona normal
- Memoria aumenta gradualmente
- Base de datos crece

#### Mediano plazo (meses)
- **Performance degradada:** App más lenta al buscar sesiones
- **UI confusa:** Mezcla trades actuales con antiguos 
- **Memoria alta:** Más consumo de RAM
- **Seguridad comprometida:** Más datos sensibles expuestos

#### Largo plazo (años)
- **App inutilizable:** Miles de sesiones antiguas
- **Crash por memoria:** OutOfMemory en dispositivos limitados
- **Base de datos gigante:** Backups y sincronización imposibles
- **Violación de privacidad:** Historial completo almacenado indefinidamente

---

## Opciones para Mantener Historial sin Degradar Performance

### Opción 1: Sistema de Archivado Automático

**Concepto:** Mover sesiones antiguas a un almacén separado después de 36 horas

**Pros:**
- ✅ Performance mantiene igual (consultas rápidas en active_sessions)
- ✅ Historial completo disponible bajo demanda
- ✅ Datos sensibles se pueden limpiar del archivo
- ✅ Fácil de implementar sobre sistema actual

**Contras:**
- ❌ Duplica complejidad del storage
- ❌ Base de datos sigue creciendo (más lento)
- ❌ Necesita UI adicional para historial

### Opción 2: Paginación con Límite Configurable

**Concepto:** Usuario configura cuántas órdenes mantener visibles (ej: 50, 100, 500)

**Pros:**
- ✅ Usuario controla su storage
- ✅ Performance predecible
- ✅ Simple de implementar
- ✅ Buena UX (configuración clara)

**Contras:**
- ❌ Pierde historial antiguo automáticamente
- ❌ Usuarios poder configurar mal (muy alto)
- ❌ No resuelve completamente el problema

### Opción 3: Limpieza Selectiva de Datos Sensibles

**Concepto:** Mantener sesiones pero limpiar datos pesados/sensibles

**Pros:**
- ✅ Historial visual completo
- ✅ Elimina datos sensibles automáticamente
- ✅ Reduce tamaño por sesión significativamente
- ✅ Performance mejor que mantener todo

**Contras:**
- ❌ Pierde funcionalidad (no puede contactar peer antiguo)
- ❌ Sigue creciendo base de datos
- ❌ Complejidad en migration de datos

### Opción 4: Export/Import de Historial

**Concepto:** Eliminar después de 36 horas pero permitir export/import

**Pros:**
- ✅ Performance óptima (sin degradación)
- ✅ Usuario mantiene control total
- ✅ No afecta funcionalidad core
- ✅ Backup portable entre dispositivos

**Contras:**
- ❌ UX complicada (export/import manual)
- ❌ Datos no están "siempre disponibles"
- ❌ Usuario puede perder exports

### Opción 5: Lazy Loading con Cache Inteligente

**Concepto:** Mantener todo en DB pero cargar solo lo necesario en memoria

**Pros:**
- ✅ Performance inicial excelente
- ✅ Historial completo disponible
- ✅ Escala bien con grandes volúmenes
- ✅ UX familiar (como redes sociales)

**Contras:**
- ❌ Complejidad alta en implementación
- ❌ Base de datos sigue creciendo
- ❌ Queries complejas para búsqueda

### Opción 6: Sistema Híbrido con Niveles

**Concepto:** Múltiples niveles de retención según importancia

**Pros:**
- ✅ Balance perfecto entre performance y retención
- ✅ Degradación gradual de datos
- ✅ Flexible y configurable
- ✅ Buena UX progresiva

**Contras:**
- ❌ Complejidad muy alta
- ❌ Múltiples sistemas de storage
- ❌ Difícil de testear y mantener

### Opción 7: Storage Externo Opcional

**Concepto:** Integración con cloud storage del usuario (Google Drive, iCloud)

**Pros:**
- ✅ Performance local óptima
- ✅ Historial "infinito" disponible
- ✅ Usuario controla sus datos
- ✅ Backup automático

**Contras:**
- ❌ Requiere permisos cloud
- ❌ Dependencia de conectividad
- ❌ Complejidad de implementación alta
- ❌ Problemas de privacidad potenciales

---

## Análisis: Control de Usuario - Tiempo vs Número de Órdenes

### Opción A: Control por Tiempo (Usuario elige días)

**Configuración típica:**
- "Eliminar sesiones después de: [1 día / 3 días / 1 semana / 1 mes / 3 meses / Nunca]"
- O slider: "Mantener historial por X días"

#### Pros del Control por Tiempo
✅ **Intuitivo:** Los usuarios entienden "mantener por 30 días"  
✅ **Predecible:** Usuario sabe exactamente cuándo se eliminará  
✅ **Flexible:** Puede ajustar según sus necesidades (trader frecuente vs ocasional)  
✅ **Alineado con privacidad:** Tiempo límite claro para datos sensibles  
✅ **Fácil implementación:** Solo cambiar `Config.sessionExpirationHours`  

#### Contras del Control por Tiempo
❌ **Performance impredecible:** Usuario pesado con "nunca" = miles de sesiones  
❌ **Riesgo de configuración extrema:** 1000 días o "nunca"  
❌ **No considera frecuencia de uso:** Trader activo vs inactivo  

### Opción B: Control por Número de Órdenes

**Configuración típica:**
- "Mantener últimas [50 / 100 / 500 / 1000] órdenes"
- O "Mantener últimas X órdenes"

#### Pros del Control por Número
✅ **Performance predecible:** Siempre X sesiones máximo  
✅ **Escalabilidad:** No importa si usuario es muy activo  
✅ **Mejor para traders frecuentes:** Mantiene las más relevantes  
✅ **Control de storage:** Usuario conoce impacto en memoria  

#### Contras del Control por Número
❌ **Menos intuitivo:** ¿Qué son "100 órdenes"?  
❌ **Pérdida impredecible:** Usuario no sabe cuándo se eliminará orden específica  
❌ **No considera importancia temporal:** Orden de ayer vs hace 6 meses  

### Análisis de Casos de Uso Reales

#### Trader Ocasional (1-2 órdenes/mes)
- **Por tiempo:** "6 meses" = 6-12 órdenes total ✅
- **Por número:** "100 órdenes" = 4+ años de historial ✅
- **Ganador:** Tiempo (más relevante)

#### Trader Activo (10+ órdenes/día)
- **Por tiempo:** "1 mes" = 300+ órdenes (performance issue) ❌
- **Por número:** "500 órdenes" = ~50 días de historial ✅
- **Ganador:** Número (performance predecible)

#### Usuario Preocupado por Privacidad
- **Por tiempo:** "3 días" = límite temporal claro ✅
- **Por número:** "50 órdenes" = timeframe impredecible ❌
- **Ganador:** Tiempo (control temporal directo)

### Benchmarks de Performance

#### Carga de Base de Datos por Escenario

| Configuración | Trader Ocasional | Trader Activo | Trader Pro |
|---------------|------------------|---------------|------------|
| 30 días | 2 sesiones | 300 sesiones | 1000+ sesiones |
| 90 días | 6 sesiones | 900 sesiones | 3000+ sesiones |
| 100 órdenes | 100 sesiones | 100 sesiones | 100 sesiones |
| 500 órdenes | 500 sesiones | 500 sesiones | 500 sesiones |

**Conclusión:** Número de órdenes es más predecible para performance.

### Problemas Potenciales

#### Con Control por Tiempo

**Configuración Extrema:**
```
Usuario selecciona "Nunca eliminar"
→ Después de 1 año: 10,000+ sesiones
→ App se vuelve inutilizable
→ Usuario no entiende por qué app está lenta
```

**Trader Muy Activo:**
```
Usuario activo selecciona "6 meses"
→ 50 órdenes/día × 180 días = 9,000 sesiones
→ Performance degradada severamente
```

#### Con Control por Número

**Pérdida Inesperada:**
```
Usuario casual configura "20 órdenes"
→ Hace 25 órdenes en 2 años
→ Pierde historial de primer año sin darse cuenta
```

## Recomendación: Sistema Híbrido

### Opción Híbrida Inteligente

**Configuración combinada:**
- "Mantener por [tiempo] O hasta [número] órdenes, lo que ocurra primero"
- Presets inteligentes:
  - **Casual:** "6 meses O 100 órdenes"
  - **Activo:** "3 meses O 500 órdenes"  
  - **Privacidad:** "1 semana O 50 órdenes"
  - **Ilimitado:** "Sin límite" (con advertencia)

### Beneficios del Híbrido
✅ **Performance protegida:** Número máximo previene degradación  
✅ **Privacidad temporal:** Límite de tiempo para datos sensibles  
✅ **Flexibilidad:** Usuario elige según patrón de uso  
✅ **UX intuitiva:** Presets evitan configuración compleja  

### Implementación Sugerida

```dart
class SessionRetentionConfig {
  final int? maxDays;        // null = sin límite temporal
  final int? maxSessions;    // null = sin límite numérico  
  final bool enabled;        // false = nunca eliminar
}

// Presets
static final casual = SessionRetentionConfig(
  maxDays: 180,     // 6 meses
  maxSessions: 100,
  enabled: true,
);
```

### UI Sugerida
```
Mantener historial de órdenes:
○ Básico (1 mes o 50 órdenes)
○ Estándar (3 meses o 200 órdenes) ← Default
○ Extendido (6 meses o 500 órdenes)  
○ Personalizado [___días] [___órdenes]
○ Sin límite (no recomendado)
```

## Veredicto Final

**Recomiendo el sistema híbrido** porque:

1. **Protege performance** (límite numérico)
2. **Respeta privacidad** (límite temporal)  
3. **Flexible para diferentes usuarios** (presets + custom)
4. **Evita configuraciones extremas** (defaults sensatos)
5. **Fácil de entender** (presets descriptivos)

**El control puro por tiempo es riesgoso** para performance a largo plazo, mientras que **control puro por número pierde el aspecto temporal** importante para privacidad y relevancia de datos.