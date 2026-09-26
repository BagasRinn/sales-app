# SDD ledger — plan: docs/superpowers/plans/2026-09-26-self-service-password-change.md

## Pre-flight scan

**Shared interfaces review**:
- Task 2 consumes Task 1 (User model with `token_version`). Match: Task 1 produces `token_version = Column(Integer, default=0, nullable=False)`, Task 2 reads it via `user.token_version`. Clean.
- Task 3 consumes Task 2 (`get_current_user` returns dict with `user_id`). Match: Task 2 returns `{"user_id": user_id, "username": ..., "role": ...}`, Task 3 uses `current_user["user_id"]`. Clean.
- Task 4 consumes Task 1 (User.token_version). Match: same field, same name. Clean.
- Task 5 consumes Task 3 (endpoint URL `/auth/change-password`). Match: explicit.
- Task 6 consumes Task 3 (same endpoint). Match: same path.

Pre-flight: no conflicts detected.

---

## Task 7: Final cleanup + cross-app manual regression

- [~] Step 1: Mobile happy-path runtime test DEFERRED — user must run app interactively
- [~] Step 2: Admin web happy-path runtime test DEFERRED — user must run browser interactively
- [~] Step 3: Cross-tab/cross-app invalidation runtime test DEFERRED — same reason
- [x] Step 4: Backend perf measurement — 50x /orders curls, avg 2.188s (network-bound to Supabase ap-south-1, NOT a regression from extra DB query). Acceptable for project scale.
- [x] Step 5: Follow-ups identified:
  - Pydantic 422 response for short new_password is functional but unfriendly; could be wrapped with friendly message via exception handler. (Defer)
  - Mobile app has background timeout (60s) — verify it doesn't conflict with the new invalidate-all flow. (Defer validation)
  - If cross-tab 401 redirect doesn't fire reliably, inspect admin_web api_service.dart onTokenExpired wiring. (Defer validation)
- [~] Step 6: User commits manually per memory rule

---

## Summary

**Completed backend tasks** (all verified via curl):
- Task 1: Migration ran + User model column added
- Task 2: tv embedded in tokens, get_current_user checks DB; verified 200 with valid token, 401 with stale token_version
- Task 3: change-password endpoint works for all paths (wrong old pw → 400, success → 200, restored login → ok)
- Task 4: Manager reset invalidates target session (verified via 401/403 discriminator)

**Completed frontend tasks** (static analysis clean):
- Task 5: Mobile repo + dialog + MiscScreen menu tile
- Task 6: Admin web repo + dialog + sidebar lock_outline icon

**Deferred** (require interactive app run):
- Manual UI flows in mobile + admin_web (login → open dialog → change → confirm LoginScreen redirect)
- Cross-tab/cross-app 401 propagation sanity check

---

## Rulings I made

1. **Task 3 ruling** — Pydantic 422 response for new_password < 6 chars. Plan explicitly accepted Pydantic default ("accept Pydantic's default"), no code change needed.
2. **Task 5 ruling** — AuthRepository isn't directly provided in mobile via Provider tree (only AuthProvider is). Used AuthProvider.changeOwnPassword() delegate instead. Cost if wrong: one extra layer of indirection, but matches plan's "alternative path".
3. **Task 6 ruling** — Same situation in admin_web: AdminRepository isn't directly provided. Dialog uses context.read<AdminProvider>().adminRepository.changePassword(). Cost if wrong: extra Provider hop, but functionally identical.
4. **Task 7 ruling** — Migration script `migrate_2026_09_26_token_version.py` is gitignored by repo convention (`.gitignore` line 97: `migrate_*.py`). The script exists on disk and worked; user must run it manually on any new environment. Pre-existing repo behavior, not changing. Cost if wrong: fresh checkout in new env won't get the migration — but same is true for all other migrations, so consistent.
5. **Task 2 ruling** — Used direct `from app.models.database import get_db` instead of plan's lazy `__import__`. Both work; direct import is cleaner. Verified no circular dependency by reading the relevant modules.

## Bug fix (post-Task-7)

**Symptom**: User clicks lock icon in admin_web sidebar, dialog appears with "Error: Could not find the correct Provider<AdminProvider> above this ChangePasswordDialog Widget".

**Root cause**: Same bug class as `_UserEditDialog` we hit earlier in session. `showDialog` creates a new route in Navigator's Overlay. In admin_web, `ChangeNotifierProvider<AdminProvider>` is rendered inside `DashboardScreen` (which IS the home route pushed onto MaterialApp's Navigator). So:
- Home route (DashboardScreen) → descendant of ChangeNotifierProvider ✓
- Dialog route → sibling of home route, NOT descendant of ChangeNotifierProvider ✗

Walking up from dialog's `BuildContext` doesn't find AdminProvider.

**Fix**: Applied the SAME pattern we used for `_UserEditDialog` — pass `AdminRepository` via constructor. `show(context, repo)` captures the repo from the calling widget's context (which IS inside the Provider tree), passes it to dialog, dialog uses `widget.adminRepository`.

**Files modified**:
- admin_web/lib/presentation/screens/change_password_dialog.dart: added `required this.adminRepository` to constructor; `show()` takes AdminRepository parameter; `_save()` uses `widget.adminRepository` instead of `context.read<AdminProvider>()`
- admin_web/lib/presentation/screens/dashboard_screen.dart: `ChangePasswordDialog.show(context, context.read<AdminProvider>().adminRepository)`
- mobile/lib/presentation/screens/auth/change_password_dialog.dart: preemptively applied same pattern with `authProvider` parameter (mobile's `MultiProvider` is ABOVE `MaterialApp` so it might work either way, but constructor pattern is robust against future refactors)
- mobile/lib/presentation/screens/misc/misc_screen.dart: `ChangePasswordDialog.show(context, context.read<AuthProvider>())`

**Verification**: `flutter analyze` clean on all 4 files.

## Deferred follow-ups (Minor)

- Pydantic 422 body format is unfriendly — wrapper exception handler would be nicer UX
- Mobile background timeout (60s) interaction with new invalidate-all flow needs live testing
- Cross-tab 401 redirect: relies on api_service.dart onTokenExpired wiring; should be confirmed live

## File manifest (changes committed by user)

Backend modified:
- sales-app/backend/app/api/endpoints/auth.py
- sales-app/backend/app/api/endpoints/users.py
- sales-app/backend/app/core/security.py
- sales-app/backend/app/models/models.py
- sales-app/backend/app/schemas/schemas.py

Backend new (gitignored by repo convention, on disk only):
- sales-app/backend/migrate_2026_09_26_token_version.py

Mobile modified:
- sales-app/lib/data/repositories/auth_repository.dart
- sales-app/lib/presentation/providers/auth_provider.dart
- sales-app/lib/presentation/screens/misc/misc_screen.dart

Mobile new:
- sales-app/lib/presentation/screens/auth/change_password_dialog.dart

Admin web modified:
- sales-app/admin_web/lib/data/repositories/admin_repository.dart
- sales-app/admin_web/lib/presentation/screens/dashboard_screen.dart

Admin web new:
- sales-app/admin_web/lib/presentation/screens/change_password_dialog.dart




