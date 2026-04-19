# UNITY_EXECUTION_CHECKLIST.md

## Goal
Guide the Unity WebGL gallery implementation so:
- Unity loads environments correctly
- Unity reads approved artwork data from the shared backend source
- Unity never requires a second artwork upload
- environment assignments and visibility rules are respected
- WebGL delivery stays scalable for many environments

## Core Rule
Unity must not become a second artwork system.

Unity must consume:
- artworks
- artwork_assets
- environment_assignments
- environment metadata

Unity must not:
- create a duplicate artwork identity
- require re-upload for gallery use
- bypass artwork approval or visibility rules

---

## Phase 1 — Unity project foundation

### Implement
- [ ] Unity project setup
- [ ] base scenes
- [ ] core runtime architecture
- [ ] configuration handling
- [ ] basic UI framework
- [ ] environment loading architecture
- [ ] backend integration service layer

### Validation
- [ ] project opens cleanly
- [ ] base scene runs
- [ ] environment/config values can be loaded
- [ ] service layer can prepare to read backend data

---

## Phase 2 — Environment library

### Implement
- [ ] environment metadata format
- [ ] environment registry
- [ ] thumbnail / preview support
- [ ] environment categories
- [ ] addressable key integration
- [ ] performance tier mapping

### Rules
- each environment must have:
  - id
  - code
  - name
  - category
  - thumbnail
  - version
  - addressable_key
  - performance_tier

### Validation
- [ ] environment metadata can be read
- [ ] environment list renders correctly
- [ ] categories and performance tiers are valid
- [ ] each environment maps to one addressable package

---

## Phase 3 — Room loading

### Implement
- [ ] load selected environment
- [ ] unload previous environment safely
- [ ] room transition flow
- [ ] loading UI
- [ ] error fallback state

### Rules
- load only selected environment on demand
- do not bundle all environments into one giant runtime path if avoidable
- environment loading must remain compatible with remote content model

### Validation
- [ ] one environment loads at a time
- [ ] room transition works
- [ ] loading state displays
- [ ] fallback state works for failed load

---

## Phase 4 — Wall anchors / placement system

### Implement
- [ ] wall anchor metadata format
- [ ] wall anchor registry in environment
- [ ] position / rotation / scale mapping
- [ ] assignment resolution logic

### Rules
- wall anchor placement must consume backend assignment data
- manual placement in Unity must not create a second persistent artwork path outside shared assignments unless explicitly requested later

### Validation
- [ ] wall anchors resolve correctly
- [ ] placement values map correctly
- [ ] artwork assignment can target intended anchor

---

## Phase 5 — Artwork loading from backend

### Implement
- [ ] backend artwork fetch for approved environment assignments
- [ ] artwork asset fetch
- [ ] texture/image load flow
- [ ] approved visibility filtering
- [ ] fallback handling for missing assets

### Rules
- Unity must use approved shared artwork record
- Unity must respect visibility_mode
- Unity must not require second upload
- Unity must not display artwork that is not approved for gallery use

### Validation
- [ ] assigned artwork loads into selected environment
- [ ] artwork references same id as marketplace/authentication
- [ ] marketplace_only artwork is not incorrectly shown in VR if rules say no
- [ ] both visibility mode works
- [ ] missing asset fallback behaves correctly

---

## Phase 6 — Gallery navigation and viewing

### Implement
- [ ] movement/navigation controls
- [ ] environment selection UI
- [ ] artwork detail viewer
- [ ] basic interaction UI
- [ ] camera behavior

### Validation
- [ ] user can navigate room
- [ ] user can switch/select environments
- [ ] artwork detail can be viewed
- [ ] camera and interaction behavior are stable

---

## Phase 7 — Lighting and display controls

### Implement
- [ ] ambient lighting presets
- [ ] spotlight system
- [ ] display tuning for artwork viewing
- [ ] floor/wall material hooks if part of current scope

### Rules
- display logic must not interfere with core artwork assignment logic
- visual configuration should be environment-level, not a duplicate artwork data system

### Validation
- [ ] lighting presets work
- [ ] spotlight adjustments work
- [ ] artwork remains readable and correctly placed

---

## Phase 8 — WebGL readiness

### Implement
- [ ] WebGL-compatible asset loading checks
- [ ] performance-sensitive configuration
- [ ] environment thumbnail/preview handling
- [ ] browser-ready fallback behavior

### Rules
- optimize for browser-based WebGL first
- keep advanced headset-only VR features deferred unless explicitly requested

### Validation
- [ ] WebGL build runs
- [ ] environment loading works in browser
- [ ] assigned artworks appear correctly in WebGL
- [ ] performance tier logic behaves as expected

---

## Phase 9 — Unity-wide validation

### Shared artwork validation
- [ ] Unity reads approved artwork data from backend
- [ ] Unity does not require duplicate upload
- [ ] Unity uses same artwork ids as marketplace and authentication
- [ ] environment assignments reference shared artwork ids correctly

### Environment validation
- [ ] environment metadata is stable
- [ ] one environment loads at a time
- [ ] assignments resolve correctly
- [ ] thumbnail/preview logic works

### Safety validation
- [ ] Unity does not bypass approval rules
- [ ] Unity does not expose unapproved artworks
- [ ] Unity does not create a second persistent artwork source

---

## Required Output After Each Major Unity Step
After each phase, report:
1. what was implemented
2. which scenes/scripts/assets changed
3. what backend data Unity reads
4. what validation/tests were run
5. what risks or open items remain

Do not claim completion without validation.

---

## Stop Conditions
Stop and warn before continuing if:
- Unity requires a second upload path
- Unity introduces a second artwork data source
- assignment logic does not reference shared artwork ids
- environment load logic conflicts with scalable remote content approach
- unapproved artwork could be displayed

---

## Definition of Unity Done
Unity WebGL gallery is not done unless:
- environments load correctly
- approved artworks auto-load from shared backend data
- no duplicate artwork path exists
- WebGL build is validated
- risks were reported clearly
