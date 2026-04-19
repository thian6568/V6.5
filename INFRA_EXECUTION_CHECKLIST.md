# INFRA_EXECUTION_CHECKLIST.md

## Goal
Guide infrastructure and deployment work so:
- the project has staging and production
- storage, CDN, logs, backups, and monitoring exist
- the deployment stays portable
- secrets stay protected
- the infrastructure supports the web app, backend, and WebGL gallery correctly

## Core Rule
Deployment should default to AWS Singapore, but architecture must remain portable enough to support a later hosting change if approved.

Do not hard-code unnecessary provider-specific assumptions into the application logic.

---

## Phase 1 — Deployment planning

### Implement
- [ ] define staging environment
- [ ] define production environment
- [ ] define web hosting path
- [ ] define backend hosting path
- [ ] define storage path
- [ ] define CDN path
- [ ] define backup path
- [ ] define monitoring/logging path

### Validation
- [ ] staging and production are separated
- [ ] secrets are not stored in repo
- [ ] deployment remains portable at architecture level

---

## Phase 2 — Environment configuration

### Implement
- [ ] environment variable structure
- [ ] staging environment config
- [ ] production environment config
- [ ] example environment file structure

### Rules
- do not expose production secrets in repo or prompts
- keep config separated by environment
- keep sensitive values externalized

### Validation
- [ ] config structure is documented
- [ ] staging and production values are separated
- [ ] example env template exists

---

## Phase 3 — Storage / CDN

### Implement
- [ ] object storage structure
- [ ] artwork media path
- [ ] certificate file path
- [ ] WebGL asset path
- [ ] environment bundle path
- [ ] CDN routing strategy

### Validation
- [ ] media paths are organized
- [ ] WebGL assets can be delivered efficiently
- [ ] environment bundles can be served correctly
- [ ] certificate/media separation is clear

---

## Phase 4 — Logs / Monitoring / Backups

### Implement
- [ ] application logging plan
- [ ] backend logging plan
- [ ] monitoring plan
- [ ] backup schedule
- [ ] restore notes

### Validation
- [ ] logging path exists
- [ ] monitoring targets are defined
- [ ] backup plan exists
- [ ] restore path is documented

---

## Phase 5 — Deployment scripts / run order

### Implement
- [ ] deployment steps for backend
- [ ] deployment steps for web
- [ ] deployment steps for WebGL assets
- [ ] staging promotion flow
- [ ] production release flow

### Validation
- [ ] deployment order is documented
- [ ] staging-first rule is preserved
- [ ] release flow does not bypass review

---

## Required Output After Each Major Infra Step
After each phase, report:
1. what was defined or implemented
2. which files/scripts/configs changed
3. what risks remain
4. what assumptions are provider-specific
5. what remains portable

---

## Stop Conditions
Stop and warn before continuing if:
- secrets are about to be committed
- staging and production are mixed
- provider-specific setup is being hard-coded into application logic
- WebGL asset delivery path conflicts with environment loading strategy

---

## Definition of Infra Done
Infrastructure is not done unless:
- staging exists
- production exists
- storage/CDN path is defined
- logs, backups, and monitoring are defined
- deployment order is documented
- portability is preserved where possible
