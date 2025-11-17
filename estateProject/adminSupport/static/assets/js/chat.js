document.addEventListener('DOMContentLoaded', function () {
  const CHAT_STORAGE = { CONVS: 'pe_conversations_v1', MESSAGES: 'pe_conv_msgs_v1' };
  const bc = ('BroadcastChannel' in window) ? new BroadcastChannel('pe-chat') : null;

  // Elements
  const convListEl = document.getElementById('conversations');
  const convSearch = document.getElementById('conv-search');
  const convFilter = document.getElementById('conv-filter');
  const newConvBtn = document.getElementById('new-conv');
  const chatEmpty = document.getElementById('chat-empty');
  const chatPanel = document.getElementById('chat-panel');
  const chatBody = document.getElementById('chat-body');
  const chatAvatar = document.getElementById('chat-avatar');
  const chatName = document.getElementById('chat-name');
  const chatSub = document.getElementById('chat-sub');
  const msgInput = document.getElementById('msg-input');
  const sendBtn = document.getElementById('send-btn');
  const typingIndicator = document.getElementById('typing-indicator');
  const metaContent = document.getElementById('meta-content');

  let activeConvId = null;

  // Seed data
  function seedChatData(){
    if(!localStorage.getItem(CHAT_STORAGE.CONVS)){
      const convs = [
        { id:'c1', title:'John Doe', role:'client', unread:2, last:'Hi, I need update on plot A12', updatedAt: Date.now()-1000*60*60 },
        { id:'c2', title:'Ada Ibrahim', role:'client', unread:0, last:'Thanks!', updatedAt: Date.now()-1000*60*60*24 },
        { id:'c3', title:'Chike Udo', role:'marketer', unread:0, last:'Sent property link', updatedAt: Date.now()-1000*60*20 }
      ];
      localStorage.setItem(CHAT_STORAGE.CONVS, JSON.stringify(convs));
    }
    if(!localStorage.getItem(CHAT_STORAGE.MESSAGES)){
      const msgs = {
        'c1':[ {id:'m1',from:'c1',to:'admin',body:'Hello, any update on plot A12?',ts:Date.now()-1000*60*60},
              {id:'m2',from:'admin',to:'c1',body:'Yes — we scheduled inspection this week',ts:Date.now()-1000*60*50,status:'delivered'} ],
        'c2':[ {id:'m3',from:'c2',to:'admin',body:'Thanks for the newsletter',ts:Date.now()-1000*60*60*24} ],
        'c3':[ {id:'m4',from:'c3',to:'admin',body:'Shared link: http://example.com/prop/22',ts:Date.now()-1000*60*20} ]
      };
      localStorage.setItem(CHAT_STORAGE.MESSAGES, JSON.stringify(msgs));
    }
  }
  seedChatData();

  // Storage helpers
  function readChats(){ return JSON.parse(localStorage.getItem(CHAT_STORAGE.CONVS) || '[]'); }
  function writeChats(arr){ localStorage.setItem(CHAT_STORAGE.CONVS, JSON.stringify(arr)); }
  function readMsgs(){ return JSON.parse(localStorage.getItem(CHAT_STORAGE.MESSAGES) || '{}'); }
  function writeMsgs(obj){ localStorage.setItem(CHAT_STORAGE.MESSAGES, JSON.stringify(obj)); }

  // Render conversation list
  function renderConversations(){
    const filter = convFilter.value || 'all';
    const q = (convSearch.value || '').trim().toLowerCase();
    const convs = readChats().slice().sort((a,b)=>b.updatedAt - a.updatedAt);
    const filtered = convs.filter(c=>{
      if(filter !== 'all' && c.role !== filter) return false;
      if(q && !(c.title.toLowerCase().includes(q) || (c.last||'').toLowerCase().includes(q))) return false;
      return true;
    });
    convListEl.innerHTML = filtered.map(c=>{
      return `<div class="conv-item" data-id="${c.id}">
        <div class="avatar">${escapeInitials(c.title)}</div>
        <div class="conv-meta">
          <h4>${escapeHtml(c.title)}</h4>
          <p>${escapeHtml(c.last || 'No messages yet')}</p>
        </div>
        <div class="conv-right">
          <div class="conv-time">${timeAgo(c.updatedAt)}</div>
          ${c.unread?`<div class="badge-unread">${c.unread}</div>`:''}
        </div>
      </div>`;
    }).join('');
    attachConvClicks();
  }

  function attachConvClicks(){
    Array.from(convListEl.querySelectorAll('.conv-item')).forEach(el=>{
      el.onclick = ()=> openConversation(el.getAttribute('data-id'));
    });
  }

  // Open conversation
  function openConversation(id){
    activeConvId = id;
    const convs = readChats();
    const conv = convs.find(c=>c.id === id);
    if(!conv) return;
    chatEmpty.style.display = 'none';
    chatPanel.classList.remove('hidden');
    chatAvatar.textContent = escapeInitials(conv.title);
    chatName.textContent = conv.title;
    chatSub.textContent = (conv.role === 'client') ? 'Client' : conv.role;
    renderMessages(id);
    // mark read
    conv.unread = 0;
    writeChats(convs);
    renderConversations();
    metaContent.innerHTML = `<div><strong>${escapeHtml(conv.title)}</strong></div>
      <div class="small-muted">Role: ${conv.role}</div>
      <div class="small-muted">Last message: ${new Date(conv.updatedAt).toLocaleString()}</div>`;
  }

  // Render messages
  function renderMessages(convId){
    const msgs = (readMsgs()[convId] || []).slice().sort((a,b)=>a.ts - b.ts);
    chatBody.innerHTML = msgs.map(m=>{
      const isOut = (m.from === 'admin');
      const cls = isOut ? 'msg-out' : 'msg-in';
      return `<div style="display:flex;flex-direction:column;${isOut ? 'align-items:flex-end' : ''}">
        <div class="chat-message ${cls}">${escapeHtml(m.body)}</div>
        <div class="msg-meta">${isOut ? 'You' : 'Them'} · ${new Date(m.ts).toLocaleTimeString()}</div>
      </div>`;
    }).join('');
    chatBody.scrollTop = chatBody.scrollHeight;
  }

  // Send message
  function sendMessage(){
    if(!activeConvId) return alert('Select a conversation');
    const text = (msgInput.value || '').trim();
    if(!text) return;
    const msgs = readMsgs();
    const m = { id:'m'+Date.now(), from:'admin', to:activeConvId, body:text, ts:Date.now(), status:'sent' };
    if(!msgs[activeConvId]) msgs[activeConvId] = [];
    msgs[activeConvId].push(m);
    writeMsgs(msgs);
    // update conv meta
    const convs = readChats();
    const conv = convs.find(c=>c.id===activeConvId);
    conv.last = text;
    conv.updatedAt = Date.now();
    writeChats(convs);
    renderMessages(activeConvId);
    renderConversations();
    msgInput.value = '';
    if(bc) bc.postMessage({ type:'message', convId:activeConvId, message:m });
    setTimeout(()=> { m.status = 'delivered'; console.debug('delivered', m.id); }, 900);
  }

  // typing handling
  let typingTimer = null;
  function showTyping(){ typingIndicator.classList.remove('hidden'); clearTimeout(typingTimer); typingTimer = setTimeout(()=> typingIndicator.classList.add('hidden'), 1500); }

  // BroadcastChannel receive
  if(bc){
    bc.onmessage = function(ev){
      const data = ev.data;
      if(!data) return;
      if(data.type === 'message'){
        const convId = data.convId;
        const m = data.message;
        const msgs = readMsgs();
        if(!msgs[convId]) msgs[convId] = [];
        msgs[convId].push(m);
        writeMsgs(msgs);
        const convs = readChats();
        const conv = convs.find(c=>c.id === convId);
        if(conv){
          if(activeConvId !== convId) conv.unread = (conv.unread || 0) + 1;
          conv.last = m.body;
          conv.updatedAt = Date.now();
          writeChats(convs);
          renderConversations();
        }
        if(activeConvId === convId) renderMessages(convId);
      } else if(data.type === 'typing'){
        if(data.convId === activeConvId) showTyping();
      }
    };
  }

  // new conversation simulation
  newConvBtn.addEventListener('click', function(){
    const id = 'c'+Date.now();
    const convs = readChats();
    const title = 'Demo Client ' + Math.floor(Math.random()*99);
    convs.unshift({ id, title, role:'client', unread:0, last:'(new)', updatedAt: Date.now() });
    writeChats(convs);
    const msgs = readMsgs();
    msgs[id] = [];
    writeMsgs(msgs);
    renderConversations();
    openConversation(id);
    // simulate customer reply
    setTimeout(()=>{
      const msgs2 = readMsgs();
      const m = { id:'m'+Date.now(), from:id, to:'admin', body:'Hi, I saw your listing — interested!', ts:Date.now() };
      msgs2[id].push(m);
      writeMsgs(msgs2);
      const convs2 = readChats();
      const cv = convs2.find(c=>c.id===id); cv.last = m.body; cv.updatedAt = Date.now(); cv.unread = 1;
      writeChats(convs2);
      if(bc) bc.postMessage({ type:'message', convId:id, message:m });
      renderConversations();
      if(activeConvId === id) renderMessages(id);
    }, 1400);
  });

  // handlers
  sendBtn.addEventListener('click', sendMessage);
  msgInput.addEventListener('keydown', function (e) {
    if(e.key === 'Enter' && !e.shiftKey){ e.preventDefault(); sendMessage(); }
    else { if(bc) bc.postMessage({ type:'typing', convId: activeConvId }); }
  });
  convFilter.addEventListener('change', renderConversations);
  convSearch.addEventListener('input', renderConversations);

  // initial render
  renderConversations();

  // helpers
  function escapeHtml(s){ if(s===null||s===undefined) return ''; return String(s).replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('>','&gt;'); }
  function escapeInitials(name){ if(!name) return ''; return name.split(' ').map(x=>x[0]||'').slice(0,2).join('').toUpperCase(); }
  function timeAgo(ts){ if(!ts) return ''; const diff = Date.now() - (ts||0); const mins = Math.round(diff/60000); if(mins<1) return 'now'; if(mins<60) return `${mins}m`; const hrs = Math.round(mins/60); if(hrs<24) return `${hrs}h`; const days = Math.round(hrs/24); return `${days}d`; }
  function appendActivityMock(text){ console.log('[chat activity]', text); }

  // Dynamic Socket.IO loader (optional — will not inject <script> into inline code)
  (function initSocketIOClient(){
    const SOCKET_SRC = '/socket.io/socket.io.js'; // change to CDN or server path if necessary

    function setupSocket(){
      if(!window.io){ console.warn('[chat] socket.io client not present'); return; }
      try {
        const socket = io('/chat', { auth: { token: 'JWT_OR_SESSION' } });
        console.log('[chat] socket.io client initialized', socket.id);

        socket.on('message:created', function(m){
          if(!m || !m.conversationId || !m.message) return;
          const msgs = readMsgs();
          if(!msgs[m.conversationId]) msgs[m.conversationId] = [];
          msgs[m.conversationId].push(m.message);
          writeMsgs(msgs);
          const convs = readChats();
          const conv = convs.find(c=>c.id === m.conversationId);
          if(conv){
            if(activeConvId !== m.conversationId) conv.unread = (conv.unread||0) + 1;
            conv.last = m.message.body || conv.last;
            conv.updatedAt = Date.now();
            writeChats(convs);
            renderConversations();
            if(activeConvId === m.conversationId) renderMessages(m.conversationId);
          }
        });

        socket.on('connect', ()=> console.log('[chat socket] connected'));
        socket.on('disconnect', ()=> console.log('[chat socket] disconnected'));

        window.PE_SOCKET = socket;
      } catch(err){
        console.error('[chat] Failed to setup socket.io client', err);
      }
    }

    if(window.io){ setupSocket(); return; }

    // Attempt to dynamically add client script; if it fails gracefully fallback to BroadcastChannel
    const s = document.createElement('script');
    s.src = SOCKET_SRC;
    s.async = true;
    s.onload = function(){ console.log('[chat] loaded socket.io client'); setupSocket(); };
    s.onerror = function(ev){ console.warn('[chat] could not load socket.io client:', ev); };
    document.head.appendChild(s);

    // Helper to send via server if available
    window.sendMessageServerSide = function(convId, body){
      if(window.PE_SOCKET && window.PE_SOCKET.connected){
        window.PE_SOCKET.emit('message:create', { conversationId: convId, body }, (ack)=>{ console.log('ack',ack); });
      } else {
        console.warn('[chat] socket not connected — using local fallback');
        // local fallback uses same sendMessage pipeline
        if(!convId || !body) return;
        const msgs = readMsgs();
        const m = { id:'m'+Date.now(), from:'admin', to:convId, body, ts:Date.now(), status:'sent' };
        if(!msgs[convId]) msgs[convId] = [];
        msgs[convId].push(m);
        writeMsgs(msgs);
        if(activeConvId === convId) renderMessages(convId);
        const convs = readChats();
        const conv = convs.find(c => c.id === convId);
        if(conv){ conv.last = body; conv.updatedAt = Date.now(); writeChats(convs); renderConversations(); }
      }
    };
  })();

});
