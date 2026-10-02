# Automation

Macaffeine can be driven from Terminal, scripts, other apps and Shortcuts. Everything goes through the running app, so the menu always shows what's keeping your Mac awake, and safety rules (battery, Low Power Mode, heat) still apply.

There are two kinds of requests:

- **Session** — what you start from the menu, the hotkey, `macaffeine on` or `macaffeine://activate`. There's only one.
- **Hold** — a named request from a script or tool, e.g. "while `make` runs". There can be many. A hold can be tied to a process and goes away when that process exits, even if it crashes.

Your Mac stays awake while there's a session or at least one hold. Turning Keep Awake off from the menu or hotkey drops everything. The *Stop after your Mac sleeps* and *Stop when you lock your screen* rules end only the session — holds belong to running processes and keep going.

## Command line

If you installed Macaffeine with Homebrew (`brew install --cask devopscodepro/tap/macaffeine`), the `macaffeine` command is already on your `PATH`. Otherwise install it once (Settings → General shows the exact command with a Copy button):

```sh
sudo mkdir -p /usr/local/bin
sudo ln -sf /Applications/Macaffeine.app/Contents/Resources/macaffeine /usr/local/bin/macaffeine
```

Then:

```sh
macaffeine run -- make release          # awake while the command runs, exit code is passed through
macaffeine run --label "nightly" -- ./backup.sh
macaffeine run --for 3h -- ./long-job   # also give up after 3 hours, whatever happens

macaffeine on                           # selected duration
macaffeine on 45m                       # 90, 45m, 2h, 1h30m or indefinite
macaffeine on --until 18:30
macaffeine off
macaffeine toggle

macaffeine hold deploy --label "Deploy" --pid 12345 --for 2h
macaffeine release deploy
```

`run` releases its hold when the command finishes, when you press Ctrl-C, and even when the script itself is killed.

## URL scheme

Handy from other apps, Raycast/Alfred, or `open -g` in scripts (`-g` keeps Macaffeine in the background):

| URL | Does |
|---|---|
| `macaffeine://activate` | start with the selected duration; does nothing if already on |
| `macaffeine://activate?minutes=90` | keep awake for 90 minutes |
| `macaffeine://activate?until=18:30` | until 18:30 (tomorrow if that already passed) |
| `macaffeine://activate?duration=indefinite` | until turned off |
| `macaffeine://deactivate` | let the Mac sleep, drops holds too |
| `macaffeine://toggle` | on/off |
| `macaffeine://hold?id=ID&label=TEXT&pid=PID&minutes=N` | add a hold; `label`, `pid`, `minutes` are optional |
| `macaffeine://release?id=ID` | drop a hold |

## Shortcuts

Macaffeine adds these actions to the Shortcuts app:

- **Keep Mac Awake** — optional number of minutes
- **Allow Mac to Sleep**
- **Toggle Keep Awake**
- **Is Mac Kept Awake** — returns true or false

"Keep my Mac awake with Macaffeine" and "Let my Mac sleep with Macaffeine" are available right away, no setup needed.

## AI coding agents

### Claude Code

Add hooks to `~/.claude/settings.json` so your Mac stays awake exactly while Claude is working on a prompt:

```json
{
  "hooks": {
    "UserPromptSubmit": [
      { "hooks": [ { "type": "command", "command": "macaffeine hold claude-$PPID --label 'Claude Code' --pid $PPID --for 2h" } ] }
    ],
    "Stop": [
      { "hooks": [ { "type": "command", "command": "macaffeine release claude-$PPID" } ] }
    ]
  }
}
```

`$PPID` is the Claude Code process, so each session gets its own hold, and the hold disappears if Claude Code quits. `--for 2h` is a safety net in case `Stop` never fires.

### Other agents and long jobs

Wrap the command:

```sh
macaffeine run -- codex exec "fix the failing tests"
macaffeine run --label "Gemini" -- gemini
```

## Lid closed

macOS always sleeps when you close the lid, unless the Mac is connected to power and an external display. Macaffeine doesn't change that on purpose: forcing it needs admin rights and can overheat a Mac in a bag.
