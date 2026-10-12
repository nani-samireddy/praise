# Onboarding and role personalization QA — 12 October 2026

Scope: StarterScreen, role/default persistence, starter routing, and Settings role row.

Changes: onboarding scrolls within SafeArea and the keyboard-resized Scaffold; role tiles expose selected semantics and use Material keyboard focus/activation; Continue disables duplicate saves and reports save failures. First-launch back is blocked until onboarding is completed. Settings pushes the explicit role-change route; Cancel/back returns without writing, with Settings as the direct-link fallback. Saving a role returns to Settings. Role changes deliberately reset every feature switch to role defaults; this is explained before Continue. Database writes use one Drift transaction and retain existing stored enum keys.

Automated checks cover 320×568 and 568×320 at 200% text, constrained 320×240 height, scroll reachability, selected semantics, keyboard activation, first-launch redirect, completed-onboarding redirect, explicit role change, cancellation, feature reset, and forced-write rollback. Tests use a local in-memory database; no user database was changed.

Device-only checks remaining: TalkBack announcement and focus order, external keyboard traversal on Android, Telugu wrapping and visual contrast, actual keyboard/inset behavior, system back on cold/warm role-change links, and persistent settings after process restart. No physical-device QA was performed.

Verification passed: `flutter test --no-pub test/features/settings/onboarding_test.dart test/features/settings/settings_repository_test.dart` (9 tests); `flutter analyze --no-pub` (no issues); Dart format check on scoped source/test files; `git diff --check`. Navigation save coverage uses a recording store; separate real SQLite tests verify persistence/defaults and rollback.
