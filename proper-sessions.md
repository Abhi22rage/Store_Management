# Proper Stateful Session Management Implementation

## Goal
Implement a robust, auditable session management system for Smart Dukan that binds the selected branch to the user's profile and tracks active sessions in a custom database table.

## Tasks
- [x] **Task 1: Database Schema Update** → Apply SQL migrations to create `user_sessions` and update `profiles`.
    - Verify: `supabase-mcp-server list_tables` shows the new table and column.
- [x] **Task 2: Enhance `AuthService` (Persistence & Audit)** → Update `lib/core/services/auth_service.dart` to track sessions in `user_sessions` and implement auto-refresh.
    - Verify: Login creates a record in `user_sessions`; session persists across app restarts.
- [x] **Task 3: Implement Branch Binding** → Update `lib/core/services/branch_service.dart` to sync the selected branch with the `profiles` table.
    - Verify: Switching branch updates the DB; logging in on another device shows the same selected branch.
- [x] **Task 4: Secure Logout & Revocation** → Implement session deactivation in `AuthService.logout`.
    - Verify: Logout marks the `user_sessions` record as `is_active = false`.
- [ ] **Task 5: Final Verification & UX Audit** → Run `mobile_audit.py` and verify all flows.
    - Verify: Smooth transition between auth states; no flickering.

## Done When
- [ ] Custom `user_sessions` are tracked for every login.
- [ ] Selected branch is persisted in the database (synced across devices).
- [ ] Session refresh happens automatically without user intervention.
- [ ] RBAC is correctly enforced based on the fetched profile.

## Notes
- We will use Supabase's `auth.onAuthStateChange` as the primary trigger for session lifecycle.
- Branch selection will fall back to 'Main Store' if no DB value exists.
- `user_sessions` will include `ip_address` and `user_agent` for security auditing.
