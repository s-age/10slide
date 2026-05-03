#!/usr/bin/env node
// Validates that all type:child path references resolve to existing files.
// Paths are resolved relative to the containing pipeline file's directory,
// which is how PipelineService loads them at runtime.
// Usage: node validate-child-paths.cjs <pipeline-file>
'use strict'

const fs = require('fs')
const path = require('path')

const file = process.argv[2]
if (!file) {
  console.error('Usage: validate-child-paths.cjs <pipeline-file>')
  process.exit(1)
}

// Resolve yaml from this script's own node_modules
const resolve = (pkg) => require.resolve(pkg, { paths: [__dirname] })

const ext = path.extname(file)
const raw = fs.readFileSync(file, 'utf-8')

let data
if (ext === '.yaml' || ext === '.yml') {
  const { parse } = require(resolve('yaml'))
  data = parse(raw)
} else {
  data = JSON.parse(raw)
}

const dir = path.dirname(path.resolve(file))
const errors = []

function checkTasks(tasks) {
  if (!Array.isArray(tasks)) return
  for (const task of tasks) {
    if (task.type === 'child') {
      const resolved = path.resolve(dir, task.path)
      if (!fs.existsSync(resolved)) {
        errors.push(`child path "${task.path}" → ${resolved} (does not exist)`)
      }
    }
    if (task.tasks) checkTasks(task.tasks)
  }
}

checkTasks(data.tasks)

if (errors.length > 0) {
  console.error(`ERROR: ${file} has unresolvable child paths:`)
  for (const e of errors) console.error(`  ${e}`)
  process.exit(1)
} else {
  console.log(`OK: ${file} — all child paths resolve`)
}
