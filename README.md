# `zsh-paste-guard`

[![License: GPL-3.0](https://img.shields.io/badge/License-GPLv3-blue.svg)](LICENSE)
[![test](https://github.com/stefanoamorelli/zsh-paste-guard/actions/workflows/test.yml/badge.svg)](https://github.com/stefanoamorelli/zsh-paste-guard/actions/workflows/test.yml)
[![Shell: zsh 5.1+](https://img.shields.io/badge/Shell-zsh%205.1%2B-green.svg)](https://zsh.sourceforge.io/)
[![MITRE ATT&CK: T1204.004](https://img.shields.io/badge/MITRE%20ATT%26CK-T1204.004-red.svg)](https://attack.mitre.org/techniques/T1204/004/)

`zsh` plugin that intercepts pasted commands and requires typed confirmation before execution.

## Threat

[MITRE ATT&CK T1204.004](https://attack.mitre.org/techniques/T1204/004/) (User Execution: Malicious Copy and Paste) describes attacks where adversaries trick users into copying and pasting malicious commands into a terminal. The most common variant is ClickFix: fake error messages or CAPTCHA prompts instruct victims to open a terminal and paste a provided "fix" that actually executes malware.

> [!NOTE]
> The [ESET H1 2025 Threat Report](https://www.globenewswire.com/news-release/2025/06/26/3106011/0/en/ESET-Threat-Report-ClickFix-fake-error-surges-spreads-ransomware-and-other-malware.html) found a **517% surge** in ClickFix attacks between H2 2024 and H1 2025, making it the second most common attack vector after phishing. Nation-state groups from North Korea, Russia, Iran, and Pakistan have [adopted ClickFix](https://www.infosecurity-magazine.com/news/clickfix-attacks-surge-2025/) in their initial access toolkits.

`paste-guard` mitigates T1204.004 by detecting pasted input through [bracketed paste mode](https://cirw.in/blog/bracketed-paste), displaying the command for review, and blocking execution until the user types a confirmation phrase. The confirmation prompt reads from `/dev/tty`, so it cannot be satisfied by piped or scripted input.

## Install

```sh
make install
```

## Configuration

Set these environment variables in your `.zshrc` before sourcing the plugin.

| Variable | Default | Description |
|---|---|---|
| `PASTE_GUARD_CONFIRM_TEXT` | `I understand` | Phrase the user must type to confirm execution |
| `PASTE_GUARD_WARNING_MESSAGE` | `You pasted this command from outside the terminal.\nOnly run commands you fully understand.` | Warning shown when a paste is detected |

Basic example:

```sh
export PASTE_GUARD_CONFIRM_TEXT="run it"
export PASTE_GUARD_WARNING_MESSAGE="This command was pasted.\nReview it before running."
```

<details>
<summary>Advanced: per-team configuration with documentation links</summary>

You can set different confirmation phrases per environment and include links to your internal documentation in the warning message:

```sh
# In your team's shared .zshrc or shell profile
export PASTE_GUARD_CONFIRM_TEXT="I have reviewed this command"
export PASTE_GUARD_WARNING_MESSAGE="You pasted a command from outside the terminal.
Do NOT run commands you do not fully understand.
Review your team's security policy: https://yourcompany.atlassian.net/wiki/spaces/SEC/pages/123456/Terminal+Safety+Policy"
```

You can also set the confirmation text dynamically based on context:

```sh
# Different confirmation text for production vs staging
if [[ "$ENV" == "production" ]]; then
  export PASTE_GUARD_CONFIRM_TEXT="I accept production risk"
  export PASTE_GUARD_WARNING_MESSAGE="You are pasting a command in a PRODUCTION environment.
Confirm you have read: https://yourcompany.atlassian.net/wiki/spaces/OPS/pages/789/Production+Runbook"
else
  export PASTE_GUARD_CONFIRM_TEXT="ok"
fi
```

</details>

## Internals

`paste-guard` hooks into three zsh mechanisms:

1. **Bracketed paste mode** (zsh 5.1+, enabled by default). When text is pasted, the terminal wraps it in escape sequences (`\e[200~`...`\e[201~`). Zsh routes this through the `bracketed-paste` ZLE widget instead of processing each character individually. `paste-guard` overrides this widget to set a flag on paste.

2. **`accept-line` widget override.** When the user presses Enter, `paste-guard` checks the flag. If it was a paste, the command is printed for review and execution is blocked until confirmation. If the user typed the command, it runs immediately with no friction.

3. **`/dev/tty` confirmation.** The confirmation prompt reads directly from the terminal device, not from stdin. An attacker cannot embed the confirmation phrase inside the pasted payload or pipe it through a script.

## Compatibility

| Requirement | Details |
|---|---|
| Shell | zsh 5.1+ with ZLE |
| macOS | Catalina (10.15) and later (zsh is the default shell) |
| Linux | Any distribution with zsh installed |
| BSDs / WSL | Supported via zsh |
| Terminals | Terminal.app, iTerm2, Kitty, Ghostty, Alacritty, GNOME Terminal, Konsole, Windows Terminal, xterm |
| Dependencies | None. Uses only zsh builtins and ZLE. No Oh My Zsh or other framework required. |

## Uninstall

```sh
make uninstall
```

## References

- [MITRE ATT&CK T1204.004 - User Execution: Malicious Copy and Paste](https://attack.mitre.org/techniques/T1204/004/)
- [ClickFix Attacks Surge 517% in H1 2025 - Infosecurity Magazine](https://www.infosecurity-magazine.com/news/clickfix-attacks-surge-2025/)
- [ESET Threat Report: ClickFix Surges, Spreads Ransomware and Other Malware](https://www.globenewswire.com/news-release/2025/06/26/3106011/0/en/ESET-Threat-Report-ClickFix-fake-error-surges-spreads-ransomware-and-other-malware.html)
- [Bracketed Paste Mode - cirw.in](https://cirw.in/blog/bracketed-paste)

## License

[GPL-3.0](LICENSE)

Copyright (c) 2026 Stefano Amorelli <stefano@amorelli.tech>
