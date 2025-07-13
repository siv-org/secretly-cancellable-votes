// To run: `npm run watch-circuits`
//
// This script watches our .circom files, and checks when their contents change.
// By importing the resulting circuit-hashes.json file into our tests, watch mode will trigger auto re-runs from updated circuits.
// (Unfortunately, we can't just watch the .circom files directly, because the test files actually touch them too (during compile), which triggers an infinite loop. See https://github.com/erhant/circomkit/issues/120)

import { createHash } from 'node:crypto'
import { readFileSync, writeFileSync, readdirSync, statSync } from 'node:fs'
import prevHashes from './circuit-hashes.json'
type HashMap = Record<string, string[]>
const prev = prevHashes as HashMap

// ANSI color codes
const RESET = '\x1b[0m'
const YELLOW = '\x1b[33m'
const GRAY = '\x1b[90m'

// Hash a single file into a short digest
function hashFile(path: string): string {
  const data = readFileSync(path)
  const hash = createHash('sha256')
  hash.update(data)
  return hash.digest('hex').slice(0, 10)
}

// Build map of hashes
let whichChanged = []
const hashes: HashMap = {}
const files = readdirSync('./circuits').filter((f) => f.endsWith('.circom'))
for (const file of files) {
  const hash = hashFile('./circuits/' + file)
  const didChange = hash !== prev[file]?.[0]
  if (didChange) whichChanged.push(file)
  hashes[file] = [hash, !didChange ? prev[file]?.[1] : new Date().toISOString()]
}

// Only write to the file if the hashes have changed
if (whichChanged.length > 0) {
  console.log(
    `${
      GRAY +
      new Date().toLocaleTimeString().replace(' AM', 'a').replace(' PM', 'p') +
      YELLOW
    } ${whichChanged.join(', ') + RESET}`
  )
  writeFileSync('./ts/circuit-hashes.json', JSON.stringify(hashes, null, 2))
}

export function shouldRecompile(file: string): boolean {
  const dotCircomMtime = new Date(prev[file]?.[1])
  const pathToR1cs = `./build/${file.replace('.circom', '.r1cs')}`
  const compiledR1cs = statSync(pathToR1cs, { throwIfNoEntry: false })
  const changedSinceCompile =
    dotCircomMtime > (compiledR1cs?.mtime || new Date(0))
  if (changedSinceCompile && compiledR1cs)
    console.log('\nRecompiling', YELLOW, file, RESET)

  return changedSinceCompile
}
