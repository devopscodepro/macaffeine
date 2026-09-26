# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Menu bar app that keeps the Mac awake using a native power assertion. The display can still sleep.
- Status header at the top of the menu with a live indicator, remaining time and end time.
- Active for Duration submenu: indefinite or one of the presets (5, 10, 15, 30 minutes, 1–5 hours by default), with remaining time shown in the menu.
- Settings window with General, Durations and Safety tabs. The app shows up in the Dock and ⌘Tab while it's open. Opening the app again brings Settings up, handy when the menu bar icon is hidden.
- Keep Display On option, in the menu and in Settings. Switching it doesn't reset the timer.
- Safety rules, on by default: stop on battery below a chosen level, in Low Power Mode, or when the Mac overheats. They also prevent turning it on in those conditions.
- The menu header explains why keep awake stopped: timer finished, battery, Low Power Mode, heat, or macOS refusing the request.
- Optional notification when keep awake stops on its own.
- `macaffeine` command line tool: `run -- <command>` keeps the Mac awake while a command runs, plus `on`, `off`, `toggle`, `hold` and `release`.
- `macaffeine://` URL scheme for scripts and other apps.
- Holds: requests from scripts and tools live next to the manual session, show up in the menu ("While make is running") and go away when their process exits.
- Shortcuts actions: Keep Mac Awake, Allow Mac to Sleep, Toggle Keep Awake, Is Mac Kept Awake.
- Until… in the duration menu to keep awake until a time of day.
- Ready-made Claude Code hooks, see docs/automation.md.
- "Also Keeping Your Mac Awake" in the menu lists other apps and tools that block sleep, like caffeinate started by another app.
- Option to stop when you lock your screen. Command line and Shortcuts requests keep running.
- Option to show the remaining time next to the menu bar icon.
- The global shortcut can be changed or turned off in Settings.
- Russian localization.
- Your own duration presets (add, remove, restore defaults).
- Keep awake turns off by itself when the duration ends, including after the Mac wakes from sleep.
- Global shortcut ⌃⌥⌘K to toggle.
- Selected duration is remembered between launches.
- App icon and a matching menu bar icon: an empty cup when off, a hot one with steam when on.
- MIT license.
