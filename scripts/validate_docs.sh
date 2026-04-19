#!/usr/bin/env bash
set -euo pipefail

projects=(backend-core web-marketplace unity-webgl-gallery infra-deployment)
required_files=(
  PROJECT_BRIEF.md
  REQUIREMENTS.md
  SYSTEM_RULES.md
  DATA_MODEL.md
  API_SPEC.md
  TASKS.md
  ACCEPTANCE_CHECKLIST.md
)

for p in "${projects[@]}"; do
  for f in "${required_files[@]}"; do
    path="$p/$f"
    if [[ ! -f "$path" ]]; then
      echo "Missing required file: $path" >&2
      exit 1
    fi
  done
done

[[ -f AGENTS.md ]] || { echo "Missing AGENTS.md" >&2; exit 1; }
[[ -f README.md ]] || { echo "Missing README.md" >&2; exit 1; }

# Root planning docs
[[ -f PROJECT_BRIEF.md ]] || { echo "Missing PROJECT_BRIEF.md" >&2; exit 1; }
[[ -f REQUIREMENTS.md ]] || { echo "Missing REQUIREMENTS.md" >&2; exit 1; }
[[ -f SYSTEM_RULES.md ]] || { echo "Missing SYSTEM_RULES.md" >&2; exit 1; }
[[ -f DATA_MODEL.md ]] || { echo "Missing DATA_MODEL.md" >&2; exit 1; }
[[ -f TASKS.md ]] || { echo "Missing TASKS.md" >&2; exit 1; }
[[ -f API_SPEC.md ]] || { echo "Missing API_SPEC.md" >&2; exit 1; }
[[ -f RLS_PLAN.md ]] || { echo "Missing RLS_PLAN.md" >&2; exit 1; }
[[ -f MIGRATION_CHECKLIST.md ]] || { echo "Missing MIGRATION_CHECKLIST.md" >&2; exit 1; }
[[ -f BACKEND_EXECUTION_CHECKLIST.md ]] || { echo "Missing BACKEND_EXECUTION_CHECKLIST.md" >&2; exit 1; }
[[ -f WEB_EXECUTION_CHECKLIST.md ]] || { echo "Missing WEB_EXECUTION_CHECKLIST.md" >&2; exit 1; }
[[ -f UNITY_EXECUTION_CHECKLIST.md ]] || { echo "Missing UNITY_EXECUTION_CHECKLIST.md" >&2; exit 1; }
[[ -f INFRA_EXECUTION_CHECKLIST.md ]] || { echo "Missing INFRA_EXECUTION_CHECKLIST.md" >&2; exit 1; }
[[ -f TEST_PLAN.md ]] || { echo "Missing TEST_PLAN.md" >&2; exit 1; }
rg -qi "Test Execution Order" TEST_PLAN.md || { echo "TEST_PLAN.md missing execution order" >&2; exit 1; }
rg -qi "Stop Conditions" TEST_PLAN.md || { echo "TEST_PLAN.md missing stop conditions" >&2; exit 1; }
rg -qi "Phase 1 — Deployment planning" INFRA_EXECUTION_CHECKLIST.md || { echo "INFRA_EXECUTION_CHECKLIST.md missing Phase 1" >&2; exit 1; }
rg -qi "Stop Conditions" INFRA_EXECUTION_CHECKLIST.md || { echo "INFRA_EXECUTION_CHECKLIST.md missing stop conditions" >&2; exit 1; }
rg -qi "Phase 1 — Unity project foundation" UNITY_EXECUTION_CHECKLIST.md || { echo "UNITY_EXECUTION_CHECKLIST.md missing Phase 1" >&2; exit 1; }
rg -qi "Stop Conditions" UNITY_EXECUTION_CHECKLIST.md || { echo "UNITY_EXECUTION_CHECKLIST.md missing stop conditions" >&2; exit 1; }
rg -qi "Phase 1 — Web foundation setup" WEB_EXECUTION_CHECKLIST.md || { echo "WEB_EXECUTION_CHECKLIST.md missing Phase 1" >&2; exit 1; }
rg -qi "Stop Conditions" WEB_EXECUTION_CHECKLIST.md || { echo "WEB_EXECUTION_CHECKLIST.md missing stop conditions" >&2; exit 1; }
rg -qi "Phase 1 — Backend foundation validation" BACKEND_EXECUTION_CHECKLIST.md || { echo "BACKEND_EXECUTION_CHECKLIST.md missing Phase 1" >&2; exit 1; }
rg -qi "Stop Conditions" BACKEND_EXECUTION_CHECKLIST.md || { echo "BACKEND_EXECUTION_CHECKLIST.md missing stop conditions" >&2; exit 1; }
rg -qi "Step 1 — Create enums first" MIGRATION_CHECKLIST.md || { echo "MIGRATION_CHECKLIST.md missing enum-first step" >&2; exit 1; }
rg -qi "single source of truth" MIGRATION_CHECKLIST.md || { echo "MIGRATION_CHECKLIST.md missing source-of-truth rule" >&2; exit 1; }
[[ -f ACCEPTANCE_CHECKLIST.md ]] || { echo "Missing ACCEPTANCE_CHECKLIST.md" >&2; exit 1; }
rg -qi "one uploaded artwork" REQUIREMENTS.md || { echo "REQUIREMENTS.md missing shared artwork requirement" >&2; exit 1; }
rg -qi "aws singapore" REQUIREMENTS.md || { echo "REQUIREMENTS.md missing deployment default" >&2; exit 1; }
rg -qi "single source of truth" DATA_MODEL.md || { echo "DATA_MODEL.md missing source-of-truth rule" >&2; exit 1; }
rg -qi "One artwork upload creates one main artwork record" SYSTEM_RULES.md || { echo "SYSTEM_RULES.md missing core rule" >&2; exit 1; }
rg -qi "1\. backend-core" TASKS.md || { echo "TASKS.md missing build order" >&2; exit 1; }
rg -qi "Phase 2 — Backend Core" TASKS.md || { echo "TASKS.md missing backend phase" >&2; exit 1; }
rg -qi "Core API Rule" API_SPEC.md || { echo "API_SPEC.md missing core API rule" >&2; exit 1; }
rg -qi "POST /artworks" API_SPEC.md || { echo "API_SPEC.md missing artwork creation endpoint" >&2; exit 1; }
rg -qi "Core Security Rule" RLS_PLAN.md || { echo "RLS_PLAN.md missing core security rule" >&2; exit 1; }
rg -qi "No policy may allow" RLS_PLAN.md || { echo "RLS_PLAN.md missing shared artwork protection language" >&2; exit 1; }
rg -qi "Done Only If" ACCEPTANCE_CHECKLIST.md || { echo "ACCEPTANCE_CHECKLIST.md missing done criteria" >&2; exit 1; }

# Monorepo scaffold checks
required_paths=(
  "apps/web-marketplace/app/(public)/page.tsx"
  "apps/web-marketplace/package.json"
  "apps/web-marketplace/tsconfig.json"
  "apps/unity-webgl-gallery/Assets/Scenes"
  "backend/supabase/config.toml"
  "packages/shared-types/package.json"
  "packages/shared-constants/package.json"
  "packages/shared-validation/package.json"
  "packages/shared-sdk/package.json"
  "docs/architecture"
  "tests/e2e"
  "infra/aws/staging"
  "infra/aws/production"
  "infra/env/example"
)
for path in "${required_paths[@]}"; do
  [[ -e "$path" ]] || { echo "Missing scaffold path: $path" >&2; exit 1; }
done

# Backend pre-migration planning checks
[[ -f backend-core/MIGRATION_PLAN.md ]] || { echo "Missing backend-core/MIGRATION_PLAN.md" >&2; exit 1; }
rg -qi "Required Creation Order" backend-core/MIGRATION_PLAN.md || { echo "MIGRATION_PLAN.md missing creation order section" >&2; exit 1; }
rg -qi "artworks is the single source of truth" backend-core/MIGRATION_PLAN.md || { echo "MIGRATION_PLAN.md missing shared artwork guardrail" >&2; exit 1; }

# Required AGENTS rules
required_rules=(
  "one artwork upload creates one main artwork record"
  "no duplicate upload path for marketplace and vr gallery"
  "user authentication and artwork authentication are separate systems"
  "escrow, subscriptions, shipping, and insurance are compulsory"
  "backend first"
  "web second"
  "unity third"
  "deployment last"
)
for rule in "${required_rules[@]}"; do
  rg -qi "$rule" AGENTS.md || { echo "AGENTS.md missing rule: $rule" >&2; exit 1; }
done

# MVP exclusions should be present
exclusions=(
  "wallet connector"
  "web3 marketplace logic"
  "blockchain smart contracts"
)
for item in "${exclusions[@]}"; do
  rg -qi "$item" AGENTS.md || { echo "AGENTS.md missing MVP exclusion: $item" >&2; exit 1; }
done

# Repo docs should not currently include excluded MVP features
if rg -n -i "wallet connector|web3 marketplace|blockchain smart contract" backend-core web-marketplace unity-webgl-gallery infra-deployment >/tmp/validator_forbidden.log; then
  echo "Found forbidden MVP terms in module docs:" >&2
  cat /tmp/validator_forbidden.log >&2
  exit 1
fi


# Required deployment skill docs
[[ -f .agents/skills/deploy-rule/SKILL.md ]] || { echo "Missing .agents/skills/deploy-rule/SKILL.md" >&2; exit 1; }
rg -qi "aws singapore" .agents/skills/deploy-rule/SKILL.md || { echo "deploy-rule missing AWS Singapore default" >&2; exit 1; }
rg -qi "staging" .agents/skills/deploy-rule/SKILL.md || { echo "deploy-rule missing staging environment" >&2; exit 1; }
rg -qi "production" .agents/skills/deploy-rule/SKILL.md || { echo "deploy-rule missing production environment" >&2; exit 1; }
rg -qi "portable" .agents/skills/deploy-rule/SKILL.md || { echo "deploy-rule missing portability rule" >&2; exit 1; }

echo "Validation passed: required project docs, AGENTS rules, and MVP boundaries are consistent."
