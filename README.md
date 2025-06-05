### 🧪 Entorno de Pruebas No Funcionales para Dolibarr

Este proyecto proporciona un entorno completo para realizar pruebas no funcionales (rendimiento, estrés, carga) en Dolibarr usando Docker, K6, Grafana e InfluxDB. Incluye scripts automatizados para generar datos de prueba realistas y monitoreo avanzado en tiempo real.

## 🏗️ Arquitectura del Sistema

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│     Nginx       │    │    Dolibarr     │    │     MySQL       │
│  Load Balancer  │◄───│   Application   │◄───│   Database      │
│   (Port 80)     │    │   (Port 8080)   │    │  (Port 3306)    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         ▲                        ▲
         │                        │
         │            ┌─────────────────┐
         │            │       K6        │
         └────────────│  Load Testing   │
                      │   Container     │
                      └─────────────────┘
                               │
                               ▼
┌─────────────────┐    ┌─────────────────┐
│    Grafana      │◄───│   InfluxDB      │
│  Dashboards     │    │   Metrics DB    │
│  (Port 3000)    │    │  (Port 8086)    │
└─────────────────┘    └─────────────────┘
```

## 🚀 Inicio Rápido

### 1. Configuración Inicial

```bash
# Clonar o crear el directorio del proyecto
mkdir dolibarr-performance-testing
cd dolibarr-performance-testing

# Hacer ejecutables todos los scripts
chmod +x setup.sh data-seeder.sh advanced-monitoring.sh run-tests.sh

# Crear estructura completa del proyecto
./setup.sh
```

### 2. Levantar el Entorno

```bash
# 1. Configurar entorno
chmod +x *.sh
./setup.sh

# 2. Levantar servicios
docker compose up -d

# 3. Completar instalación de Dolibarr
# Ir a http://localhost:8080 y seguir el wizard

# 4. Poblar con datos de prueba
./data-seeder.sh full

# 5. Ejecutar pruebas de performance
./run-tests.sh full

# 6. Ver métricas en Grafana
# http://localhost:3000 (admin/admin123)

# Verificar que todos los contenedores estén corriendo
docker compose ps

# Ver logs si hay problemas
docker compose logs -f dolibarr
```

### 4. Poblar con Datos de Prueba

```bash
# Configuración completa de datos de prueba (recomendado)
./data-seeder.sh full

# O crear datos específicos
./data-seeder.sh users       # Solo usuarios
./data-seeder.sh companies   # Solo empresas  
./data-seeder.sh products    # Solo productos
./data-seeder.sh bulk 50     # 50 registros adicionales
```

### 5. Ejecutar Pruebas de Performance

```bash
# Smoke test (verificación rápida)
./run-tests.sh smoke

# Quick test (10 usuarios, 30 segundos)
./run-tests.sh quick

# Load test 
./run-tests.sh load

# Suite completa de pruebas (23 + 18 + 1.5 minutos)
./run-tests.sh full
```

### 6. Monitoreo Avanzado y Reportes

```bash
# Suite completa con monitoreo y reportes HTML
./advanced-monitoring.sh full

# Solo verificar estado de servicios
./advanced-monitoring.sh health

```


## 📈 Interpretación de Resultados

### Métricas Clave

#### Response Time (Tiempo de Respuesta)

```
✅ Excelente: < 100ms
✅ Bueno: 100-300ms
⚠️ Aceptable: 300-1000ms
❌ Lento: 1000-3000ms
🚨 Crítico: > 3000ms
```

#### Throughput (Rendimiento)

```
✅ Alto: > 1000 req/s
✅ Medio: 500-1000 req/s
⚠️ Bajo: 100-500 req/s
❌ Muy bajo: < 100 req/s
```

#### Error Rate (Tasa de Errores)

```
✅ Excelente: < 0.1%
✅ Bueno: 0.1-1%
⚠️ Aceptable: 1-5%
❌ Alto: 5-10%
🚨 Crítico: > 10%
```

### Umbrales Configurados ⚠️

- **P95 Response Time**: < 2000ms (95% de requests en menos de 2s)
- **Error Rate**: < 10% (menos del 10% de requests fallidas)
- **Login Success Rate**: > 90% (más del 90% de logins exitosos)
- **Page Load Time**: P90 < 3000ms (90% de páginas cargan en menos de 3s)

## 🎯 Escenarios de Prueba Realistas

### Flujo de Usuario Simulado

1. **Login** con credenciales de usuarios reales
2. **Navegación** por dashboard y módulos principales
3. **Búsquedas** en catálogo de productos y clientes
4. **Consultas** de facturas y documentos
5. **Creación de contenido** (empresas, productos)
6. **Reportes** y listados comerciales

### Módulos Probados

- 🏠 **Dashboard principal**
- 🏢 **Terceros** (clientes y proveedores)
- 📦 **Productos y servicios**
- 💰 **Facturación**
- 📋 **Pedidos y propuestas**
- 🔍 **Búsquedas globales**
- 📊 **Reportes comerciales**

## 📁 Estructura del Proyecto

```
dolibarr-performance-testing/
├── docker-compose.yml          # Servicios principales
├── setup.sh                    # Configuración inicial
├── data-seeder.sh              # Datos de prueba
├── run-tests.sh                # Ejecutor de pruebas
├── advanced-monitoring.sh      # Monitoreo avanzado
├── k6/
│   ├── load-test.js            # Pruebas principales K6
│   ├── quick-test.js           # Prueba rápida
│   └── smoke-test.js           # Smoke test
├── grafana/
│   ├── provisioning/           # Configuración automática
│   └── dashboards/             # Dashboards pre-configurados
├── nginx/
│   └── nginx.conf              # Load balancer
├── mysql/
│   └── init.sql                # Inicialización DB
├── logs/                       # Logs de pruebas
└── reports/                    # Reportes HTML
```
