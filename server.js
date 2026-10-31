import express from 'express';
import helmet from 'helmet';
import pg from 'pg';
import Redis from 'ioredis';
import jwt from 'jsonwebtoken';
import crypto from 'node:crypto';
import fs from 'node:fs';
import { promisify } from 'node:util';

/* ========================================================================
 * CONFIGURACIÓN
 * ===================================================================== */
const C = {
  port: +process.env.PORT || 3000,
  jwt: process.env.JWT_SECRET,
  db: process.env.DATABASE_URL,
  redis: process.env.REDIS_URL,
  gw: process.env.GATEWAY_URL,
  dev: process.env.DEV_SHOW_OTP === '1',
  rl: +process.env.RL_MAX || 10,
  maxSessions: +process.env.MAX_SESSIONS || 2,
};

if (!C.jwt || C.jwt.length < 32) throw new Error('JWT_SECRET (>=32 caracteres) requerido');

const pool = new pg.Pool({ connectionString: C.db });
const redis = new Redis(C.redis);
const scrypt = promisify(crypto.scrypt);

pool.on('error', e => console.error('[postgres]', e.message));
redis.on('error', e => console.error('[redis]', e.message));

/* ========================================================================
 * UTILIDADES
 * ===================================================================== */
// Error con status HTTP
const E = (s, m) => Object.assign(new Error(m), { s });

// Wrapper para handlers async
const h = f => (q, s, n) => f(q, s, n).catch(n);

// Hash SHA-256 en base64url
const sha = x => crypto.createHash('sha256').update(x).digest('base64url');

// Comparación en tiempo constante
const eq = (a, b) => {
  const A = Buffer.from(a);
  const B = Buffer.from(b);
  return A.length === B.length && crypto.timingSafeEqual(A, B);
};

// Contraseñas (scrypt + salt)
const hashPw = async p => {
  const s = crypto.randomBytes(16);
  return s.toString('hex') + ':' + (await scrypt(p, s, 64)).toString('hex');
};

const verifyPw = async (p, st) => {
  try {
    const [s, x] = String(st).split(':');
    if (!s || !x || x.length % 2) return false;

    const expected = Buffer.from(x, 'hex');
    const actual = await scrypt(p, Buffer.from(s, 'hex'), 64);

    return expected.length === actual.length && crypto.timingSafeEqual(actual, expected);
  } catch {
    return false;
  }
};

// Constantes de negocio
const PRICE = 25;
const SEATS = [...'ABCDE'].flatMap(r =>
  Array.from({ length: 10 }, (_, i) => r + (i + 1)),
);
const mask = e => e.replace(/^(.).*(@.*)$/, '$1***$2');
const uuid = /^[0-9a-f-]{36}$/i;

/* ========================================================================
 * LLAVES ECDSA P-256 PARA QR
 * (privada solo en servidor; pública se precarga en validadores)
 * ===================================================================== */
fs.mkdirSync('keys', { recursive: true });

if (!fs.existsSync('keys/qr_private.pem')) {
  const k = crypto.generateKeyPairSync('ec', { namedCurve: 'P-256' });
  fs.writeFileSync(
    'keys/qr_private.pem',
    k.privateKey.export({ type: 'pkcs8', format: 'pem' }),
    { mode: 0o600 },
  );
  fs.writeFileSync(
    'keys/qr_public.pem',
    k.publicKey.export({ type: 'spki', format: 'pem' }),
  );
}

const SK = crypto.createPrivateKey(fs.readFileSync('keys/qr_private.pem'));
const PUB = fs.readFileSync('keys/qr_public.pem', 'utf8');
const PK = crypto.createPublicKey(PUB);

const sign = a =>
  crypto
    .sign('sha256', Buffer.from(a), { key: SK, dsaEncoding: 'ieee-p1363' })
    .toString('base64url');

const vfy = (a, s) => {
  try {
    return crypto.verify(
      'sha256',
      Buffer.from(a),
      { key: PK, dsaEncoding: 'ieee-p1363' },
      Buffer.from(s, 'base64url'),
    );
  } catch {
    return false;
  }
};

/* ========================================================================
 * AUDITORÍA WORM CON CADENA DE HASHES
 * (serializada con advisory lock)
 * ===================================================================== */
async function audit(ev, actor, detail = '') {
  const c = await pool.connect();
  try {
    await c.query('BEGIN');
    await c.query('SELECT pg_advisory_xact_lock(42)');

    const prev =
      (await c.query('SELECT hash FROM audit_logs ORDER BY id DESC LIMIT 1')).rows[0]?.hash ||
      'GENESIS';
    const ts = new Date().toISOString();

    await c.query(
      'INSERT INTO audit_logs(ts,event,actor,detail,prev_hash,hash) VALUES($1,$2,$3,$4,$5,$6)',
      [ts, ev, String(actor), String(detail), prev, sha(prev + ts + ev + actor + detail)],
    );
    await c.query('COMMIT');
  } catch (e) {
    await c.query('ROLLBACK');
    throw e;
  } finally {
    c.release();
  }
}

async function chain() {
  let prev = 'GENESIS';
  const { rows } = await pool.query('SELECT * FROM audit_logs ORDER BY id');
  for (const e of rows) {
    if (e.prev_hash !== prev || e.hash !== sha(prev + e.ts + e.event + e.actor + e.detail)) {
      return e.id;
    }
    prev = e.hash;
  }
  return 0;
}

/* ========================================================================
 * APP + MIDDLEWARES GLOBALES
 * ===================================================================== */
const app = express();
app.disable('x-powered-by');

app.use(
  helmet({
    contentSecurityPolicy: false,
  }),
);
app.use((q, s, n) => {
  const gatewayUrl = new URL(`http://${q.get('host')}`);
  gatewayUrl.port = '4001';
  s.setHeader(
    'Content-Security-Policy',
    [
      "default-src 'self'",
      "script-src 'self' https://cdnjs.cloudflare.com",
      "style-src 'self'",
      "img-src 'self' data:",
      `connect-src 'self' ${gatewayUrl.origin}`,
      "object-src 'none'",
    ].join('; '),
  );
  n();
});
app.use(express.static('public'));
app.use(express.json({ limit: '10kb' }));

/* ---- WAF básico: rate limiting por IP en Redis ---- */
app.use(
  h(async (q, s, n) => {
    const k = 'rl:' + q.ip;
    const c = await redis.incr(k);
    if (c === 1) await redis.pexpire(k, 3000);
    if (c > C.rl) return s.status(429).json({ error: 'Too Many Requests' });
    n();
  }),
);

/* ---- API Gateway: validación JWT + RBAC ---- */
const auth = roles =>
  h(async (q, s, n) => {
    let p;
    try {
      p = jwt.verify((q.headers.authorization || '').replace(/^Bearer /, ''), C.jwt, {
        algorithms: ['HS256'],
      });
    } catch {
      throw E(401, 'Token inválido o expirado');
    }

    if (!(await redis.exists('sess:' + p.sid))) throw E(401, 'Sesión revocada');

    if (!roles.includes(p.role)) {
      await audit('ACCESS_DENIED', p.email, q.method + ' ' + q.path);
      throw E(403, 'Forbidden');
    }

    q.u = p;
    n();
  });

const ALL = ['cliente', 'validador', 'soporte', 'admin'];

/* ========================================================================
 * MS AUTENTICACIÓN
 * ===================================================================== */
app.post(
  '/api/auth/register',
  h(async (q, s) => {
    const { name, cedula, email, pass } = q.body;

    if (!/^[\p{L} ]{3,60}$/u.test(name || '')) throw E(400, 'Nombre inválido');
    if (!/^\d{10}$/.test(cedula || '')) throw E(400, 'Cédula: 10 dígitos');
    if (!/^[^\s@]{1,64}@[^\s@]+\.[^\s@]+$/.test(email || '')) throw E(400, 'Correo inválido');
    if (!/^(?=.*[A-Z])(?=.*[a-z])(?=.*\d)(?=.*[^\w\s]).{10,}$/.test(pass || '')) {
      throw E(400, 'Contraseña débil (10+, mayús., minús., número y símbolo)');
    }

    try {
      await pool.query(
        "INSERT INTO users(email,name,cedula_hash,cedula_last4,pass_hash,role) VALUES($1,$2,$3,$4,$5,'cliente')",
        [email.toLowerCase(), name, sha('pepper' + cedula), cedula.slice(-4), await hashPw(pass)],
      );
    } catch (e) {
      throw E(409, 'No se pudo registrar');
    }

    await audit('REGISTER', email, 'datos mínimos');
    s.status(201).json({ ok: true });
  }),
);

app.post(
  '/api/auth/login',
  h(async (q, s) => {
    const email = String(q.body.email || '').toLowerCase().slice(0, 80);
    const pass = String(q.body.pass || '');

    if (await redis.exists('lock:' + email)) throw E(429, 'Cuenta bloqueada 30 s');

    const u = (await pool.query('SELECT * FROM users WHERE email=$1', [email])).rows[0];
    const ok = u ? await verifyPw(pass, u.pass_hash) : (await hashPw(pass), false);

    if (!ok) {
      const n = await redis.incr('fail:' + email);
      await redis.expire('fail:' + email, 900);
      await audit('LOGIN_FAIL', email, q.ip);

      if (n >= 5) {
        await redis.set('lock:' + email, 1, 'EX', 30);
        await redis.del('fail:' + email);
        await audit('ACCOUNT_LOCK', email, q.ip);
      }
      throw E(401, 'Credenciales inválidas');
    }

    await redis.del('fail:' + email);

    const ch = crypto.randomUUID();
    const otp = String(crypto.randomInt(100000, 1000000));

    await redis.set('otp:' + ch, JSON.stringify({ id: u.id, otp, t: 0 }), 'EX', 120);
    console.log(`[OTP simulado ${email}] ${otp}`);

    s.json({ challenge: ch, ...(C.dev && { otp }) });
  }),
);

app.post(
  '/api/auth/verify',
  h(async (q, s) => {
    const k = 'otp:' + q.body.challenge;
    const raw = await redis.get(k);
    if (!raw) throw E(401, 'Desafío expirado');

    const c = JSON.parse(raw);

    if (++c.t > 3) {
      await redis.del(k);
      throw E(429, 'Demasiados intentos');
    }

    if (!eq(c.otp, String(q.body.otp || ''))) {
      await redis.set(k, JSON.stringify(c), 'KEEPTTL');
      throw E(401, 'OTP incorrecto');
    }

    await redis.del(k);

    const u = (await pool.query('SELECT id,email,role,name,cedula_last4 FROM users WHERE id=$1', [c.id])).rows[0];
    const sid = crypto.randomUUID();
    const zk = 'usess:' + u.id;

    await redis.set('sess:' + sid, u.id, 'EX', 86400);
    await redis.zadd(zk, Date.now(), sid);

    // máx. de dispositivos simultáneos por cuenta (configurable)
    while ((await redis.zcard(zk)) > C.maxSessions) {
      const [old] = await redis.zpopmin(zk);
      await redis.del('sess:' + old);
    }

    await audit('LOGIN_OK', u.email, sid);

    s.json({
      token: jwt.sign({ sub: String(u.id), email: u.email, role: u.role, sid }, C.jwt, {
        algorithm: 'HS256',
        expiresIn: '15m',
      }),
      user: {
        id: String(u.id),
        email: u.email,
        role: u.role,
        name: u.name,
        cedula_last4: u.cedula_last4,
      },
    });
  }),
);

app.post(
  '/api/auth/logout',
  auth(ALL),
  h(async (q, s) => {
    await redis.del('sess:' + q.u.sid);
    await redis.zrem('usess:' + q.u.sub, q.u.sid);
    await audit('LOGOUT', q.u.email, q.u.sid);
    s.json({ ok: true });
  }),
);

/* ========================================================================
 * MS SALA DE ESPERA (cola en Redis)
 * ===================================================================== */
const qs = async id => {
  if (await redis.exists('adm:' + id)) return { ok: true, pos: 0 };

  const r = await redis.zrank('queue', id);
  if (r === null) throw E(409, 'No está en la sala');

  return { ok: false, pos: r + 1 };
};

// Admite hasta 5 personas por segundo desde la cola
setInterval(async () => {
  try {
    for (const id of await redis.zrange('queue', 0, 4)) {
      await redis.set('adm:' + id, 1, 'EX', 600);
      await redis.zrem('queue', id);
    }
  } catch {}
}, 1000);

app.post(
  '/api/queue/join',
  auth(['cliente']),
  h(async (q, s) => {
    if (!(await redis.exists('adm:' + q.u.sub))) {
      await redis.zadd('queue', 'NX', Date.now(), q.u.sub);
    }
    await audit('QUEUE_JOIN', q.u.email);
    s.json(await qs(q.u.sub));
  }),
);

app.get(
  '/api/queue/status',
  auth(['cliente']),
  h(async (q, s) => s.json(await qs(q.u.sub))),
);

/* ========================================================================
 * MS BOLETERÍA
 * ===================================================================== */
const locks = () => redis.mget(SEATS.map(x => 'lock:seat:' + x));

/* ---- Asientos ---- */
app.get(
  '/api/seats',
  auth(['cliente']),
  h(async (q, s) => {
    const sold = new Set((await pool.query('SELECT seat FROM tickets')).rows.map(r => r.seat));
    const L = await locks();

    s.json({
      price: PRICE,
      seats: Object.fromEntries(
        SEATS.map((x, i) => [
          x,
          sold.has(x) ? 'sold' : L[i] ? (L[i] === q.u.sub ? 'mine' : 'locked') : 'free',
        ]),
      ),
    });
  }),
);

app.post(
  '/api/seats/lock',
  auth(['cliente']),
  h(async (q, s) => {
    const seat = q.body.seat;

    if (!(await redis.exists('adm:' + q.u.sub))) {
      throw E(403, 'Debe pasar por la sala de espera');
    }
    if (!SEATS.includes(seat)) throw E(400, 'Asiento inválido');
    if ((await pool.query('SELECT 1 FROM tickets WHERE seat=$1', [seat])).rowCount) {
      throw E(409, 'Asiento vendido');
    }

    const have = (
      await pool.query('SELECT count(*)::int n FROM tickets WHERE owner_id=$1', [q.u.sub])
    ).rows[0].n;
    const mine = (await locks()).filter(v => v === q.u.sub).length;

    if (have + mine >= 4) throw E(422, 'Límite: 4 boletos por cuenta');

    if (
      !(await redis.set('lock:seat:' + seat, q.u.sub, 'EX', 120, 'NX')) &&
      (await redis.get('lock:seat:' + seat)) !== q.u.sub
    ) {
      throw E(409, 'Asiento bloqueado');
    }

    await audit('SEAT_LOCK', q.u.email, seat);
    s.json({ ok: true, ttl: 120 });
  }),
);

app.post(
  '/api/seats/unlock',
  auth(['cliente']),
  h(async (q, s) => {
    const k = 'lock:seat:' + q.body.seat;
    if ((await redis.get(k)) === q.u.sub) await redis.del(k);
    s.json({ ok: true });
  }),
);

/* ---- Compra ---- */
app.post(
  '/api/tickets/buy',
  auth(['cliente']),
  h(async (q, s) => {
    const { seats, payToken } = q.body;

    if (
      !Array.isArray(seats) ||
      !seats.length ||
      seats.length > 4 ||
      new Set(seats).size !== seats.length ||
      typeof payToken !== 'string'
    ) {
      throw E(400, 'Solicitud inválida');
    }

    for (const x of seats) {
      if (!SEATS.includes(x)) throw E(400, 'Asiento inválido: ' + x);
      if ((await redis.get('lock:seat:' + x)) !== q.u.sub) {
        throw E(409, 'Bloqueo expirado: ' + x);
      }
    }

    const c = await pool.connect();
    let charged = false;
    let last4 = '';
    const ids = [];

    try {
      await c.query('BEGIN');

      const have = (
        await c.query('SELECT count(*)::int n FROM tickets WHERE owner_id=$1', [q.u.sub])
      ).rows[0].n;
      if (have + seats.length > 4) throw E(422, 'Límite: 4 boletos por cuenta');

      const sold = await c.query('SELECT seat FROM tickets WHERE seat = ANY($1::text[])', [seats]);
      if (sold.rowCount) throw E(409, 'Asiento ya vendido: ' + sold.rows[0].seat);

      const g = await fetch(C.gw + '/charge', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ token: payToken, amount: PRICE * seats.length }),
      });
      if (!g.ok) throw E(402, 'Pago rechazado');

      charged = true;
      ({ last4 } = await g.json());

      for (const x of seats) {
        const r = await c.query(
          'INSERT INTO tickets(seat,owner_id,pay_token,last4) VALUES($1,$2,$3,$4) RETURNING id',
          [x, q.u.sub, payToken, last4],
        );
        ids.push(r.rows[0].id);
      }

      await c.query('COMMIT');
    } catch (e) {
      await c.query('ROLLBACK').catch(() => {});

      if (charged) {
        await fetch(C.gw + '/refund', {
          method: 'POST',
          headers: { 'content-type': 'application/json' },
          body: JSON.stringify({ token: payToken }),
        }).catch(() => {});
      }

      throw e.s ? e : E(409, 'Asiento ya vendido');
    } finally {
      c.release();
    }

    for (const x of seats) await redis.del('lock:seat:' + x);

    await audit('PURCHASE', q.u.email, `${ids.join(',')} ${payToken} ****${last4}`);
    s.status(201).json({ ids, total: PRICE * seats.length });
  }),
);

/* ---- Mis boletos ---- */
app.get(
  '/api/tickets/mine',
  auth(['cliente']),
  h(async (q, s) =>
    s.json({
      tickets: (
        await pool.query('SELECT id,seat,used,last4 FROM tickets WHERE owner_id=$1', [q.u.sub])
      ).rows,
    }),
  ),
);

/* ---- QR firmado ---- */
app.post(
  '/api/tickets/qr',
  auth(['cliente']),
  h(async (q, s) => {
    const id = String(q.body.id || '');
    const t = uuid.test(id) && (await pool.query('SELECT * FROM tickets WHERE id=$1', [id])).rows[0];

    if (!t || String(t.owner_id) !== q.u.sub) {
      await audit('IDOR_BLOCKED', q.u.email, id.slice(0, 40));
      throw E(403, 'Forbidden');
    }

    const a = Buffer.from(JSON.stringify({ t: t.id, v: t.version, ts: Date.now() })).toString(
      'base64url',
    );

    s.json({ qr: a + '.' + sign(a), rotateSeconds: 15 });
  }),
);

/* ---- Transferencia ---- */
app.post(
  '/api/tickets/transfer',
  auth(['cliente']),
  h(async (q, s) => {
    const to = (
      await pool.query("SELECT id,email FROM users WHERE email=$1 AND role='cliente'", [
        String(q.body.to || '').toLowerCase(),
      ])
    ).rows[0];
    if (!to) throw E(404, 'Destinatario no registrado');
    if (String(to.id) === q.u.sub) throw E(400, 'No puedes transferirte un boleto a ti mismo');

    const target = (
      await pool.query('SELECT count(*)::int n FROM tickets WHERE owner_id=$1', [to.id])
    ).rows[0].n;
    if (target >= 4) throw E(422, 'El destinatario ya tiene 4 boletos');

    const r = await pool.query(
      'UPDATE tickets SET owner_id=$1,version=version+1 WHERE id=$2 AND owner_id=$3 AND used=false RETURNING id',
      [to.id, q.body.id, q.u.sub],
    );
    if (!r.rowCount) throw E(403, 'Forbidden');

    await audit('TRANSFER', q.u.email, `${q.body.id} -> ${to.email}`);
    s.json({ ok: true });
  }),
);

/* ========================================================================
 * PUERTA (validación con llave pública)
 * ===================================================================== */
app.get('/api/gate/pubkey', auth(['validador']), (q, s) => s.type('text/plain').send(PUB));

app.post(
  '/api/gate/scan',
  auth(['validador']),
  h(async (q, s) => {
    const [a, sg] = String(q.body.qr || '').split('.');

    const rej = async m => {
      await audit('SCAN_REJECT', q.u.email, m);
      throw E(422, m);
    };

    if (!a || !sg || !vfy(a, sg)) await rej('Firma inválida (QR falsificado)');

    let p;
    try {
      p = JSON.parse(Buffer.from(a, 'base64url'));
    } catch {
      await rej('QR malformado');
    }

    if (Math.abs(Date.now() - p.ts) > 30000) await rej('QR expirado (captura/replay)');

    const t = uuid.test(p.t) && (await pool.query('SELECT * FROM tickets WHERE id=$1', [p.t])).rows[0];
    if (!t) await rej('Boleto inexistente');
    if (t.version !== p.v) await rej('QR invalidado por transferencia');

    const r = await pool.query('UPDATE tickets SET used=true WHERE id=$1 AND used=false RETURNING seat', [
      t.id,
    ]);
    if (!r.rowCount) await rej('Boleto ya utilizado');

    await audit('ENTRY', q.u.email, t.id);
    s.json({ ok: true, seat: r.rows[0].seat });
  }),
);

/* ========================================================================
 * SOPORTE / ADMINISTRACIÓN
 * ===================================================================== */
app.post(
  '/api/support/ticket',
  auth(['soporte']),
  h(async (q, s) => {
    const id = String(q.body.id || '');
    const r =
      uuid.test(id) &&
      (
        await pool.query(
          'SELECT t.id,t.seat,t.used,u.email FROM tickets t JOIN users u ON u.id=t.owner_id WHERE t.id=$1',
          [id],
        )
      ).rows[0];

    if (!r) throw E(404, 'No encontrado');

    await audit('SUPPORT_VIEW', q.u.email, id);
    s.json({
      id: r.id,
      seat: r.seat,
      estado: r.used ? 'Ingresado' : 'Válido',
      titular: mask(r.email),
    });
  }),
);

app.get(
  '/api/admin/report',
  auth(['admin']),
  h(async (q, s) => {
    const r = (
      await pool.query('SELECT count(*)::int n,count(*) FILTER (WHERE used)::int u FROM tickets')
    ).rows[0];

    s.json({ vendidos: r.n, ingresos: r.n * PRICE, ingresaron: r.u });
  }),
);

app.get(
  '/api/admin/export',
  auth(['admin']),
  h(async (q, s) => {
    await audit('ALERT_EXPORT_REQUEST', q.u.email, 'exportación masiva');
    s.status(202).json({ estado: 'PENDIENTE', msg: 'Requiere aprobación gerencial + MFA' });
  }),
);

app.get(
  '/api/audit',
  auth(['admin']),
  h(async (q, s) =>
    s.json({
      broken: await chain(),
      entries: (await pool.query('SELECT * FROM audit_logs ORDER BY id DESC LIMIT 100')).rows,
    }),
  ),
);

// Demuestra que el rol app_user NO puede alterar el log
app.post(
  '/api/audit/edit',
  auth(ALL),
  h(async (q, s) => {
    try {
      await pool.query(
        "UPDATE audit_logs SET detail='x' WHERE id=(SELECT max(id) FROM audit_logs)",
      );
    } catch (e) {
      await audit('ALERT_TAMPER_ATTEMPT', q.u.email, 'pg ' + e.code);
      throw E(403, 'permission denied: audit_logs es WORM');
    }
    throw E(500, '¡WORM roto!');
  }),
);

/* ========================================================================
 * MANEJO DE ERRORES
 * ===================================================================== */
app.use((q, s) => s.status(404).json({ error: 'Not found' }));

app.use((e, q, s, n) => {
  if (!e.s && e.type !== 'entity.parse.failed') console.error(e);

  s.status(e.s || (e.type ? 400 : 500)).json({
    error: e.s ? e.message : e.type ? 'JSON inválido' : 'Error interno',
  });
});

/* ========================================================================
 * SEED (datos demo)
 * ===================================================================== */
async function seed() {
  if ((await pool.query('SELECT 1 FROM users LIMIT 1')).rowCount) return;

  const demoUsers = [
    ['cliente@demo.com', 'Ana Cliente', 'Cliente#2026', 'cliente'],
    ['otro@demo.com', 'Luis Otro', 'Otro#2026', 'cliente'],
    ['validador@demo.com', 'Puerta 7', 'Validador#2026', 'validador'],
    ['soporte@demo.com', 'Soporte N1', 'Soporte#2026', 'soporte'],
    ['admin@demo.com', 'Admin Estadio', 'Admin#2026', 'admin'],
  ];

  for (const [e, n, p, r] of demoUsers) {
    await pool.query(
      'INSERT INTO users(email,name,cedula_hash,cedula_last4,pass_hash,role) VALUES($1,$2,$3,$4,$5,$6)',
      [e, n, sha('pepper0000000000'), '0000', await hashPw(p), r],
    );
  }

  const o = (await pool.query("SELECT id FROM users WHERE email='otro@demo.com'")).rows[0].id;

  await pool.query(
    "INSERT INTO tickets(id,seat,owner_id,pay_token,last4) VALUES('00000000-0000-0000-0000-000000000001','E10',$1,'tok_seed','4242')",
    [o],
  );

  await audit('SEED', 'system', 'usuarios demo');
}

/* ========================================================================
 * ARRANQUE
 * ===================================================================== */
await seed();
app.listen(C.port, () => console.log('API segura en :' + C.port));