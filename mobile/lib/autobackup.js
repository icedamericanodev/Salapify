// autobackup.js: the pure, testable brains of the automatic backup feature.
//
// IMPORTANT: only the AUTOMATIC backup is Pro. Manual backup, restore, CSV
// export, and v1 import stay free forever, because data portability is never
// something we lock behind a paywall. This file owns only the automatic path.
//
// Everything here is a pure function: no clock reads, no file IO, no Platform
// checks. The caller (AppData.js) passes the time in and does the Platform.OS
// guard, so this module stays deterministic and easy to test in the harness.
// The actual SAF reads and writes live in files.js next to saveToDevice.

// The filename prefix that marks a file as one WE created for auto backup.
// Rotation filters strictly to this prefix so we can never delete a file the
// user (or another app) dropped in the same folder.
export const AUTO_PREFIX = 'salapify-auto-';

// shouldRunAutoBackup: the guard, minus the Platform check (that stays in the
// caller so this file has no react-native import). Runs only when the user is
// Pro, has the feature on, has picked a folder, and has not already backed up
// today. lastAutoBackupAt is a YYYY-MM-DD string compared for equality with
// todayStr, the same shape and discipline as the recurring monthKey guard.
export function shouldRunAutoBackup(settings, todayStr) {
  if (!settings) return false;
  return (
    settings.pro === true &&
    settings.autoBackup === true &&
    !!settings.autoBackupUri &&
    settings.lastAutoBackupAt !== todayStr
  );
}

// autoBackupFilename: builds 'salapify-auto-YYYY-MM-DD-HHmm.json' from the
// parts passed in. Deterministic on purpose (no Date.now inside), so tests can
// pin the exact name. The date part is zero padded and the time is a 24 hour
// HHmm, which keeps the name lexically sortable in chronological order, the
// property filesToPrune below relies on.
export function autoBackupFilename({ year, month, day, hours, minutes }) {
  const p2 = (n) => String(n).padStart(2, '0');
  return `${AUTO_PREFIX}${year}-${p2(month)}-${p2(day)}-${p2(hours)}${p2(minutes)}.json`;
}

// autoBackupFilenameFromDate: a small convenience wrapper for the caller, still
// taking the Date in from outside so this module never reads the clock itself.
export function autoBackupFilenameFromDate(d) {
  return autoBackupFilename({
    year: d.getFullYear(),
    month: d.getMonth() + 1,
    day: d.getDate(),
    hours: d.getHours(),
    minutes: d.getMinutes(),
  });
}

// filesToPrune: pure rotation logic. Given every filename found in the folder
// and the keep-N count, return the list of OUR files to delete (the oldest
// ones beyond the newest N). Foreign names and anything not starting with our
// prefix are ignored entirely, so we never delete a file we did not create.
// Because the timestamped name sorts chronologically, a plain string sort puts
// oldest first; we keep the tail of length keep and delete the head.
export function filesToPrune(names, keep) {
  const ours = (Array.isArray(names) ? names : []).filter(
    (n) => typeof n === 'string' && n.startsWith(AUTO_PREFIX)
  );
  ours.sort(); // ascending: oldest first, newest last
  const keepN = Math.max(0, Math.trunc(Number(keep)) || 0);
  if (ours.length <= keepN) return [];
  return ours.slice(0, ours.length - keepN);
}
