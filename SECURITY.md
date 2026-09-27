# Security

## Reporting a vulnerability

Please don't open a public issue for security problems. Report them privately through [GitHub's private vulnerability reporting](https://github.com/devopscodepro/macaffeine/security/advisories/new) instead.

Include what you found, how to reproduce it and what an attacker could do with it. I'll get back to you as soon as I can, usually within a few days, and keep you posted until it's fixed. If you'd like to be credited in the release notes, say so.

## Supported versions

Only the latest release gets security fixes. Macaffeine updates are small, so please update before reporting.

## What Macaffeine can and can't do

It helps to know the boundaries when judging an issue:

- The app runs in the App Sandbox with the Hardened Runtime and has no network access.
- It keeps the Mac awake only through standard power assertions (`IOPMAssertion`). It never runs `pmset`, never asks for admin rights and has no privileged helper.
- The `macaffeine://` URL scheme and the `macaffeine` command line tool can turn keep awake on and off and add or remove holds. Nothing else.
- Settings are stored in the app's sandbox container.

Things like "a web page can open `macaffeine://activate`" are known and by design: the worst outcome is your Mac staying awake, and the menu always shows why.
