"use strict";

/*
 * ============================================================================
 * TicketSec · Interfaz web (JavaScript sin frameworks)
 * ============================================================================
 * Esta interfaz consume la API segura de boletería. No contiene lógica de
 * negocio sensible: solo presenta datos, captura entradas y llama a los
 * endpoints protegidos. Los controles reales (JWT, RBAC, WAF, WORM, QR
 * firmado, tokenización) viven en el backend.
 *
 * Organización del archivo:
 *   1. Configuración y estado
 *   2. Utilidades (DOM, formato, API, JWT)
 *   3. Componentes de interfaz (toast, modal, campos)
 *   4. Vistas por rol
 *   5. Acciones del usuario
 *   6. Renderizado y eventos globales
 *
 * Flujo principal del cliente:
 *   login -> verificación 2FA -> sala de espera -> asientos -> pago -> QR
 *
 * Roles y pestañas:
 *   cliente   -> Comprar, Mis boletos
 *   validador -> Puerta
 *   soporte   -> Soporte
 *   admin     -> Panel (reportes y auditoría)
 * ============================================================================
 */

/* ============================================================================
 * 1. CONFIGURACIÓN
 * ========================================================================== */

// Pasarela de pagos simulada. Es la única que recibe PAN/CVV.
const paymentGatewayUrl = new URL(window.location.href);
paymentGatewayUrl.port = '4001';
const PAYMENT_GATEWAY_URL = paymentGatewayUrl.origin;

// Precio unitario mostrado en la interfaz (el backend también lo valida).
const TICKET_PRICE = 25;

// Pestañas disponibles para cada rol. El backend aplica el RBAC real; esto
// solo evita mostrar opciones que el rol no puede usar.
const TABS_BY_ROLE = {
  cliente: [['buy', 'Comprar'], ['mine', 'Mis boletos']],
  validador: [['gate', 'Puerta']],
  soporte: [['sup', 'Soporte']],
  admin: [['adm', 'Panel']]
};

// Cuentas de demostración creadas por el backend al iniciar.
const DEMO_ACCOUNTS = [
  { label: 'Cliente', email: 'cliente@demo.com', pass: 'Cliente#2026' },
  { label: 'Validador', email: 'validador@demo.com', pass: 'Validador#2026' },
  { label: 'Soporte', email: 'soporte@demo.com', pass: 'Soporte#2026' },
  { label: 'Admin', email: 'admin@demo.com', pass: 'Admin#2026' }
];

/* ============================================================================
 * 2. ESTADO DE LA APLICACIÓN
 * ========================================================================== */

// Todo el estado de la pantalla vive aquí. Al recargar la página se pierde,
// salvo el tema elegido, que se guarda en localStorage.
const state = {
  token: null,            // JWT entregado por /api/auth/verify
  user: null,             // Payload decodificado del JWT (sub, email, role)
  currentTab: 'login',    // Pestaña visible
  challenge: null,        // Desafío temporal del login (paso 2FA)
  joinedQueue: false,     // Indica si el cliente ya pidió entrar a la cola
  selectedSeats: [],      // Asientos bloqueados por el usuario actual
  lastQr: '',             // Último QR generado (para el botón "Pegar")
  authTab: 'login',       // Sub-pestaña del acceso: login | register
  qrTimer: null,          // Intervalo que renueva el QR cada 15 segundos
  remainingSeats: 4       // Cupo restante según los boletos ya comprados
};

/* ============================================================================
 * 3. UTILIDADES
 * ========================================================================== */

/** Busca un elemento en el documento. */
const query = (selector, scope = document) => scope.querySelector(selector);

/** Busca un elemento por id. */
const byId = (id) => document.getElementById(id);

/** Lee el valor actual de un input. */
const inputValue = (id) => byId(id)?.value || '';

/** Escapa texto antes de insertarlo como HTML (previene XSS en la interfaz). */
const escapeHtml = (value) => String(value ?? '').replace(/[&<>"']/g, (char) => ({
  '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;'
}[char]));

/** Formatea un número como precio en dólares. */
const formatMoney = (amount) => '$' + Number(amount || 0).toLocaleString('es-EC');

/** Texto del botón de pago según los asientos seleccionados. */
const payButtonLabel = () => 'Pagar' + (state.selectedSeats.length
  ? ' ' + formatMoney(state.selectedSeats.length * TICKET_PRICE)
  : '');

/* ---------------------------------------------------------------------------
 * Notificaciones (toast)
 * ------------------------------------------------------------------------- */
let toastTimer;

function showToast(message, type = 'info') {
  const toast = byId('toast');
  toast.textContent = message;
  toast.className = 'toast show ' + type;
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => { toast.className = 'toast ' + type; }, 6000);
}

/* ---------------------------------------------------------------------------
 * Llamadas a la API
 * ------------------------------------------------------------------------- */
/**
 * Realiza una petición a la API y devuelve { status, body }.
 * Agrega automáticamente el token Bearer y cierra la sesión si la API
 * responde 401 (token vencido, alterado o sesión revocada).
 */
async function apiRequest(method, path, body) {
  const response = await fetch(path, {
    method,
    headers: {
      'content-type': 'application/json',
      ...(state.token ? { authorization: 'Bearer ' + state.token } : {})
    },
    body: body ? JSON.stringify(body) : undefined
  });

  let json = {};
  try { json = await response.json(); } catch { /* respuesta sin cuerpo */ }

  if (response.status === 401 && state.token) {
    logoutUser();
    showToast('Tu sesión expiró. Inicia sesión de nuevo.', 'warn');
  }

  return { status: response.status, body: json };
}

/* ---------------------------------------------------------------------------
 * Decodificación del JWT (solo para mostrar datos en pantalla)
 * ------------------------------------------------------------------------- */
/**
 * Lee el payload del JWT. No valida la firma: esa validación la hace el
 * backend en cada petición. Aquí solo se usa para conocer el rol y el correo.
 */
function decodeJwtPayload(token) {
  try {
    const base64 = token.split('.')[1].replace(/-/g, '+').replace(/_/g, '/');
    const padded = base64 + '='.repeat((4 - base64.length % 4) % 4);
    const bytes = Uint8Array.from(atob(padded), (char) => char.charCodeAt(0));
    return JSON.parse(new TextDecoder().decode(bytes));
  } catch {
    return null;
  }
}

/* ---------------------------------------------------------------------------
 * Generador de campos de formulario
 * ------------------------------------------------------------------------- */
function formField(id, label, type = 'text', options = {}) {
  const placeholder = options.placeholder ? ` placeholder="${escapeHtml(options.placeholder)}"` : '';
  const autocomplete = options.autocomplete ? ` autocomplete="${escapeHtml(options.autocomplete)}"` : ' autocomplete="off"';
  const inputMode = options.inputmode ? ` inputmode="${escapeHtml(options.inputmode)}"` : '';
  return `<label class="field"><span>${escapeHtml(label)}</span><input id="${id}" type="${type}"${placeholder}${autocomplete}${inputMode}></label>`;
}

/* ---------------------------------------------------------------------------
 * Modal genérico (se usa para mostrar el QR)
 * ------------------------------------------------------------------------- */
function openModal(html) {
  byId('modal-body').innerHTML = html;
  byId('modal').hidden = false;
  document.body.classList.add('no-scroll');
}

function closeModal() {
  const modal = byId('modal');
  if (!modal || modal.hidden) return;
  modal.hidden = true;
  byId('modal-body').innerHTML = '';
  document.body.classList.remove('no-scroll');
  clearInterval(state.qrTimer);
  state.qrTimer = null;
}

/* ============================================================================
 * 4. VISTAS POR ROL
 * ========================================================================== */

const views = {};

/** Botones que rellenan automáticamente las credenciales de demostración. */
function demoAccountChips() {
  return DEMO_ACCOUNTS.map(({ label, email, pass }) =>
    `<button type="button" class="chip" data-act="demo" data-em="${escapeHtml(email)}" data-pw="${escapeHtml(pass)}">${escapeHtml(label)}</button>`
  ).join('');
}

/** Formulario de inicio de sesión. */
function loginForm() {
  return `<h2>Iniciar sesión</h2>
    <p class="mut small">Acceso con verificación en dos pasos (2FA).</p>
    ${formField('em', 'Correo electrónico', 'email', { placeholder: 'tu@correo.com', autocomplete: 'username' })}
    ${formField('pw', 'Contraseña', 'password', { placeholder: '••••••••', autocomplete: 'current-password' })}
    <button class="btn primary block" type="button" data-act="login">Ingresar</button>
    <div class="demo">
      <span class="mut small">Cuentas demo</span>
      <div class="chips">${demoAccountChips()}</div>
    </div>`;
}

/** Formulario de registro con datos mínimos (LOPDP). */
function registerForm() {
  return `<h2>Crea tu cuenta</h2>
    <p class="mut small">Solo pedimos los datos mínimos necesarios (LOPDP).</p>
    ${formField('rn', 'Nombre completo', 'text', { placeholder: 'Ana Cliente' })}
    ${formField('rc', 'Cédula (10 dígitos)', 'text', { placeholder: '1712345678', inputmode: 'numeric' })}
    ${formField('re', 'Correo electrónico', 'email', { placeholder: 'tu@correo.com' })}
    ${formField('rp', 'Contraseña', 'password', { placeholder: '10+ caracteres, mayúscula, número y símbolo' })}
    <button class="btn primary block" type="button" data-act="reg">Crear cuenta</button>
    <p class="hint">La contraseña debe tener 10+ caracteres, mayúscula, minúscula, número y símbolo.</p>`;
}

/** Segundo factor del login: código OTP de 6 dígitos. */
function twoFactorView() {
  return `<div class="auth single"><section class="card auth-card narrow">
    <span class="badge info">Paso 2 de 2</span>
    <h2 class="mt">Verificación en dos pasos</h2>
    <p class="mut small">Ingresa el código de 6 dígitos. En modo demo también aparece en la consola del servidor.</p>
    ${formField('otp', 'Código OTP', 'text', { placeholder: '000000', inputmode: 'numeric' })}
    <button class="btn primary block" type="button" data-act="otp">Verificar código</button>
    <button class="btn ghost block" type="button" data-act="cancelOtp">Volver</button>
  </section></div>`;
}

/** Vista de acceso: formulario simple o el paso 2FA. */
views.login = async () => {
  if (state.challenge) return twoFactorView();

  return `<div class="auth">
    <section class="card auth-card">
      <h1 class="auth-title">TicketSec</h1>
      <p class="mut">Boletería segura</p>
      <div class="segmented" role="tablist">
        <button type="button" class="${state.authTab === 'login' ? 'on' : ''}" data-act="authtab" data-k="login">Ingresar</button>
        <button type="button" class="${state.authTab === 'register' ? 'on' : ''}" data-act="authtab" data-k="register">Crear cuenta</button>
      </div>
      ${state.authTab === 'login' ? loginForm() : registerForm()}
    </section>
  </div>`;
};

/** Tarjeta inicial de la sala de espera. */
function joinQueueCard() {
  return `<section class="card center narrow">
    <span class="badge info">Alta demanda</span>
    <h2 class="mt">Sala de espera virtual</h2>
    <p class="mut">Para proteger el inventario y evitar bots, el acceso se asigna por turnos. Mantén esta ventana abierta.</p>
    <button class="btn primary" type="button" data-act="join">Entrar a la sala</button>
  </section>`;
}

/** Tarjeta que muestra la posición en la cola mientras se espera turno. */
function queuePositionCard(position) {
  return `<section class="card center narrow">
    <div class="spinner" aria-hidden="true"></div>
    <h2>Estás en la fila</h2>
    <p class="mut small">Tu posición</p>
    <div class="queue-pos">${escapeHtml(position)}</div>
    <p class="mut small">La página se actualiza automáticamente. No cierres la ventana.</p>
  </section>`;
}

/** Tarjeta cuando la cuenta ya alcanzó el máximo de 4 boletos. */
function ticketLimitCard(count) {
  return `<section class="card center narrow">
    <span class="badge warn">Límite alcanzado</span>
    <h2 class="mt">Ya tienes ${escapeHtml(count)} boletos</h2>
    <p class="mut">Cada cuenta puede tener hasta 4 boletos. Revisa tus boletos o transfiere uno para liberar cupo.</p>
    <button class="btn primary" type="button" data-act="go" data-k="mine">Ver mis boletos</button>
  </section>`;
}

/**
 * Dibuja el mapa de asientos en filas (A-E) y columnas (1-10).
 * Estados posibles que entrega el backend:
 *   free   -> disponible
 *   mine   -> bloqueado por este usuario
 *   locked -> bloqueado por otro usuario
 *   sold   -> vendido
 */
function seatMap(seats) {
  const rows = [...new Set(Object.keys(seats).map((seat) => seat[0]))];

  return `<div class="seatmap-scroll" role="region" aria-label="Mapa de asientos" tabindex="0"><div class="seatmap">${rows.map((row) => {
    const seatsInRow = Object.keys(seats)
      .filter((seat) => seat[0] === row)
      .sort((a, b) => Number(a.slice(1)) - Number(b.slice(1)));

    return `<div class="seat-row"><span class="row-label">${escapeHtml(row)}</span>${seatsInRow.map((seat) => {
      const status = seats[seat];
      const disabled = status === 'free' || status === 'mine' ? '' : ' disabled';
      const statusLabel = {
        free: 'Libre', mine: 'Tu bloqueo', locked: 'Bloqueado', sold: 'Vendido'
      }[status] || status;

      return `<button type="button" class="seat ${escapeHtml(status)}"${disabled}
        data-act="seat" data-seat="${escapeHtml(seat)}" data-st="${escapeHtml(status)}"
        title="${escapeHtml(seat)}: ${escapeHtml(statusLabel)}"
        aria-label="Asiento ${escapeHtml(seat)}: ${escapeHtml(statusLabel)}">${escapeHtml(seat.slice(1))}</button>`;
    }).join('')}</div>`;
  }).join('')}</div></div>`;
}

/** Leyenda de colores del mapa de asientos. */
function seatLegend() {
  return `<div class="legend">
    <span><i class="sw free"></i>Libre</span>
    <span><i class="sw mine"></i>Tu bloqueo</span>
    <span><i class="sw locked"></i>Bloqueado</span>
    <span><i class="sw sold"></i>Vendido</span>
  </div>`;
}

/**
 * Vista de compra.
 * Si el usuario no ha entrado a la cola, muestra la tarjeta de entrada.
 * Si está en cola, consulta su posición y se refresca cada 1.5 s.
 * Cuando es admitido, carga el mapa de asientos y el formulario de pago.
 */
views.buy = async () => {
  if (!state.joinedQueue) return joinQueueCard();

  const queueStatus = await apiRequest('GET', '/api/queue/status');
  if (!state.token) return '';

  if (queueStatus.status !== 200) {
    state.joinedQueue = false;
    return `<section class="card center narrow">
      <h2>Fuera de la sala</h2>
      <p class="mut">${escapeHtml(queueStatus.body.error || 'No estás en la sala de espera.')}</p>
      <button class="btn primary" type="button" data-act="join">Volver a entrar</button>
    </section>`;
  }

  // Aún no es su turno: se vuelve a consultar automáticamente.
  if (!queueStatus.body.ok) {
    setTimeout(() => {
      if (state.currentTab === 'buy' && state.token) renderApp();
    }, 1500);
    return queuePositionCard(queueStatus.body.pos);
  }

  const [seatsResponse, mineResponse] = await Promise.all([
    apiRequest('GET', '/api/seats'),
    apiRequest('GET', '/api/tickets/mine')
  ]);
  if (!state.token) return '';

  const ownedTickets = mineResponse.body.tickets || [];
  const ownedCount = ownedTickets.length;
  state.remainingSeats = Math.max(0, 4 - ownedCount);

  // Si ya llegó al límite, se explica el motivo en lugar de dejar botones sin efecto.
  if (ownedCount >= 4) {
    state.selectedSeats = [];
    return ticketLimitCard(ownedCount);
  }

  const seats = seatsResponse.body.seats || {};
  // Los asientos "mine" son los bloqueos vigentes de este usuario.
  state.selectedSeats = Object.keys(seats).filter((seat) => seats[seat] === 'mine');
  if (state.selectedSeats.length > state.remainingSeats) {
    state.selectedSeats = state.selectedSeats.slice(0, state.remainingSeats);
  }

  return `<div class="buy-grid">
    <section class="card">
      <div class="card-head">
        <div><h2>Mapa de asientos</h2><p class="mut small">Haz clic en un asiento libre. El bloqueo dura 120 s.</p></div>
        <span class="badge info">${formatMoney(TICKET_PRICE)} c/u</span>
      </div>
      <p class="hint">Boletos de esta cuenta: ${escapeHtml(ownedCount)}/4 · Puedes elegir ${escapeHtml(state.remainingSeats)} más.</p>
      ${seatMap(seats)}
      ${seatLegend()}
    </section>
    <aside class="card checkout">
      <h2>Resumen de compra</h2>
      ${state.selectedSeats.length
        ? `<div class="selected">${state.selectedSeats.map((seat) => `<span class="seat-chip">${escapeHtml(seat)}</span>`).join('')}</div>`
        : `<p class="mut small">Aún no has seleccionado asientos.</p>`}
      <div class="total"><span>Total</span><strong>${formatMoney(state.selectedSeats.length * TICKET_PRICE)}</strong></div>
      <hr class="sep">
      <h3>Pago</h3>
      ${formField('pn', 'Número de tarjeta', 'text', { placeholder: '4242 4242 4242 4242', inputmode: 'numeric', autocomplete: 'cc-number' })}
      <div class="two">
        ${formField('pe', 'Vencimiento', 'text', { placeholder: 'MM/AA', inputmode: 'numeric', autocomplete: 'cc-exp' })}
        ${formField('pc', 'CVV', 'password', { placeholder: '123', inputmode: 'numeric', autocomplete: 'cc-csc' })}
      </div>
      <button class="btn primary block" type="button" data-act="pay"${state.selectedSeats.length ? '' : ' disabled'}>${payButtonLabel()}</button>
      <p class="hint">Tarjeta de prueba: 4242 4242 4242 4242 · 12/29 · 123</p>
    </aside>
  </div>`;
};

/** Vista "Mis boletos": lista los boletos del cliente autenticado. */
views.mine = async () => {
  const response = await apiRequest('GET', '/api/tickets/mine');
  if (!state.token) return '';

  const tickets = response.body.tickets || [];
  if (!tickets.length) {
    return `<section class="card center narrow">
      <h2>Aún no tienes boletos</h2>
      <p class="mut">Cuando completes una compra, tus entradas aparecerán aquí con su QR dinámico.</p>
      <button class="btn primary" type="button" data-act="go" data-k="buy">Comprar boletos</button>
    </section>`;
  }

  return `<div class="tickets-head"><h2>Mis boletos</h2><span class="badge info">${tickets.length} boleto(s)</span></div>
    <div class="tickets">${tickets.map((ticket) => `<article class="ticket ${ticket.used ? 'used' : ''}">
      <div class="ticket-main">
        <span class="seat-big">${escapeHtml(ticket.seat)}</span>
        <div><h3>Boleto ${escapeHtml(String(ticket.id).slice(0, 8))}</h3><p class="mut small">Tarjeta ****${escapeHtml(ticket.last4)}</p></div>
      </div>
      <div class="ticket-status">${ticket.used ? '<span class="badge ok">Ingresado</span>' : '<span class="badge info">Válido</span>'}</div>
      <div class="ticket-actions">
        <button class="btn small" type="button" data-act="qr" data-id="${escapeHtml(ticket.id)}"${ticket.used ? ' disabled' : ''}>Ver QR</button>
        <div class="transfer">
          <input id="tr${escapeHtml(ticket.id)}" placeholder="correo destino"${ticket.used ? ' disabled' : ''}>
          <button class="btn small ghost" type="button" data-act="xfer" data-id="${escapeHtml(ticket.id)}"${ticket.used ? ' disabled' : ''}>Transferir</button>
        </div>
      </div>
    </article>`).join('')}</div>`;
};

/** Vista del validador de puerta. */
views.gate = async () => `<div class="gate-grid">
  <section class="card">
    <div class="card-head">
      <div><h2>Validación de acceso</h2><p class="mut small">Escanea o pega el QR del asistente.</p></div>
    </div>
    <label class="field"><span>Contenido del QR</span><textarea id="qrin" rows="4" placeholder="Pega aquí el contenido del código QR..."></textarea></label>
    <div class="row">
      <button class="btn ghost" type="button" data-act="paste">Pegar último QR</button>
      <button class="btn primary" type="button" data-act="scan">Validar QR</button>
      <button class="btn ghost" type="button" data-act="pubkey">Descargar llave pública</button>
    </div>
    <div id="gr" class="scan-result"></div>
  </section>
</div>`;

/** Vista de soporte: consulta puntual de un boleto por ID. */
views.sup = async () => `<div class="support-grid">
  <section class="card">
    <h2>Consulta de boleto</h2>
    <p class="mut small">Consulta el estado de un boleto por su ID.</p>
    ${formField('sid', 'ID del boleto', 'text', { placeholder: '00000000-0000-0000-0000-000000000001' })}
    <button class="btn primary" type="button" data-act="sup">Consultar</button>
    <div id="sr" class="scan-result"></div>
  </section>
</div>`;

/** Tarjeta de indicador (KPI) del panel administrativo. */
function kpiCard(label, value, tone = '') {
  return `<article class="card kpi ${tone}"><span class="mut">${escapeHtml(label)}</span><strong>${escapeHtml(value)}</strong></article>`;
}

/** Vista del panel de administración: reporte agregado + auditoría. */
views.adm = async () => {
  const [reportResponse, auditResponse] = await Promise.all([
    apiRequest('GET', '/api/admin/report'),
    apiRequest('GET', '/api/audit')
  ]);
  if (!state.token) return '';

  const report = reportResponse.body || {};
  const audit = auditResponse.body || {};
  const brokenAt = audit.broken || 0;
  const entries = audit.entries || [];

  return `<div class="kpis">
    ${kpiCard('Boletos vendidos', report.vendidos ?? '—')}
    ${kpiCard('Ingresos', report.ingresos != null ? formatMoney(report.ingresos) : '—')}
    ${kpiCard('Asistentes ingresados', report.ingresaron ?? '—')}
    ${kpiCard('Integridad del log', brokenAt ? `Rota #${brokenAt}` : 'Íntegra', brokenAt ? 'bad' : 'ok')}
  </div>
  <div class="admin-grid">
    <section class="card">
      <div class="card-head">
        <div><h2>Auditoría</h2><p class="mut small">Registro de eventos</p></div>
        <span class="badge ${brokenAt ? 'bad' : 'ok'}">${brokenAt ? 'Cadena rota' : 'Cadena íntegra'}</span>
      </div>
      <div class="table-wrap">
        <table>
          <thead><tr><th>#</th><th>Hora</th><th>Evento</th><th>Actor</th><th>Detalle</th><th>Hash</th></tr></thead>
          <tbody>${entries.map((entry) => `<tr>
            <td>${escapeHtml(entry.id)}</td>
            <td>${escapeHtml(String(entry.ts).slice(11, 19))}</td>
            <td><span class="badge info">${escapeHtml(entry.event)}</span></td>
            <td>${escapeHtml(entry.actor)}</td>
            <td>${escapeHtml(entry.detail)}</td>
            <td class="mono">${escapeHtml(String(entry.hash).slice(0, 10))}</td>
          </tr>`).join('') || '<tr><td colspan="6" class="mut">Sin registros.</td></tr>'}</tbody>
        </table>
      </div>
    </section>
    <aside class="card">
      <h3>Acciones</h3>
      <button class="btn ghost block" type="button" data-act="exp">Solicitar exportación</button>
      <button class="btn danger block" type="button" data-act="edit">Intentar editar el log</button>
      <hr class="sep">
      <button class="btn ghost block" type="button" data-act="refresh">Actualizar panel</button>
    </aside>
  </div>`;
};

/* ============================================================================
 * 5. ACCIONES DEL USUARIO
 * ========================================================================== */

const actions = {
  /** Vuelve al inicio o a la primera pestaña del rol. */
  home() {
    if (!state.user) { state.currentTab = 'login'; renderApp(); return; }
    state.currentTab = TABS_BY_ROLE[state.user.role]?.[0]?.[0] || 'login';
    renderApp();
  },

  /** Cambia entre "Ingresar" y "Crear cuenta". */
  authtab(dataset) {
    state.authTab = dataset.k;
    renderApp();
  },

  /** Rellena el formulario con una cuenta demo. */
  demo(dataset) {
    if (byId('em')) byId('em').value = dataset.em;
    if (byId('pw')) byId('pw').value = dataset.pw;
  },

  /** Navegación entre pestañas del rol actual. */
  go(dataset) {
    const allowedTabs = state.user ? (TABS_BY_ROLE[state.user.role] || []) : [];
    if (!allowedTabs.some(([key]) => key === dataset.k)) return;
    state.currentTab = dataset.k;
    closeModal();
    renderApp();
  },

  /** Paso 1 del login: correo + contraseña -> desafío 2FA. */
  async login() {
    const email = inputValue('em').trim();
    const password = inputValue('pw');
    if (!email || !password) return showToast('Ingresa tu correo y contraseña.', 'warn');

    const button = query('[data-act="login"]');
    if (button) { button.disabled = true; button.textContent = 'Verificando…'; }

    const response = await apiRequest('POST', '/api/auth/login', { email, pass: password });

    if (response.status !== 200) {
      showToast(response.body.error || 'No se pudo iniciar sesión.', 'error');
      if (button) { button.disabled = false; button.textContent = 'Ingresar'; }
      return;
    }

    state.challenge = response.body.challenge;
    if (response.body.otp) showToast('Código OTP (modo demo): ' + response.body.otp, 'info');
    renderApp();
  },

  /** Paso 2 del login: verifica el OTP y guarda el JWT. */
  async otp() {
    const code = inputValue('otp').trim();
    if (!/^\d{6}$/.test(code)) return showToast('El OTP debe tener 6 dígitos.', 'warn');

    const response = await apiRequest('POST', '/api/auth/verify', {
      challenge: state.challenge,
      otp: code
    });
    if (response.status !== 200) return showToast(response.body.error || 'Código inválido.', 'error');

    state.token = response.body.token;
    state.user = decodeJwtPayload(state.token);
    if (!state.user) {
      state.token = null;
      return showToast('Token inválido.', 'error');
    }

    state.challenge = null;
    state.joinedQueue = false;
    state.selectedSeats = [];
    state.currentTab = TABS_BY_ROLE[state.user.role]?.[0]?.[0] || 'login';
    showToast('Sesión iniciada como ' + state.user.role + '.', 'ok');
    renderApp();
  },

  /** Cancela el 2FA y vuelve al formulario de login. */
  cancelOtp() {
    state.challenge = null;
    renderApp();
  },

  /** Registro de un nuevo cliente. */
  async reg() {
    const body = {
      name: inputValue('rn').trim(),
      cedula: inputValue('rc').trim(),
      email: inputValue('re').trim(),
      pass: inputValue('rp')
    };
    if (!body.name || !body.cedula || !body.email || !body.pass) {
      return showToast('Completa todos los campos.', 'warn');
    }
    if (!/^\d{10}$/.test(body.cedula)) {
      return showToast('La cédula debe tener 10 dígitos numéricos.', 'warn');
    }

    const button = query('[data-act="reg"]');
    if (button) { button.disabled = true; button.textContent = 'Creando…'; }

    const response = await apiRequest('POST', '/api/auth/register', body);
    if (response.status === 201) {
      showToast('Cuenta creada. Ya puedes iniciar sesión.', 'ok');
      state.authTab = 'login';
      renderApp();
    } else {
      showToast(response.body.error || 'No se pudo crear la cuenta.', 'error');
    }
    if (button) { button.disabled = false; button.textContent = 'Crear cuenta'; }
  },

  /** Entra a la sala de espera virtual. */
  async join() {
    const response = await apiRequest('POST', '/api/queue/join');
    if (response.status !== 200) return showToast(response.body.error || 'No se pudo entrar a la sala.', 'error');
    state.joinedQueue = true;
    renderApp();
  },

  /**
   * Bloquea o libera un asiento.
   * Si el asiento ya es "mine", el clic lo libera; si está libre, lo bloquea.
   */
  async seat(dataset) {
    const action = dataset.st === 'mine' ? 'unlock' : 'lock';

    if (action === 'lock' && state.selectedSeats.length >= state.remainingSeats) {
      return showToast('Solo puedes seleccionar ' + state.remainingSeats + ' asiento(s) más.', 'warn');
    }

    const scrollY = window.scrollY;
    const response = await apiRequest('POST', '/api/seats/' + action, { seat: dataset.seat });

    if (response.status === 200) {
      showToast(action === 'lock'
        ? 'Asiento ' + dataset.seat + ' bloqueado por 120 s.'
        : 'Asiento ' + dataset.seat + ' liberado.', 'ok');
    } else {
      showToast(response.body.error || 'No se pudo actualizar el asiento.', 'error');
    }

    await renderApp();
    window.scrollTo(0, scrollY);
  },

  /**
   * Pago: primero tokeniza la tarjeta en la pasarela externa y luego envía
   * únicamente el token al backend. El PAN/CVV nunca llega a la API del estadio.
   */
  async pay() {
    if (!state.selectedSeats.length) return showToast('Selecciona al menos un asiento.', 'warn');

    const cardNumber = inputValue('pn').replace(/\s/g, '');
    const expiry = inputValue('pe').trim();
    const cvv = inputValue('pc').trim();
    if (!cardNumber || !expiry || !cvv) return showToast('Completa los datos de la tarjeta.', 'warn');

    const button = query('[data-act="pay"]');
    if (button) { button.disabled = true; button.textContent = 'Procesando pago…'; }

    let paymentToken;
    try {
      const gatewayResponse = await fetch(PAYMENT_GATEWAY_URL + '/tokenize', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ pan: cardNumber, exp: expiry, cvv })
      });
      const gatewayBody = await gatewayResponse.json().catch(() => ({}));
      if (!gatewayResponse.ok) throw new Error(gatewayBody.error || 'Tarjeta rechazada');
      paymentToken = gatewayBody;
    } catch (error) {
      showToast('Pasarela: ' + error.message, 'error');
      if (button) { button.disabled = false; button.textContent = payButtonLabel(); }
      return;
    }

    const response = await apiRequest('POST', '/api/tickets/buy', {
      seats: state.selectedSeats,
      payToken: paymentToken.token
    });

    if (response.status !== 201) {
      showToast(response.body.error || 'Compra rechazada.', 'error');
      if (button) { button.disabled = false; button.textContent = payButtonLabel(); }
      return;
    }

    state.selectedSeats = [];
    state.currentTab = 'mine';
    showToast('Compra confirmada · ' + paymentToken.token + ' · ****' + paymentToken.last4, 'ok');
    renderApp();
  },

  /**
   * Abre el modal con el QR dinámico.
   * El backend firma el contenido con ECDSA P-256 y lo renueva cada 15 s.
   * Aquí solo se dibuja el QR y se lleva la cuenta regresiva.
   */
  qr(dataset) {
    clearInterval(state.qrTimer);

    openModal(`<h2>Tu QR dinámico</h2>
      <p class="mut small">Firmado con ECDSA P-256 y válido por 30 s.</p>
      <div id="qrbox" class="qrbox"><div class="spinner"></div></div>
      <p class="qr-count">Se renueva en <b id="qrcount">15</b> s</p>`);

    let secondsLeft = 15;

    const drawQr = async () => {
      const qrBox = byId('qrbox');
      if (!qrBox) {
        clearInterval(state.qrTimer);
        state.qrTimer = null;
        return;
      }

      const response = await apiRequest('POST', '/api/tickets/qr', { id: dataset.id });
      if (response.status !== 200) {
        qrBox.innerHTML = '<p class="bad">' + escapeHtml(response.body.error || 'No se pudo generar el QR.') + '</p>';
        return;
      }

      state.lastQr = response.body.qr;
      qrBox.innerHTML = '<div id="qrc"></div>';

      if (window.QRCode) {
        new QRCode(byId('qrc'), {
          text: response.body.qr,
          width: 220,
          height: 220,
          correctLevel: QRCode.CorrectLevel.L
        });
      } else {
        // Sin la librería externa, se muestra el contenido para no romper el flujo.
        byId('qrc').textContent = response.body.qr;
      }

      secondsLeft = 15;
      const counter = byId('qrcount');
      if (counter) counter.textContent = secondsLeft;
    };

    drawQr();
    state.qrTimer = setInterval(() => {
      if (!byId('qrcount')) {
        clearInterval(state.qrTimer);
        state.qrTimer = null;
        return;
      }
      secondsLeft--;
      const counter = byId('qrcount');
      if (counter) counter.textContent = Math.max(secondsLeft, 0);
      if (secondsLeft <= 0) drawQr();
    }, 1000);
  },

  /** Transfiere un boleto a otro cliente; invalida el QR anterior. */
  async xfer(dataset) {
    const destination = inputValue('tr' + dataset.id).trim();
    if (!destination) return showToast('Ingresa el correo del destinatario.', 'warn');

    const response = await apiRequest('POST', '/api/tickets/transfer', {
      id: dataset.id,
      to: destination
    });
    if (response.status !== 200) return showToast(response.body.error || 'No se pudo transferir.', 'error');

    showToast('Boleto transferido. El QR anterior quedó invalidado.', 'ok');
    renderApp();
  },

  /** Pega en la puerta el último QR generado en esta sesión (modo demo). */
  paste() {
    if (byId('qrin')) byId('qrin').value = state.lastQr;
  },

  /** Envía el contenido del QR al backend para validar firma, vigencia y uso. */
  async scan() {
    const qr = inputValue('qrin').trim();
    if (!qr) return showToast('Pega el contenido del QR.', 'warn');

    const response = await apiRequest('POST', '/api/gate/scan', { qr });
    const resultBox = byId('gr');
    if (!resultBox) return;

    resultBox.innerHTML = response.status === 200
      ? `<div class="result ok"><strong>Acceso permitido</strong><span>Asiento ${escapeHtml(response.body.seat)}</span></div>`
      : `<div class="result bad"><strong>Acceso denegado</strong><span>${escapeHtml(response.body.error || 'QR inválido')}</span></div>`;
  },

  /** Descarga la llave pública para validar QR sin conexión. */
  async pubkey() {
    try {
      const response = await fetch('/api/gate/pubkey', {
        headers: { authorization: 'Bearer ' + state.token }
      });
      if (!response.ok) throw new Error('No autorizado');

      const publicKey = await response.text();
      const downloadUrl = URL.createObjectURL(new Blob([publicKey], { type: 'text/plain' }));
      const link = document.createElement('a');
      link.href = downloadUrl;
      link.download = 'qr_public.pem';
      document.body.appendChild(link);
      link.click();
      link.remove();
      setTimeout(() => URL.revokeObjectURL(downloadUrl), 1000);
      showToast('Llave pública descargada para validación offline.', 'ok');
    } catch (error) {
      showToast(error.message, 'error');
    }
  },

  /** Consulta puntual de soporte (datos mínimos y auditada). */
  async sup() {
    const ticketId = inputValue('sid').trim();
    if (!ticketId) return showToast('Ingresa el ID del boleto.', 'warn');

    const response = await apiRequest('POST', '/api/support/ticket', { id: ticketId });
    const resultBox = byId('sr');
    if (!resultBox) return;

    resultBox.innerHTML = response.status === 200
      ? `<div class="result info"><strong>Boleto ${escapeHtml(String(response.body.id).slice(0, 8))}</strong><span>Asiento ${escapeHtml(response.body.seat)} · ${escapeHtml(response.body.estado)} · Titular ${escapeHtml(response.body.titular)}</span></div>`
      : `<div class="result bad"><strong>No encontrado</strong><span>${escapeHtml(response.body.error || 'Boleto inexistente')}</span></div>`;
  },

  /** Solicita una exportación masiva (queda pendiente de aprobación). */
  async exp() {
    const response = await apiRequest('GET', '/api/admin/export');
    showToast(response.body.msg || response.body.error || 'Solicitud registrada.', 'info');
  },

  /** Intenta alterar el log para demostrar que la tabla WORM lo impide. */
  async edit() {
    const response = await apiRequest('POST', '/api/audit/edit');
    showToast('Intento bloqueado (HTTP ' + response.status + '): ' + (response.body.error || 'WORM activo'), 'error');
    renderApp();
  },

  /** Recarga el panel actual. */
  refresh() {
    renderApp();
  },

  closeModal,

  /** Cierra la sesión y limpia el estado local. */
  logout: logoutUser
};

/** Limpia la sesión, los temporizadores y vuelve al login. */
function logoutUser() {
  clearInterval(state.qrTimer);
  state.qrTimer = null;
  closeModal();
  state.token = null;
  state.user = null;
  state.challenge = null;
  state.joinedQueue = false;
  state.selectedSeats = [];
  state.lastQr = '';
  state.currentTab = 'login';
  state.authTab = 'login';
  renderApp();
}

/* ============================================================================
 * 6. RENDERIZADO Y EVENTOS GLOBALES
 * ========================================================================== */

// Evita que una vista lenta sobrescriba una renderización más reciente
// (por ejemplo, cuando una petición responde 401 y se vuelve al login).
let renderVersion = 0;

/**
 * Dibuja la barra de navegación, el usuario conectado y la vista actual.
 * La vista se obtiene de `views` según `state.currentTab`.
 */
async function renderApp() {
  const version = ++renderVersion;
  const role = state.user?.role;
  const tabs = role ? (TABS_BY_ROLE[role] || []) : [];
  const nav = byId('nav');

  nav.hidden = !tabs.length;
  nav.innerHTML = tabs.map(([key, label]) =>
    `<button type="button" class="tab ${state.currentTab === key ? 'on' : ''}" data-act="go" data-k="${key}">${label}</button>`
  ).join('');

  byId('user').innerHTML = role
    ? `<span class="user-mail">${escapeHtml(state.user.email)}</span><span class="badge role">${escapeHtml(role)}</span><button class="btn small ghost" type="button" data-act="logout">Salir</button>`
    : '';

  const currentView = views[state.currentTab] || views.login;

  try {
    const html = await currentView();
    if (version !== renderVersion) return; // ya hay una renderización más nueva
    byId('main').innerHTML = html;
  } catch (error) {
    if (version !== renderVersion) return;
    byId('main').innerHTML = `<section class="card center"><h2>No se pudo cargar la vista</h2><p class="mut small">${escapeHtml(error.message)}</p></section>`;
  }
}

/* ---------------------------------------------------------------------------
 * Delegación de clics: cualquier elemento con data-act ejecuta actions[accion]
 * ------------------------------------------------------------------------- */
document.addEventListener('click', (event) => {
  const element = event.target.closest('[data-act]');
  if (!element) return;
  const action = actions[element.dataset.act];
  if (typeof action === 'function') action(element.dataset);
});

/* ---------------------------------------------------------------------------
 * Formato automático de campos sensibles mientras el usuario escribe
 * ------------------------------------------------------------------------- */
document.addEventListener('input', (event) => {
  const input = event.target;

  if (input.id === 'pn') {
    // Número de tarjeta: solo dígitos, agrupados de 4 en 4.
    const digits = input.value.replace(/\D/g, '').slice(0, 19);
    input.value = digits.replace(/(\d{4})(?=\d)/g, '$1 ');
  } else if (input.id === 'pe') {
    // Vencimiento: MM/AA.
    const digits = input.value.replace(/\D/g, '').slice(0, 4);
    input.value = digits.length > 2 ? digits.slice(0, 2) + '/' + digits.slice(2) : digits;
  } else if (input.id === 'pc') {
    // CVV: 3 o 4 dígitos.
    input.value = input.value.replace(/\D/g, '').slice(0, 4);
  } else if (input.id === 'rc') {
    // Cédula ecuatoriana: 10 dígitos.
    input.value = input.value.replace(/\D/g, '').slice(0, 10);
  } else if (input.id === 'otp') {
    // Código OTP: 6 dígitos.
    input.value = input.value.replace(/\D/g, '').slice(0, 6);
  }
});

/* ---------------------------------------------------------------------------
 * Enter envía el formulario correspondiente; Escape cierra el modal
 * ------------------------------------------------------------------------- */
document.addEventListener('keydown', (event) => {
  if (event.key === 'Escape') closeModal();
  if (event.key !== 'Enter') return;

  const actionByField = {
    em: 'login', pw: 'login', otp: 'otp',
    rn: 'reg', rc: 'reg', re: 'reg', rp: 'reg',
    pn: 'pay', pe: 'pay', pc: 'pay',
    sid: 'sup'
  };

  const actionName = actionByField[event.target.id];
  if (actionName && typeof actions[actionName] === 'function') {
    event.preventDefault();
    actions[actionName]();
  }
});

/* Cerrar el modal al hacer clic fuera de la tarjeta. */
byId('modal').addEventListener('click', (event) => {
  if (event.target.id === 'modal') closeModal();
});

/* Arranque de la aplicación. */
renderApp();
