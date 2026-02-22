# paste-guard.zsh
# Force confirmation before executing pasted commands.
#
# When text is pasted into the terminal (detected via bracketed paste mode),
# the plugin shows the command, highlights it, and requires the user to type
# a confirmation phrase to execute. Typed commands are unaffected.
#
# Works on any system with zsh 5.1+ and a terminal that supports bracketed
# paste mode (macOS, Linux, BSDs, WSL). No Oh My Zsh required.
#
# Configuration (set these env vars before sourcing, or export in .zshrc):
#
#   PASTE_GUARD_MODE
#     Operating mode. "confirm" (default) shows the command and asks for
#     typed confirmation. "strict" blocks all pasted commands unless
#     PASTE_GUARD_ALLOW_PASTE=1 is exported (in which case it falls
#     through to the confirm flow).
#     Default: "confirm"
#
#   PASTE_GUARD_ALLOW_PASTE
#     Only used in strict mode. Set to "1" to allow pasted commands
#     (they still go through the confirm flow). When unset or any
#     other value, pasting is blocked entirely.
#
#   PASTE_GUARD_CONFIRM_TEXT
#     The text the user must type to confirm execution.
#     Default: "I understand"
#
#   PASTE_GUARD_WARNING_MESSAGE
#     The warning message shown to the user. Use \n for line breaks.
#     Default: "You pasted this command from outside the terminal.
#               Only run commands you fully understand."
#
# Install:
#   1. Copy this file somewhere, e.g. ~/.paste-guard.zsh
#   2. Add this line to your ~/.zshrc:
#        source ~/.paste-guard.zsh
#   3. Open a new terminal window.
#
# Uninstall:
#   Remove the source line from ~/.zshrc.

# Guard against double-sourcing
if (( ${+__paste_guard_loaded} )); then
  return
fi
typeset -g __paste_guard_loaded=1

# Track whether the current buffer content came from a paste
typeset -g __paste_guard_pasted=0

# Override the bracketed-paste widget to detect paste events.
# Bracketed paste mode is enabled by default in zsh 5.1+.
# When the terminal sends a paste, zsh invokes the "bracketed-paste" widget
# instead of inserting characters one by one — this is how we tell paste
# apart from typing.
function __paste_guard_bracketed_paste() {
  zle .bracketed-paste
  __paste_guard_pasted=1
}
zle -N bracketed-paste __paste_guard_bracketed_paste

# Override accept-line (Enter key) to intercept pasted commands
function __paste_guard_accept_line() {
  if (( __paste_guard_pasted )) && [[ -n "$BUFFER" ]]; then
    local pasted_cmd="$BUFFER"

    # Determine operating mode (default: confirm)
    local mode="${PASTE_GUARD_MODE:-confirm}"
    if [[ "$mode" != "strict" ]]; then
      mode="confirm"
    fi

    # Strict mode: block paste unless PASTE_GUARD_ALLOW_PASTE=1
    if [[ "$mode" == "strict" && "${PASTE_GUARD_ALLOW_PASTE}" != "1" ]]; then
      __paste_guard_pasted=0
      BUFFER=""
      CURSOR=0
      <PERSON>print ""
      print "\033[1;31m================================================================\033[0m"
      print "\033[1;31m  PASTED COMMAND BLOCKED\033[0m"
      print "\033[1;31m================================================================\033[0m"
      print ""
      print "\033[1;37m  $pasted_cmd\033[0m"
      print ""
      print "\033[1;31m================================================================\033[0m"
      print "\033[0;31m  Pasting commands is disabled in strict mode.\033[0m"
      print "\033[0;31m  Contact your team lead or export PASTE_GUARD_ALLOW_PASTE=1\033[0m"
      print "\033[0;31m  to enable pasting.\033[0m"
      print "\033[1;31m================================================================\033[0m"
      print ""
      <PERSON> .reset-prompt
      return
    fi

    # Configurable confirmation text and warning message
    local confirm_text="${PASTE_GUARD_CONFIRM_TEXT:-I understand}"
    local warning_message="${PASTE_GUARD_WARNING_MESSAGE:-You pasted this command from outside the terminal.
Only run commands you fully understand.}"

    # Reset flag immediately
    __paste_guard_pasted=0

    # Clear the buffer so nothing lingers in ZLE
    BUFFER=""
    CURSOR=0

    # Tell ZLE we're about to write outside its control
    zle -I

    print ""
    print "\033[1;33m================================================================\033[0m"
    print "\033[1;33m  PASTED COMMAND DETECTED\033[0m"
    print "\033[1;33m================================================================\033[0m"
    print ""
    print "\033[1;37m  $pasted_cmd\033[0m"
    print ""
    print "\033[1;33m================================================================\033[0m"
    # Print each line of the warning message with styling
    print -r -- "$warning_message" | while IFS= read -r __pg_line; do
      print "\033[0;33m  $__pg_line\033[0m"
    done
    print "\033[1;33m================================================================\033[0m"
    print ""
    print -n "\033[1;31m  Type '$confirm_text' to run, or anything else to cancel: \033[0m"

    local response
    read -r response < /dev/tty

    if [[ "$response" == "$confirm_text" ]]; then
      print "\033[1;32m  Running command.\033[0m"
      print ""
      # Put the command back and execute
      zle -U "$pasted_cmd"
      zle .accept-line
    else
      print "\033[1;31m  Command cancelled.\033[0m"
      print ""
      # Redraw a clean prompt with empty buffer
      zle .reset-prompt
    fi
  else
    __paste_guard_pasted=0
    zle .accept-line
  fi
}
zle -N accept-line __paste_guard_accept_line
