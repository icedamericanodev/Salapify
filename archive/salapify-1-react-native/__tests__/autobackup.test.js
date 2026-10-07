// Regression suite for lib/autobackup.js: the pure brains of the Pro automatic
// backup. These functions decide WHEN a backup runs and WHICH old files get
// rotated away, so a bug here could either skip backups or delete a file we did
// not create. Everything is deterministic: the time is always passed in.

import {
  shouldRunAutoBackup,
  filesToPrune,
  autoBackupFilename,
  autoBackupFilenameFromDate,
  AUTO_PREFIX,
} from '../lib/autobackup';

// A settings object that passes every guard, so each test can flip one field.
const okSettings = {
  pro: true,
  autoBackup: true,
  autoBackupUri: 'content://tree/primary%3ABackups',
  lastAutoBackupAt: '2026-07-08',
};
const TODAY = '2026-07-09';

describe('shouldRunAutoBackup gates on Pro, the toggle, a folder, and once-a-day', () => {
  test('all guards satisfied returns true', () => {
    expect(shouldRunAutoBackup(okSettings, TODAY)).toBe(true);
  });
  test('not Pro returns false', () => {
    expect(shouldRunAutoBackup({ ...okSettings, pro: false }, TODAY)).toBe(false);
  });
  test('a truthy but non-true pro (like a string) does not unlock', () => {
    expect(shouldRunAutoBackup({ ...okSettings, pro: 'yes' }, TODAY)).toBe(false);
  });
  test('autoBackup toggle off returns false', () => {
    expect(shouldRunAutoBackup({ ...okSettings, autoBackup: false }, TODAY)).toBe(false);
  });
  test('no folder chosen returns false', () => {
    expect(shouldRunAutoBackup({ ...okSettings, autoBackupUri: '' }, TODAY)).toBe(false);
  });
  test('already backed up today returns false', () => {
    expect(shouldRunAutoBackup({ ...okSettings, lastAutoBackupAt: TODAY }, TODAY)).toBe(false);
  });
  test('never backed up before (empty stamp) still runs', () => {
    expect(shouldRunAutoBackup({ ...okSettings, lastAutoBackupAt: '' }, TODAY)).toBe(true);
  });
  test('a null settings object never runs', () => {
    expect(shouldRunAutoBackup(null, TODAY)).toBe(false);
  });
});

describe('autoBackupFilename builds a sortable dated name', () => {
  test('zero pads every part', () => {
    expect(
      autoBackupFilename({ year: 2026, month: 7, day: 9, hours: 8, minutes: 5 })
    ).toBe('salapify-auto-2026-07-09-0805.json');
  });
  test('the from-Date wrapper reads local parts', () => {
    // Local Date parts, month is 0-based in the constructor.
    const d = new Date(2026, 11, 3, 21, 45);
    expect(autoBackupFilenameFromDate(d)).toBe('salapify-auto-2026-12-03-2145.json');
  });
  test('names sort chronologically as plain strings', () => {
    const early = autoBackupFilename({ year: 2026, month: 1, day: 2, hours: 3, minutes: 4 });
    const late = autoBackupFilename({ year: 2026, month: 12, day: 31, hours: 23, minutes: 59 });
    expect([late, early].sort()).toEqual([early, late]);
  });
});

describe('filesToPrune keeps the newest N and never touches foreign files', () => {
  const auto = (mmdd) => `${AUTO_PREFIX}2026-${mmdd}-0900.json`;
  test('deletes the oldest beyond keep, keeps the newest N', () => {
    const names = [auto('07-01'), auto('07-05'), auto('07-03'), auto('07-09'), auto('07-07')];
    // keep 2: newest two are 07-09 and 07-07, delete the other three oldest.
    const pruned = filesToPrune(names, 2);
    expect(pruned.sort()).toEqual([auto('07-01'), auto('07-03'), auto('07-05')]);
  });
  test('fewer files than keep deletes nothing', () => {
    const names = [auto('07-01'), auto('07-02')];
    expect(filesToPrune(names, 7)).toEqual([]);
  });
  test('exactly keep deletes nothing', () => {
    const names = [auto('07-01'), auto('07-02'), auto('07-03')];
    expect(filesToPrune(names, 3)).toEqual([]);
  });
  test('ignores files that are not ours, even when over the limit', () => {
    const names = [
      auto('07-01'),
      auto('07-02'),
      'salapify-backup-2026-07-02.json', // manual backup, different prefix
      'random.txt',
      'IMG_0001.jpg',
    ];
    // keep 1: only our two auto files count, delete the older one, foreign
    // files are never returned for deletion.
    expect(filesToPrune(names, 1)).toEqual([auto('07-01')]);
  });
  test('an empty or non-array input is safe', () => {
    expect(filesToPrune([], 3)).toEqual([]);
    expect(filesToPrune(undefined, 3)).toEqual([]);
  });
  test('keep of zero deletes all of our files', () => {
    const names = [auto('07-01'), auto('07-02')];
    expect(filesToPrune(names, 0).sort()).toEqual([auto('07-01'), auto('07-02')]);
  });
});
