#!/bin/bash

echo "🧪 Ejecutando pruebas de carga para Dolibarr"

# Función para verificar que los servicios estén listos
wait_for_services() {
    echo "⏳ Esperando que los servicios estén listos..."
    
    # Esperar Dolibarr
    echo "Esperando Dolibarr..."
    until curl -f http://localhost:8080/ > /dev/null 2>&1; do
        sleep 5
        echo "Dolibarr aún no está listo..."
    done
    echo "✅ Dolibarr está listo"
    
    # Esperar InfluxDB
    echo "Esperando InfluxDB..."
    until curl -f http://localhost:8086/health > /dev/null 2>&1; do
        sleep 5
        echo "InfluxDB aún no está listo..."
    done
    echo "✅ InfluxDB está listo"
    
    # Esperar Grafana
    echo "Esperando Grafana..."
    until curl -f http://localhost:3000/api/health > /dev/null 2>&1; do
        sleep 5
        echo "Grafana aún no está listo..."
    done
    echo "✅ Grafana está listo"
}

# Función para mostrar el estado actual
show_status() {
    echo "📋 Estado actual del sistema:"
    echo ""
    
    # Verificar servicios
    echo "🔍 Verificando servicios..."
    curl -f http://localhost:8080/ > /dev/null 2>&1 && echo "✅ Dolibarr: Activo" || echo "❌ Dolibarr: Inactivo"
    curl -f http://localhost:8086/health > /dev/null 2>&1 && echo "✅ InfluxDB: Activo" || echo "❌ InfluxDB: Inactivo"
    curl -f http://localhost:3000/api/health > /dev/null 2>&1 && echo "✅ Grafana: Activo" || echo "❌ Grafana: Inactivo"
    
    echo ""
    echo "📁 Archivos de prueba disponibles:"
    [ -f "./k6/smoke-test.js" ] && echo "✅ smoke-test.js" || echo "❌ smoke-test.js"
    [ -f "./k6/quick-test.js" ] && echo "✅ quick-test.js" || echo "❌ quick-test.js"
    [ -f "./k6/load-test.js" ] && echo "✅ load-test.js" || echo "❌ load-test.js"
    [ -f "./k6_load_test.js" ] && echo "ℹ️ k6_load_test.js (en raíz)" || echo "❌ archivo de carga principal"
}

# Ejecutar diferentes tipos de pruebas
run_tests() {
    echo "🚀 Iniciando pruebas..."
    
    case "${1:-full}" in
        "smoke")
            echo "💨 Ejecutando smoke test..."
            docker compose run --rm k6 run /scripts/smoke-test.js
            ;;
        "quick")
            echo "⚡ Ejecutando quick test..."
            docker compose run --rm k6 run /scripts/quick-test.js
            ;;
        "load")
            echo "📈 Ejecutando load test..."
            docker compose run --rm k6 run /scripts/load-test.js
            ;;
        "full")
            echo "🎯 Ejecutando suite completa de pruebas..."
            docker compose run --rm k6 run /scripts/load-test.js
            ;;
        *)
            echo "❌ Tipo de prueba no válido. Opciones: smoke, quick, load, full"
            exit 1
            ;;
    esac
}

# Mostrar información de monitoreo
show_monitoring_info() {
    echo ""
    echo "📊 URLs de Monitoreo:"
    echo "- Dolibarr: http://localhost:8080"
    echo "- Grafana: http://localhost:3000 (admin/admin123)"
    echo "- InfluxDB: http://localhost:8086"
    echo ""
    echo "💡 Para ver las métricas en tiempo real, abre Grafana en tu navegador"
}

# Función principal
main() {
    case "${1:-help}" in
        "status")
            show_status
            ;;
        "smoke"|"quick"|"load"|"full")
            wait_for_services
            run_tests "$1"
            show_monitoring_info
            ;;
        "help"|*)
            echo "🧪 Script de Pruebas de Carga para Dolibarr"
            echo ""
            echo "Uso: $0 [COMMAND]"
            echo ""
            echo "Comandos disponibles:"
            echo "  smoke     - Prueba rápida con 1 usuario (1 minuto)"
            echo "  quick     - Prueba rápida con 10 usuarios (30 segundos)"
            echo "  load      - Prueba de carga completa"
            echo "  full      - Suite completa de pruebas (igual que load)"
            echo "  status    - Mostrar estado de servicios y archivos"
            echo "  help      - Mostrar esta ayuda"
            echo ""
            echo "Ejemplos:"
            echo "  $0 status    # Ver estado actual"
            echo "  $0 smoke     # Prueba rápida"
            echo "  $0 load      # Prueba completa"
            ;;
    esac
}

main "$@"
