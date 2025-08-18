# 🚀 Configuración del Servidor Web para Fichar Trivalle

## 📋 Requisitos del Servidor

### **1. Servidor Web Recomendado**
- ✅ **Apache 2.4+** (con mod_headers, mod_rewrite, mod_expires, mod_deflate)
- ✅ **Nginx 1.18+** (alternativa)
- ✅ **HTTPS obligatorio** para producción

### **2. Módulos Apache Necesarios**
```bash
# Verificar módulos instalados
apache2ctl -M | grep -E "(headers|rewrite|expires|deflate)"

# Instalar si no están disponibles
sudo a2enmod headers
sudo a2enmod rewrite
sudo a2enmod expires
sudo a2enmod deflate
sudo systemctl restart apache2
```

## 🔧 Configuración Apache (.htaccess)

### **Archivo .htaccess (ya incluido en build/web/)**
```apache
# CORS para la API
<IfModule mod_headers.c>
    Header always set Access-Control-Allow-Origin "*"
    Header always set Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS"
    Header always set Access-Control-Allow-Headers "Content-Type, Authorization, X-Requested-With"
    Header always set Access-Control-Max-Age "86400"
</IfModule>

# SPA Routing
<IfModule mod_rewrite.c>
    RewriteEngine On
    RewriteCond %{REQUEST_FILENAME} !-f
    RewriteCond %{REQUEST_FILENAME} !-d
    RewriteRule ^(.*)$ /index.html [QSA,L]
</IfModule>

# Caché y compresión
<IfModule mod_expires.c>
    ExpiresActive On
    ExpiresByType application/wasm "access plus 1 year"
    ExpiresByType text/html "access plus 0 seconds"
</IfModule>
```

## 🌐 Configuración del Hosting

### **1. Subir Archivos**
```bash
# Copiar todo el contenido de build/web/ a tu servidor
# Asegúrate de que .htaccess esté en la raíz del sitio
```

### **2. Verificar Permisos**
```bash
# Archivos
chmod 644 *.html *.js *.css *.json *.wasm

# Directorios
chmod 755 assets/ canvaskit/ icons/

# .htaccess
chmod 644 .htaccess
```

### **3. Verificar MIME Types**
```apache
# En .htaccess o configuración del servidor
AddType application/wasm .wasm
AddType application/javascript .js
```

## 🔍 Diagnóstico de Problemas

### **1. Test de CORS**
```bash
# Desde la consola del navegador
curl -H "Origin: https://tudominio.com" \
     -H "Access-Control-Request-Method: POST" \
     -H "Access-Control-Request-Headers: Content-Type" \
     -X OPTIONS \
     https://www.trivalle.com/apiFichar/trvFichar.php
```

### **2. Verificar Headers de Respuesta**
```bash
curl -I https://www.trivalle.com/apiFichar/trvFichar.php
```

### **3. Test de la API desde el Servidor**
```bash
# Desde tu servidor web
curl "https://www.trivalle.com/apiFichar/trvFichar.php?Code=0"
```

## 🚨 Problemas Comunes y Soluciones

### **Error 1: CORS Policy**
```
Access to fetch at 'https://www.trivalle.com/apiFichar/trvFichar.php' 
from origin 'https://tudominio.com' has been blocked by CORS policy
```
**Solución**: Tu API ya tiene CORS configurado correctamente. El problema puede estar en:
- Servidor web no procesando .htaccess
- Módulo mod_headers no habilitado
- Configuración del hosting bloqueando headers personalizados

### **Error 2: Failed to Fetch**
```
Failed to fetch: NetworkError when attempting to fetch resource
```
**Solución**: 
- Verificar que HTTPS esté habilitado
- Comprobar que no haya firewalls bloqueando
- Verificar que la API esté accesible desde tu servidor

### **Error 3: 404 Not Found**
```
GET https://tudominio.com/ruta 404 (Not Found)
```
**Solución**: 
- Verificar que mod_rewrite esté habilitado
- Comprobar que .htaccess esté en la raíz
- Verificar permisos del archivo .htaccess

## 📱 Configuración PWA

### **1. Service Worker**
- ✅ Ya incluido: `flutter_service_worker.js`
- ✅ Registrado automáticamente por Flutter

### **2. Manifest**
- ✅ Ya incluido: `manifest.json`
- ✅ Configurado para instalación como app

## 🧪 Testing

### **1. Usar el archivo test_api.html**
- Abrir en tu servidor web
- Ejecutar todos los tests
- Verificar consola del navegador

### **2. Test desde Flutter Web**
- Abrir la app en tu servidor
- Abrir DevTools (F12)
- Verificar pestaña Network
- Buscar errores en Console

## 📞 Soporte

### **Si persisten los problemas:**
1. **Verificar logs del servidor web**
2. **Comprobar configuración del hosting**
3. **Verificar que todos los módulos Apache estén habilitados**
4. **Contactar al proveedor de hosting si es necesario**

### **Comandos útiles para diagnóstico:**
```bash
# Ver configuración Apache
apache2ctl -S

# Ver módulos cargados
apache2ctl -M

# Ver logs de error
tail -f /var/log/apache2/error.log

# Test de configuración
apache2ctl configtest
```
