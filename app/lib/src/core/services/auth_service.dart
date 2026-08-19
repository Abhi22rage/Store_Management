import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'branch_service.dart';

class User {
  final String id;
  final String email;
  final String role; // 'owner', 'manager', 'staff'
  final String? selectedBranch;

  User({
    required this.id,
    required this.email,
    required this.role,
    this.selectedBranch,
  });

  User copyWith({String? selectedBranch}) {
    return User(
      id: id,
      email: email,
      role: role,
      selectedBranch: selectedBranch ?? this.selectedBranch,
    );
  }
}

class AuthService extends ChangeNotifier {
  User? _currentUser;
  bool _isLoading = true;
  String? _currentSessionAuditId;

  User? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  bool get isLoading => _isLoading;

  AuthService() {
    _init();
  }

  void _init() {
    // Listen to auth state changes for robust session management
    supabase.Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
      final event = data.event;
      final session = data.session;

      if (event == supabase.AuthChangeEvent.signedIn && session != null) {
        await _refreshSession();
        await _createSessionAudit(session);
      } else if (event == supabase.AuthChangeEvent.signedOut) {
        await _deactivateSessionAudit();
        _currentUser = null;
        _isLoading = false;
        notifyListeners();
      } else if (event == supabase.AuthChangeEvent.tokenRefreshed) {
        await _refreshSession();
        await _updateSessionActivity();
      } else {
        await _refreshSession();
      }
    });
  }

  // ─── SESSION AUDIT LOGIC ───────────────────────────────────────

  Future<void> _createSessionAudit(supabase.Session session) async {
    try {
      final client = supabase.Supabase.instance.client;
      // We store the session audit in the public schema
      final response = await client.from('user_sessions').insert({
        'user_id': session.user.id,
        'user_agent': 'Flutter App', // In a real app, use device_info_plus
        'is_active': true,
      }).select('id').single();

      _currentSessionAuditId = response['id'];
    } catch (e) {
      debugPrint('Error creating session audit: $e');
    }
  }

  Future<void> _updateSessionActivity() async {
    if (_currentSessionAuditId == null) return;
    try {
      await supabase.Supabase.instance.client
          .from('user_sessions')
          .update({'last_active_at': DateTime.now().toIso8601String()})
          .eq('id', _currentSessionAuditId!);
    } catch (e) {
      debugPrint('Error updating session activity: $e');
    }
  }

  Future<void> _deactivateSessionAudit() async {
    if (_currentSessionAuditId == null) return;
    try {
      await supabase.Supabase.instance.client
          .from('user_sessions')
          .update({'is_active': false})
          .eq('id', _currentSessionAuditId!);
      _currentSessionAuditId = null;
    } catch (e) {
      debugPrint('Error deactivating session audit: $e');
    }
  }

  // ─── REFRESH SESSION & FETCH ROLE/BRANCH ────────────────────────
  Future<void> _refreshSession() async {
    final session = supabase.Supabase.instance.client.auth.currentSession;
    if (session != null) {
      try {
        final List<dynamic> rows = await supabase.Supabase.instance.client
            .from('profiles')
            .select('role, selected_branch')
            .eq('id', session.user.id);

        if (rows.isEmpty) {
          // Profile row not found — trigger may not be applied in Supabase.
          // See docs/migration.sql for the on_auth_user_created trigger.
          debugPrint('[AuthService] ⚠️ No profile row found for user ${session.user.id}. '
              'Ensure the on_auth_user_created trigger is applied in Supabase.');
          _currentUser = User(
            id: session.user.id,
            email: session.user.email ?? '',
            role: 'staff',
          );
        } else {
          final profile = rows.first;
          _currentUser = User(
            id: session.user.id,
            email: session.user.email ?? '',
            role: profile['role'] ?? 'staff',
            selectedBranch: profile['selected_branch'],
          );

          // Sync branch selection from database if available
          if (profile['selected_branch'] != null) {
            BranchService().setBranch(profile['selected_branch'], persistToDb: false);
          }
        }
      } catch (e) {
        debugPrint('[AuthService] ❌ Error fetching profile: $e');
        _currentUser = User(
          id: session.user.id,
          email: session.user.email ?? '',
          role: 'staff',
        );
      }
    } else {
      _currentUser = null;
    }
    _isLoading = false;
    notifyListeners();
  }

  // ─── AUTH ACTIONS ──────────────────────────────────────────────

  Future<String?> login(String credential, String password) async {
    try {
      final isEmail = credential.contains('@');
      await supabase.Supabase.instance.client.auth.signInWithPassword(
        email: isEmail ? credential : null,
        phone: !isEmail ? credential : null,
        password: password,
      );
      return null; // onAuthStateChange will handle the rest
    } on supabase.AuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> signup(String credential, String password, String role) async {
    try {
      final isEmail = credential.contains('@');
      final response = await supabase.Supabase.instance.client.auth.signUp(
        email: isEmail ? credential : null,
        phone: !isEmail ? credential : null,
        password: password,
        data: {'role': role},
      );
      
      if (response.user != null) {
        // Create profile record if it doesn't exist via trigger, or manually here if needed
        // Assuming a trigger handles profile creation on signup
        return null;
      }
      return 'Signup failed';
    } on supabase.AuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  Future<void> logout() async {
    await supabase.Supabase.instance.client.auth.signOut();
  }
}

class AuthProvider extends InheritedNotifier<AuthService> {
  const AuthProvider({
    super.key,
    required AuthService authService,
    required super.child,
  }) : super(notifier: authService);

  static AuthService of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AuthProvider>()!.notifier!;
  }
}
