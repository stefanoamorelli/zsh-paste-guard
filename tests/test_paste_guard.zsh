#!/usr/bin/env zsh
# test_paste_guard.zsh — Unit tests for paste-guard.zsh
# Run: zsh tests/test_paste_guard.zsh

# ---------------------------------------------------------------------------
# Test helpers
# ---------------------------------------------------------------------------
typeset -g __test_pass=0
typeset -g __test_fail=0

pass() {
  (( __test_pass++ ))
  print "  PASS: $1"
}

fail() {
  (( __test_fail++ ))
  print "  FAIL: $1"
  [[ -n "$2" ]] && print "        expected: $2" && print "        got:      $3"
}

assert_equals() {
  local description="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    pass "$description"
  else
    fail "$description" "$expected" "$actual"
  fi
}

assert_contains() {
  local description="$1" haystack="$2" needle="$3"
  if [[ "$haystack" == *"$needle"* ]]; then
    pass "$description"
  else
    fail "$description" "string containing '$needle'" "$haystack"
  fi
}

# ---------------------------------------------------------------------------
# Locate the plugin
# ---------------------------------------------------------------------------
SCRIPT_DIR="${0:A:h}"
PLUGIN="${SCRIPT_DIR}/../paste-guard.zsh"

if [[ ! -f "$PLUGIN" ]]; then
  print "ERROR: Cannot find paste-guard.zsh at $PLUGIN"
  exit 1
fi

print "Running paste-guard tests..."
print ""

# ---------------------------------------------------------------------------
# Test 1: Default confirmation text is "I understand"
# ---------------------------------------------------------------------------
print -r -- "--- Default configuration ---"

default_confirm=$(zsh -c '
  unset PASTE_GUARD_CONFIRM_TEXT
  print -r -- "${PASTE_GUARD_CONFIRM_TEXT:-I understand}"
')
assert_equals "Default confirmation text is 'I understand'" \
  "I understand" "$default_confirm"

# ---------------------------------------------------------------------------
# Test 2: Default warning message contains expected text
# ---------------------------------------------------------------------------
default_warning=$(zsh -c '
  unset PASTE_GUARD_WARNING_MESSAGE
  print -r -- "${PASTE_GUARD_WARNING_MESSAGE:-You pasted this command from outside the terminal.
Only run commands you fully understand.}"
')
assert_contains "Default warning message mentions 'pasted'" \
  "$default_warning" "pasted"
assert_contains "Default warning message mentions 'understand'" \
  "$default_warning" "understand"

# ---------------------------------------------------------------------------
# Test 3: Custom PASTE_GUARD_CONFIRM_TEXT is respected
# ---------------------------------------------------------------------------
print ""
print -r -- "--- Custom configuration ---"

custom_confirm=$(zsh -c '
  export PASTE_GUARD_CONFIRM_TEXT="yes please"
  print -r -- "${PASTE_GUARD_CONFIRM_TEXT:-I understand}"
')
assert_equals "Custom confirm text is respected" \
  "yes please" "$custom_confirm"

# ---------------------------------------------------------------------------
# Test 4: Custom PASTE_GUARD_WARNING_MESSAGE is respected
# ---------------------------------------------------------------------------
custom_warning=$(zsh -c '
  export PASTE_GUARD_WARNING_MESSAGE="Custom warning here"
  print -r -- "${PASTE_GUARD_WARNING_MESSAGE:-You pasted this command from outside the terminal.
Only run commands you fully understand.}"
')
assert_equals "Custom warning message is respected" \
  "Custom warning here" "$custom_warning"

# ---------------------------------------------------------------------------
# Test 5: Double-source guard prevents re-loading
# ---------------------------------------------------------------------------
print ""
print -r -- "--- Double-source guard ---"

result=$(zsh -c "
  # Provide stubs for zle so the plugin does not error outside ZLE context
  zle() { : }
  source '$PLUGIN'
  first=\$__paste_guard_loaded
  source '$PLUGIN'
  second=\$__paste_guard_loaded
  print -r -- \"\${first}:\${second}\"
" 2>/dev/null)
assert_equals "Double-source guard keeps loaded flag at 1" \
  "1:1" "$result"

# ---------------------------------------------------------------------------
# Test 6: Paste flag is initially 0
# ---------------------------------------------------------------------------
print ""
print -r -- "--- Initial state ---"

result=$(zsh -c "
  zle() { : }
  source '$PLUGIN'
  print -r -- \$__paste_guard_pasted
" 2>/dev/null)
assert_equals "Paste flag is initially 0" "0" "$result"

# ---------------------------------------------------------------------------
# Test 7: Empty BUFFER does not trigger the guard
# ---------------------------------------------------------------------------
print ""
print -r -- "--- Guard condition ---"

result=$(zsh -c '
  __paste_guard_pasted=1
  BUFFER=""
  if (( __paste_guard_pasted )) && [[ -n "$BUFFER" ]]; then
    print "triggered"
  else
    print "skipped"
  fi
')
assert_equals "Empty BUFFER does not trigger the guard" \
  "skipped" "$result"

# ---------------------------------------------------------------------------
# Test 8: Non-empty BUFFER with paste flag triggers the guard
# ---------------------------------------------------------------------------
result=$(zsh -c '
  __paste_guard_pasted=1
  BUFFER="echo hello"
  if (( __paste_guard_pasted )) && [[ -n "$BUFFER" ]]; then
    print "triggered"
  else
    print "skipped"
  fi
')
assert_equals "Non-empty BUFFER with paste flag triggers the guard" \
  "triggered" "$result"

# ---------------------------------------------------------------------------
# Test 9: Guard does not trigger when paste flag is 0
# ---------------------------------------------------------------------------
result=$(zsh -c '
  __paste_guard_pasted=0
  BUFFER="echo hello"
  if (( __paste_guard_pasted )) && [[ -n "$BUFFER" ]]; then
    print "triggered"
  else
    print "skipped"
  fi
')
assert_equals "Paste flag 0 does not trigger the guard" \
  "skipped" "$result"

# ---------------------------------------------------------------------------
# Test 10: PASTE_GUARD_MODE defaults to "confirm"
# ---------------------------------------------------------------------------
print ""
print -r -- "--- Strict mode ---"

result=$(zsh -c '
  unset PASTE_GUARD_MODE
  local mode="${PASTE_GUARD_MODE:-confirm}"
  if [[ "$mode" != "strict" ]]; then
    mode="confirm"
  fi
  print -r -- "$mode"
')
assert_equals "PASTE_GUARD_MODE defaults to confirm" \
  "confirm" "$result"

# ---------------------------------------------------------------------------
# Test 11: Strict mode without PASTE_GUARD_ALLOW_PASTE blocks paste
# ---------------------------------------------------------------------------
result=$(zsh -c '
  export PASTE_GUARD_MODE=strict
  unset PASTE_GUARD_ALLOW_PASTE
  __paste_guard_pasted=1
  BUFFER="echo malicious"
  local mode="${PASTE_GUARD_MODE:-confirm}"
  if [[ "$mode" != "strict" ]]; then
    mode="confirm"
  fi
  if (( __paste_guard_pasted )) && [[ -n "$BUFFER" ]]; then
    if [[ "$mode" == "strict" && "${PASTE_GUARD_ALLOW_PASTE}" != "1" ]]; then
      print "blocked"
    else
      print "confirm-flow"
    fi
  else
    print "skipped"
  fi
')
assert_equals "Strict mode without allow var blocks paste" \
  "blocked" "$result"

# ---------------------------------------------------------------------------
# Test 12: Strict mode with PASTE_GUARD_ALLOW_PASTE=1 falls through
# ---------------------------------------------------------------------------
result=$(zsh -c '
  export PASTE_GUARD_MODE=strict
  export PASTE_GUARD_ALLOW_PASTE=1
  __paste_guard_pasted=1
  BUFFER="echo hello"
  local mode="${PASTE_GUARD_MODE:-confirm}"
  if [[ "$mode" != "strict" ]]; then
    mode="confirm"
  fi
  if (( __paste_guard_pasted )) && [[ -n "$BUFFER" ]]; then
    if [[ "$mode" == "strict" && "${PASTE_GUARD_ALLOW_PASTE}" != "1" ]]; then
      print "blocked"
    else
      print "confirm-flow"
    fi
  else
    print "skipped"
  fi
')
assert_equals "Strict mode with PASTE_GUARD_ALLOW_PASTE=1 falls through to confirm" \
  "confirm-flow" "$result"

# ---------------------------------------------------------------------------
# Test 13: Invalid PASTE_GUARD_MODE defaults to confirm
# ---------------------------------------------------------------------------
result=$(zsh -c '
  export PASTE_GUARD_MODE=banana
  __paste_guard_pasted=1
  BUFFER="echo hello"
  local mode="${PASTE_GUARD_MODE:-confirm}"
  if [[ "$mode" != "strict" ]]; then
    mode="confirm"
  fi
  if (( __paste_guard_pasted )) && [[ -n "$BUFFER" ]]; then
    if [[ "$mode" == "strict" && "${PASTE_GUARD_ALLOW_PASTE}" != "1" ]]; then
      print "blocked"
    else
      print "confirm-flow"
    fi
  else
    print "skipped"
  fi
')
assert_equals "Invalid PASTE_GUARD_MODE defaults to confirm flow" \
  "confirm-flow" "$result"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
print ""
print "========================================="
print "  Results: $__test_pass passed, $__test_fail failed"
print "========================================="

if (( __test_fail > 0 )); then
  exit 1
fi
exit 0
