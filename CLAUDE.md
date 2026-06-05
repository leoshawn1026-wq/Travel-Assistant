# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A collection of productivity/entertainment web apps, primarily a **Pomodoro Timer** (Electron) and a **Wheel of Fortune** (standalone HTML).

## Projects

### 🍅 pomodoro-app — Electron 桌面番茄钟

Desktop Pomodoro timer built with Electron (no framework).

- **Entry:** `pomodoro-app/main.js` — Electron main process
- **Renderer:** `pomodoro-app/renderer/index.html` + `style.css` + `app.js` (complete)
- **Bridge:** `pomodoro-app/preload.js` — exposes `window.electronAPI` via contextBridge

**Architecture:**
- `main.js` handles window lifecycle, system tray, global shortcuts (`Ctrl+Shift+T`), system notifications, and IPC (`window-minimize`, `window-close`, `show-notification`, `flash-taskbar`, `get-app-version`)
- `app.js` (~800 lines) contains all renderer logic: timer state machine, Canvas ring progress, Web Audio API sound system, todo CRUD, statistics, settings persistence, and dark mode toggle
- Renderer has three sidebar views: task list (待办), statistics (统计), settings (设置)
- Timer supports three modes: pomodoro (25min), short break (5min), long break (15min) with auto-transition
- Data persistence is via `localStorage` (renderer-side) in two keys: `pomo_config` (settings) and `pomo_state` (todos, history, timer state)
- Light/dark theme support via CSS custom properties on `<body>`, persisted as `pomo_theme`

**Key commands:**
```bash
cd pomodoro-app
npm install          # Install Electron
npm start            # Launch the app
npm run dev          # Launch with --dev flag
```

**Notable:** Space toggles timer. Timer uses `requestAnimationFrame` for smooth Canvas updates and delta-based time tracking (not `setInterval`). Result overlay shown on pomodoro/break completion; auto-transition respects "auto start" settings.

### 🌀 摸鱼大转盘 — Wheel of Fortune (Standalone)

Single-file HTML game at `摸鱼大转盘.html`. Open directly in a browser — no build step, no dependencies. Canvas-based spinning wheel with 12 segments, CSS animations, and a result modal. Keyboard shortcut: Space to spin.

### 🗂 番茄钟/

Empty directory — placeholder for a future project.

## Git Notes

- Repository was recently initialized (`git init`) — no commits yet.
- `pomodoro-app/node_modules/` is checked in. Consider adding `.gitignore` before the first commit.
