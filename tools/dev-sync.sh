#!/usr/bin/env bash
#
# Run Salapify 3 on your emulator and restart it whenever the code changes.
#
#   bash tools/dev-sync.sh            # watch GITHUB  (Claude runs in the cloud)
#   bash tools/dev-sync.sh --local    # watch YOUR FILES (Claude runs on this Mac)
#
# Both modes hot restart the running app for you. You do not type anything
# after starting it. Stop with Ctrl-C, which stops the app too.
#
# WHICH MODE YOU WANT depends on where Claude is running, and picking the wrong
# one looks exactly like "my changes are not showing up".
#
#   Default mode watches origin/<your branch>. It is right when Claude is
#   working in a cloud session and PUSHING commits: the work only reaches your
#   Mac when this pulls it.
#
#   --local watches app/lib and app/pubspec.yaml on disk. It is right when
#   Claude Code is running on this machine and editing files directly, because
#   nothing is ever pushed and the default mode would sit there forever
#   reporting no new commits while the files under it changed.
#
# In --local mode a restart follows about two seconds after the last edit
# lands, so a screen is on the emulator before you have finished reading what
# changed.
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
LOCAL_INTERVAL=2
MODE="remote"

for arg in "$@"; do
  case "$arg" in
    --local) MODE="local" ;;
    -h | --help)
      sed -n '2,26p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "Unknown option: $arg" >&2
      echo "Use --local to watch your own files instead of GitHub." >&2
      exit 1
      ;;
  esac
done

cd "$(dirname "$0")/.." || exit 1

if [ ! -d "$APP_DIR" ]; then
  echo "Run this from inside the Salapify repository." >&2
  exit 1
fi

BRANCH="$(git rev-parse --abbrev-ref HEAD)"
# Built from the shell's own PID rather than mktemp, and that is a bug fix.
#
# This used to be `mktemp -u /tmp/salapify-flutter.XXXXXX.pid`. GNU mktemp
# happily substitutes X's that have a suffix after them, so it worked on Linux
# and in CI. BSD mktemp, which is what macOS ships, requires the X's to be LAST
# and fails outright:
#
#   mktemp: mkstemp failed on /tmp/salapify-flutter.XXXXXX.pid: File exists
#
# The failure was not fatal, which is what made it expensive. PIDFILE became
# the EMPTY STRING, the script carried on, and `flutter run --pid-file ""` died
# with "Flutter failed to write to a file at ''" and a PathNotFoundException
# pointing at nothing. The founder was told to fix a build error that did not
# exist. $$ is unique per run, portable, and needs no subprocess at all.
PIDFILE="/tmp/salapify-flutter.$$.pid"

# Set when a NEW PACKAGE arrives and the app must be rebuilt rather than hot
# restarted. A file rather than a variable, because the watcher runs in a
# background subshell and a variable set there never reaches the run loop.
#
# WHY THIS EXISTS. A hot restart re-runs Dart and nothing else. Adding a
# package with a NATIVE side (path_provider, share_plus, anything with a
# platform channel) also adds a generated plugin registrant that is compiled
# into the APK, so the running app has no implementation for the new channel
# no matter how many times it restarts. The founder hit this exactly:
#
#   MissingPluginException(No implementation found for method
#   getTemporaryDirectory on channel plugins.flutter.io/path_provider)
#
# and the same missing plugin was ALSO silently stopping every save, because
# storage reads the documents directory through the same channel. The script
# had been reporting "Restarting the app" the whole time and was telling the
# truth: it restarted, and a restart was never going to be enough.
REBUILD_FLAG="/tmp/salapify-rebuild.$$.flag"
STAMP="/tmp/salapify-watch.$$"

# A belt-and-braces guard for the class of failure above: never hand an empty
# path to `flutter run --pid-file`, whatever went wrong upstream.
if [ -z "$PIDFILE" ] || [ -z "$STAMP" ]; then
  echo "Could not build the temporary file paths. Not starting." >&2
  exit 1
fi

# A previous run that was killed rather than stopped can leave these behind,
# and a stale pid file makes the watcher signal a process that is long gone.
rm -f "$PIDFILE" "$STAMP" "$REBUILD_FLAG"

if [ "$MODE" = "local" ]; then
  echo "Watching your own files in $APP_DIR/, checking every ${LOCAL_INTERVAL}s."
  echo "Nothing is pulled and nothing is pushed. Edit and the app restarts."
else
  echo "Watching origin/$BRANCH, checking every ${INTERVAL}s."
  echo "If Claude is editing files ON THIS MAC rather than pushing, stop and"
  echo "run: bash tools/dev-sync.sh --local"
fi
echo "Press Ctrl-C to stop."
echo

# Set by cleanup so the relaunch loop below can tell a DELIBERATE stop from the
# emulator falling over. Without it, Ctrl-C would be answered by helpfully
# starting the app again, which is the opposite of what Ctrl-C means.
STOPPING=0

cleanup() {
  STOPPING=1
  echo
  echo "Stopping."
  if [ -f "$PIDFILE" ]; then
    kill "$(cat "$PIDFILE")" 2>/dev/null
    rm -f "$PIDFILE"
  fi
  rm -f "$STAMP" "$REBUILD_FLAG"
  [ -n "${WATCH_PID:-}" ] && kill "$WATCH_PID" 2>/dev/null
}
trap cleanup EXIT
trap 'cleanup; exit 0' INT TERM

# The watcher runs in the background and the APP stays in the foreground, so
# its output is what you see and its keyboard still works.
(
  # Wait for the first build before doing anything. It compiles everything from
  # nothing and is slow; every build after it is seconds.
  while [ ! -f "$PIDFILE" ]; do sleep 2; done
  sleep 5

  # LOCAL MODE: the files under this script are the only thing that moves.
  #
  # `find -newer` against a stamp file, rather than fswatch or inotify, because
  # neither ships with macOS and a setup step that needs Homebrew first is a
  # setup step that does not happen. This is POSIX and works out of the box.
  #
  # The watermark advances to the moment of the SCAN, not the moment the
  # restart finishes. A build takes seconds and an edit landing during one
  # would otherwise be older than a stamp touched afterwards, so it would be
  # skipped entirely and the emulator would sit on code one save behind.
  if [ "$MODE" = "local" ]; then
    : >"$STAMP"
    while true; do
      sleep "$LOCAL_INTERVAL"

      NOW="$(mktemp -u /tmp/salapify-now.XXXXXX)"
      touch "$NOW"
      CHANGED="$(
        find "$APP_DIR/lib" "$APP_DIR/pubspec.yaml" -newer "$STAMP" -print 2>/dev/null | head -1
      )"
      if [ -z "$CHANGED" ]; then
        rm -f "$NOW"
        continue
      fi

      # SETTLE FIRST. One change from a person is one file; one change from an
      # agent is often six in a row, and restarting on the first of them builds
      # a half-written tree and shows an error that fixes itself a second
      # later. Wait for two quiet seconds before doing anything.
      while true; do
        sleep "$LOCAL_INTERVAL"
        MORE="$(
          find "$APP_DIR/lib" "$APP_DIR/pubspec.yaml" -newer "$NOW" -print 2>/dev/null | head -1
        )"
        [ -z "$MORE" ] && break
        touch "$NOW"
      done

      mv -f "$NOW" "$STAMP"

      echo
      echo "Files changed. Restarting the app."

      NEEDS_REBUILD=0
      if find "$APP_DIR/pubspec.yaml" -newer "$STAMP" -print 2>/dev/null | grep -q . ||
        [ "$CHANGED" = "$APP_DIR/pubspec.yaml" ]; then
        echo "  pubspec.yaml changed, fetching packages."
        (cd "$APP_DIR" && flutter pub get >/dev/null)
        NEEDS_REBUILD=1
      fi

      if [ -f "$PIDFILE" ]; then
        if [ "$NEEDS_REBUILD" = "1" ]; then
          # A new package needs the NATIVE side rebuilt, which a hot restart
          # cannot do. Stop the app and let the run loop start it again.
          echo "  A package changed, so this needs a full rebuild."
          : >"$REBUILD_FLAG"
          kill -TERM "$(cat "$PIDFILE")" 2>/dev/null || true
        else
          kill -USR2 "$(cat "$PIDFILE")" 2>/dev/null ||
            echo "  Could not signal the app. Is it still running?"
        fi
      else
        echo "  App is not running, so there is nothing to restart."
      fi
    done
  fi

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

    # TWO GENERATED FILES WILL STRAND THIS SCRIPT IF NOTHING HANDLES THEM.
    #
    # `flutter pub get` rewrites app/pubspec.lock to whichever SDK ran it, and
    # from 3.47 also writes an analyzer.exclude block into
    # app/analysis_options.yaml. The founder's Mac runs a newer Flutter than
    # the CI pin, so merely RUNNING the app dirties both, `--ff-only` then
    # refuses, and this loop sits there fetching and declining to pull. The
    # emulator stays on old code while the terminal looks healthy, which is
    # exactly the failure this script exists to prevent. It happened on
    # 2026-09-18 and cost a round trip to diagnose.
    #
    # Only these two paths, and only when they are the ONLY thing dirty. Real
    # edits are never discarded: if anything else has changed the pull is left
    # to fail loudly, the way it did before.
    # "Anything else" means TRACKED changes only. An earlier version of this
    # asked `git status --porcelain`, which also lists UNTRACKED files, so a
    # stray file anywhere in the repo made it refuse to help. Untracked files
    # do not block a fast forward in the first place. Caught by testing the
    # check rather than reading it.
    GENERATED="$APP_DIR/pubspec.lock $APP_DIR/analysis_options.yaml"
    if ! git diff --quiet -- $GENERATED; then
      OTHER="$( { git diff --name-only; git diff --cached --name-only; } |
        grep -v -e "^$APP_DIR/pubspec.lock$" \
          -e "^$APP_DIR/analysis_options.yaml$" | head -1 )"
      if [ -z "$OTHER" ]; then
        echo "  Your Flutter rewrote pubspec.lock / analysis_options.yaml."
        echo "  Both are generated, so putting them back to let the pull through."
        git checkout -- $GENERATED 2>/dev/null
      else
        echo "  Generated files are dirty, but so is $OTHER, so nothing is"
        echo "  being discarded. The pull below will say what is in the way."
      fi
    fi

    if ! git pull --quiet --ff-only origin "$BRANCH"; then
      echo "  Could not fast forward. You have local changes, or the branch"
      echo "  was rebuilt. Sort it out by hand and this picks up again."
      echo "  What is in the way:"
      git --no-pager status --short | sed 's/^/    /'
      continue
    fi

    # THIS SCRIPT CANNOT UPGRADE ITSELF, so it says so instead of pretending.
    #
    # bash reads a script into memory once, when it starts. A pull that changes
    # tools/dev-sync.sh therefore changes the file on disk and NOT the loop that
    # is running, so a fix to this script only takes effect when somebody
    # restarts it. That is not a theoretical nuisance: the auto-heal above was
    # added precisely because pulls were being refused, and the founder then sat
    # on a stale commit because the OLD copy of this loop was still the one
    # running and still refusing. Two fixes, neither reaching them.
    #
    # It is announced loudly and the restart is left to the person, rather than
    # exec'ing the new copy automatically. Re-running yourself mid-loop with a
    # child `flutter run` attached is a good way to orphan the app and leave an
    # emulator nobody owns.
    if git --no-pager diff --name-only "$LOCAL" HEAD |
      grep -q '^tools/dev-sync.sh$'; then
      echo
      echo "  ############################################################"
      echo "  #  dev-sync.sh ITSELF was updated by this pull.            #"
      echo "  #  This running copy is still the OLD one.                 #"
      echo "  #  Press Ctrl-C and run it again to pick up the new one.   #"
      echo "  ############################################################"
      echo
    fi

    # New packages have to be fetched before a restart, or the restart fails in
    # a way that reads as a code error.
    NEEDS_REBUILD=0
    if git --no-pager diff --name-only "$LOCAL" HEAD |
      grep -q "$APP_DIR/pubspec.yaml"; then
      echo "  pubspec.yaml changed, fetching packages."
      (cd "$APP_DIR" && flutter pub get >/dev/null)
      NEEDS_REBUILD=1
    fi

    if [ -f "$PIDFILE" ] && [ "$NEEDS_REBUILD" = "1" ]; then
      echo "  A package changed, so this needs a full rebuild."
      : >"$REBUILD_FLAG"
      kill -TERM "$(cat "$PIDFILE")" 2>/dev/null || true
    elif [ -f "$PIDFILE" ]; then
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

# RELAUNCH WHEN THE EMULATOR DROPS, rather than quitting with it.
#
# `flutter run` holds the foreground, so the moment the device goes away it
# prints "Lost connection to device." and returns, the EXIT trap fires, and the
# whole watcher stops. Nothing is broken at that point and no code is at fault:
# the emulator was closed, went to sleep, or the app was force stopped. But the
# founder is then looking at a dead prompt with no idea that the fix they are
# waiting for is sitting one pull away, and the only way back is a command they
# have to be told. That happened, and being told a command is exactly the
# inefficiency this script exists to remove.
#
# So a lost device is treated as what it is, a pause. Ctrl-C still stops
# everything, because cleanup sets STOPPING first and the loop reads it.
# A BUILD FAILURE IS NOT A LOST EMULATOR, and the first version of this loop
# could not tell them apart. It answered "Gradle task assembleDebug failed with
# exit code 1" with "Lost the emulator. Waiting for it to come back", then
# retried every five seconds forever, burying the actual compiler error under
# its own message and telling the founder to fix a device that was never
# unplugged. That is worse than the crash it replaced.
#
# The discriminator is TIME. A real session runs for as long as the app is open,
# minutes at least. A build that fails comes back in seconds, which is what
# these runs did: 992ms and 1,074ms.
while true; do
  START="$(date +%s)"
  flutter run --pid-file "$PIDFILE"
  [ "$STOPPING" = "1" ] && break
  RAN=$(( $(date +%s) - START ))

  rm -f "$PIDFILE"
  echo

  # A rebuild we asked for is not a crash, however fast it came back. Without
  # this the loop reads its own deliberate stop as "the app never got running
  # properly" and prints a page of troubleshooting for a problem nobody has.
  if [ -f "$REBUILD_FLAG" ]; then
    rm -f "$REBUILD_FLAG"
    echo "Rebuilding with the new package. This one takes longer than a restart."
    echo
    continue
  fi

  if [ "$RAN" -lt 30 ]; then
    # Deliberately does NOT name the cause any more.
    #
    # It used to assert "this is a BUILD error and not a disconnected
    # emulator", and that confident sentence cost real time: a macOS-only
    # mktemp fault produced an empty --pid-file path, `flutter run` died on
    # that, and this told the founder to go hunting for a compiler error in a
    # run whose build had SUCCEEDED and whose APK had installed. A short run
    # proves the app did not stay up. It does not prove why.
    echo "The app stopped after ${RAN}s, so it never got running properly."
    echo "This is NOT a disconnected emulator, which would have run longer."
    echo
    echo "The reason is in the output ABOVE. Worth checking, in order:"
    echo "  1. A compile or Gradle error, usually past the '* Try:' block."
    echo "  2. A flutter tool error that is not about your code at all,"
    echo "     for example a path it could not write to."
    echo "  3. An emulator that started but could not host the app."
    echo
    echo "Not retrying, because retrying just buries the message that matters."
    echo "Fix it, then run: bash tools/dev-sync.sh"
    break
  fi

  echo "Lost the emulator. Waiting for it to come back, checking every 5s."
  echo "Start your emulator and this picks up on its own. Ctrl-C to stop."
  sleep 5
  [ "$STOPPING" = "1" ] && break
done
