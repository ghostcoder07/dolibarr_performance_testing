#!/bin/bash

# advanced-monitoring.sh - Script de monitoreo avanzado para las pruebas

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuración
LOG_DIR="./logs"
REPORT_DIR="./reports"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Crear directorios necesarios
mkdir -p "$LOG_DIR" "$REPORT_DIR"

# Función para logging
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
}

# Función para verificar dependencias
check_dependencies() {
    log "Verificando dependencias..."
    
    local deps=("docker" "docker compose" "curl" "jq")
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing+=("$dep")
        fi
    done
    
    if [ ${#missing[@]} -ne 0 ]; then
        error "Dependencias faltantes: ${missing[*]}"
        echo "Instalar con: sudo apt-get install ${missing[*]}"
        exit 1
    fi
    
    log "✅ Todas las dependencias están disponibles"
}

# Función para verificar el estado de los servicios
check_services_health() {
    log "Verificando estado de los servicios..."
    
    local services=(
        "dolibarr:http://localhost:8080:Dolibarr"
        "grafana:http://localhost:3000/api/health:Grafana"
        "influxdb:http://localhost:8086/health:InfluxDB"
    )
    
    local failed_services=()
    
    for service_info in "${services[@]}"; do
        IFS=':' read -r name url display_name <<< "$service_info"
        
        if curl -f -s "$url" > /dev/null 2>&1; then
            log "✅ $display_name está respondiendo"
        else
            warn "❌ $display_name no está respondiendo en $url"
            failed_services+=("$display_name")
        fi
    done
    
    if [ ${#failed_services[@]} -ne 0 ]; then
        error "Servicios con problemas: ${failed_services[*]}"
        return 1
    fi
    
    log "✅ Todos los servicios están saludables"
    return 0
}

# Función para monitorear recursos del sistema
monitor_system_resources() {
    log "Monitoreando recursos del sistema..."
    
    local output_file="$LOG_DIR/system_resources_$TIMESTAMP.log"
    
    {
        echo "=== RECURSOS DEL SISTEMA - $(date) ==="
        echo
        echo "=== MEMORIA ==="
        free -h
        echo
        echo "=== CPU ==="
        top -bn1 | grep "Cpu(s)"
        echo
        echo "=== DISCO ==="
        df -h
        echo
        echo "=== CONTENEDORES DOCKER ==="
        docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.NetIO}}\t{{.BlockIO}}"
        echo
    } > "$output_file"
    
    log "📊 Recursos del sistema guardados en: $output_file"
}

# Función para obtener métricas de InfluxDB
get_influxdb_metrics() {
    log "Obteniendo métricas de InfluxDB..."
    
    local query='from(bucket:"k6-metrics") |> range(start:-1h) |> filter(fn:(r) => r._measurement == "http_req_duration") |> mean()'
    local output_file="$REPORT_DIR/influxdb_metrics_$TIMESTAMP.json"
    
    # Usar la API de InfluxDB para obtener datos
    if curl -s -X POST "http://localhost:8086/api/v2/query?org=testing-org" \
        -H "Authorization: Token my-super-secret-auth-token" \
        -H "Content-Type: application/vnd.flux" \
        -d "$query" > "$output_file"; then
        log "📈 Métricas de InfluxDB guardadas en: $output_file"
    else
        warn "No se pudieron obtener métricas de InfluxDB"
    fi
}

# Función para generar reporte de pruebas
generate_test_report() {
    log "Generando reporte de pruebas..."
    
    local report_file="$REPORT_DIR/test_report_$TIMESTAMP.html"
    
    cat > "$report_file" << EOF
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Reporte de Pruebas - Dolibarr Performance Testing</title>
    <style>
        body { 
            font-family: Arial, sans-serif; 
            margin: 20px; 
            background-color: #f5f5f5; 
        }
        .container { 
            max-width: 1200px; 
            margin: 0 auto; 
            background: white; 
            padding: 20px; 
            border-radius: 10px; 
            box-shadow: 0 2px 10px rgba(0,0,0,0.1); 
        }
        .header { 
            text-align: center; 
            color: #333; 
            border-bottom: 2px solid #007bff; 
            padding-bottom: 20px; 
            margin-bottom: 30px; 
        }
        .metric-card { 
            background: #f8f9fa; 
            padding: 15px; 
            margin: 10px 0; 
            border-left: 4px solid #007bff; 
            border-radius: 5px; 
        }
        .status-ok { border-left-color: #28a745; }
        .status-warning { border-left-color: #ffc107; }
        .status-error { border-left-color: #dc3545; }
        .grid { 
            display: grid; 
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); 
            gap: 20px; 
        }
        .timestamp { 
            color: #666; 
            font-size: 0.9em; 
        }
        pre { 
            background: #f1f1f1; 
            padding: 10px; 
            border-radius: 5px; 
            overflow-x: auto; 
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🧪 Reporte de Pruebas de Performance</h1>
            <h2>Dolibarr ERP/CRM Testing</h2>
            <p class="timestamp">Generado el: $(date)</p>
        </div>
        
        <div class="grid">
            <div class="metric-card status-ok">
                <h3>📊 Estado de Servicios</h3>
                <ul>
                    <li>Dolibarr: $(curl -f -s http://localhost:8080 > /dev/null && echo "✅ Activo" || echo "❌ Inactivo")</li>
                    <li>Grafana: $(curl -f -s http://localhost:3000/api/health > /dev/null && echo "✅ Activo" || echo "❌ Inactivo")</li>
                    <li>InfluxDB: $(curl -f -s http://localhost:8086/health > /dev/null && echo "✅ Activo" || echo "❌ Inactivo")</li>
                    <li>MySQL: $(docker compose exec -T dolibarr-db mysqladmin ping -u root -proot_password 2>/dev/null && echo "✅ Activo" || echo "❌ Inactivo")</li>
                </ul>
            </div>
            
            <div class="metric-card">
                <h3>🖥️ Recursos del Sistema</h3>
                <pre>$(free -h | head -2)</pre>
                <pre>$(df -h / | tail -1)</pre>
            </div>
            
            <div class="metric-card">
                <h3>🐳 Contenedores Docker</h3>
                <pre>$(docker compose ps --format "table {{.Name}}\t{{.Status}}")</pre>
            </div>
            
            <div class="metric-card">
                <h3>📈 Enlaces Útiles</h3>
                <ul>
                    <li><a href="http://localhost:8080" target="_blank">Dolibarr Application</a></li>
                    <li><a href="http://localhost:3000" target="_blank">Grafana Dashboard</a></li>
                    <li><a href="http://localhost:8086" target="_blank">InfluxDB</a></li>
                </ul>
            </div>
        </div>
        
        <div class="metric-card">
            <h3>📝 Comandos de Prueba Ejecutados</h3>
            <pre>
# Smoke Test
./run-tests.sh smoke

# Load Test  
./run-tests.sh load

# Stress Test (incluido en load test)
./run-tests.sh full
            </pre>
        </div>
        
        <div class="metric-card">
            <h3>🎯 Próximos Pasos Recomendados</h3>
            <ol>
                <li>Revisar métricas en Grafana</li>
                <li>Analizar logs de errores si los hay</li>
                <li>Optimizar configuraciones identificadas</li>
                <li>Ejecutar nuevamente las pruebas</li>
                <li>Documentar hallazgos y mejoras</li>
            </ol>
        </div>
    </div>
</body>
</html>
EOF
    
    log "📄 Reporte HTML generado: $report_file"
    
    # Intentar abrir el reporte en el navegador
    if command -v xdg-open &> /dev/null; then
        xdg-open "$report_file" 2>/dev/null &
    elif command -v open &> /dev/null; then
        open "$report_file" 2>/dev/null &
    fi
}

# Función para ejecutar suite completa de monitoreo
run_full_monitoring() {
    log "🚀 Iniciando suite completa de monitoreo..."
    
    # Pre-checks
    check_dependencies
    
    # Verificar servicios
    if ! check_services_health; then
        error "Los servicios no están funcionando correctamente"
        exit 1
    fi
    
    # Monitorear recursos antes de las pruebas
    monitor_system_resources
    
    # Ejecutar pruebas
    log "Ejecutando pruebas de carga..."
    if ./run-tests.sh full 2>&1 | tee "$LOG_DIR/k6_output_$TIMESTAMP.log"; then
        log "✅ Pruebas completadas exitosamente"
    else
        warn "⚠️ Las pruebas completaron con warnings/errores"
    fi
    
    # Esperar un poco para que las métricas se procesen
    sleep 10
    
    # Obtener métricas post-prueba
    get_influxdb_metrics
    monitor_system_resources
    
    # Generar reporte final
    generate_test_report
    
    log "🎉 Suite de monitoreo completada!"
    log "📁 Archivos generados en: $LOG_DIR y $REPORT_DIR"
}

# Función para limpiar logs antiguos
cleanup_old_logs() {
    log "🧹 Limpiando logs antiguos (más de 7 días)..."
    
    find "$LOG_DIR" -name "*.log" -mtime +7 -delete 2>/dev/null || true
    find "$REPORT_DIR" -name "*.html" -mtime +7 -delete 2>/dev/null || true
    find "$REPORT_DIR" -name "*.json" -mtime +7 -delete 2>/dev/null || true
    
    log "✅ Limpieza completada"
}

# Función para mostrar métricas en tiempo real
show_realtime_metrics() {
    log "📊 Mostrando métricas en tiempo real (Ctrl+C para salir)..."
    
    while true; do
        clear
        echo -e "${BLUE}=== MÉTRICAS EN TIEMPO REAL ===${NC}"
        echo "Timestamp: $(date)"
        echo
        
        echo -e "${GREEN}=== ESTADO DE SERVICIOS ===${NC}"
        curl -f -s http://localhost:8080 > /dev/null && echo "✅ Dolibarr: Activo" || echo "❌ Dolibarr: Inactivo"
        curl -f -s http://localhost:3000/api/health > /dev/null && echo "✅ Grafana: Activo" || echo "❌ Grafana: Inactivo"
        curl -f -s http://localhost:8086/health > /dev/null && echo "✅ InfluxDB: Activo" || echo "❌ InfluxDB: Inactivo"
        echo
        
        echo -e "${GREEN}=== RECURSOS DEL SISTEMA ===${NC}"
        free -h | head -2
        echo
        
        echo -e "${GREEN}=== CONTENEDORES DOCKER ===${NC}"
        docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}"
        echo
        
        echo "Actualizando en 5 segundos... (Ctrl+C para salir)"
        sleep 5
    done
}

# Función principal
main() {
    case "${1:-help}" in
        "full")
            run_full_monitoring
            ;;
        "health")
            check_services_health
            ;;
        "resources")
            monitor_system_resources
            ;;
        "report")
            generate_test_report
            ;;
        "cleanup")
            cleanup_old_logs
            ;;
        "realtime")
            show_realtime_metrics
            ;;
        "help"|*)
            echo -e "${BLUE}🔧 Advanced Monitoring Script para Dolibarr Performance Testing${NC}"
            echo
            echo "Uso: $0 [COMMAND]"
            echo
            echo "Comandos disponibles:"
            echo "  full      - Ejecutar suite completa de monitoreo y pruebas"
            echo "  health    - Verificar estado de todos los servicios"
            echo "  resources - Monitorear recursos del sistema"
            echo "  report    - Generar reporte HTML"
            echo "  cleanup   - Limpiar logs antiguos"
            echo "  realtime  - Mostrar métricas en tiempo real"
            echo "  help      - Mostrar esta ayuda"
            echo
            echo -e "${GREEN}Ejemplos:${NC}"
            echo "  $0 full       # Suite completa"
            echo "  $0 health     # Solo verificar servicios"
            echo "  $0 realtime   # Monitoreo en vivo"
            ;;
    esac
}

# Ejecutar función principal con argumentos
main "$@"
