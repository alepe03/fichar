# Configuración de Google Maps API

## 🗺️ **Configuración Requerida para Google Maps**

Para usar Google Maps en lugar de OpenStreetMap, necesitas configurar las claves API de Google.

### 📱 **Android (AndroidManifest.xml)**

1. **Obtener API Key:**
   - Ve a [Google Cloud Console](https://console.cloud.google.com/)
   - Crea un nuevo proyecto o selecciona uno existente
   - Habilita la API de Maps SDK for Android
   - Crea credenciales (API Key)

2. **Configurar en AndroidManifest.xml:**
   ```xml
   <meta-data
       android:name="com.google.android.geo.API_KEY"
       android:value="TU_API_KEY_AQUI" />
   ```

### 🍎 **iOS (Info.plist)**

1. **Obtener API Key:**
   - En el mismo proyecto de Google Cloud Console
   - Habilita la API de Maps SDK for iOS
   - Usa la misma API Key o crea una específica para iOS

2. **Configurar en Info.plist:**
   ```xml
   <key>GMSApiKey</key>
   <string>TU_API_KEY_AQUI</string>
   ```

### 🌐 **Web (index.html)**

1. **Obtener API Key:**
   - Habilita la API de Maps JavaScript API
   - Usa la misma API Key

2. **Configurar en web/index.html:**
   ```html
   <script src="https://maps.googleapis.com/maps/api/js?key=TU_API_KEY_AQUI"></script>
   ```

## 🔑 **Pasos para Obtener API Key**

### 1. **Crear Proyecto en Google Cloud Console**
- Ve a [console.cloud.google.com](https://console.cloud.google.com/)
- Crea un nuevo proyecto o selecciona uno existente

### 2. **Habilitar APIs**
- Maps SDK for Android
- Maps SDK for iOS  
- Maps JavaScript API (para web)

### 3. **Crear Credenciales**
- Ve a "APIs & Services" > "Credentials"
- Crea una nueva API Key
- Restringe la key por plataforma y aplicación

### 4. **Configurar Restricciones (Recomendado)**
- Restringe por aplicación Android (SHA-1 fingerprint)
- Restringe por bundle ID de iOS
- Restringe por dominio para web

## 💰 **Costos y Límites**

### **Precios (2024):**
- **$200 USD de crédito gratuito** mensual
- **$7 USD por cada 1000 cargas de mapa** después del crédito gratuito
- **Uso típico de app personal**: Gratis (dentro del crédito mensual)

### **Límites del Crédito Gratuito:**
- ~28,500 cargas de mapa por mes
- Suficiente para uso personal y pequeñas empresas

## ⚠️ **Importante**

1. **Nunca subas las claves API al repositorio público**
2. **Usa variables de entorno o archivos de configuración locales**
3. **Restringe las claves por aplicación y plataforma**
4. **Monitorea el uso en Google Cloud Console**

## 🚀 **Alternativa: Usar OpenStreetMap**

Si prefieres no configurar Google Maps, puedes mantener la implementación anterior con OpenStreetMap:

```yaml
# En pubspec.yaml
dependencies:
  flutter_map: ^6.1.0
  latlong2: ^0.9.0
```

**Ventajas de OpenStreetMap:**
- ✅ Completamente gratuito
- ✅ Sin límites de API
- ✅ Sin necesidad de claves
- ✅ Funciona offline

**Desventajas:**
- ❌ Menos detalle en algunas áreas
- ❌ Interfaz menos familiar
- ❌ Sin funcionalidades avanzadas (Street View, tráfico)

## 📋 **Resumen de Configuración**

| Plataforma | Archivo | Clave |
|------------|---------|-------|
| Android | `android/app/src/main/AndroidManifest.xml` | `com.google.android.geo.API_KEY` |
| iOS | `ios/Runner/Info.plist` | `GMSApiKey` |
| Web | `web/index.html` | `<script src="...key=...">` |

## 🔧 **Solución de Problemas**

### **Error: "Maps API key not found"**
- Verifica que la clave esté en el archivo correcto
- Asegúrate de que la API esté habilitada
- Revisa las restricciones de la clave

### **Error: "This app is not authorized to use this API key"**
- Verifica las restricciones de la clave
- Asegúrate de que el SHA-1 fingerprint sea correcto
- Verifica el bundle ID de iOS

### **Mapa no se muestra**
- Verifica la conexión a internet
- Revisa los logs de la consola
- Verifica que las coordenadas sean válidas
