import { existsSync, readdirSync } from 'node:fs'
import { delimiter, join, resolve } from 'node:path'
import { spawnSync } from 'node:child_process'
import { fileURLToPath } from 'node:url'

const docsDir = fileURLToPath(new URL('../', import.meta.url))
const javaExecutable = process.platform === 'win32' ? 'java.exe' : 'java'
const pathDirectories = (process.env.PATH ?? '').split(delimiter).filter(Boolean)
const javaDirectories = [
  process.env.JAVA_HOME && join(process.env.JAVA_HOME, 'bin'),
  ...pathDirectories,
]

if (process.platform === 'win32' && process.env.ProgramFiles) {
  const adoptiumDir = join(process.env.ProgramFiles, 'Eclipse Adoptium')
  if (existsSync(adoptiumDir)) {
    javaDirectories.push(
      ...readdirSync(adoptiumDir, { withFileTypes: true })
        .filter((entry) => entry.isDirectory())
        .map((entry) => join(adoptiumDir, entry.name, 'bin'))
    )
  }
}

const javaDirectory = javaDirectories.find(
  (directory) => directory && existsSync(join(directory, javaExecutable))
)

if (!javaDirectory) {
  throw new Error('Java no esta disponible. Instala Java 21 o configura JAVA_HOME.')
}

const cliPath = resolve(docsDir, 'node_modules/plantuml-cli/index.js')
const result = spawnSync(
  process.execPath,
  [
    cliPath,
    '-tsvg',
    '-o',
    '../images',
    'modules/ROOT/partials/mobile-c4-context.puml',
    'modules/ROOT/partials/mobile-c4-containers.puml',
  ],
  {
    cwd: docsDir,
    env: {
      ...process.env,
      PATH: [javaDirectory, process.env.PATH].filter(Boolean).join(delimiter),
    },
    stdio: 'inherit',
  }
)

if (result.error) throw result.error
process.exitCode = result.status ?? 1
