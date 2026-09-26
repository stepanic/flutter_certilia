import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

// Verzija servera dolazi iz package.json, koji se kopira u Docker image i
// dostupan je u runtimeu. Za novi release podigni verziju u package.json i
// napravi `git tag vX.Y.Z` s istim brojem.
const __dirname = dirname(fileURLToPath(import.meta.url));
const pkg = JSON.parse(
  readFileSync(join(__dirname, '../../package.json'), 'utf8'),
);

export const VERSION = pkg.version;
