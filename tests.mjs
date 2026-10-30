// Pruebas de seguridad (Tabla 12 / MITRE ATT&CK).
// Requiere servidor + gateway activos y DEV_SHOW_OTP=1

/* ========================================================================
 * CONFIGURACIÓN Y UTILIDADES
 * ===================================================================== */
const B = process.env.API || 'http://localhost:3000';

const sleep = ms => new Promise(r => setTimeout(r, ms));

// Llamada HTTP: devuelve { s: status, b: body }
const call = async (m, p, { tok, body } = {}) => {
  const r = await fetch(B + p, {
    method: m,
    headers: {
      'content-type': 'application/json',
      ...(tok && { authorization: 'Bearer ' + tok }),
    },
    body: body && JSON.stringify(body),
  });

  return { s: r.status, b: await r.json().catch(() => ({})) };
};

// Login completo (credenciales + OTP) → devuelve el token JWT
const login = async (email, pass) => {
  const a = await call('POST', '/api/auth/login', { body: { email, pass } });
  const v = await call('POST', '/api/auth/verify', {
    body: { challenge: a.b.challenge, otp: a.b.otp },
  });
  return v.b.token;
};

/* ========================================================================
 * PRUEBAS
 * Cada prueba: [nombre, async () => [pasó?, detalle]]
 * ===================================================================== */
const T = [
  [
    'T1595 Active Scanning (429)',
    async () => {
      const r = await Promise.all(
        Array.from({ length: 30 }, () => call('POST', '/api/tickets/buy')),
      );
      const n = r.filter(x => x.s === 429).length;
      return [n > 0, n + ' respuestas 429'];
    },
  ],

  [
    'T1110 Brute Force (bloqueo en 6.º intento)',
    async () => {
      let s;
      for (let i = 0; i < 6; i++) {
        s = (
          await call('POST', '/api/auth/login', {
            body: { email: 'victima@demo.com', pass: 'x' + i },
          })
        ).s;
      }
      return [s === 429, 'último: ' + s];
    },
  ],

  [
    'T1078 Escalada de privilegios (403)',
    async () => {
      const t = await login('cliente@demo.com', 'Cliente#2026');
      const r = await call('GET', '/api/admin/export', { tok: t });
      return [r.s === 403, 'HTTP ' + r.s];
    },
  ],

  [
    'T1539 JWT alterado / alg=none (401)',
    async () => {
      const t = await login('cliente@demo.com', 'Cliente#2026');
      const bad = t.slice(0, -3) + (t.endsWith('AAA') ? 'BBB' : 'AAA');
      const none = 'eyJhbGciOiJub25lIn0.' + t.split('.')[1] + '.';

      const a = await call('GET', '/api/tickets/mine', { tok: bad });
      const b = await call('GET', '/api/tickets/mine', { tok: none });

      return [a.s === 401 && b.s === 401, `${a.s}/${b.s}`];
    },
  ],

  [
    'T1190 SQL Injection (401)',
    async () => {
      const r = await call('POST', '/api/auth/login', {
        body: { email: "' OR 1=1 --", pass: "' OR 1=1 --" },
      });
      return [r.s === 401 && !r.b.challenge, 'HTTP ' + r.s];
    },
  ],

  [
    'T1565 Manipulación de logs (403 + cadena íntegra)',
    async () => {
      const t = await login('admin@demo.com', 'Admin#2026');
      const e = await call('POST', '/api/audit/edit', { tok: t });
      const a = await call('GET', '/api/audit', { tok: t });
      return [e.s === 403 && a.b.broken === 0, `edit ${e.s}, cadena rota=${a.b.broken}`];
    },
  ],

  [
    'IDOR: QR de boleto ajeno (403)',
    async () => {
      const t = await login('cliente@demo.com', 'Cliente#2026');
      const r = await call('POST', '/api/tickets/qr', {
        tok: t,
        body: { id: '00000000-0000-0000-0000-000000000001' },
      });
      return [r.s === 403, 'HTTP ' + r.s];
    },
  ],
];

/* ========================================================================
 * EJECUCIÓN
 * ===================================================================== */
let f = 0;

for (const [n, fn] of T) {
  let r;
  try {
    r = await fn();
  } catch (e) {
    r = [false, String(e)];
  }

  if (!r[0]) f++;
  console.log(r[0] ? '✔ PASA ' : '✘ FALLA', n, '→', r[1]);

  await sleep(3300);
}

console.log('\nT1552 (secretos): ejecutar  npx gitleaks detect --source .');
process.exit(f ? 1 : 0);