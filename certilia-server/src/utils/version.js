import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

// Single source of truth za reportanu verziju servera: package.json (kopira se
// u Docker image, pa je dostupan u runtimeu). Drži ga u syncu s git tagom —
// bump package.json + `git tag vX.Y.Z` idu zajedno (npm konvencija).
const __dirname = dirname(fileURLToPath(import.meta.url));
const pkg = JSON.parse(
  readFileSync(join(__dirname, '../../package.json'), 'utf8'),
);

export const VERSION = pkg.version;
