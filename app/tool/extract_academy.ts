// Extracts the Academy curriculum from src/data/academyData.ts into JSON, so
// the Dart port is a transcription of the real thing rather than a retyping
// of it.
//
//   bun app/tool/extract_academy.ts > academy.json
//
// Why programmatic: 32 courses, 96 lesson sections and 24 quizzes is a list
// with a typo in it if a person copies it. The same reason the fast-log
// keyword map was extracted rather than retyped.
//
// The module imports lucide-react for its icons, which does not resolve here
// and would not survive into Flutter anyway. The icons are turned into NAMES,
// which is what Salapify's own icon resolver takes.

import { readFileSync, writeFileSync, mkdtempSync } from 'fs';
import { tmpdir } from 'os';
import { join } from 'path';

const src = readFileSync('src/data/academyData.ts', 'utf8');

// Drop the lucide import and quote every icon reference, so `iconName: Target`
// becomes `iconName: 'Target'` and the module needs no React at all.
const withoutImport = src.replace(
  /^import\s*\{[\s\S]*?\}\s*from\s*'lucide-react';\s*$/m,
  ''
);
const quoted = withoutImport
  .replace(/iconName:\s*LucideIcon/g, 'iconName: string')
  .replace(/iconName:\s*([A-Za-z0-9_]+)\s*,/g, "iconName: '$1',");

const dir = mkdtempSync(join(tmpdir(), 'academy-'));
const file = join(dir, 'academyData.ts');
writeFileSync(file, quoted);

const mod = await import(file);
const courses = mod.academyCourses;

if (!Array.isArray(courses) || courses.length === 0) {
  console.error('no courses extracted');
  process.exit(1);
}

console.log(JSON.stringify(courses, null, 2));
