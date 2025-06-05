#!/bin/bash

# data-seeder.sh - Script para poblar Dolibarr con datos de prueba

set -e

# Configuración
DOLIBARR_URL="http://localhost:8080"
ADMIN_USER="admin"
ADMIN_PASS="admin123"
COOKIE_JAR="/tmp/dolibarr_cookies.txt"

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date +'%H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%H:%M:%S')] ERROR: $1${NC}"
}

# Función para hacer login en Dolibarr
dolibarr_login() {
    log "Iniciando sesión en Dolibarr..."
    
    # Obtener token
    local login_page=$(curl -s -c "$COOKIE_JAR" "$DOLIBARR_URL/")
    local token=$(echo "$login_page" | grep -o 'name="token" value="[^"]*"' | cut -d'"' -f4)
    
    if [ -z "$token" ]; then
        error "No se pudo obtener el token de login"
        return 1
    fi
    
    # Hacer login
    local login_response=$(curl -s -b "$COOKIE_JAR" -c "$COOKIE_JAR" \
        -d "username=$ADMIN_USER" \
        -d "password=$ADMIN_PASS" \
        -d "token=$token" \
        -d "loginfunction=loginfunction" \
        -X POST "$DOLIBARR_URL/index.php")
    
    if echo "$login_response" | grep -q "logout\|admin\|dashboard"; then
        log "✅ Login exitoso"
        return 0
    else
        error "❌ Login fallido"
        return 1
    fi
}

# Función para crear usuarios de prueba
create_test_users() {
    log "Creando usuarios de prueba..."
    
    local users=(
        "vendedor1:password123:Vendedor:Uno:vendedor"
        "contable1:password123:Contador:Uno:accountant"
        "manager1:password123:Manager:Uno:manager"
        "user1:password123:Usuario:Uno:user"
        "user2:password123:Usuario:Dos:user"
    )
    
    for user_data in "${users[@]}"; do
        IFS=':' read -r username password firstname lastname type <<< "$user_data"
        
        log "Creando usuario: $username"
        
        # Obtener página de creación de usuario
        local user_page=$(curl -s -b "$COOKIE_JAR" "$DOLIBARR_URL/user/card.php?action=create")
        local token=$(echo "$user_page" | grep -o 'name="token" value="[^"]*"' | cut -d'"' -f4)
        
        if [ -n "$token" ]; then
            curl -s -b "$COOKIE_JAR" \
                -d "token=$token" \
                -d "action=add" \
                -d "login=$username" \
                -d "password=$password" \
                -d "password2=$password" \
                -d "firstname=$firstname" \
                -d "lastname=$lastname" \
                -d "email=${username}@test.com" \
                -d "admin=0" \
                -X POST "$DOLIBARR_URL/user/card.php" > /dev/null
            
            log "✅ Usuario $username creado"
        else
            warn "No se pudo crear usuario $username"
        fi
        
        sleep 1
    done
}

# Función para crear empresas/terceros de prueba
create_test_companies() {
    log "Creando empresas de prueba..."
    
    local companies=(
        "Empresa Test 1:Cliente:cliente1@test.com:+34123456789"
        "Proveedor Test 1:Proveedor:proveedor1@test.com:+34987654321"
        "Cliente Premium:Cliente:premium@test.com:+34111222333"
        "Mayorista ABC:Cliente:mayorista@test.com:+34444555666"
        "Servicios XYZ:Proveedor:servicios@test.com:+34777888999"
    )
    
    for company_data in "${companies[@]}"; do
        IFS=':' read -r name type email phone <<< "$company_data"
        
        log "Creando empresa: $name"
        
        # Obtener página de creación
        local company_page=$(curl -s -b "$COOKIE_JAR" "$DOLIBARR_URL/societe/card.php?action=create")
        local token=$(echo "$company_page" | grep -o 'name="token" value="[^"]*"' | cut -d'"' -f4)
        
        if [ -n "$token" ]; then
            local client_type="1"  # 1 = Cliente, 2 = Proveedor
            if [ "$type" = "Proveedor" ]; then
                client_type="2"
            fi
            
            curl -s -b "$COOKIE_JAR" \
                -d "token=$token" \
                -d "action=add" \
                -d "name=$name" \
                -d "client=$client_type" \
                -d "email=$email" \
                -d "phone=$phone" \
                -d "address=Dirección de prueba 123" \
                -d "zip=28001" \
                -d "town=Madrid" \
                -d "country_id=1" \
                -X POST "$DOLIBARR_URL/societe/card.php" > /dev/null
            
            log "✅ Empresa $name creada"
        else
            warn "No se pudo crear empresa $name"
        fi
        
        sleep 1
    done
}

# Función para crear productos de prueba
create_test_products() {
    log "Creando productos de prueba..."
    
    local products=(
        "Producto A:Producto físico de prueba:100.00:PROD001"
        "Servicio B:Servicio de consultoría:75.50:SERV001"
        "Producto C:Otro producto físico:250.00:PROD002"
        "Licencia Software:Licencia de software anual:500.00:LIC001"
        "Formación:Curso de formación:300.00:FORM001"
    )
    
    for product_data in "${products[@]}"; do
        IFS=':' read -r label description price ref <<< "$product_data"
        
        log "Creando producto: $label"
        
        # Obtener página de creación de producto
        local product_page=$(curl -s -b "$COOKIE_JAR" "$DOLIBARR_URL/product/card.php?action=create")
        local token=$(echo "$product_page" | grep -o 'name="token" value="[^"]*"' | cut -d'"' -f4)
        
        if [ -n "$token" ]; then
            curl -s -b "$COOKIE_JAR" \
                -d "token=$token" \
                -d "action=add" \
                -d "label=$label" \
                -d "ref=$ref" \
                -d "description=$description" \
                -d "price=$price" \
                -d "price_base_type=HT" \
                -d "type=0" \
                -d "status=1" \
                -X POST "$DOLIBARR_URL/product/card.php" > /dev/null
            
            log "✅ Producto $label creado"
        else
            warn "No se pudo crear producto $label"
        fi
        
        sleep 1
    done
}

# Función para crear facturas de prueba
create_test_invoices() {
    log "Creando facturas de prueba..."
    
    # Primero obtenemos IDs de clientes creados
    local invoice_page=$(curl -s -b "$COOKIE_JAR" "$DOLIBARR_URL/compta/facture/card.php?action=create")
    local token=$(echo "$invoice_page" | grep -o 'name="token" value="[^"]*"' | cut -d'"' -f4)
    
    if [ -n "$token" ]; then
        for i in {1..5}; do
            log "Creando factura de prueba $i"
            
            curl -s -b "$COOKIE_JAR" \
                -d "token=$token" \
                -d "action=add" \
                -d "type=0" \
                -d "socid=1" \
                -d "date=$(date +%d/%m/%Y)" \
                -d "cond_reglement_id=1" \
                -d "mode_reglement_id=1" \
                -X POST "$DOLIBARR_URL/compta/facture/card.php" > /dev/null
            
            sleep 1
        done
        
        log "✅ Facturas de prueba creadas"
    else
        warn "No se pudieron crear facturas"
    fi
}

# Función para configurar módulos de Dolibarr
setup_dolibarr_modules() {
    log "Configurando módulos de Dolibarr..."
    
    # Activar módulos principales
    local modules=(
        "modSociete"      # Terceros
        "modProduct"      # Productos
        "modFacture"      # Facturación
        "modCommande"     # Pedidos
        "modPropale"      # Presupuestos
        "modFournisseur"  # Proveedores
        "modStock"        # Stock
        "modComptabilite" # Contabilidad
    )
    
    for module in "${modules[@]}"; do
        log "Activando módulo: $module"
        
        local admin_page=$(curl -s -b "$COOKIE_JAR" "$DOLIBARR_URL/admin/modules.php")
        local token=$(echo "$admin_page" | grep -o 'name="token" value="[^"]*"' | cut -d'"' -f4)
        
        if [ -n "$token" ]; then
            curl -s -b "$COOKIE_JAR" \
                -d "token=$token" \
                -d "action=set" \
                -d "value=1" \
                -d "const=$module" \
                -X POST "$DOLIBARR_URL/admin/modules.php" > /dev/null
        fi
        
        sleep 1
    done
    
    log "✅ Módulos configurados"
}

# Función para crear configuración de performance
optimize_dolibarr_performance() {
    log "Optimizando configuración para pruebas de performance..."
    
    # Configuraciones de performance
    local configs=(
        "MAIN_OPTIMIZE_SPEED:1"
        "MAIN_LOG_FACILITY:LOG_LOCAL0"
        "MAIN_LOGLEVEL:1"
        "MAIN_UMASK:0664"
        "MAIN_USE_ADVANCED_PERMS:0"
    )
    
    for config in "${configs[@]}"; do
        IFS=':' read -r const_name const_value <<< "$config"
        
        log "Configurando: $const_name = $const_value"
        
        local config_page=$(curl -s -b "$COOKIE_JAR" "$DOLIBARR_URL/admin/const.php")
        local token=$(echo "$config_page" | grep -o 'name="token" value="[^"]*"' | cut -d'"' -f4)
        
        if [ -n "$token" ]; then
            curl -s -b "$COOKIE_JAR" \
                -d "token=$token" \
                -d "action=set" \
                -d "const=$const_name" \
                -d "value=$const_value" \
                -X POST "$DOLIBARR_URL/admin/const.php" > /dev/null
        fi
        
        sleep 1
    done
    
    log "✅ Configuraciones de performance aplicadas"
}

# Función para verificar la instalación
verify_dolibarr_setup() {
    log "Verificando configuración de Dolibarr..."
    
    # Verificar que podemos acceder al dashboard
    local dashboard=$(curl -s -b "$COOKIE_JAR" "$DOLIBARR_URL/index.php?mainmenu=home")
    
    if echo "$dashboard" | grep -q "dashboard\|tableau\|bord"; then
        log "✅ Dashboard accesible"
    else
        warn "⚠️ Problema accediendo al dashboard"
    fi
    
    # Verificar módulos activos
    local modules_page=$(curl -s -b "$COOKIE_JAR" "$DOLIBARR_URL/admin/modules.php")
    
    if echo "$modules_page" | grep -q "modSociete.*checked\|modProduct.*checked"; then
        log "✅ Módulos principales activados"
    else
        warn "⚠️ Algunos módulos pueden no estar activados"
    fi
    
    log "✅ Verificación completada"
}

# Función para generar datos aleatorios adicionales
generate_bulk_data() {
    local count=${1:-50}
    log "Generando $count registros adicionales de cada tipo..."
    
    # Crear empresas adicionales
    for i in $(seq 1 $count); do
        log "Creando empresa adicional $i/$count"
        
        local company_page=$(curl -s -b "$COOKIE_JAR" "$DOLIBARR_URL/societe/card.php?action=create")
        local token=$(echo "$company_page" | grep -o 'name="token" value="[^"]*"' | cut -d'"' -f4)
        
        if [ -n "$token" ]; then
            curl -s -b "$COOKIE_JAR" \
                -d "token=$token" \
                -d "action=add" \
                -d "name=Empresa Auto $i" \
                -d "client=1" \
                -d "email=empresa$i@test.com" \
                -d "phone=+3412345$i" \
                -d "address=Calle Falsa $i" \
                -d "zip=2800$i" \
                -d "town=Madrid" \
                -d "country_id=1" \
                -X POST "$DOLIBARR_URL/societe/card.php" > /dev/null
        fi
        
        # No hacer todos de una vez para no sobrecargar
        if [ $((i % 10)) -eq 0 ]; then
            log "Procesados $i registros, pausa breve..."
            sleep 2
        fi
    done
    
    log "✅ Datos bulk generados"
}

# Función para crear script SQL de datos de prueba
create_sql_test_data() {
    log "Creando script SQL para datos de prueba adicionales..."
    
    cat > dolibarr_test_data.sql << 'EOF'
-- Script SQL para datos de prueba adicionales en Dolibarr
-- Ejecutar después de la instalación inicial

USE dolibarr;

-- Insertar datos de terceros adicionales
INSERT INTO llx_societe (nom, client, fournisseur, email, phone, address, zip, town, fk_pays, datec, entity) VALUES
('Tech Solutions SL', 1, 0, 'tech@solutions.com', '+34600111222', 'Av. Tecnología 15', '28050', 'Madrid', 1, NOW(), 1),
('Distribuidora Norte', 1, 1, 'info@norte.com', '+34600333444', 'Polígono Industrial 8', '48100', 'Bilbao', 1, NOW(), 1),
('Servicios Premium', 1, 0, 'contacto@premium.es', '+34600555666', 'Gran Vía 45', '08001', 'Barcelona', 1, NOW(), 1),
('Global Partners', 1, 1, 'global@partners.net', '+34600777888', 'Parque Empresarial 3', '41020', 'Sevilla', 1, NOW(), 1),
('Innovation Hub', 1, 0, 'hello@innovation.io', '+34600999000', 'Centro Negocios 12', '46100', 'Valencia', 1, NOW(), 1);

-- Insertar productos adicionales
INSERT INTO llx_product (ref, label, description, price, price_base_type, fk_product_type, tosell, tobuy, entity, datec) VALUES
('AUTO001', 'Producto Automático 1', 'Producto generado automáticamente para pruebas', 99.99, 'HT', 0, 1, 1, 1, NOW()),
('AUTO002', 'Servicio Automático 1', 'Servicio generado automáticamente para pruebas', 149.50, 'HT', 1, 1, 0, 1, NOW()),
('AUTO003', 'Producto Premium', 'Producto premium para pruebas de carga', 299.99, 'HT', 0, 1, 1, 1, NOW()),
('AUTO004', 'Consultoría Express', 'Servicio de consultoría rápida', 75.00, 'HT', 1, 1, 0, 1, NOW()),
('AUTO005', 'Kit Completo', 'Kit completo de productos para testing', 499.99, 'HT', 0, 1, 1, 1, NOW());

-- Configurar algunas constantes para optimizar performance
INSERT INTO llx_const (name, value, type, visible, entity) VALUES
('MAIN_OPTIMIZE_SPEED', '1', 'chaine', 0, 1),
('MAIN_DELAY_ACTIONS_TODO', '7', 'chaine', 0, 1),
('MAIN_SIZE_LISTE_LIMIT', '100', 'chaine', 0, 1)
ON DUPLICATE KEY UPDATE value=VALUES(value);

EOF
    
    log "✅ Script SQL creado: dolibarr_test_data.sql"
    log "💡 Ejecutar con: docker compose exec dolibarr-db mysql -u dolibarr_user -p dolibarr < dolibarr_test_data.sql"
}

# Función para crear contactos adicionales
create_test_contacts() {
    log "Creando contactos de prueba..."
    
    local contacts=(
        "Juan:Pérez:juan.perez@empresa1.com:+34600111111:Director Comercial"
        "María:García:maria.garcia@empresa2.com:+34600222222:Responsable Compras"
        "Carlos:López:carlos.lopez@empresa3.com:+34600333333:Gerente"
        "Ana:Martín:ana.martin@empresa4.com:+34600444444:Contable"
        "Pedro:Sánchez:pedro.sanchez@empresa5.com:+34600555555:Técnico"
    )
    
    for contact_data in "${contacts[@]}"; do
        IFS=':' read -r firstname lastname email phone position <<< "$contact_data"
        
        log "Creando contacto: $firstname $lastname"
        
        local contact_page=$(curl -s -b "$COOKIE_JAR" "$DOLIBARR_URL/contact/card.php?action=create")
        local token=$(echo "$contact_page" | grep -o 'name="token" value="[^"]*"' | cut -d'"' -f4)
        
        if [ -n "$token" ]; then
            curl -s -b "$COOKIE_JAR" \
                -d "token=$token" \
                -d "action=add" \
                -d "firstname=$firstname" \
                -d "lastname=$lastname" \
                -d "email=$email" \
                -d "phone_pro=$phone" \
                -d "poste=$position" \
                -d "socid=1" \
                -X POST "$DOLIBARR_URL/contact/card.php" > /dev/null
            
            log "✅ Contacto $firstname $lastname creado"
        else
            warn "No se pudo crear contacto $firstname $lastname"
        fi
        
        sleep 1
    done
}

# Función para crear propuestas comerciales
create_test_proposals() {
    log "Creando propuestas comerciales de prueba..."
    
    for i in {1..3}; do
        log "Creando propuesta comercial $i"
        
        local proposal_page=$(curl -s -b "$COOKIE_JAR" "$DOLIBARR_URL/comm/propal/card.php?action=create")
        local token=$(echo "$proposal_page" | grep -o 'name="token" value="[^"]*"' | cut -d'"' -f4)
        
        if [ -n "$token" ]; then
            curl -s -b "$COOKIE_JAR" \
                -d "token=$token" \
                -d "action=add" \
                -d "socid=1" \
                -d "date=$(date +%d/%m/%Y)" \
                -d "duree_validite=30" \
                -d "cond_reglement_id=1" \
                -d "mode_reglement_id=1" \
                -X POST "$DOLIBARR_URL/comm/propal/card.php" > /dev/null
            
            log "✅ Propuesta $i creada"
        else
            warn "No se pudo crear propuesta $i"
        fi
        
        sleep 1
    done
}

# Función para crear pedidos de prueba
create_test_orders() {
    log "Creando pedidos de prueba..."
    
    for i in {1..3}; do
        log "Creando pedido $i"
        
        local order_page=$(curl -s -b "$COOKIE_JAR" "$DOLIBARR_URL/commande/card.php?action=create")
        local token=$(echo "$order_page" | grep -o 'name="token" value="[^"]*"' | cut -d'"' -f4)
        
        if [ -n "$token" ]; then
            curl -s -b "$COOKIE_JAR" \
                -d "token=$token" \
                -d "action=add" \
                -d "socid=1" \
                -d "date_commande=$(date +%d/%m/%Y)" \
                -d "cond_reglement_id=1" \
                -d "mode_reglement_id=1" \
                -X POST "$DOLIBARR_URL/commande/card.php" > /dev/null
            
            log "✅ Pedido $i creado"
        else
            warn "No se pudo crear pedido $i"
        fi
        
        sleep 1
    done
}

# Función para crear categorías
create_test_categories() {
    log "Creando categorías de prueba..."
    
    local categories=(
        "Productos Informáticos:0:Categoría para productos de informática"
        "Servicios Profesionales:0:Categoría para servicios profesionales"
        "Material de Oficina:0:Categoría para material de oficina"
        "Clientes VIP:2:Categoría para clientes VIP"
        "Proveedores Habituales:2:Categoría para proveedores habituales"
    )
    
    for category_data in "${categories[@]}"; do
        IFS=':' read -r label type description <<< "$category_data"
        
        log "Creando categoría: $label"
        
        local category_page=$(curl -s -b "$COOKIE_JAR" "$DOLIBARR_URL/categories/card.php?action=create&type=$type")
        local token=$(echo "$category_page" | grep -o 'name="token" value="[^"]*"' | cut -d'"' -f4)
        
        if [ -n "$token" ]; then
            curl -s -b "$COOKIE_JAR" \
                -d "token=$token" \
                -d "action=add" \
                -d "label=$label" \
                -d "description=$description" \
                -d "type=$type" \
                -X POST "$DOLIBARR_URL/categories/card.php" > /dev/null
            
            log "✅ Categoría $label creada"
        else
            warn "No se pudo crear categoría $label"
        fi
        
        sleep 1
    done
}

# Función para mostrar resumen de datos creados
show_data_summary() {
    log "📊 Resumen de datos de prueba creados:"
    echo
    echo "👥 Usuarios:"
    echo "  - admin (admin123) - Administrador"
    echo "  - vendedor1 (password123) - Vendedor"
    echo "  - contable1 (password123) - Contador"
    echo "  - manager1 (password123) - Manager"
    echo "  - user1, user2 (password123) - Usuarios estándar"
    echo
    echo "🏢 Empresas:"
    echo "  - 5+ empresas de prueba (clientes y proveedores)"
    echo "  - Datos completos con direcciones y contactos"
    echo
    echo "📦 Productos:"
    echo "  - 5+ productos de prueba"
    echo "  - Incluye productos físicos y servicios"
    echo "  - Precios variados para testing"
    echo
    echo "👤 Contactos:"
    echo "  - 5+ contactos asociados a empresas"
    echo "  - Datos completos con cargos y teléfonos"
    echo
    echo "📄 Documentos comerciales:"
    echo "  - Propuestas comerciales"
    echo "  - Pedidos de clientes"
    echo "  - Facturas de ejemplo"
    echo
    echo "🏷️ Categorías:"
    echo "  - Categorías de productos"
    echo "  - Categorías de clientes"
    echo
    echo "⚙️ Configuración:"
    echo "  - Módulos principales activados"
    echo "  - Configuraciones de performance aplicadas"
    echo
    echo "🔑 URLs de acceso:"
    echo "  - Dolibarr: http://localhost:8080"
    echo "  - Usuario: admin / Contraseña: admin123"
    echo
    echo "📈 Para pruebas de carga:"
    echo "  - ./run-tests.sh smoke   (prueba rápida)"
    echo "  - ./run-tests.sh load    (100 usuarios)"
    echo "  - ./run-tests.sh full    (suite completa)"
    echo
}

# Función para verificar prerequisitos
check_prerequisites() {
    log "Verificando prerequisitos..."
    
    # Verificar que curl esté disponible
    if ! command -v curl &> /dev/null; then
        error "curl no está instalado. Instalar con: sudo apt-get install curl"
        return 1
    fi
    
    # Verificar que Dolibarr esté accesible
    if ! curl -f -s "$DOLIBARR_URL/" > /dev/null; then
        error "Dolibarr no está accesible en $DOLIBARR_URL"
        echo "Asegúrate de que Docker Compose esté ejecutándose:"
        echo "  docker compose up -d"
        return 1
    fi
    
    log "✅ Prerequisitos verificados"
    return 0
}

# Función para limpiar datos de prueba
clean_test_data() {
    log "⚠️  Esta función eliminaría datos de prueba"
    warn "Por seguridad, esta función no está implementada"
    warn "Para limpiar, reinicia el contenedor de base de datos:"
    echo "  docker compose down -v"
    echo "  docker compose up -d"
}

# Función principal
main() {
    case "${1:-full}" in
        "users")
            check_prerequisites && dolibarr_login && create_test_users
            ;;
        "companies")
            check_prerequisites && dolibarr_login && create_test_companies
            ;;
        "products")
            check_prerequisites && dolibarr_login && create_test_products
            ;;
        "invoices")
            check_prerequisites && dolibarr_login && create_test_invoices
            ;;
        "contacts")
            check_prerequisites && dolibarr_login && create_test_contacts
            ;;
        "proposals")
            check_prerequisites && dolibarr_login && create_test_proposals
            ;;
        "orders")
            check_prerequisites && dolibarr_login && create_test_orders
            ;;
        "categories")
            check_prerequisites && dolibarr_login && create_test_categories
            ;;
        "modules")
            check_prerequisites && dolibarr_login && setup_dolibarr_modules
            ;;
        "optimize")
            check_prerequisites && dolibarr_login && optimize_dolibarr_performance
            ;;
        "bulk")
            check_prerequisites && dolibarr_login && generate_bulk_data "${2:-20}"
            ;;
        "sql")
            create_sql_test_data
            ;;
        "verify")
            check_prerequisites && dolibarr_login && verify_dolibarr_setup
            ;;
        "clean")
            clean_test_data
            ;;
        "full")
            log "🚀 Ejecutando configuración completa de datos de prueba..."
            
            if ! check_prerequisites; then
                exit 1
            fi
            
            if dolibarr_login; then
                setup_dolibarr_modules
                sleep 2
                create_test_users
                sleep 2
                create_test_companies
                sleep 2
                create_test_products
                sleep 2
                create_test_contacts
                sleep 2
                create_test_categories
                sleep 2
                create_test_proposals
                sleep 2
                create_test_orders
                sleep 2
                create_test_invoices
                sleep 2
                optimize_dolibarr_performance
                sleep 2
                verify_dolibarr_setup
                
                create_sql_test_data
                show_data_summary
                
                log "🎉 ¡Configuración completa de datos de prueba finalizada!"
                log "🔗 Accede a Dolibarr en: $DOLIBARR_URL"
                log "👤 Usuario: $ADMIN_USER / Contraseña: $ADMIN_PASS"
            else
                error "No se pudo hacer login en Dolibarr"
                echo ""
                echo "🔧 Posibles soluciones:"
                echo "1. Verificar que Dolibarr esté ejecutándose:"
                echo "   docker compose ps"
                echo ""
                echo "2. Verificar que la instalación inicial esté completa:"
                echo "   Ir a $DOLIBARR_URL y completar el wizard de instalación"
                echo ""
                echo "3. Verificar credenciales de admin:"
                echo "   Usuario: $ADMIN_USER"
                echo "   Contraseña: $ADMIN_PASS"
                echo ""
                exit 1
            fi
            ;;
        "help"|*)
            echo -e "${BLUE}📊 Data Seeder para Dolibarr Performance Testing${NC}"
            echo
            echo "Uso: $0 [COMMAND] [OPTIONS]"
            echo
            echo "Comandos disponibles:"
            echo "  full        - Configuración completa (recomendado)"
            echo "  users       - Crear solo usuarios de prueba"
            echo "  companies   - Crear solo empresas de prueba"
            echo "  products    - Crear solo productos de prueba"
            echo "  contacts    - Crear solo contactos de prueba"
            echo "  categories  - Crear solo categorías de prueba"
            echo "  proposals   - Crear solo propuestas comerciales"
            echo "  orders      - Crear solo pedidos de prueba"
            echo "  invoices    - Crear solo facturas de prueba"
            echo "  modules     - Activar módulos principales"
            echo "  optimize    - Aplicar configuraciones de performance"
            echo "  bulk [N]    - Generar N registros adicionales (default: 20)"
            echo "  sql         - Generar script SQL de datos adicionales"
            echo "  verify      - Verificar configuración actual"
            echo "  clean       - Información sobre limpieza de datos"
            echo "  help        - Mostrar esta ayuda"
            echo
            echo -e "${GREEN}Prerequisitos:${NC}"
            echo "  - Dolibarr debe estar ejecutándose en $DOLIBARR_URL"
            echo "  - Usuario admin con contraseña $ADMIN_PASS configurado"
            echo "  - curl instalado en el sistema"
            echo
            echo -e "${GREEN}Ejemplos de uso:${NC}"
            echo "  $0 full                    # Configuración completa"
            echo "  $0 users                   # Solo crear usuarios"
            echo "  $0 bulk 50                 # Generar 50 registros adicionales"
            echo "  $0 verify                  # Verificar configuración"
            echo
            echo -e "${YELLOW}Pasos recomendados:${NC}"
            echo "  1. docker compose up -d                    # Levantar servicios"
            echo "  2. Ir a $DOLIBARR_URL                      # Completar instalación"
            echo "  3. $0 full                                 # Poblar con datos"
            echo "  4. ./run-tests.sh smoke                    # Prueba rápida"
            echo "  5. ./run-tests.sh full                     # Pruebas completas"
            echo
            echo -e "${BLUE}Datos que se crearán:${NC}"
            echo "  📋 5 usuarios de prueba con diferentes roles"
            echo "  🏢 5 empresas (clientes y proveedores)"
            echo "  📦 5 productos y servicios"
            echo "  👤 5 contactos asociados"
            echo "  🏷️5 categorías organizativas"
            echo "  📄 3 propuestas comerciales"
            echo "  📋 3 pedidos de clientes"
            echo "  💰 5 facturas de ejemplo"
            echo "  ⚙️ Módulos principales activados"
            echo "  🚀 Configuraciones de performance"
            echo
            echo -e "${RED}IMPORTANTE:${NC}"
            echo "  - Este script modifica la base de datos de Dolibarr"
            echo "  - Úsalo solo en entornos de desarrollo/testing"
            echo "  - Para producción, crear datos manualmente"
            echo
            ;;
    esac
}

# Función de limpieza al salir
cleanup_on_exit() {
    if [ -f "$COOKIE_JAR" ]; then
        rm -f "$COOKIE_JAR"
        log "🧹 Archivo de cookies limpiado"
    fi
}

# Registrar función de limpieza
trap cleanup_on_exit EXIT

# Verificar si el script se ejecuta directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Mostrar información inicial
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════╗"
    echo "║           🧪 DOLIBARR DATA SEEDER               ║"
    echo "║        Script de Datos de Prueba v1.0           ║"
    echo "╚══════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo
    
    # Ejecutar función principal con argumentos
    main "$@"
    
    echo
    echo -e "${GREEN}✨ Ejecución completada. ¡Listo para pruebas de performance!${NC}"
fi
