#!/bin/bash

# 🚀 Script de Despliegue para Fichar Trivalle Web
# Este script automatiza el proceso de build y despliegue

set -e  # Salir si hay algún error

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Función para imprimir con colores
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Verificar que estemos en el directorio correcto
if [ ! -f "pubspec.yaml" ]; then
    print_error "No se encontró pubspec.yaml. Ejecuta este script desde la raíz del proyecto."
    exit 1
fi

print_status "🚀 Iniciando despliegue de Fichar Trivalle Web..."

# 1. Limpiar build anterior
print_status "🧹 Limpiando build anterior..."
flutter clean

# 2. Obtener dependencias
print_status "📦 Obteniendo dependencias..."
flutter pub get

# 3. Construir para web
print_status "🔨 Construyendo aplicación web..."
flutter build web --release

# 4. Verificar que se generó el build
if [ ! -d "build/web" ]; then
    print_error "❌ No se generó el directorio build/web/"
    exit 1
fi

print_success "✅ Build completado exitosamente"

# 5. Mostrar información del build
print_status "📊 Información del build:"
echo "   📁 Directorio: build/web/"
echo "   📄 Archivos principales:"
ls -la build/web/ | grep -E "\.(html|js|wasm|json)$"

# 6. Verificar archivos críticos
print_status "🔍 Verificando archivos críticos..."
critical_files=("index.html" "main.dart.js" "flutter.js" "manifest.json" ".htaccess")
missing_files=()

for file in "${critical_files[@]}"; do
    if [ -f "build/web/$file" ]; then
        print_success "   ✅ $file"
    else
        print_error "   ❌ $file (FALTANTE)"
        missing_files+=("$file")
    fi
done

if [ ${#missing_files[@]} -gt 0 ]; then
    print_error "❌ Faltan archivos críticos: ${missing_files[*]}"
    exit 1
fi

# 7. Verificar tamaño del build
print_status "📏 Tamaño del build:"
total_size=$(du -sh build/web/ | cut -f1)
print_success "   Tamaño total: $total_size"

# 8. Crear archivo de verificación
print_status "📝 Creando archivo de verificación..."
cat > build/web/DEPLOY_INFO.txt << EOF
Fichar Trivalle - Información de Despliegue
============================================

Fecha de build: $(date)
Versión Flutter: $(flutter --version | head -n1)
Directorio: build/web/
Tamaño total: $total_size

Archivos críticos:
$(for file in "${critical_files[@]}"; do echo "- $file"; done)

Instrucciones de despliegue:
1. Copiar todo el contenido de build/web/ a tu servidor web
2. Asegurarte de que .htaccess esté en la raíz
3. Verificar que mod_headers y mod_rewrite estén habilitados en Apache
4. Probar la aplicación

Para testing, usar test_api.html en tu servidor web.

Soporte: Revisar web_server_config.md para configuración detallada.
EOF

print_success "✅ Archivo de verificación creado: build/web/DEPLOY_INFO.txt"

# 9. Crear archivo de test para el servidor
print_status "🧪 Copiando archivo de test..."
cp test_api.html build/web/

# 10. Instrucciones finales
echo ""
print_success "🎉 ¡Despliegue preparado exitosamente!"
echo ""
echo "📋 Próximos pasos:"
echo "   1. 📤 Subir todo el contenido de 'build/web/' a tu servidor web"
echo "   2. 🔧 Verificar que .htaccess esté en la raíz del sitio"
echo "   3. 🌐 Probar la aplicación en tu dominio"
echo "   4. 🧪 Usar 'test_api.html' para diagnosticar problemas de API"
echo ""
echo "📚 Documentación:"
echo "   - web_server_config.md - Configuración del servidor"
echo "   - DEPLOY_INFO.txt - Información del despliegue"
echo ""
echo "🔍 Para diagnosticar problemas:"
echo "   - Abrir DevTools (F12) en el navegador"
echo "   - Verificar pestaña Network para errores de API"
echo "   - Revisar Console para errores JavaScript"
echo "   - Usar test_api.html para tests específicos de la API"
echo ""

# 11. Opcional: Abrir el directorio del build
if command -v open &> /dev/null; then
    read -p "¿Quieres abrir el directorio del build? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        open build/web/
    fi
fi

print_success "✨ ¡Todo listo para el despliegue!"
