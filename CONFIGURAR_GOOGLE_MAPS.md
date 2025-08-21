# 🗺️ Configurar Google Maps - Paso a Paso

## ⚡ **Configuración Rápida (5 minutos)**

### **Paso 1: Obtener API Key**
1. Ve a [Google Cloud Console](https://console.cloud.google.com/)
2. **Crea proyecto nuevo** o selecciona existente
3. **Habilita APIs:**
   - Maps SDK for Android
   - Maps SDK for iOS
4. **Crea credenciales** → API Key

### **Paso 2: Configurar Android**
Edita `android/app/src/main/AndroidManifest.xml`:
```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="TU_API_KEY_AQUI" />
```

### **Paso 3: Configurar iOS**
Edita `ios/Runner/Info.plist`:
```xml
<key>GMSApiKey</key>
<string>TU_API_KEY_AQUI</string>
```

## 🔑 **Obtener API Key Detallado**

### **1. Crear Proyecto**
- Ve a [console.cloud.google.com](https://console.cloud.google.com/)
- Clic en "Seleccionar proyecto" → "Nuevo proyecto"
- Nombre: "Fichar App" (o el que prefieras)
- Clic "Crear"

### **2. Habilitar APIs**
- En el menú lateral: "APIs y servicios" → "Biblioteca"
- Busca y habilita:
  - **Maps SDK for Android**
  - **Maps SDK for iOS**
  - **Maps JavaScript API** (para web)

### **3. Crear Credenciales**
- "APIs y servicios" → "Credenciales"
- Clic "Crear credenciales" → "Clave de API"
- Copia la clave generada

### **4. Restringir API Key (Opcional pero recomendado)**
- Clic en la clave creada
- En "Restricciones de aplicación":
  - **Android apps**: Agrega tu SHA-1 fingerprint
  - **iOS apps**: Agrega tu bundle ID
  - **Sitios web**: Agrega tu dominio

## 📱 **Configurar en tu App**

### **Android (AndroidManifest.xml)**
```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application>
        <!-- ... otras configuraciones ... -->
        
        <meta-data
            android:name="com.google.android.geo.API_KEY"
            android:value="TU_API_KEY_AQUI" />
    </application>
</manifest>
```

### **iOS (Info.plist)**
```xml
<dict>
    <!-- ... otras configuraciones ... -->
    
    <key>GMSApiKey</key>
    <string>TU_API_KEY_AQUI</string>
</dict>
```

## 🧪 **Probar la Configuración**

### **1. Reemplazar API Key**
- Cambia `TU_API_KEY_AQUI` por tu clave real
- Guarda los archivos

### **2. Compilar y Probar**
```bash
flutter clean
flutter pub get
flutter run
```

### **3. Probar Funcionalidad**
- Ve a la pestaña "Fichajes" del admin
- Haz clic en cualquier coordenada
- El mapa de Google Maps debería cargar correctamente

## 🚨 **Solución de Problemas**

### **Error: "Maps API key not found"**
- ✅ Verifica que la clave esté en AndroidManifest.xml
- ✅ Verifica que la clave esté en Info.plist
- ✅ Asegúrate de que las APIs estén habilitadas

### **Error: "This app is not authorized"**
- ✅ Verifica las restricciones de la API Key
- ✅ Asegúrate de que el SHA-1 fingerprint sea correcto
- ✅ Verifica el bundle ID de iOS

### **Pantalla congelada**
- ✅ Verifica que la API Key sea válida
- ✅ Verifica que las APIs estén habilitadas
- ✅ Revisa la consola para errores específicos

## 💰 **Costos**

- **$200 USD gratis** mensual (suficiente para uso personal)
- **$7 USD por 1000 cargas** después del límite gratuito
- **Uso típico**: Completamente gratis

## 📞 **Soporte**

Si tienes problemas:
1. Revisa los logs de la consola
2. Verifica que la API Key esté correctamente configurada
3. Asegúrate de que las APIs estén habilitadas
4. Verifica las restricciones de la clave

## 🎯 **Resultado Esperado**

Una vez configurado correctamente:
- ✅ Mapa de Google Maps se carga al instante
- ✅ Sin pantalla congelada
- ✅ Funcionalidades completas: zoom, marcadores, navegación
- ✅ Experiencia nativa y familiar para los usuarios
