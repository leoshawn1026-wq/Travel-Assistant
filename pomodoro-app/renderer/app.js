// ============================================================
//  🍅 番茄钟 — app.js
//  状态机 · Canvas 环形进度 · 待办 · 设置 · 统计 · 音效 · 暗黑模式
// ============================================================

// ============================================================
//  1.  Constants & State
// ============================================================
const MODES = ['pomodoro', 'shortBreak', 'longBreak'];
const MODE_LABELS = { pomodoro: '番茄钟', shortBreak: '短放松', longBreak: '长放松' };
const MODE_EMOJI = { pomodoro: '🍅', shortBreak: '☕', longBreak: '🌿' };
const MODE_COLORS = {
  pomodoro:   { gradient: ['#FF5A4F', '#FF7A45', '#FF8FB8'], shadow: 'rgba(255,90,79,0.35)', glow: 'rgba(255,90,79,0.15)' },
  shortBreak: { gradient: ['#8DE2C4', '#7ED5B8'],           shadow: 'rgba(141,226,196,0.30)', glow: 'rgba(141,226,196,0.12)' },
  longBreak:  { gradient: ['#5BA0D9', '#7BBDE6'],           shadow: 'rgba(91,160,217,0.30)', glow: 'rgba(91,160,217,0.12)' },
};

const DEFAULT_CONFIG = {
  pomodoro: 25, shortBreak: 5, longBreak: 15,
  longInterval: 4,
  sound: 'classic', volume: 80,
  autoPomo: false, autoBreak: false, notify: true,
};

let config = loadConfig();
let state = {
  mode: 'pomodoro',
  status: 'idle',        // idle | running | paused
  timeLeft: config.pomodoro * 60,
  pomodoroCount: 0,
  totalPomodoros: 0,     // lifetime
  history: [],           // [{date, count}]
  todos: [],
  currentTask: null,
  lastTimestamp: null,
  animId: null,
};

// Load persisted state
loadState();
// Ensure timeLeft matches current mode
if (state.timeLeft <= 0) state.timeLeft = config[state.mode] * 60;

// ============================================================
//  2.  DOM Refs
// ============================================================
const $ = (s) => document.querySelector(s);
const $$ = (s) => document.querySelectorAll(s);

const canvas = $('#timerCanvas');
const ctx = canvas.getContext('2d');
const timerDisplay = $('#timerDisplay');
const timerStatus = $('#timerStatus');
const primaryBtn = $('#primaryBtn');
const resetBtn = $('#resetBtn');
const modeTabs = $('#modeTabs');
const sessionDots = $('#sessionDots');
const sessionCount = $('#sessionCount');
const currentTaskText = $('#currentTaskText');
const themeToggle = $('#themeToggle');
const minimizeBtn = $('#minimizeBtn');
const closeBtn = $('#closeBtn');
const resultOverlay = $('#resultOverlay');
const resultEmoji = $('#resultEmoji');
const resultLabel = $('#resultLabel');
const resultTitle = $('#resultTitle');
const resultHint = $('#resultHint');
const resultBtn = $('#resultBtn');

// Sidebar
const snBtns = $$('.sn-btn');
const sidebarViews = {
  todo: $('#viewTodo'),
  stats: $('#viewStats'),
  settings: $('#viewSettings'),
};

// Todo
const todoInput = $('#todoInput');
const todoAddBtn = $('#todoAddBtn');
const todoList = $('#todoList');
const todoCount = $('#todoCount');

// Stats
const statToday = $('#statToday');
const statWeek = $('#statWeek');
const statTotal = $('#statTotal');
const statHours = $('#statHours');
const weekChart = $('#weekChart');
const historyList = $('#historyList');

// Settings
const setPomodoro = $('#setPomodoro');
const setShortBreak = $('#setShortBreak');
const setLongBreak = $('#setLongBreak');
const setLongInterval = $('#setLongInterval');
const setSound = $('#setSound');
const setVolume = $('#setVolume');
const volumeVal = $('#volumeVal');
const setAutoPomo = $('#setAutoPomo');
const setAutoBreak = $('#setAutoBreak');
const setNotify = $('#setNotify');
const clearDataBtn = $('#clearDataBtn');

// ============================================================
//  3.  Canvas Ring
// ============================================================
const CX = canvas.width / 2;
const CY = canvas.height / 2;
const CW = canvas.width;
const CH = canvas.height;
const R = 130;
const LINE_W = 12;

// Pre-computed tick mark positions (12 points around the ring)
const TICK_POSITIONS = Array.from({ length: 12 }, (_, i) => {
  const angle = -Math.PI / 2 + (i / 12) * 2 * Math.PI;
  return { dx: CX + Math.cos(angle) * R, dy: CY + Math.sin(angle) * R };
});

// Cached gradients per mode
const gradientCache = {};

function getGradient(mode) {
  if (!gradientCache[mode]) {
    const g = ctx.createLinearGradient(0, 0, CW, CH);
    const colors = MODE_COLORS[mode].gradient;
    colors.forEach((c, i) => g.addColorStop(i / (colors.length - 1 || 1), c));
    gradientCache[mode] = g;
  }
  return gradientCache[mode];
}

function drawRing() {
  const total = config[state.mode] * 60;
  const progress = total > 0 ? 1 - state.timeLeft / total : 0;
  const isDark = document.body.classList.contains('dark');
  const mc = MODE_COLORS[state.mode];

  ctx.clearRect(0, 0, CW, CH);

  // === Outer ambient glow (energy aura) ===
  ctx.save();
  ctx.beginPath();
  ctx.arc(CX, CY, R + 16, 0, 2 * Math.PI);
  ctx.shadowColor = mc.glow;
  ctx.shadowBlur = 40;
  ctx.fillStyle = isDark ? 'rgba(0,0,0,0.02)' : 'rgba(255,255,255,0.01)';
  ctx.fill();
  ctx.restore();

  // === Track ring gradient background ===
  ctx.save();
  ctx.beginPath();
  ctx.arc(CX, CY, R, 0, 2 * Math.PI);
  const trackGrad = ctx.createLinearGradient(0, 0, CW, CH);
  trackGrad.addColorStop(0, isDark ? 'rgba(255,255,255,0.04)' : 'rgba(0,0,0,0.03)');
  trackGrad.addColorStop(1, isDark ? 'rgba(255,255,255,0.08)' : 'rgba(0,0,0,0.06)');
  ctx.strokeStyle = trackGrad;
  ctx.lineWidth = LINE_W;
  ctx.lineCap = 'round';
  ctx.stroke();
  ctx.restore();

  // === Progress arc with dual glow layers ===
  if (progress > 0) {
    const start = -Math.PI / 2;
    const end = start + 2 * Math.PI * progress;

    // Outer glow trail
    ctx.save();
    ctx.shadowColor = mc.shadow;
    ctx.shadowBlur = 24;
    ctx.beginPath();
    ctx.arc(CX, CY, R, start, end);
    ctx.strokeStyle = getGradient(state.mode);
    ctx.lineWidth = LINE_W + 4;
    ctx.lineCap = 'round';
    ctx.globalAlpha = 0.25;
    ctx.stroke();
    ctx.restore();

    // Main progress arc
    ctx.save();
    ctx.shadowColor = mc.shadow;
    ctx.shadowBlur = 14;
    ctx.beginPath();
    ctx.arc(CX, CY, R, start, end);
    ctx.strokeStyle = getGradient(state.mode);
    ctx.lineWidth = LINE_W;
    ctx.lineCap = 'round';
    ctx.stroke();
    ctx.restore();

    // Inner bright highlight
    ctx.save();
    ctx.shadowColor = mc.shadow;
    ctx.shadowBlur = 8;
    ctx.beginPath();
    ctx.arc(CX, CY, R, start, end);
    ctx.strokeStyle = 'rgba(255,255,255,0.25)';
    ctx.lineWidth = 3;
    ctx.lineCap = 'round';
    ctx.globalAlpha = 0.5;
    ctx.stroke();
    ctx.restore();
  }

  // === Energy particle dots (tick marks) ===
  const dotProgress = progress > 0 ? Math.ceil(progress * 12) : 0;
  TICK_POSITIONS.forEach((pos, i) => {
    const isActive = i < dotProgress;
    ctx.save();

    // Active dots get a glow bubble
    if (isActive) {
      ctx.shadowColor = mc.shadow;
      ctx.shadowBlur = 12;
      // Outer glow ring
      ctx.beginPath();
      ctx.arc(pos.dx, pos.dy, 5, 0, 2 * Math.PI);
      ctx.fillStyle = 'rgba(255,255,255,0.15)';
      ctx.fill();
    }

    // Main dot
    ctx.shadowBlur = 0;
    ctx.beginPath();
    ctx.arc(pos.dx, pos.dy, isActive ? 3.5 : 2.5, 0, 2 * Math.PI);
    ctx.fillStyle = isActive
      ? getGradient(state.mode)
      : isDark ? 'rgba(255,255,255,0.06)' : 'rgba(0,0,0,0.05)';
    ctx.fill();
    ctx.restore();
  });
}

// ============================================================
//  4.  Timer Logic
// ============================================================
function formatTime(sec) {
  const m = Math.floor(sec / 60);
  const s = Math.floor(sec % 60);
  return `${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`;
}

function updateUI() {
  timerDisplay.textContent = formatTime(state.timeLeft);
  const labels = {
    idle: '准备开始',
    running: state.mode === 'pomodoro' ? '专注中……' : '放松中……',
    paused: '已暂停',
  };
  timerStatus.textContent = labels[state.status] || '';

  document.body.classList.toggle('running', state.status === 'running');

  const btnCfg = {
    running: { icon: '⏸', text: '暂停' },
    paused:  { icon: '▶', text: '继续' },
    idle:    { icon: '▶', text: '开始' },
  };
  const cfg = btnCfg[state.status] || btnCfg.idle;
  primaryBtn.innerHTML = `<span class="btn-icon">${cfg.icon}</span><span>${cfg.text}</span>`;
  primaryBtn.classList.toggle('running', state.status === 'running');

  sessionCount.textContent = state.pomodoroCount;
  updateSessionDots();
  updateCurrentTask();
  drawRing();
}

const sessionDotElements = sessionDots.querySelectorAll('span');

function updateSessionDots() {
  sessionDotElements.forEach((dot, i) => {
    dot.classList.toggle('done', i < state.pomodoroCount % config.longInterval);
  });
}

function updateCurrentTask() {
  const t = state.todos.find(t => t.id === state.currentTask);
  currentTaskText.textContent = t ? t.text : '—';
}

// Timer tick
function tick(timestamp) {
  if (state.status !== 'running') return;
  if (state.lastTimestamp === null) {
    state.lastTimestamp = timestamp;
    state.animId = requestAnimationFrame(tick);
    return;
  }
  const delta = timestamp - state.lastTimestamp;
  state.lastTimestamp = timestamp;
  if (delta >= 0) {
    state.timeLeft = Math.max(0, state.timeLeft - delta / 1000);
    updateUI();
    if (state.timeLeft <= 0) {
      state.timeLeft = 0;
      updateUI();
      onTimerComplete();
      return;
    }
  }
  state.animId = requestAnimationFrame(tick);
}

function startTimer() {
  if (state.status === 'idle' || state.status === 'paused') {
    state.status = 'running';
    state.lastTimestamp = null;
    state.animId = requestAnimationFrame(tick);
    updateUI();
  }
}

function pauseTimer() {
  if (state.status === 'running') {
    state.status = 'paused';
    cancelAnimationFrame(state.animId);
    state.animId = null;
    updateUI();
  }
}

function stopTimer() {
  cancelAnimationFrame(state.animId);
  state.animId = null;
  state.status = 'idle';
  state.lastTimestamp = null;
}

function resetTimer() {
  const wasActive = state.status === 'running' || state.status === 'paused';
  stopTimer();
  state.timeLeft = config[state.mode] * 60;
  updateUI();
}

function toggleTimer() {
  if (state.status === 'running') pauseTimer();
  else startTimer();
}

// ============================================================
//  5.  Audio System
// ============================================================
let audioCtx = null;

function getAudioCtx() {
  if (!audioCtx) audioCtx = new (window.AudioContext || window.webkitAudioContext)();
  return audioCtx;
}

function playNote(ctx, vol, now, freq, type, delay, dur) {
  const osc = ctx.createOscillator();
  const gain = ctx.createGain();
  osc.connect(gain); gain.connect(ctx.destination);
  osc.type = type;
  osc.frequency.value = freq;
  const t = now + delay;
  gain.gain.setValueAtTime(vol, t);
  gain.gain.exponentialRampToValueAtTime(0.001, t + dur);
  osc.start(t); osc.stop(t + dur);
}

const SOUND_PROFILES = {
  classic:  { notes: [[880,'sine',0.3],[1100,'sine',0.15],[880,'sine',0.3],[1100,'sine',0.45]], vol: 0.3, dur: 0.4 },
  gentle:   { notes: [[660,'triangle',0.2],[880,'triangle',0.25]], vol: 0.2, dur: 0.6 },
  digital:  { notes: [[1200,'square',0.1],[1500,'square',0.2]], vol: 0.1, dur: 0.15 },
};

const SOUNDS = {};
Object.entries(SOUND_PROFILES).forEach(([name, p]) => {
  SOUNDS[name] = (ctx, vol, now) => {
    p.notes.forEach(([freq, type, delay]) => {
      playNote(ctx, vol * p.vol, now, freq, type, delay, p.dur);
    });
  };
});
SOUNDS.none = () => {};

function playSound() {
  const snd = config.sound;
  if (snd === 'none') return;
  try {
    const ctx = getAudioCtx();
    const vol = config.volume / 100;
    const now = ctx.currentTime;
    (SOUNDS[snd] || SOUNDS.classic)(ctx, vol, now);
  } catch { /* silently fail */ }
}

// ============================================================
//  6.  Notification
// ============================================================
function sendNotification(title, body) {
  if (!config.notify) return;
  try {
    if (window.electronAPI) {
      window.electronAPI.showNotification(title, body);
      window.electronAPI.flashTaskbar();
    } else if (Notification.permission === 'granted') {
      new Notification(title, { body });
    } else if (Notification.permission !== 'denied') {
      Notification.requestPermission().then(p => {
        if (p === 'granted') new Notification(title, { body });
      });
    }
  } catch { /* fallback silent */ }
}

// ============================================================
//  7.  Timer Complete
// ============================================================
function onTimerComplete() {
  state.status = 'idle';
  playSound();

  if (state.mode === 'pomodoro') {
    // Record this pomodoro
    state.pomodoroCount++;
    state.totalPomodoros++;
    saveHistory();
    saveState();

    sendNotification('🍅 番茄搞定！', '专注 25 分钟，该放松一下了！');
    showResult('pomodoro');

    const nextMode = (state.pomodoroCount % config.longInterval === 0) ? 'longBreak' : 'shortBreak';
    setTimeout(() => switchMode(nextMode, config.autoBreak), 600);
  } else {
    sendNotification('⏰ 放松结束', '该回来继续搬砖了 💪');
    showResult('break');
    setTimeout(() => switchMode('pomodoro', config.autoPomo), 600);
  }
}

// ============================================================
//  8.  Result Overlay
// ============================================================
function showResult(type) {
  if (type === 'pomodoro') {
    const emojis = ['🎉', '🌟', '🏆', '✨', '🔥', '💪'];
    resultEmoji.textContent = emojis[Math.floor(Math.random() * emojis.length)];
    resultLabel.textContent = '番茄搞定！';
    const msgs = ['太棒了！', '专注力 MAX！', '又搞定一个！', '效率满满！'];
    resultTitle.textContent = msgs[Math.floor(Math.random() * msgs.length)];
    resultHint.textContent = `专注 25 分钟，起来活动一下吧 🚶`;
  } else {
    resultEmoji.textContent = '☕';
    resultLabel.textContent = '放松结束';
    resultTitle.textContent = '该继续搬砖了 💪';
    resultHint.textContent = '放松好了就回来干大事！';
  }
  resultOverlay.classList.add('show');
}

function hideResult() {
  resultOverlay.classList.remove('show');
}

resultBtn.addEventListener('click', hideResult);
resultOverlay.addEventListener('click', (e) => {
  if (e.target === resultOverlay) hideResult();
});

// ============================================================
//  9.  Mode Switching
// ============================================================
function switchMode(newMode, autoStart = false) {
  hideResult();
  stopTimer();
  state.mode = newMode;
  state.timeLeft = config[newMode] * 60;
  state.status = 'idle';
  state.lastTimestamp = null;

  $$('.mode-tab').forEach(tab => {
    tab.classList.toggle('active', tab.dataset.mode === newMode);
  });

  // Slide indicator to active tab
  const activeTab = document.querySelector('.mode-tab.active');
  const indicator = document.querySelector('.mode-indicator') || (() => {
    const el = document.createElement('div');
    el.className = 'mode-indicator';
    document.querySelector('.mode-tabs').appendChild(el);
    return el;
  })();
  if (activeTab) {
    const tabsRect = document.querySelector('.mode-tabs').getBoundingClientRect();
    const tabRect = activeTab.getBoundingClientRect();
    indicator.style.width = tabRect.width + 'px';
    indicator.style.transform = `translateX(${tabRect.left - tabsRect.left}px)`;
  }

  updateUI();

  if (autoStart) startTimer();
}

// ============================================================
//  10. Todo
// ============================================================

function renderTodos() {
  todoList.innerHTML = '';
  if (state.todos.length === 0) {
    todoList.innerHTML = '<div class="todo-empty">还没有待办，添加一个吧 📋</div>';
    todoCount.textContent = '0';
    return;
  }
  todoCount.textContent = state.todos.length;
  state.todos.forEach(todo => {
    const div = document.createElement('div');
    div.className = `todo-item${todo.done ? ' done' : ''}${todo.id === state.currentTask ? ' active' : ''}`;
    div.dataset.id = todo.id;

    const check = document.createElement('span');
    check.className = `todo-check${todo.done ? ' done' : ''}`;
    check.textContent = todo.done ? '✓' : '';

    const text = document.createElement('span');
    text.className = 'todo-text';
    text.textContent = todo.text;

    const del = document.createElement('button');
    del.className = 'todo-del';
    del.textContent = '✕';
    del.title = '删除';

    div.appendChild(check);
    div.appendChild(text);
    div.appendChild(del);

    // Click: select as current task
    div.addEventListener('click', (e) => {
      if (e.target === del) return;
      state.currentTask = todo.id;
      renderTodos();
      updateCurrentTask();
      saveState();
    });

    // Check: toggle done
    check.addEventListener('click', (e) => {
      e.stopPropagation();
      todo.done = !todo.done;
      renderTodos();
      saveState();
    });

    // Delete
    del.addEventListener('click', (e) => {
      e.stopPropagation();
      div.classList.add('removing');
      setTimeout(() => {
        state.todos = state.todos.filter(t => t.id !== todo.id);
        if (state.currentTask === todo.id) state.currentTask = null;
        renderTodos();
        updateCurrentTask();
        saveState();
      }, 200);
    });

    todoList.appendChild(div);
  });
}

function addTodo(text) {
  text = text.trim();
  if (!text) return;
  state.todos.unshift({ id: Date.now(), text, done: false });
  renderTodos();
  saveState();
  // Animate the first (newest) item
  const firstItem = todoList.querySelector('.todo-item');
  if (firstItem) firstItem.classList.add('new-item');
  todoInput.value = '';
  todoInput.focus();
}

todoAddBtn.addEventListener('click', () => addTodo(todoInput.value));
todoInput.addEventListener('keydown', (e) => {
  if (e.key === 'Enter') addTodo(todoInput.value);
});

// ============================================================
//  11. Statistics
// ============================================================
function getToday() {
  return new Date().toISOString().slice(0, 10);
}

function getWeekDates() {
  const now = new Date();
  const day = now.getDay(); // 0=Sun
  const monday = new Date(now);
  monday.setDate(now.getDate() - ((day + 6) % 7));
  return Array.from({ length: 7 }, (_, i) => {
    const d = new Date(monday);
    d.setDate(monday.getDate() + i);
    return d.toISOString().slice(0, 10);
  });
}

function getDayLabel(dateStr) {
  const days = ['日', '一', '二', '三', '四', '五', '六'];
  const d = new Date(dateStr);
  return days[d.getDay()];
}

function updateStats() {
  const today = getToday();
  const week = getWeekDates();
  const todayCount = state.history.filter(h => h.date === today).reduce((s, h) => s + h.count, 0);
  const weekCount = state.history.filter(h => week.includes(h.date)).reduce((s, h) => s + h.count, 0);
  const totalHours = (state.totalPomodoros * config.pomodoro / 60).toFixed(1);

  statToday.textContent = todayCount;
  statWeek.textContent = weekCount;
  statTotal.textContent = state.totalPomodoros;
  statHours.textContent = totalHours;

  // Week chart
  weekChart.innerHTML = '';
  const weekData = week.map(date => {
    const count = state.history.filter(h => h.date === date).reduce((s, h) => s + h.count, 0);
    return { date, count };
  });
  const maxCount = Math.max(...weekData.map(d => d.count), 1);
  weekData.forEach(d => {
    const bar = document.createElement('div');
    bar.className = 'week-bar';
    const fill = document.createElement('div');
    fill.className = 'week-bar-fill';
    fill.style.height = `${(d.count / maxCount) * 100}%`;
    const label = document.createElement('div');
    label.className = 'week-bar-label';
    label.textContent = getDayLabel(d.date);
    bar.appendChild(fill);
    bar.appendChild(label);
    weekChart.appendChild(bar);
  });

  // History list
  historyList.innerHTML = '';
  const recent = [...state.history].reverse().slice(0, 14);
  if (recent.length === 0) {
    historyList.innerHTML = '<div style="text-align:center;color:var(--text-sec);font-size:12px;padding:16px 0;">还没有历史记录</div>';
    return;
  }
  recent.forEach(h => {
    const div = document.createElement('div');
    div.className = 'history-item';
    div.innerHTML = `<span class="history-date">${h.date}</span><span class="history-count">🍅 × ${h.count}</span>`;
    historyList.appendChild(div);
  });
}

// ============================================================
//  12. History Persistence
// ============================================================
function saveHistory() {
  const today = getToday();
  const existing = state.history.find(h => h.date === today);
  if (existing) {
    existing.count++;
  } else {
    state.history.push({ date: today, count: 1 });
  }
}

// ============================================================
//  13. Settings
// ============================================================
function loadConfig() {
  try {
    const raw = localStorage.getItem('pomo_config');
    if (raw) return { ...DEFAULT_CONFIG, ...JSON.parse(raw) };
  } catch {}
  return { ...DEFAULT_CONFIG };
}

function saveConfig() {
  localStorage.setItem('pomo_config', JSON.stringify(config));
}

function applySettingsToUI() {
  setPomodoro.value = config.pomodoro;
  setShortBreak.value = config.shortBreak;
  setLongBreak.value = config.longBreak;
  setLongInterval.value = config.longInterval;
  setSound.value = config.sound;
  setVolume.value = config.volume;
  volumeVal.textContent = config.volume + '%';
  setAutoPomo.checked = config.autoPomo;
  setAutoBreak.checked = config.autoBreak;
  setNotify.checked = config.notify;
}

function saveSettings() {
  config.pomodoro = parseInt(setPomodoro.value) || 25;
  config.shortBreak = parseInt(setShortBreak.value) || 5;
  config.longBreak = parseInt(setLongBreak.value) || 15;
  config.longInterval = parseInt(setLongInterval.value) || 4;
  config.sound = setSound.value;
  config.volume = parseInt(setVolume.value) || 80;
  config.autoPomo = setAutoPomo.checked;
  config.autoBreak = setAutoBreak.checked;
  config.notify = setNotify.checked;
  saveConfig();

  // Update current session time if idle
  if (state.status === 'idle') {
    state.timeLeft = config[state.mode] * 60;
    updateUI();
  }
}

// Settings event listeners
[setPomodoro, setShortBreak, setLongBreak, setLongInterval, setSound, setVolume, setAutoPomo, setAutoBreak, setNotify].forEach(el => {
  el.addEventListener('change', saveSettings);
  if (el.type === 'range') {
    el.addEventListener('input', () => {
      volumeVal.textContent = el.value + '%';
      saveSettings();
    });
  }
});

clearDataBtn.addEventListener('click', () => {
  if (confirm('确定清除所有数据？（番茄记录、待办、设置将全部重置）')) {
    state.history = [];
    state.totalPomodoros = 0;
    state.pomodoroCount = 0;
    state.todos = [];
    state.currentTask = null;
    Object.assign(config, DEFAULT_CONFIG);
    saveConfig();
    applySettingsToUI();
    saveState();
    renderTodos();
    updateStats();
    updateUI();
  }
});

// ============================================================
//  14. State Persistence
// ============================================================
function saveState() {
  try {
    localStorage.setItem('pomo_state', JSON.stringify({
      pomodoroCount: state.pomodoroCount,
      totalPomodoros: state.totalPomodoros,
      history: state.history,
      todos: state.todos,
      currentTask: state.currentTask,
      mode: state.mode,
      timeLeft: state.timeLeft,
    }));
  } catch {}
}

function loadState() {
  try {
    const raw = localStorage.getItem('pomo_state');
    if (!raw) return;
    const saved = JSON.parse(raw);
    if (saved.pomodoroCount != null) state.pomodoroCount = saved.pomodoroCount;
    if (saved.totalPomodoros != null) state.totalPomodoros = saved.totalPomodoros;
    if (saved.history) state.history = saved.history;
    if (saved.todos) state.todos = saved.todos;
    if (saved.currentTask != null) state.currentTask = saved.currentTask;
    if (saved.mode && MODES.includes(saved.mode)) state.mode = saved.mode;
    if (saved.timeLeft != null && saved.timeLeft > 0) state.timeLeft = saved.timeLeft;
  } catch {}
}

// ============================================================
//  15. Theme / Dark Mode
// ============================================================
function loadTheme() {
  const theme = localStorage.getItem('pomo_theme') || 'light';
  document.body.className = theme;
  themeToggle.textContent = theme === 'dark' ? '☀️' : '🌙';
  drawRing();
}

function toggleTheme() {
  const isDark = document.body.classList.contains('dark');
  document.body.className = isDark ? 'light' : 'dark';
  localStorage.setItem('pomo_theme', document.body.className);
  themeToggle.textContent = isDark ? '🌙' : '☀️';
  drawRing();
}

themeToggle.addEventListener('click', toggleTheme);

// ============================================================
//  16. Event Listeners
// ============================================================

// Primary button
primaryBtn.addEventListener('click', toggleTimer);

// Reset
resetBtn.addEventListener('click', resetTimer);

// Mode tabs
modeTabs.addEventListener('click', (e) => {
  const tab = e.target.closest('.mode-tab');
  if (!tab || tab.dataset.mode === state.mode) return;
  switchMode(tab.dataset.mode);
});

// Keyboard shortcuts
document.addEventListener('keydown', (e) => {
  if (e.code === 'Space' && !e.repeat && !resultOverlay.classList.contains('show') &&
      !e.target.matches('input, select, textarea')) {
    e.preventDefault();
    toggleTimer();
  }
});

// Title bar controls
minimizeBtn.addEventListener('click', () => {
  if (window.electronAPI) window.electronAPI.minimize();
});
closeBtn.addEventListener('click', () => {
  if (window.electronAPI) window.electronAPI.close();
});

// Sidebar nav
snBtns.forEach(btn => {
  btn.addEventListener('click', () => {
    snBtns.forEach(b => b.classList.remove('active'));
    btn.classList.add('active');
    document.querySelector('.sidebar-view.active')?.classList.remove('active');
    const target = sidebarViews[btn.dataset.view];
    if (target) target.classList.add('active');
    if (btn.dataset.view === 'stats') {
      updateStats();
      // Animate week bars after a frame
      requestAnimationFrame(() => {
        document.querySelectorAll('.week-bar-fill').forEach(bar => {
          bar.style.animation = 'none';
          bar.offsetHeight; // reflow
          bar.style.animation = 'barGrow 0.5s cubic-bezier(0.34, 1.56, 0.64, 1)';
        });
      });
    }
  });
});

// ============================================================
//  17. Init
// ============================================================
function init() {
  loadTheme();
  applySettingsToUI();

  // Set initial mode tab
  $$('.mode-tab').forEach(tab => {
    tab.classList.toggle('active', tab.dataset.mode === state.mode);
  });

  renderTodos();
  updateStats();
  updateUI();

  // Init mode indicator after layout
  requestAnimationFrame(() => {
    const activeTab = document.querySelector('.mode-tab.active');
    if (!activeTab) return;
    const tabsEl = document.querySelector('.mode-tabs');
    // Create indicator if it doesn't exist
    let indicator = document.querySelector('.mode-indicator');
    if (!indicator) {
      indicator = document.createElement('div');
      indicator.className = 'mode-indicator';
      tabsEl.appendChild(indicator);
    }
    const tabsRect = tabsEl.getBoundingClientRect();
    const tabRect = activeTab.getBoundingClientRect();
    indicator.style.width = tabRect.width + 'px';
    indicator.style.transform = `translateX(${tabRect.left - tabsRect.left}px)`;
    indicator.style.transition = 'none';
    // Force reflow then enable transitions
    indicator.offsetHeight;
    indicator.style.transition = '';
  });

  if (window.electronAPI) {
    window.electronAPI.getVersion().then(v => {
      document.querySelector('.settings-footer').textContent = `番茄钟 v${v}  ·  Ctrl+Shift+T 切换窗口`;
    }).catch(() => {});
  }

  console.log('🍅 番茄钟已加载');
}

init();
