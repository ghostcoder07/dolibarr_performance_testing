import http from 'k6/http';
import { check, sleep, group } from 'k6';
import { Counter, Rate, Trend } from 'k6/metrics';

// Métricas personalizadas
const loginErrors = new Counter('login_errors');
const loginSuccessRate = new Rate('login_success_rate');
const pageLoadTime = new Trend('page_load_time');

// Configuración de la prueba
export const options = {
  scenarios: {
    // Prueba de carga gradual
    load_test: {
      executor: 'ramping-vus',
      stages: [
        { duration: '2m', target: 10 },   // Ramp up to 10 users
        { duration: '5m', target: 50 },   // Stay at 50 users
        { duration: '3m', target: 100 },  // Ramp up to 100 users
        { duration: '10m', target: 100 }, // Stay at 100 users
        { duration: '3m', target: 0 },    // Ramp down
      ],
      gracefulRampDown: '30s',
    },
    
    // Prueba de estrés
    stress_test: {
      executor: 'ramping-vus',
      startTime: '25m', // Inicia después de la prueba de carga
      stages: [
        { duration: '2m', target: 100 },  // Ramp up to 100 users
        { duration: '5m', target: 200 },  // Ramp up to 200 users
        { duration: '3m', target: 300 },  // Ramp up to 300 users (stress level)
        { duration: '5m', target: 300 },  // Stay at stress level
        { duration: '3m', target: 0 },    // Ramp down
      ],
      gracefulRampDown: '30s',
    },

    // Prueba de picos
    spike_test: {
      executor: 'ramping-vus',
      startTime: '43m', // Inicia después de la prueba de estrés
      stages: [
        { duration: '10s', target: 1 },    // Normal load
        { duration: '1m', target: 500 },   // Spike to 500 users
        { duration: '10s', target: 1 },    // Return to normal
      ],
      gracefulRampDown: '30s',
    }
  },
  
  thresholds: {
    http_req_duration: ['p(95)<2000'], // 95% de las requests deben completarse en menos de 2s
    http_req_failed: ['rate<0.1'],     // Menos del 10% de requests fallidas
    login_success_rate: ['rate>0.9'],  // Más del 90% de logins exitosos
    page_load_time: ['p(90)<3000'],    // 90% de páginas cargan en menos de 3s
  },
};

// URL base de Dolibarr
const BASE_URL = 'http://dolibarr:80';

// Datos de prueba
const testUsers = [
  { username: 'admin', password: 'admin123' },
  { username: 'user1', password: 'password1' },
  { username: 'user2', password: 'password2' },
  // Añadir más usuarios según sea necesario
];

function getRandomUser() {
  return testUsers[Math.floor(Math.random() * testUsers.length)];
}

// Función de setup (se ejecuta una vez al inicio)
export function setup() {
  console.log('Iniciando pruebas de carga para Dolibarr...');
  
  // Verificar que Dolibarr esté disponible
  const response = http.get(`${BASE_URL}/`);
  check(response, {
    'Dolibarr is accessible': (r) => r.status === 200,
  });
  
  return { baseUrl: BASE_URL };
}

// Función principal de prueba
export default function(data) {
  const user = getRandomUser();
  
  group('User Journey - Complete Flow', function() {
    
    // 1. Acceder a la página de login
    group('Access Login Page', function() {
      const startTime = Date.now();
      const response = http.get(`${data.baseUrl}/`);
      
      check(response, {
        'Login page loads': (r) => r.status === 200,
        'Login page contains form': (r) => r.body.includes('form'),
      });
      
      pageLoadTime.add(Date.now() - startTime);
      sleep(1);
    });

    // 2. Realizar login
    group('User Login', function() {
      const loginData = {
        username: user.username,
        password: user.password,
        loginfunction: 'loginfunction',
      };
      
      const response = http.post(`${data.baseUrl}/index.php`, loginData, {
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      });
      
      const loginSuccess = check(response, {
        'Login successful': (r) => r.status === 200 || r.status === 302,
        'No login error': (r) => !r.body.includes('error') && !r.body.includes('Error'),
      });
      
      if (loginSuccess) {
        loginSuccessRate.add(1);
      } else {
        loginSuccessRate.add(0);
        loginErrors.add(1);
      }
      
      sleep(2);
    });

    // 3. Navegar por el dashboard
    group('Navigate Dashboard', function() {
      const startTime = Date.now();
      const response = http.get(`${data.baseUrl}/index.php?mainmenu=home`);
      
      check(response, {
        'Dashboard loads': (r) => r.status === 200,
        'Dashboard has content': (r) => r.body.length > 1000,
      });
      
      pageLoadTime.add(Date.now() - startTime);
      sleep(1);
    });

    // 4. Acceder a módulos principales
    group('Access Main Modules', function() {
      const modules = [
        '/index.php?mainmenu=companies',  // Terceros
        '/index.php?mainmenu=products',   // Productos
        '/index.php?mainmenu=commercial', // Comercial
        '/index.php?mainmenu=accountancy', // Contabilidad
      ];
      
      const randomModule = modules[Math.floor(Math.random() * modules.length)];
      const startTime = Date.now();
      const response = http.get(`${data.baseUrl}${randomModule}`);
      
      check(response, {
        'Module loads': (r) => r.status === 200,
        'Module accessible': (r) => r.body.length > 500,
      });
      
      pageLoadTime.add(Date.now() - startTime);
      sleep(2);
    });

    // 5. Realizar búsquedas
    group('Search Functionality', function() {
      const searchTerms = ['test', 'client', 'product', 'invoice'];
      const randomTerm = searchTerms[Math.floor(Math.random() * searchTerms.length)];
      
      const response = http.get(`${data.baseUrl}/core/search.php?search=${randomTerm}`);
      
      check(response, {
        'Search works': (r) => r.status === 200,
        'Search results page': (r) => r.body.includes('search') || r.body.includes('resultado'),
      });
      
      sleep(1);
    });

    // 6. Crear/Editar contenido (simulado)
    group('Content Creation', function() {
      // Simular creación de un tercero
      const createData = {
        'name': `Test Company ${Math.floor(Math.random() * 10000)}`,
        'action': 'add',
        'type': '1',
      };
      
      const response = http.post(`${data.baseUrl}/societe/card.php`, createData, {
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      });
      
      check(response, {
        'Content creation attempted': (r) => r.status === 200 || r.status === 302,
      });
      
      sleep(1);
    });

  });

  // Tiempo de espera entre iteraciones
  sleep(Math.random() * 3 + 1); // Entre 1 y 4 segundos
}

// Función de teardown (se ejecuta al final)
export function teardown(data) {
  console.log('Pruebas de carga completadas');
  
  // Verificar que el sistema siga respondiendo
  const response = http.get(`${data.baseUrl}/`);
  check(response, {
    'System still responsive after tests': (r) => r.status === 200,
  });
}
