#!/usr/bin/env bash
# Deploy Firestore rules and indexes (Spark plan — no Firebase Storage / billing).
# Uses the project ID from .firebaserc (currently todoa-e26b3).
set -euo pipefail
cd "$(dirname "$0")/.."
npx --yes firebase-tools@latest deploy \
  --only firestore:rules,firestore:indexes
