// Pasarela de pagos SIMULADA (proveedor externo PCI-DSS).
// Única que ve el PAN/CVV.
import express from 'express';
import crypto from 'node:crypto';

/* ========================================================================
 * CONFIGURACIÓN
 * ===================================================================== */
const vault = new Map();
const app = express();

app.use(express.json({ limit: '2kb' }));

// CORS: permite solo a interfaces servidas desde el mismo host (red local).
app.use((q, s, n) => {
  const origin = q.get('origin');
  if (origin) {
    try {
      const parsedOrigin = new URL(origin);
      const originHostname = parsedOrigin.hostname.replace(/^\[|\]$/g, '');
      const requestHostname = q.hostname.replace(/^\[|\]$/g, '');
      if (
        parsedOrigin.protocol === 'http:' &&
        originHostname === requestHostname &&
        parsedOrigin.origin === origin
      ) {
        s.set({
          'access-control-allow-origin': origin,
          'access-control-allow-headers': 'content-type',
          'vary': 'Origin',
        });
      }
    } catch (error) {
      if (!(error instanceof TypeError)) throw error;
    }
  }
  q.method === 'OPTIONS' ? s.sendStatus(204) : n();
});

/* ========================================================================
 * UTILIDADES
 * ===================================================================== */
// Validación de tarjeta con el algoritmo de Luhn
const luhn = n => {
  let s = 0;
  let d = false;

  for (let i = n.length - 1; i >= 0; i--) {
    let x = +n[i];
    if (d) {
      x *= 2;
      if (x > 9) x -= 9;
    }
    s += x;
    d = !d;
  }

  return s % 10 === 0;
};

/* ========================================================================
 * ENDPOINTS
 * ===================================================================== */
app.post('/tokenize', (q, s) => {
  const n = String(q.body.pan || '').replace(/\s/g, '');

  if (
    !/^\d{13,19}$/.test(n) ||
    !luhn(n) ||
    !/^(0[1-9]|1[0-2])\/\d{2}$/.test(q.body.exp) ||
    !/^\d{3,4}$/.test(q.body.cvv)
  ) {
    return s.status(422).json({ error: 'Tarjeta inválida' });
  }

  const t = 'tok_' + crypto.randomBytes(9).toString('base64url');
  vault.set(t, { last4: n.slice(-4), used: false });

  s.json({ token: t, last4: n.slice(-4) });
});

app.post('/charge', (q, s) => {
  const record = vault.get(q.body.token);
  if (!record || record.used) return s.status(402).json({ error: 'Token inválido o ya utilizado' });

  record.used = true;
  s.json({ ok: true, last4: record.last4 });
});

app.post('/refund', (q, s) => {
  const record = vault.get(q.body.token);
  if (!record || !record.used) return s.status(402).json({ error: 'Nada que reembolsar' });

  record.used = false;
  s.json({ ok: true });
});

/* ========================================================================
 * ARRANQUE
 * ===================================================================== */
app.listen(4001, () => console.log('Gateway simulado en :4001'));