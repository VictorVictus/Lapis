# Deploy Firestore rules and indexes (Spark plan — no Firebase Storage / billing).
# Uses the project ID from .firebaserc (currently todoa-e26b3).
$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..")
npx --yes firebase-tools@latest deploy `
  --only firestore:rules,firestore:indexes
