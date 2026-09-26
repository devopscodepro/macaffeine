# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Menu bar app that keeps the Mac awake using a native power assertion. The display can still sleep.
- Active for Duration submenu: indefinite or one of the presets (5, 10, 15, 30 minutes, 1–5 hours by default), with remaining time shown in the menu.
- Settings window: Launch at Login and your own duration presets (add, remove, restore defaults). The app shows up in the Dock and ⌘Tab while it's open.
- Keep awake turns off by itself when the duration ends, including after the Mac wakes from sleep.
- Global hotkey ⌃⌥⌘K to toggle.
- Selected duration is remembered between launches.
- App icon.
- MIT license.
