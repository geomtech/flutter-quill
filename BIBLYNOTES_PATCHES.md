# BiblyNotes patches on flutter_quill v11.6.0

Base: upstream tag `v11.6.0` (commit `e880534f`), branch `biblynotes`.
Remotes: `upstream` = singerdmx/flutter-quill, `origin` = geomtech/flutter-quill (fork).
Code follows upstream rules (CONTRIBUTING.md) so each fix can be proposed as a
separate upstream PR. This file is local only: do NOT include it in a PR.

| Id | File(s) | Problem | Fix |
|----|---------|---------|-----|
| caret-rect-dx | `lib/src/editor/editor.dart` (`getLocalRectForCaret`) | Caret rect was only shifted by the child's dy, so the iOS floating cursor / IME caret rect was off horizontally in indented/blocks (see upstream PR #2768). | Shift by the full `boxParentData.offset`. |
| floating-cursor | `lib/src/editor/editor.dart` (`setFloatingCursor`), `lib/src/editor/raw_editor/raw_editor_state_text_input_client_mixin.dart` (`updateFloatingCursor`, `onFloatingCursorResetTick`) | Spacebar trackpad on iPad: start used a stale position, updates called `onSelectionChanged` every frame, no auto-scroll, a press without move left the cursor stuck (upstream issue #1169), reset tick could crash on null state. | Use `startLocation`, null guards, no per-update selection commit, `bringIntoView`, explicit End when no update, commit the final collapsed selection once at the end of the reset animation (keeps two-finger selections). |
| perf-rules-delta | `lib/src/document/document.dart` (`deltaView`), `lib/src/rules/{insert,delete,format}.dart` | Each heuristic rule called `document.toDelta()`, which copies the full operation list: several O(document) copies per keystroke on long notes. | Rules read a non-copying `deltaView` (`_delta` is never mutated in place; `compose` replaces it). |
| link-recognizers | `lib/src/editor/widgets/text/text_line.dart` | `_linkRecognizers` was never pruned when leaves were removed or reformatted: leaks and possibly stale link recognizers on edited links. | Track the style each recognizer was built for and prune (dispose post-frame) entries whose node left the line or whose style changed. |

Tests: `test/editor/floating_cursor_test.dart`, `test/editor/editor_test.dart`
(removing a link drops its cached recognizer), `test/document/document_test.dart`
(`deltaView`). Verified they fail without the fixes.

## Upstream PR checklist (singerdmx/flutter-quill)

- One PR per fix, target `master`; fill `.github/PULL_REQUEST_TEMPLATE.md`.
- Do not bump the version in `pubspec.yaml`.
- Add entries under `## [Unreleased]` in `CHANGELOG.md` (Keep a Changelog; CI checks it is modified and runs `cider list`).
- `flutter analyze`, `dart format --set-exit-if-changed .` (CI pins Flutter 3.44.1: re-check formatting with that version), `dart fix --dry-run`, `flutter test`.
- Public API must have doc comments; internal helpers use `@internal`.
