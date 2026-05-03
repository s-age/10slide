#!/usr/bin/env node
// Validates a pipeline JSON or YAML file against schemas/pipeline.schema.json.
// YAML is converted to a plain object before validation.
// Usage: node validate-schema.cjs <pipeline-file>
'use strict'

const fs = require('fs')
const path = require('path')

const file = process.argv[2]
if (!file) {
  console.error('Usage: validate-schema.cjs <pipeline-file>')
  process.exit(1)
}

// Resolve yaml and ajv from this script's own node_modules
const resolve = (pkg) => require.resolve(pkg, { paths: [__dirname] })

// Read and parse the pipeline file
const ext = path.extname(file)
const raw = fs.readFileSync(file, 'utf-8')

let data
if (ext === '.yaml' || ext === '.yml') {
  const { parse } = require(resolve('yaml'))
  data = parse(raw)
} else {
  data = JSON.parse(raw)
}

// Load schema relative to cwd (project root)
const schemaPath = path.resolve(process.cwd(), 'schemas/pipeline.schema.json')
const schema = JSON.parse(fs.readFileSync(schemaPath, 'utf-8'))

// Validate with ajv (draft-07)
const Ajv = require(resolve('ajv'))
const ajv = new Ajv({ allErrors: true })
const validate = ajv.compile(schema)

if (validate(data)) {
  console.log(`OK: ${file} is valid`)
} else {
  console.error(`ERROR: ${file} failed schema validation:`)
  for (const err of validate.errors) {
    const loc = err.instancePath || '(root)'
    console.error(`  ${loc}: ${err.message}`)
  }
  process.exit(1)
}
