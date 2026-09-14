#!/usr/bin/env bash
#
# Run Salapify 3 on your emulator and reload it whenever new work is pushed.
#
#   bash tools/dev-sync.sh
#
# Every 15 seconds it checks GitHub for new commits, pulls them, and hot
# restarts the running app. You do not type anything after starting it.
# Stop with Ctrl-C, which stops the app too.
#
# WHY A SIGNAL, AND NOT A PIPE. The first version of this wrote "R" into a
# named pipe attached to `flutter run`'s stdin, on the assumption that a
# keystroke is a keystroke. It is not: Flutter only enables its interactive
# key handling when stdin is a real TERMINAL. Given a pipe it runs the app
# perfectly and ignores everything written at it, so the script pulled new code
# every fifteen seconds and never once restarted, while looking like it worked.
# The founder hit this within minutes: their emulator stayed on old code and
# the missing feature they reported was already on their machine.
#
# `--pid-file` plus a signal is the documented way to drive a running Flutter
# app from a script:
#
#   SIGUSR1  hot reload
#   SIGUSR2  hot restart
#
# It also leaves stdin alone, so the terminal stays interactive and you can
# still press r, R or q yourself while this is running.

set -u

APP_DIR="app"
INTERVAL=15

cd "$(dirname "$0")/.." || exit 1

if [ ! -d "$APP_DIR" ]; then
  echo "Run this from inside the Salapify repository." >&2
  exit 1
fi

BRANCH="$(git rev-parse --abbrev-ref HEAD)"
PIDFILE="$(mktemp -u /tmp/salapify-flutter.XXXXXX.pid)"

echo "Watching origin/$BRANCH, checking every ${INTERVAL}s."
echo "Press Ctrl-C to stop."
echo

cleanup() {
  echo
  echo "Stopping."
  if [ -f "$PIDFILE" ]; then
    kill "$(cat "$PIDFILE")" 2>/dev/null
    rm -f "$PIDFILE"
  fi
  [ -n "${APP_PID:-}" ] && kill "$APP_PID" 2>/dev/null
  [ -n "${WATCH_PID:-}" ] && kill "$WATCH_PID" 2>/dev/null
}
trap cleanup EXIT INT TERM

# The watcher runs in the background and the APP stays in the foreground, so
# its output is what you see and its keyboard still works.
(
  # Wait for the first build before doing anything. It compiles everything from
  # nothing and is slow; every build after it is seconds.
  while [ ! -f "$PIDFILE" ]; do sleep 2; done
  sleep 5

  while true; do
    sleep "$INTERVAL"

    # Ask GitHub what it has. This does NOT change your files.
    git fetch --quiet origin "$BRANCH" 2>/dev/null || continue

    LOCAL="$(git rev-parse HEAD 2>/dev/null)"
    REMOTE="$(git rev-parse "origin/$BRANCH" 2>/dev/null)"
    [ -z "$REMOTE" ] && continue
    [ "$LOCAL" = "$REMOTE" ] && continue

    echo
    echo "New work on origin/$BRANCH:"
    git --no-pager log --oneline "HEAD..origin/$BRANCH" | sed 's/^/    /'

    if ! git pull --quiet --ff-only origin "$BRANCH"; then
      echo "  Could not fast forward. You have local changes, or the branch"
      echo "  was rebuilt. Sort it out by hand and this picks up again."
      continue
    fi

    # New packages have to be fetched before a restart, or the restart fails in
    # a way that reads as a code error.
    if git --no-pager diff --name-only "$LOCAL" HEAD |
      grep -q "$APP_DIR/pubspec.yaml"; then
      echo "  pubspec.yaml changed, fetching packages."
      (cd "$APP_DIR" && flutter pub get >/dev/null)
    fi

    if [ -f "$PIDFILE" ]; then
      # SIGUSR2 is a hot RESTART, not a reload, and that is deliberate. A pull
      # brings whole new files and changes to things that only run at startup,
      # and a plain reload silently skips const widgets. That exact gap left a
      # screen title and a whole button on old code while everything around
      # them updated.
      echo "  Restarting the app."
      kill -USR2 "$(cat "$PIDFILE")" 2>/dev/null ||
        echo "  Could not signal the app. Is it still running?"
    else
      echo "  App is not running, so there is nothing to restart."
    fi
  done
) &
WATCH_PID=$!

cd "$APP_DIR" || exit 1
flutter run --pid-file "$PIDFILE"
APP_PID=$!
