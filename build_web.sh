#!/bin/bash

echo "🚀 Construyendo aplicación web optimizada..."

# Limpiar build anterior
echo "🧹 Limpiando build anterior..."
flutter clean

# Obtener dependencias
echo "📦 Obteniendo dependencias..."
flutter pub get

# Construir para web con optimizaciones
echo "🔨 Construyendo para web..."
flutter build web \
  --release \
  --web-renderer canvaskit \
  --dart-define=FLUTTER_WEB_USE_SKIA=true \
  --dart-define=FLUTTER_WEB_AUTO_DETECT=true \
  --base-href "/" \
  --source-maps

# Verificar archivos generados
echo "✅ Verificando archivos generados..."
if [ -d "build/web" ]; then
    echo "📁 Build completado en build/web/"
    echo "📊 Tamaño del build:"
    du -sh build/web/*
    
    echo "🔍 Archivos críticos:"
    ls -la build/web/
    
    echo "🎯 Para desplegar, copia el contenido de build/web/ a tu servidor web"
else
    echo "❌ Error: No se generó el directorio build/web/"
    exit 1
fi

echo "🎉 ¡Build completado exitosamente!"
