#!/usr/bin/env bash
#
# Run Salapify 3 on your emulator and reload it whenever new work is pushed.
#
#   bash tools/dev-sync.sh
#
# What it does, in one sentence: it starts the app, then every 15 seconds it
# checks GitHub for new commits, pulls them, and tells the running app to
# reload itself. You do not have to type anything after starting it.
#
# WHY THIS EXISTS. Flutter's hot reload is triggered by a keypress in the
# terminal running `flutter run`, or by your editor saving a file. Neither of
# those happens when the change arrives over the network from somebody else's
# machine, so without this the loop is "notice a push, git pull, press r", and
# the noticing is the slow part.
#
# Stop it with Ctrl-C. That stops the app and the watcher together.

set -u

# Where the Flutter project lives, relative to the repository root.
APP_DIR="app"

# How often to check for new commits. Seconds. GitHub is fine with this: a
# fetch with nothing to fetch is a very small request.
INTERVAL=15

cd "$(dirname "$0")/.." || exit 1

if [ ! -d "$APP_DIR" ]; then
  echo "Run this from inside the Salapify repository." >&2
  exit 1
fi

BRANCH="$(git rev-parse --abbrev-ref HEAD)"
echo "Watching origin/$BRANCH, checking every ${INTERVAL}s."
echo

# A named pipe is how the watcher talks to the running app.
#
# `flutter run` reads its commands ("r" for reload, "R" for restart) from
# standard input. Pointing that at a pipe means anything written to the pipe
# arrives as if it had been typed, so the watcher below can press "r" without a
# human being there.
PIPE="$(mktemp -u /tmp/salapify-flutter.XXXXXX)"
mkfifo "$PIPE"

cleanup() {
  echo
  echo "Stopping."
  # Kill the whole process group so the app, the watcher and this script all go
  # together. Without this, quitting leaves flutter running invisibly and the
  # next run fails on a device that is already claimed.
  [ -n "${APP_PID:-}" ] && kill "$APP_PID" 2>/dev/null
  [ -n "${WATCH_PID:-}" ] && kill "$WATCH_PID" 2>/dev/null
  rm -f "$PIPE"
}
trap cleanup EXIT INT TERM

# Hold the pipe open. Without a writer that never closes, the pipe reaches end
# of file the moment the first write finishes and flutter run quits, which
# looks exactly like a crash and is not one.
sleep infinity > "$PIPE" &
WATCH_PID=$!

(
  cd "$APP_DIR" || exit 1
  flutter run < "$PIPE"
) &
APP_PID=$!

# Give the first build a moment before the watcher starts interrupting it. The
# first build is slow because it compiles everything from nothing; every build
# after it is seconds.
sleep 20

while true; do
  sleep "$INTERVAL"

  # Quietly ask GitHub what it has. This does NOT change your files.
  git fetch --quiet origin "$BRANCH" 2>/dev/null || continue

  LOCAL="$(git rev-parse HEAD 2>/dev/null)"
  REMOTE="$(git rev-parse "origin/$BRANCH" 2>/dev/null)"
  [ "$LOCAL" = "$REMOTE" ] && continue

  echo
  echo "New work on origin/$BRANCH:"
  git --no-pager log --oneline "HEAD..origin/$BRANCH" | sed 's/^/    /'

  if ! git pull --quiet --ff-only origin "$BRANCH"; then
    echo "  Could not fast forward. You have local changes, or the branch was"
    echo "  rebuilt. Sort it out by hand, then this will pick up again."
    continue
  fi

  # If the dependency list changed, the reload will fail in a confusing way
  # unless the new packages are fetched first.
  if git --no-pager diff --name-only "$LOCAL" HEAD | grep -q "$APP_DIR/pubspec.yaml"; then
    echo "  pubspec.yaml changed, fetching packages."
    (cd "$APP_DIR" && flutter pub get >/dev/null)
  fi

  # A capital R is a hot RESTART, not a hot reload. Deliberate: a pull can
  # bring in whole new files and changes to things that only run at startup,
  # and those are exactly the cases a plain reload silently does not pick up.
  # A restart costs a couple of seconds and is never wrong.
  echo "  Restarting the app."
  printf 'R\n' > "$PIPE"
done
