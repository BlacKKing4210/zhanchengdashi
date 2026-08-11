# F-ZC-MOBILE-ORIENTATION-001 Producer Decision

## Decision

- Request: `REQ-20260811-ANDROID-PORTRAIT`.
- Decision state: `APPROVED` by the producer-user's direct instruction on 2026-08-11.
- Approved rule: the Android mobile package must launch in portrait orientation and remain locked to portrait; device rotation must not switch the game to landscape.
- Superseded rule: the existing Android export behavior in which the packaged activity declares `screenOrientation=0` (landscape).
- Formal runtime source: `project.godot`.
- Implementation value: `display/window/handheld/orientation=1`, Godot's fixed portrait mode rather than a sensor-controlled portrait mode.

## Scope and acceptance

- Allowed tracked writes: `project.godot`, `docs/active_scope.yaml`, and receipts under `docs/receipts/F-ZC-MOBILE-ORIENTATION-001-*`.
- Generated deliverable: ignored Android APK under `build/android/`.
- Baseline project hash: `DAE555661D9BA4CC0B97AB2CD05A0409D508CF8A7AC7B5A5FCDB0E3ACD981E48`.
- Baseline export preset hash: `8824A2691DFD169C610F29E31B6A6CFCB70EEABA354D8C25C361C98A1E2D4D2D`.
- Baseline APK evidence: `AndroidManifest.xml` declares `android:screenOrientation=0`.
- Acceptance 1: `project.godot` declares the fixed portrait handheld orientation.
- Acceptance 2: a newly exported Android APK declares `android:screenOrientation=1` for the Godot activity.
- Acceptance 3: the export configuration contains no sensor, user-controlled, unspecified, reverse-portrait, or landscape orientation override.
- Acceptance 4: configuration validation/export and Godot project smoke remain clean.

## Non-goals and boundaries

- No mobile UI layout redesign, camera redesign, gameplay-rule change, or new asset production.
- No change to Windows, Web, dedicated-server, or iOS orientation behavior.
- The Android package remains an internally signed test package unless a separate store-signing request is authorized.
- Runtime device installation and physical rotation testing are additional device-level evidence; the packaged manifest is the deterministic acceptance source for the orientation lock in this task.

## Structured decision receipt

- `feature_id`: `F-ZC-MOBILE-ORIENTATION-001`
- `decision_state`: `approved`
- `approved_rule`: fixed portrait Android orientation; no landscape rotation
- `superseded_rule`: packaged Android landscape orientation
- `formal_source_target`: `project.godot`
- `affected_domains`: engineering, Android packaging, QA
- `affected_files`: `project.godot`, Android APK, task receipts
- `execution_readiness`: ready after task registration, RAG refresh, and control-plane verification
- `unresolved_producer_decisions`: none
- `reusable_method_candidate`: none
