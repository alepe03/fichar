# 🚀 INSTRUCCIONES DE DESPLIEGUE - Fichar Trivalle Web

## 📋 Archivos Preparados

✅ **Build optimizado**: `build/web/`  
✅ **Archivo ZIP**: `build/fichar_web_deploy.zip` (9.9 MB)  
✅ **Archivo de test**: `test_api.html`  
✅ **Configuración servidor**: `.htaccess`  

## 🌐 PASO 1: Acceder a tu Hosting

### **Opción A: Panel de Control (cPanel, Plesk, etc.)**
1. Accede al panel de control de tu hosting
2. Busca **"Administrador de archivos"** o **"File Manager"**
3. Navega a la carpeta raíz de tu sitio web (normalmente `public_html/` o `www/`)

### **Opción B: FTP/SFTP**
1. Usa un cliente FTP como **FileZilla** o **Cyberduck**
2. Conecta a tu servidor con:
   - **Host**: tu-dominio.com
   - **Usuario**: tu-usuario-ftp
   - **Contraseña**: tu-contraseña-ftp
   - **Puerto**: 21 (FTP) o 22 (SFTP)

## 📤 PASO 2: Subir Archivos

### **Método 1: Subir ZIP y descomprimir**
1. **Sube** `fichar_web_deploy.zip` a la raíz de tu sitio
2. **Descomprime** el archivo ZIP
3. **Mueve** todo el contenido de la carpeta `web/` a la raíz

### **Método 2: Subir archivos individuales**
1. **Sube TODOS** los archivos de `build/web/` a la raíz de tu sitio
2. **Asegúrate** de que `.htaccess` esté en la raíz
3. **Verifica** que las carpetas `assets/`, `canvaskit/`, `icons/` se suban completas

## 🔧 PASO 3: Verificar Configuración

### **Archivos CRÍTICOS que deben estar en la raíz:**
```
✅ index.html
✅ main.dart.js
✅ flutter.js
✅ .htaccess
✅ manifest.json
✅ flutter_service_worker.js
✅ test_api.html
```

### **Carpetas que deben estar en la raíz:**
```
✅ assets/
✅ canvaskit/
✅ icons/
```

## 🌍 PASO 4: Configurar el Servidor

### **Para Apache (la mayoría de hostings):**
El archivo `.htaccess` ya está configurado y debería funcionar automáticamente.

### **Si tienes problemas con .htaccess:**
1. **Contacta a tu proveedor de hosting**
2. **Pide que habiliten**:
   - `mod_headers` (para CORS)
   - `mod_rewrite` (para SPA routing)
   - `mod_expires` (para caché)

### **Para Nginx:**
```nginx
location / {
    try_files $uri $uri/ /index.html;
}

# Headers CORS
add_header Access-Control-Allow-Origin *;
add_header Access-Control-Allow-Methods "GET, POST, OPTIONS";
add_header Access-Control-Allow-Headers "Content-Type, Authorization";
```

## 🧪 PASO 5: Probar la Aplicación

### **1. Abrir tu sitio web**
- Ve a tu dominio: `https://tu-dominio.com`
- La aplicación debería cargar automáticamente

### **2. Si hay errores, usar el archivo de test**
- Abre: `https://tu-dominio.com/test_api.html`
- Ejecuta todos los tests
- Verifica que la API responda correctamente

### **3. Abrir DevTools (F12)**
- Ve a la pestaña **Console**
- Busca errores en rojo
- Ve a la pestaña **Network** para ver peticiones HTTP

## 🚨 SOLUCIÓN DE PROBLEMAS

### **Error 1: Página en blanco**
**Solución**: Verificar que todos los archivos se subieron correctamente

### **Error 2: CORS Policy**
**Solución**: Verificar que `.htaccess` esté en la raíz y que el hosting soporte mod_headers

### **Error 3: 404 en rutas**
**Solución**: Verificar que mod_rewrite esté habilitado

### **Error 4: Archivos no cargan**
**Solución**: Verificar permisos (644 para archivos, 755 para carpetas)

## 📱 PASO 6: Verificar PWA

### **1. Instalar como app**
- En móvil: "Añadir a pantalla de inicio"
- En desktop: "Instalar aplicación"

### **2. Verificar funcionamiento offline**
- La app debería funcionar sin conexión
- Los datos se sincronizan cuando vuelve la conexión

## 🔍 DIAGNÓSTICO FINAL

### **Si todo funciona:**
🎉 **¡PROBLEMA RESUELTO!** Tu aplicación web funciona perfectamente

### **Si hay errores:**
1. **Comparte el error específico** de la consola del navegador
2. **Ejecuta test_api.html** y comparte los resultados
3. **Verifica la configuración** del hosting

## 📞 SOPORTE

### **Archivos de ayuda incluidos:**
- `web_server_config.md` - Configuración detallada del servidor
- `DEPLOY_INFO.txt` - Información del build
- `test_api.html` - Diagnóstico de la API

### **Comandos útiles para verificar:**
```bash
# Verificar que la API responde
curl "https://www.trivalle.com/apiFichar/trvFichar.php?Code=0"

# Verificar headers CORS
curl -I "https://www.trivalle.com/apiFichar/trvFichar.php"
```

---

## 🎯 RESUMEN DE PASOS

1. **📤 Subir archivos** de `build/web/` a tu servidor
2. **🔧 Verificar** que `.htaccess` esté en la raíz
3. **🌐 Probar** la aplicación en tu dominio
4. **🧪 Usar** `test_api.html` si hay problemas
5. **📱 Verificar** funcionamiento PWA

**¡Tu API está perfecta y Flutter web está optimizado! Solo falta subir los archivos.** 🚀
