#!/bin/bash

# setup.sh - Script para configurar el entorno de pruebas

echo "🚀 Configurando entorno de pruebas para Dolibarr..."

# Crear estructura de directorios
create_directories() {
    echo "📁 Creando estructura de directorios..."
    
    mkdir -p k6
    mkdir -p mysql
    mkdir -p grafana/provisioning/dashboards
    mkdir -p grafana/provisioning/datasources
    mkdir -p grafana/dashboards
    mkdir -p nginx
    mkdir -p dolibarr/conf
    
    echo "✅ Directorios creados"
}

# Crear configuración de MySQL
create_mysql_config() {
    echo "🗄️ Creando configuración de MySQL..."
    
    cat > mysql/init.sql << 'EOF'
-- Configuración inicial para Dolibarr
CREATE DATABASE IF NOT EXISTS dolibarr CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Crear usuarios de prueba adicionales
USE dolibarr;

-- Estos usuarios se crearán después de la instalación inicial de Dolibarr
-- mediante la interfaz web o scripts adicionales
EOF
    
    echo "✅ Configuración de MySQL creada"
}

# Crear configuración de Nginx
create_nginx_config() {
    echo "🌐 Creando configuración de Nginx..."
    
    cat > nginx/nginx.conf << 'EOF'
events {
    worker_connections 1024;
}

http {
    upstream dolibarr_backend {
        server dolibarr:80;
        # Añadir más instancias de Dolibarr aquí si es necesario
        # server dolibarr2:80;
    }
    
    server {
        listen 80;
        server_name localhost;
        
        # Configuración para pruebas de carga
        client_max_body_size 100M;
        keepalive_timeout 65;
        keepalive_requests 100;
        
        location / {
            proxy_pass http://dolibarr_backend;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            
            # Timeouts para pruebas de carga
            proxy_connect_timeout 60s;
            proxy_send_timeout 60s;
            proxy_read_timeout 60s;
        }
        
        # Logs para análisis
        access_log /var/log/nginx/dolibarr_access.log;
        error_log /var/log/nginx/dolibarr_error.log;
    }
}
EOF
    
    echo "✅ Configuración de Nginx creada"
}

# Crear configuración de Grafana
create_grafana_config() {
    echo "📊 Creando configuración de Grafana..."
    
    # Datasource para InfluxDB
    cat > grafana/provisioning/datasources/influxdb.yml << 'EOF'
apiVersion: 1

datasources:
  - name: InfluxDB-K6
    type: influxdb
    access: proxy
    url: http://influxdb:8086
    jsonData:
      version: Flux
      organization: testing-org
      defaultBucket: k6-metrics
    secureJsonData:
      token: my-super-secret-auth-token
EOF

    # Dashboard provisioning
    cat > grafana/provisioning/dashboards/dashboard.yml << 'EOF'
apiVersion: 1

providers:
  - name: 'K6 Load Testing'
    orgId: 1
    folder: ''
    type: file
    disableDeletion: false
    editable: true
    options:
      path: /var/lib/grafana/dashboards
EOF

    # Dashboard básico para K6
    cat > grafana/dashboards/k6-dashboard.json << 'EOF'
{
  "dashboard": {
    "id": null,
    "title": "K6 Load Testing Dashboard",
    "tags": ["k6", "load-testing"],
    "timezone": "browser",
    "panels": [
      {
        "id": 1,
        "title": "Virtual Users",
        "type": "stat",
        "targets": [
          {
            "expr": "vus",
            "refId": "A"
          }
        ],
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 0}
      },
      {
        "id": 2,
        "title": "Request Rate",
        "type": "graph",
        "targets": [
          {
            "expr": "http_reqs",
            "refId": "A"
          }
        ],
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 0}
      }
    ],
    "time": {
      "from": "now-1h",
      "to": "now"
    },
    "refresh": "5s"
  }
}
EOF
    
    echo "✅ Configuración de Grafana creada"
}

# Crear script de pruebas rápidas
create_quick_tests() {
    echo "⚡ Creando scripts de pruebas rápidas..."
    
    cat > k6/quick-test.js << 'EOF'
import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  vus: 10,
  duration: '30s',
};

export default function() {
  const response = http.get('http://dolibarr:80/');
  check(response, {
    'status is 200': (r) => r.status === 200,
  });
  sleep(1);
}
EOF

    cat > k6/smoke-test.js << 'EOF'
import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  vus: 1,
  duration: '1m',
};

export default function() {
  const response = http.get('http://dolibarr:80/');
  check(response, {
    'status is 200': (r) => r.status === 200,
    'response time < 500ms': (r) => r.timings.duration < 500,
  });
  sleep(1);
}
EOF
    
    echo "✅ Scripts de pruebas rápidas creados"
}

# Crear script de ejecución de pruebas
create_test_runner() {
    echo "🏃 Creando script de ejecución de pruebas..."
    
    cat > run-tests.sh << 'EOF'
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
    wait_for_services
    run_tests "$1"
    show_monitoring_info
}

main "$@"
EOF
    
    chmod +x run-tests.sh
    echo "✅ Script de ejecución creado"
}

# Función principal
main() {
    create_directories
    create_mysql_config
    create_nginx_config
    create_grafana_config
    create_quick_tests
    create_test_runner
    
    echo ""
    echo "🎉 ¡Configuración completada!"
    echo ""
    echo "📋 Próximos pasos:"
    echo "1. docker compose up -d"
    echo "2. Esperar que todos los servicios estén listos (~2-3 minutos)"
    echo "3. Configurar Dolibarr en http://localhost:8080"
    echo "4. ./run-tests.sh [smoke|quick|load|full]"
    echo ""
    echo "🔧 URLs importantes:"
    echo "- Dolibarr: http://localhost:8080"
    echo "- Grafana: http://localhost:3000 (admin/admin123)"
    echo "- InfluxDB: http://localhost:8086"
}

# Ejecutar si el script se llama directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
