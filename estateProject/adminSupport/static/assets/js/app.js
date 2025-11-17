
/* ---------------- Robust FullCalendar loader & waiter ---------------- */
(function () {
  // Expose a loader under window.PECalendarLoader
  const FC_VERSION = '6.1.19'; // use a stable 6.x global bundle
  const JS_CANDIDATES = [
    `https://cdn.jsdelivr.net/npm/fullcalendar@${FC_VERSION}/index.global.min.js`,
    `https://unpkg.com/fullcalendar@${FC_VERSION}/index.global.min.js`,
    `https://cdn.jsdelivr.net/npm/fullcalendar@${FC_VERSION}/main.min.js`
  ];

  function loadScriptUrl(url, timeout = 7000) {
    return new Promise((resolve, reject) => {
      // If FullCalendar already available, resolve immediately
      if (window.FullCalendar && window.FullCalendar.Calendar) return resolve(window.FullCalendar);

      const s = document.createElement('script');
      s.src = url;
      s.async = true;
      let timer = setTimeout(() => {
        s.onerror = s.onload = null;
        try { s.remove(); } catch (_) { }
        reject(new Error('Timeout loading ' + url));
      }, timeout);

      s.onload = () => {
        clearTimeout(timer);
        // short tick to let global attach
        setTimeout(() => {
          if (window.FullCalendar && window.FullCalendar.Calendar) return resolve(window.FullCalendar);
          // Some CDNs might expose differently — check common names
          if (window.FullCalendar) return resolve(window.FullCalendar);
          // otherwise fail
          reject(new Error('Loaded script but FullCalendar global not found: ' + url));
        }, 20);
      };
      s.onerror = (e) => {
        clearTimeout(timer);
        try { s.remove(); } catch (_) { }
        reject(new Error('Error loading script ' + url));
      };
      document.head.appendChild(s);
    });
  }

  async function tryLoadFullCalendar() {
    // If already loaded, return immediately
    if (window.FullCalendar && window.FullCalendar.Calendar) return window.FullCalendar;
    let lastErr = null;
    for (const u of JS_CANDIDATES) {
      try {
        const fc = await loadScriptUrl(u, 8000);
        if (fc && fc.Calendar) return fc;
      } catch (err) {
        console.warn('[PE] FullCalendar load candidate failed:', u, err);
        lastErr = err;
      }
    }
    throw lastErr || new Error('Failed to load FullCalendar from known CDNs');
  }

  // Waiter utility: polls for FullCalendar global
  function waitForFullCalendar(timeout = 5000, interval = 120) {
    return new Promise((resolve) => {
      const start = Date.now();
      (function check() {
        if ((typeof FullCalendar !== 'undefined' && FullCalendar && FullCalendar.Calendar) || (window.FullCalendar && window.FullCalendar.Calendar))
          return resolve(true);
        if (Date.now() - start > timeout) return resolve(false);
        setTimeout(check, interval);
      })();
    });
  }

  // The exported function: ensures FullCalendar then runs callback
  async function ensureFullCalendarThen(callback) {
    // If already present
    if ((typeof FullCalendar !== 'undefined' && FullCalendar && typeof FullCalendar.Calendar !== 'undefined') ||
      (window.FullCalendar && typeof window.FullCalendar.Calendar !== 'undefined')) {
      try { if (typeof callback === 'function') callback(); } catch (e) { console.error('[PE] callback error', e); }
      return;
    }

    // If a script tag referencing fullcalendar is present, attach listeners and poll
    const existing = Array.from(document.getElementsByTagName('script'))
      .find(s => s.src && s.src.toLowerCase().includes('fullcalendar'));
    if (existing) {
      if (existing.getAttribute('data-pe-fc-loaded') === '1') {
        try { if (typeof callback === 'function') callback(); } catch (e) { console.error('[PE] callback error', e); }
        return;
      }
      existing.addEventListener('load', function onLoad() {
        existing.setAttribute('data-pe-fc-loaded', '1');
        waitForFullCalendar(4000).then(ok => {
          if (ok) try { if (typeof callback === 'function') callback(); } catch (e) { console.error('[PE] callback error', e); }
          else showCalendarLoadError();
        });
      });
      existing.addEventListener('error', function onError(ev) {
        console.error('[PE] FullCalendar script failed to load (existing).', ev);
        showCalendarLoadError();
      });
      // fallback poll
      waitForFullCalendar(3000).then(ok => {
        if (ok) {
          existing.setAttribute('data-pe-fc-loaded', '1');
          try { if (typeof callback === 'function') callback(); } catch (e) { console.error('[PE] callback error', e); }
        } else {
          // attempt to load from CDN candidates
          tryLoadFullCalendar().then(() => {
            try { if (typeof callback === 'function') callback(); } catch (e) { console.error('[PE] callback error', e); }
          }).catch(err => {
            console.error('[PE] fallback load failed', err);
            showCalendarLoadError();
          });
        }
      });
      return;
    }

    // Otherwise dynamically attempt to load FullCalendar from known CDNs sequentially
    try {
      await tryLoadFullCalendar();
      // mark any loaded script
      const s = Array.from(document.getElementsByTagName('script')).find(sc => sc.src && sc.src.includes('fullcalendar'));
      if (s) s.setAttribute('data-pe-fc-loaded', '1');
      // wait shortly and run callback
      waitForFullCalendar(3000).then(ok => {
        if (ok) {
          try { if (typeof callback === 'function') callback(); } catch (e) { console.error('[PE] callback error', e); }
        } else {
          console.warn('[PE] FullCalendar loaded but global did not appear in time.');
          showCalendarLoadError();
        }
      });
    } catch (err) {
      console.error('[PE] Failed to dynamically load FullCalendar', err);
      showCalendarLoadError();
    }
  }

  function showCalendarLoadError() {
    ['dashboard-calendar', 'calendar'].forEach(id => {
      const el = document.getElementById(id);
      if (el) {
        el.innerHTML = `<div style="padding:14px;border-radius:8px;background:#fff3f2;color:#b91c1c">
          Calendar library failed to load. Check network / CDN or open the console for details.
        </div>`;
      }
    });
  }

  // expose on window
  window.PECalendarLoader = { ensureFullCalendarThen, waitForFullCalendar, showCalendarLoadError };
})();

/* ---------------- Holiday API helper (Nager.Date v3) ---------------- */
const API = {
  HOLIDAYS: (year, country = 'NG') => `https://date.nager.at/api/v3/PublicHolidays/${year}/${country}`
};

/* ---------------- Mock users / storage ---------------- */
const MOCK_USERS = [
  { id: 1, firstName: 'John', lastName: 'Doe', role: 'client', phone: '+2348010000001', email: 'john@example.com', birthday: '1990-09-10' },
  { id: 2, firstName: 'Ada', lastName: 'Ibrahim', role: 'client', phone: '+2348010000002', email: 'ada@example.com', birthday: '1987-09-22' },
  { id: 3, firstName: 'Blessing', lastName: 'Okoro', role: 'marketer', phone: '+2348010000003', email: 'blessing@example.com', birthday: '1995-10-05' },
  { id: 4, firstName: 'Chike', lastName: 'Udo', role: 'marketer', phone: '+2348010000004', email: 'chike@example.com', birthday: '1992-09-07' },
  { id: 5, firstName: 'Mary', lastName: 'Smith', role: 'client', phone: '+2348010000005', email: 'mary@example.com', birthday: '1992-09-07' },
  { id: 6, firstName: 'Tunde', lastName: 'Adebayo', role: 'client', phone: '+2348010000006', email: 'tunde@example.com', birthday: '1989-09-11' }
];

const STORAGE = {
  USERS: 'pe_users_v1',
  TEMPLATES: 'pe_templates_v1',
  OUTBOUND: 'pe_outbound_v1',
  MESSAGES: 'pe_messages_v1',
  ACTIVITY: 'pe_activity_v1'
};

function ensureData() {
  if (!localStorage.getItem(STORAGE.USERS)) localStorage.setItem(STORAGE.USERS, JSON.stringify(MOCK_USERS));
  if (!localStorage.getItem(STORAGE.TEMPLATES)) {
    const defaultTpl = [{
      id: 'tpl-default-sms',
      name: 'Birthday SMS (Clients)',
      channel: 'sms',
      audience: 'clients',
      message: 'Happy Birthday, {firstName}! From PrimeEstate NG.',
      time: '09:00',
      createdAt: new Date().toISOString()
    }];
    localStorage.setItem(STORAGE.TEMPLATES, JSON.stringify(defaultTpl));
  }
  if (!localStorage.getItem(STORAGE.OUTBOUND)) localStorage.setItem(STORAGE.OUTBOUND, JSON.stringify([]));
  if (!localStorage.getItem(STORAGE.MESSAGES)) localStorage.setItem(STORAGE.MESSAGES, JSON.stringify([]));
  if (!localStorage.getItem(STORAGE.ACTIVITY)) localStorage.setItem(STORAGE.ACTIVITY, JSON.stringify([]));
}
ensureData();

function read(key) { return JSON.parse(localStorage.getItem(key) || 'null'); }
function write(key, val) { localStorage.setItem(key, JSON.stringify(val)); }
function appendActivity(text) {
  const act = read(STORAGE.ACTIVITY) || [];
  act.unshift({ at: new Date().toISOString(), text });
  write(STORAGE.ACTIVITY, act.slice(0, 200));
  try { renderActivity && renderActivity(); } catch (e) { /* ignore */ }
}

/* ---------------- Simple mock send ---------------- */
function sendMock({ channel, toUsers, subject, body }) {
  const queue = read(STORAGE.OUTBOUND) || [];
  const item = { id: 'o' + Date.now(), channel, toCount: toUsers.length, toSample: toUsers.slice(0, 3).map(u => `${u.firstName} ${u.lastName}`), subject: subject || '', body, createdAt: new Date().toISOString(), status: 'queued' };
  queue.unshift(item);
  write(STORAGE.OUTBOUND, queue);
  appendActivity(`Queued ${channel.toUpperCase()} to ${item.toCount} recipients`);
  try { renderOutbound && renderOutbound(); } catch (e) { /* ignore */ }
  return Promise.resolve(item);
}

/* ---------------- Modals helpers ---------------- */
function openTemplateModal({ mode = 'edit', id = null, data = null } = {}) {
  $('#template-modal-overlay').show();
  $('#template-modal-id').val(id || '');
  $('#template-modal-title').text(mode === 'create' ? 'Create Template' : (id && id.toString().startsWith('out_') ? 'Edit Outbound' : 'Edit Template'));
  if (data) {
    $('#template-modal-name').val(data.name || '');
    $('#template-modal-channel').val(data.channel || 'sms');
    $('#template-modal-audience').val(data.audience || 'clients');
    $('#template-modal-time').val(data.time || '');
    $('#template-modal-message').val(data.message || '');
  } else {
    $('#template-modal-name').val('');
    $('#template-modal-channel').val('sms');
    $('#template-modal-audience').val('clients');
    $('#template-modal-time').val('');
    $('#template-modal-message').val('');
  }
  $('#template-modal-overlay').data('outbound-edit-id', null);
}
function closeTemplateModal() {
  $('#template-modal-overlay').hide();
  $('#template-modal-id').val('');
  $('#template-modal-overlay').data('outbound-edit-id', null);
}

function openConfirmModal({ title = 'Confirm', message = 'Are you sure?', confirmLabel = 'Yes', onConfirm = null } = {}) {
  $('#confirm-modal-title').text(title);
  $('#confirm-modal-message').text(message);
  $('#confirm-modal-confirm').text(confirmLabel);
  $('#confirm-modal-overlay').show();
  $('#confirm-modal-confirm').off('click').on('click', function () {
    $('#confirm-modal-overlay').hide();
    try { if (typeof onConfirm === 'function') onConfirm(); } catch (e) { console.error(e); }
  });
  $('#confirm-modal-cancel, #confirm-modal-close').off('click').on('click', function () { $('#confirm-modal-overlay').hide(); });
}

/* ---------------- Compose modal helpers ---------------- */
function openComposeModal(editId = null) {
  $('#compose-overlay').show();
  $('#compose-overlay').data('editMessageId', editId || null);
  if (editId) {
    const msgs = read(STORAGE.MESSAGES) || [];
    const msg = msgs.find(m => m.id === editId);
    if (msg) {
      $('#compose-recipients').val('all');
      $('#compose-channel').val('inapp');
      $('#compose-subject').val(msg.subject || '');
      $('#compose-body').val(msg.body || '');
      return;
    }
  }
  $('#compose-recipients').val('all');
  $('#compose-channel').val('inapp');
  $('#compose-subject').val('');
  $('#compose-body').val('');
}
function closeComposeModal() {
  $('#compose-overlay').hide();
  $('#compose-overlay').data('editMessageId', null);
}

/* ---------------- jQuery DOM wiring ---------------- */
$(document).ready(function () {
  // initial non-calendar render
  renderStats();
  renderRecentMessages();
  renderTemplatesList();
  renderOutbound();
  renderBirthdaysUpcoming();
  renderActivity();

  // Quick compose submit
  $('#quick-compose').on('submit', async function (e) {
    e.preventDefault();
    const seg = $('#qc-segment').val();
    const ch = $('#qc-channel').val();
    const text = $('#qc-message').val().trim();
    if (!text) return alert('Enter message');
    const users = selectUsers(seg);
    await sendMock({ channel: ch, toUsers: users, body: text });
    $('#qc-message').val('');
    alert('Mock queued');
    renderRecentMessages();
    renderStats();
  });

  $('#qc-save-draft').on('click', function () {
    const body = $('#qc-message').val().trim();
    const msgs = read(STORAGE.MESSAGES) || [];
    msgs.unshift({ id: 'd' + Date.now(), subject: 'Draft', body, createdAt: new Date().toISOString() });
    write(STORAGE.MESSAGES, msgs);
    renderRecentMessages();
    alert('Draft saved (mock)');
  });

  // Compose modal wiring
  $('#open-compose, #open-compose-2').on('click', function () { openComposeModal(); });
  $('#compose-close, #compose-cancel').on('click', function () { closeComposeModal(); });
  $('#compose-form').on('submit', async function (e) {
    e.preventDefault();
    const recipients = $('#compose-recipients').val();
    const channel = $('#compose-channel').val();
    const subject = $('#compose-subject').val();
    const body = $('#compose-body').val();
    const editId = $('#compose-overlay').data('editMessageId');
    if (editId) {
      const msgs = read(STORAGE.MESSAGES) || [];
      const idx = msgs.findIndex(m => m.id === editId);
      if (idx > -1) {
        msgs[idx].subject = subject;
        msgs[idx].body = body;
        msgs[idx].updatedAt = new Date().toISOString();
        write(STORAGE.MESSAGES, msgs);
        appendActivity(`Edited draft ${editId}`);
        renderRecentMessages();
        closeComposeModal();
        alert('Draft updated (mock)');
        return;
      }
    }
    const users = selectUsers(recipients);
    await sendMock({ channel, toUsers: users, subject, body });
    closeComposeModal();
    alert('Mock broadcast queued');
    renderRecentMessages();
  });

  // Newsletter
  $('#newsletter-form').on('submit', async function (e) {
    e.preventDefault();
    const subj = $('#nl-subject').val();
    const aud = $('#nl-audience').val();
    const body = $('#nl-body').val();
    const users = selectUsers(aud);
    await sendMock({ channel: 'email', toUsers: users, subject: subj, body });
    alert('Mock newsletter queued');
    renderStats();
  });

  // Template quick save buttons
  $('#save-tpl-sms').on('click', saveTplSMS);
  $('#save-tpl-email').on('click', saveTplEmail);
  $('#save-tpl-inapp').on('click', saveTplInapp);

  // Template modal save/cancel wiring
  $('#template-modal-cancel, #template-modal-close').on('click', function () { closeTemplateModal(); });
  $('#template-modal-save').on('click', function (e) {
    e.preventDefault();
    const outboundEditId = $('#template-modal-overlay').data('outbound-edit-id') || null;
    const id = $('#template-modal-id').val() || '';
    const name = $('#template-modal-name').val().trim();
    const channel = $('#template-modal-channel').val();
    const audience = $('#template-modal-audience').val();
    const time = $('#template-modal-time').val();
    const message = $('#template-modal-message').val().trim();
    if (!message) return alert('Enter message body');

    if (outboundEditId) {
      // update outbound item
      const q = read(STORAGE.OUTBOUND) || [];
      const idx = q.findIndex(it => it.id === outboundEditId);
      if (idx > -1) {
        q[idx].body = message;
        q[idx].updatedAt = new Date().toISOString();
        write(STORAGE.OUTBOUND, q);
        appendActivity(`Edited outbound ${outboundEditId}`);
        renderOutbound();
        alert('Outbound updated (mock)');
      } else {
        alert('Outbound item not found');
      }
      $('#template-modal-overlay').data('outbound-edit-id', null);
      closeTemplateModal();
      return;
    }

    const tpls = read(STORAGE.TEMPLATES) || [];
    if (id) {
      const idx = tpls.findIndex(t => t.id === id);
      if (idx > -1) {
        tpls[idx].name = name || tpls[idx].name;
        tpls[idx].channel = channel;
        tpls[idx].audience = audience;
        tpls[idx].time = time;
        tpls[idx].message = message;
        tpls[idx].updatedAt = new Date().toISOString();
      } else {
        tpls.unshift({ id: id || 't' + Date.now(), name: name || 'Template', channel, audience, time, message, createdAt: new Date().toISOString() });
      }
    } else {
      const newTpl = { id: 't' + Date.now(), name: name || 'Template', channel, audience, time, message, createdAt: new Date().toISOString() };
      tpls.unshift(newTpl);
      appendActivity(`Created template ${newTpl.id}`);
    }
    write(STORAGE.TEMPLATES, tpls);
    renderTemplatesList();
    closeTemplateModal();
    alert('Template saved (mock)');
  });

  // UI wiring
  $('.tab').on('click', function () { $('.tab').removeClass('active'); $(this).addClass('active'); const tabId = $(this).data('tab'); $('.tab-content').removeClass('active'); $('#' + tabId + '-tab').addClass('active'); });
  $('.menu-item').on('click', function () { $('.menu-item').removeClass('active'); $(this).addClass('active'); });
  $('#filter-birthdays, #filter-holidays, #filter-special').on('change', function () { refreshDashboardEvents(); });
  $('.action[data-target]').on('click', function () { const t = $(this).data('target'); if (t) window.location.href = t; });
  $(document).on('click', '#run-scheduled', async function () { await runScheduledTriggers(); alert('Scheduled triggers executed (mock). Check outbound queue.'); });

  /* ---------- Delegated Edit/Delete handlers ---------- */
  $(document).on('click', '.tpl-edit', function () {
    const id = $(this).data('id');
    const tpls = read(STORAGE.TEMPLATES) || [];
    const tpl = tpls.find(t => t.id === id);
    openTemplateModal({ mode: 'edit', id, data: tpl });
  });

  $(document).on('click', '.tpl-delete', function () {
    const id = $(this).data('id');
    openConfirmModal({
      title: 'Delete Template',
      message: 'This will permanently remove the template. Continue?',
      confirmLabel: 'Delete',
      onConfirm: function () {
        const tpls = read(STORAGE.TEMPLATES) || [];
        const filtered = tpls.filter(t => t.id !== id);
        write(STORAGE.TEMPLATES, filtered);
        renderTemplatesList();
        appendActivity(`Deleted template ${id}`);
        alert('Template deleted (mock)');
      }
    });
  });

  $(document).on('click', '.out-edit', function () {
    const id = $(this).data('id');
    const q = read(STORAGE.OUTBOUND) || [];
    const item = q.find(it => it.id === id);
    if (!item) return alert('Outbound item not found');
    openTemplateModal({ mode: 'edit', id: 'out_' + id, data: { name: `${item.channel.toUpperCase()} Outbound`, channel: item.channel, audience: 'all', time: '', message: item.body || item.subject || '' } });
    $('#template-modal-overlay').data('outbound-edit-id', id);
  });

  $(document).on('click', '.out-delete', function () {
    const id = $(this).data('id');
    openConfirmModal({
      title: 'Remove Outbound Item',
      message: 'This will remove the queued outbound item. Continue?',
      confirmLabel: 'Remove',
      onConfirm: function () {
        const q = read(STORAGE.OUTBOUND) || [];
        const filtered = q.filter(it => it.id !== id);
        write(STORAGE.OUTBOUND, filtered);
        renderOutbound();
        appendActivity(`Deleted outbound ${id}`);
        alert('Outbound removed (mock)');
      }
    });
  });

  $(document).on('click', '.msg-edit', function () {
    const id = $(this).data('id');
    openComposeModal(id);
  });

  $(document).on('click', '.msg-delete', function () {
    const id = $(this).data('id');
    openConfirmModal({
      title: 'Delete Message',
      message: 'Delete this message/draft permanently?',
      confirmLabel: 'Delete',
      onConfirm: function () {
        const msgs = read(STORAGE.MESSAGES) || [];
        const filtered = msgs.filter(m => m.id !== id);
        write(STORAGE.MESSAGES, filtered);
        renderRecentMessages();
        appendActivity(`Deleted message ${id}`);
        alert('Message deleted (mock)');
      }
    });
  });

}); // end document ready

/* ---------------- Short helpers for quick template saves ---------------- */
function saveTplSMS() {
  const content = $('#tpl-sms').val();
  if (!content) return alert('Enter SMS content');
  const tpls = read(STORAGE.TEMPLATES) || [];
  tpls.unshift({ id: 't' + Date.now(), name: 'SMS Quick', channel: 'sms', audience: 'clients', message: content, time: '09:00', createdAt: new Date().toISOString() });
  write(STORAGE.TEMPLATES, tpls);
  renderTemplatesList();
  alert('Saved SMS template (mock)');
}
function saveTplEmail() {
  const subj = $('#tpl-email-subject').val();
  const body = $('#tpl-email-body').val();
  if (!subj || !body) return alert('Enter subject and body');
  const tpls = read(STORAGE.TEMPLATES) || [];
  tpls.unshift({ id: 't' + Date.now(), name: subj, channel: 'email', audience: 'clients', message: body, time: '09:00', createdAt: new Date().toISOString() });
  write(STORAGE.TEMPLATES, tpls);
  renderTemplatesList();
  alert('Saved Email template (mock)');
}
function saveTplInapp() {
  const body = $('#tpl-inapp').val();
  if (!body) return alert('Enter in-app content');
  const tpls = read(STORAGE.TEMPLATES) || [];
  tpls.unshift({ id: 't' + Date.now(), name: 'InApp Quick', channel: 'inapp', audience: 'clients', message: body, time: '09:00', createdAt: new Date().toISOString() });
  write(STORAGE.TEMPLATES, tpls);
  renderTemplatesList();
  alert('Saved InApp template (mock)');
}

/* ---------------- Renderers ---------------- */
function renderTemplatesList() {
  const tpls = read(STORAGE.TEMPLATES) || [];
  if (!tpls || !tpls.length) {
    $('#templates-list').html('<div class="message-item">No templates</div>');
    return;
  }
  const html = tpls.map(t => `
    <li class="message-item" style="display:flex;justify-content:space-between;align-items:flex-start">
      <div style="display:flex;gap:12px">
        <div class="message-avatar"><img src="https://ui-avatars.com/api/?name=${encodeURIComponent(t.name)}&background=3498db&color=fff" /></div>
        <div class="message-content">
          <h4>${escapeHtml(t.name)} · ${t.channel ? t.channel.toUpperCase() : ''}</h4>
          <p>${escapeHtml((t.message || '').slice(0, 260))}${(t.message && t.message.length > 260) ? '...' : ''}</p>
          <div class="small-muted">Audience: ${t.audience || 'all'} · Send at ${t.time || '--'}</div>
        </div>
      </div>
      <div style="display:flex;flex-direction:column;gap:8px">
        <button class="btn btn-secondary tpl-edit" data-id="${t.id}">Edit</button>
        <button class="btn btn-secondary tpl-delete" data-id="${t.id}">Delete</button>
      </div>
    </li>`).join('');
  $('#templates-list').html(html);
}

function renderRecentMessages() {
  const msgs = read(STORAGE.MESSAGES) || [];
  if (!msgs || !msgs.length) {
    const none = '<li class="message-item">No messages yet</li>';
    $('#recent-messages').html(none);
    $('#messages-list').html(none);
    return;
  }
  const listHtml = (msgs.slice(0, 30)).map(m => {
    const title = m.subject || (m.id && m.id.startsWith('d') ? 'Draft' : 'Message');
    const body = (m.body || '').slice(0, 240);
    const isDraft = m.id && String(m.id).startsWith('d');
    return `<li class="message-item" style="display:flex;justify-content:space-between;align-items:flex-start">
      <div style="display:flex;gap:12px">
        <div class="message-avatar"><img src="https://ui-avatars.com/api/?name=${encodeURIComponent(title)}&background=3498db&color=fff" /></div>
        <div class="message-content">
          <h4>${escapeHtml(title)} ${isDraft ? '<span style="font-weight:600;color:#f39c12;margin-left:8px">[DRAFT]</span>' : ''}</h4>
          <p>${escapeHtml(body)}</p>
          <div class="small-muted">${m.createdAt ? new Date(m.createdAt).toLocaleString() : ''}${m.updatedAt ? ' · updated ' + new Date(m.updatedAt).toLocaleString() : ''}</div>
        </div>
      </div>
      <div style="display:flex;flex-direction:column;gap:8px">
        ${isDraft ? `<button class="btn btn-secondary msg-edit" data-id="${m.id}">Edit</button>` : ''}
        <button class="btn btn-secondary msg-delete" data-id="${m.id}">Delete</button>
      </div>
    </li>`;
  }).join('');
  $('#recent-messages').html(listHtml);
  $('#messages-list').html(listHtml);
}

function renderOutbound() {
  const q = read(STORAGE.OUTBOUND) || [];
  if (!q || !q.length) {
    $('#outbound-queue').html('<li class="message-item">No outbound items</li>');
    $('#outbound-count').text(0);
    return;
  }
  const html = q.map(it => `<li class="message-item" style="display:flex;justify-content:space-between;align-items:flex-start">
    <div style="display:flex;gap:12px">
      <div class="message-avatar"><img src="https://ui-avatars.com/api/?name=${encodeURIComponent(it.channel)}&background=f39c12&color=fff" /></div>
      <div class="message-content">
        <h4>${it.channel.toUpperCase()} — ${it.toCount} recipients</h4>
        <p>${escapeHtml((it.body || it.subject || '').slice(0, 180))}</p>
        <div class="small-muted">${new Date(it.createdAt).toLocaleString()}</div>
      </div>
    </div>
    <div style="display:flex;flex-direction:column;gap:8px">
      <button class="btn btn-secondary out-edit" data-id="${it.id}">Edit</button>
      <button class="btn btn-secondary out-delete" data-id="${it.id}">Delete</button>
    </div>
  </li>`).join('');
  $('#outbound-queue').html(html);
  $('#outbound-count').text(q.length);
}

function renderActivity() {
  const act = read(STORAGE.ACTIVITY) || [];
  const html = act.slice(0, 30).map(a => `<li class="message-item"><div class="message-content"><h4>${escapeHtml(a.text)}</h4><p class="small-muted">${new Date(a.at).toLocaleString()}</p></div></li>`).join('') || '<li class="message-item">No activity yet</li>';
  $('#activity').html(html);
}

/* ---------------- Stats & Birthdays ---------------- */
function renderStats() {
  const users = read(STORAGE.USERS) || [];
  $('#stat-customers').text(users.length);
  const now = new Date();
  const birthdays = users.filter(u => { if (!u.birthday) return false; const b = new Date(u.birthday); return b.getMonth() === now.getMonth(); });
  $('#stat-birthdays').text(birthdays.length);
  const outbound = read(STORAGE.OUTBOUND) || [];
  $('#stat-sent').text(outbound.length);
  $('#stat-open').text('82%');
  $('#outbound-count').text(outbound.length);
}

function renderBirthdaysUpcoming() {
  const users = read(STORAGE.USERS) || [];
  const now = new Date();
  const start = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  start.setHours(0, 0, 0, 0);
  const end = new Date(start);
  end.setDate(start.getDate() + 7);
  end.setHours(23, 59, 59, 999);

  function nextBirthdayDateFor(birthdayYMD) {
    if (!birthdayYMD) return null;
    const parts = String(birthdayYMD).split('-');
    if (parts.length < 3) return null;
    const month = Number(parts[1]);
    const day = Number(parts[2]);
    let candidate = new Date(start.getFullYear(), month - 1, day);
    candidate.setHours(0, 0, 0, 0);
    if (candidate < start) candidate.setFullYear(start.getFullYear() + 1);
    return candidate;
  }

  const clients = users
    .filter(u => u.role === 'client' && u.birthday)
    .map(u => ({ u, next: nextBirthdayDateFor(u.birthday) }))
    .filter(x => x.next && x.next >= start && x.next <= end)
    .sort((a, b) => a.next - b.next);

  const marketers = users
    .filter(u => u.role === 'marketer' && u.birthday)
    .map(u => ({ u, next: nextBirthdayDateFor(u.birthday) }))
    .filter(x => x.next && x.next >= start && x.next <= end)
    .sort((a, b) => a.next - b.next);

  const mkList = (arr) => {
    if (!arr || arr.length === 0) return '<li class="message-item small-muted">No birthdays</li>';
    return arr.map(x => `<li class="message-item"><div class="message-avatar"><img src="https://ui-avatars.com/api/?name=${encodeURIComponent(x.u.firstName)}&background=27ae60&color=fff" /></div><div class="message-content"><h4>${x.u.firstName} ${x.u.lastName}</h4><p class="small-muted">${x.next.toDateString()}</p></div></li>`).join('');
  };

  $('#week-birthdays-clients').html(mkList(clients));
  $('#week-birthdays-marketers').html(mkList(marketers));
}

/* ---------------- Scheduled triggers ---------------- */
async function runScheduledTriggers() {
  appendActivity('Running scheduled triggers (mock)');
  const tpls = read(STORAGE.TEMPLATES) || [];
  const users = read(STORAGE.USERS) || [];
  for (const t of tpls) {
    if ((t.name || '').toLowerCase().includes('birthday')) {
      const now = new Date();
      const todays = users.filter(u => {
        if (!u.birthday) return false;
        const b = new Date(u.birthday);
        return b.getDate() === now.getDate() && b.getMonth() === now.getMonth();
      });
      if (todays.length) {
        for (const u of todays) {
          const body = (t.message || '').replace(/{firstName}/g, u.firstName).replace(/{lastName}/g, u.lastName);
          await sendMock({ channel: t.channel, toUsers: [u], body });
        }
      } else {
        appendActivity(`No birthdays for template ${t.name} today`);
      }
    } else {
      const recipients = (t.audience === 'clients') ? users.filter(u => u.role === 'client') : (t.audience === 'marketers' ? users.filter(u => u.role === 'marketer') : users);
      if (recipients.length) await sendMock({ channel: t.channel, toUsers: recipients, body: t.message });
    }
  }
  renderRecentMessages();
  renderOutbound();
  renderStats();
}

/* ---------------- FullCalendar init & holiday fetch ---------------- */
let dashboardFC = null, fullFC = null;

async function initDashboardCalendar() {
  try {
    const el = document.getElementById('dashboard-calendar');
    if (!el) return;
    if (!el.style.minHeight) el.style.minHeight = '320px';

    // ensure FC is available (with loader waiter)
    const ok = await window.PECalendarLoader.waitForFullCalendar(5000);
    if (!ok) {
      el.innerHTML = '<div style="padding:12px;color:#b91c1c;background:#fff3f2;border-radius:6px">Calendar library not available. Check network / CDN.</div>';
      return;
    }

    const Calendar = (typeof FullCalendar !== 'undefined' && FullCalendar && FullCalendar.Calendar) ? FullCalendar.Calendar : (window.FullCalendar && window.FullCalendar.Calendar ? window.FullCalendar.Calendar : null);
    if (!Calendar) {
      el.innerHTML = '<div style="padding:12px;color:#b91c1c;background:#fff3f2;border-radius:6px">Calendar constructor not found.</div>';
      return;
    }

    dashboardFC = new Calendar(el, {
      initialView: 'dayGridMonth',
      headerToolbar: { left: 'prev,next today', center: 'title', right: '' },
      height: 340,
      events: []
    });
    dashboardFC.render();
    dashboardFC.on('datesSet', function () { computeMonthTagsFromView(); });
  } catch (err) {
    console.error('[PE] initDashboardCalendar error', err);
    const el = document.getElementById('dashboard-calendar'); if (el) el.innerHTML = '<div style="padding:12px;color:#b91c1c;background:#fff3f2;border-radius:6px">Failed to initialize dashboard calendar. See console.</div>';
  }
}

async function initFullCalendar() {
  try {
    const el = document.getElementById('calendar');
    if (!el) return;
    if (!el.style.minHeight) el.style.minHeight = '420px';

    const ok = await window.PECalendarLoader.waitForFullCalendar(5000);
    if (!ok) {
      el.innerHTML = '<div style="padding:12px;color:#b91c1c;background:#fff3f2;border-radius:6px">Calendar library not available. Check network / CDN.</div>';
      return;
    }

    const Calendar = (typeof FullCalendar !== 'undefined' && FullCalendar && FullCalendar.Calendar) ? FullCalendar.Calendar : (window.FullCalendar && window.FullCalendar.Calendar ? window.FullCalendar.Calendar : null);
    if (!Calendar) {
      el.innerHTML = '<div style="padding:12px;color:#b91c1c;background:#fff3f2;border-radius:6px">Calendar constructor not found.</div>';
      return;
    }

    fullFC = new Calendar(el, {
      initialView: 'dayGridMonth',
      headerToolbar: { left: 'prev,next today', center: 'title', right: 'dayGridMonth,timeGridWeek,timeGridDay,listMonth' },
      height: 600,
      events: []
    });
    fullFC.render();
  } catch (err) {
    console.error('[PE] initFullCalendar error', err);
    const el = document.getElementById('calendar'); if (el) el.innerHTML = '<div style="padding:12px;color:#b91c1c;background:#fff3f2;border-radius:6px">Failed to initialize calendar. See console.</div>';
  }
}

async function fetchAndRenderHolidays() {
  try {
    if (!fullFC) await initFullCalendar();
    const year = new Date().getFullYear();
    const url = API.HOLIDAYS(year, 'NG');
    appendActivity(`Fetching NG holidays ${year}`);
    const res = await fetch(url);

    let holidays = [];
    if (res.ok) {
      try { holidays = await res.json(); } catch (e) { holidays = []; appendActivity('Failed to parse holidays response.'); }
    } else {
      holidays = []; appendActivity(`Holidays fetch returned ${res.status}, using fallback.`);
    }

    if (document.getElementById('holiday-list')) $('#holiday-list').html(holidays.map(h => `<li class="message-item"><div class="message-content"><h4>${escapeHtml(h.localName)}</h4><p class="small-muted">${h.date} · ${escapeHtml(h.name)}</p></div></li>`).join(''));

    if (fullFC && typeof fullFC.removeAllEvents === 'function') fullFC.removeAllEvents();
    const evts = holidays.map(h => ({ title: h.localName, start: h.date, classNames: ['holiday'] }));

    const users = read(STORAGE.USERS) || [];
    const userEvents = users.map(u => {
      const b = new Date(u.birthday);
      const str = `${year}-${String(b.getMonth() + 1).padStart(2, '0')}-${String(b.getDate()).padStart(2, '0')}`;
      return { title: `${u.firstName} ${u.lastName} Birthday`, start: str, classNames: ['birthday'] };
    });

    const specialEvents = [
      { title: 'Customer Appreciation Day', start: `${year}-05-15`, classNames: ['special-day'] },
      { title: 'Open House Event', start: `${year}-07-22`, classNames: ['special-day'] }
    ];

    if (fullFC && typeof fullFC.addEventSource === 'function') fullFC.addEventSource(evts.concat(userEvents).concat(specialEvents));
    appendActivity(`Holidays loaded (${holidays.length})`);
    renderDashboardEvents(holidays);
  } catch (err) {
    console.error('[PE] fetchAndRenderHolidays error', err);
    appendActivity('Holiday fetch failed: ' + (err && err.message ? err.message : String(err)));
    if (document.getElementById('holiday-list')) $('#holiday-list').html(`<li class="message-item small-muted">Could not fetch holidays: ${escapeHtml(err && err.message ? err.message : String(err))}</li>`);
  }
}

async function fetchAndRenderHolidaysForDashboard() {
  try {
    if (!dashboardFC) await initDashboardCalendar();
    const year = new Date().getFullYear();
    const url = API.HOLIDAYS(year, 'NG');
    appendActivity(`Fetching NG holidays ${year} (dashboard)`);
    const res = await fetch(url);

    let holidays = [];
    if (res.ok) {
      try { holidays = await res.json(); } catch (e) { holidays = []; appendActivity('Failed to parse holidays response.'); }
    } else {
      holidays = []; appendActivity(`Dashboard holidays fetch returned ${res.status}, using fallback.`);
    }

    renderDashboardEvents(holidays);
    appendActivity(`Dashboard holidays loaded (${holidays.length})`);
  } catch (err) {
    console.error('[PE] fetchAndRenderHolidaysForDashboard error', err);
    appendActivity('Dashboard holiday fetch failed: ' + (err && err.message ? err.message : String(err)));
  }
}

function renderDashboardEvents(holidays) {
  if (!dashboardFC) return;
  if (typeof dashboardFC.removeAllEvents === 'function') dashboardFC.removeAllEvents();
  const users = read(STORAGE.USERS) || [];
  const year = new Date().getFullYear();
  const events = [];
  if ($('#filter-holidays').is(':checked')) events.push(...(holidays.map(h => ({ title: h.localName, start: h.date, classNames: ['holiday'] }))));
  if ($('#filter-birthdays').is(':checked')) events.push(...users.map(u => {
    const b = new Date(u.birthday);
    const str = `${year}-${String(b.getMonth() + 1).padStart(2, '0')}-${String(b.getDate()).padStart(2, '0')}`;
    return { title: `${u.firstName} ${u.lastName} ( ${u.role} )`, start: str, classNames: ['birthday'] };
  }));
  if ($('#filter-special').is(':checked')) events.push(...[
    { title: 'Customer Appreciation Day', start: `${year}-05-15`, classNames: ['special-day'] },
    { title: 'Open House Event', start: `${year}-07-22`, classNames: ['special-day'] }
  ]);
  if (typeof dashboardFC.addEventSource === 'function') dashboardFC.addEventSource(events);
  computeMonthTags(events);
  renderBirthdaysUpcoming();
}

function refreshDashboardEvents() {
  fetchAndRenderHolidaysForDashboard();
}

function computeMonthTags(events) {
  if (!dashboardFC) return;
  const view = dashboardFC.view;
  const start = view.activeStart;
  const end = view.activeEnd;
  let holidays = 0, birthdays = 0, specials = 0, others = 0;
  for (const e of events) {
    const d = new Date(e.start);
    if (d >= start && d < end) {
      if (e.classNames && e.classNames.includes('holiday')) holidays++;
      else if (e.classNames && e.classNames.includes('birthday')) birthdays++;
      else if (e.classNames && e.classNames.includes('special-day')) specials++;
      else others++;
    }
  }
  const el = $('#month-tags');
  const html = `<div style="display:flex;gap:12px;align-items:center">
    <div class="tag"><strong>${holidays}</strong><div class="small-muted">Holidays</div></div>
    <div class="tag"><strong>${birthdays}</strong><div class="small-muted">Birthdays</div></div>
    <div class="tag"><strong>${specials}</strong><div class="small-muted">Special Days</div></div>
    <div class="tag"><strong>${others}</strong><div class="small-muted">Events</div></div>
    </div>`;
  el.html(html);
}

function computeMonthTagsFromView() {
  fetchAndRenderHolidaysForDashboard();
}

/* ---------------- Boot calendars after ensuring FullCalendar exists ---------------- */
if (window.PECalendarLoader && window.PECalendarLoader.ensureFullCalendarThen) {
  window.PECalendarLoader.ensureFullCalendarThen(function () {
    try {
      if (document.getElementById('dashboard-calendar')) {
        initDashboardCalendar();
        fetchAndRenderHolidaysForDashboard();
      }
      if (document.getElementById('calendar')) {
        initFullCalendar();
        fetchAndRenderHolidays();
        $('#refresh-holidays').on('click', fetchAndRenderHolidays);
      }
    } catch (err) {
      console.error('[PE] Calendar init callback failed:', err);
    }
  });
} else {
  // If loader not present for some reason, log. (loader is defined above, so this branch is unlikely)
  console.warn('[PE] PECalendarLoader missing at boot time.');
}

/* ---------------- Utilities ---------------- */
function selectUsers(seg) {
  const users = read(STORAGE.USERS) || [];
  if (seg === 'all') return users;
  if (seg === 'clients') return users.filter(u => u.role === 'client');
  if (seg === 'marketers') return users.filter(u => u.role === 'marketer');
  return users;
}

function escapeHtml(s) { if (s === null || s === undefined) return ''; return String(s).replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;').replaceAll("'", '&#039;'); }

/* ---------------- Backwards-compatible shim:
   Some HTML pages (older versions) may call initCalendar() directly.
   Provide a safe shim that defers to our loader + initializers when possible.
*/
window.initCalendar = function () {
  if (window.PECalendarLoader && window.PECalendarLoader.ensureFullCalendarThen) {
    window.PECalendarLoader.ensureFullCalendarThen(function () {
      if (typeof initDashboardCalendar === 'function') {
        try { initDashboardCalendar(); } catch (err) { console.error('initDashboardCalendar threw', err); }
      }
      if (typeof initFullCalendar === 'function') {
        try { initFullCalendar(); } catch (err) { console.error('initFullCalendar threw', err); }
      }
    });
  } else {
    console.warn('PECalendarLoader not present; cannot init calendar from shim.');
  }
};
