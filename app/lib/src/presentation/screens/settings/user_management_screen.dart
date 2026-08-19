import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:smart_store/src/presentation/themes/app_theme.dart';
import 'package:smart_store/src/core/services/auth_service.dart';

class UserManagementScreen extends StatefulWidget {
  final AuthService authService;

  const UserManagementScreen({super.key, required this.authService});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    try {
      final data = await Supabase.instance.client
          .from('profiles')
          .select('id, role, selected_branch, created_at, users (email, name)')
          .order('created_at', ascending: true);
      
      setState(() {
        _users = List<Map<String, dynamic>>.from(data.map((item) {
          final usersData = item['users'] as Map<String, dynamic>?;
          return {
            'id': item['id'],
            'role': item['role'],
            'selected_branch': item['selected_branch'],
            'created_at': item['created_at'],
            'email': usersData?['email'] ?? 'No Email',
            'name': usersData?['name'] ?? 'New User',
          };
        }));
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading users: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateRole(String userId, String newRole) async {
    try {
      await Supabase.instance.client
          .from('profiles')
          .update({'role': newRole})
          .eq('id', userId);
      
      _loadUsers();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Role updated successfully')),
      );
    } catch (e) {
      debugPrint('Error updating role: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update role')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text('USER MANAGEMENT', style: GoogleFonts.inter(letterSpacing: 2, fontSize: 14, fontWeight: FontWeight.w900)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadUsers,
              child: ListView.separated(
                padding: const EdgeInsets.all(24),
                itemCount: _users.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final user = _users[index];
                  final isMe = user['id'] == widget.authService.currentUser?.id;
                  final currentRole = user['role'] as String;

                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                          child: Text(
                            (user['email'] as String? ?? '?')[0].toUpperCase(),
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user['email'] ?? 'No Email',
                                style: GoogleFonts.manrope(fontWeight: FontWeight.w900),
                              ),
                              Text(
                                isMe ? 'You ( $currentRole )' : currentRole.toUpperCase(),
                                style: GoogleFonts.inter(fontSize: 12, color: AppTheme.outline),
                              ),
                            ],
                          ),
                        ),
                        if (!isMe)
                          DropdownButton<String>(
                            value: currentRole,
                            items: ['owner', 'manager', 'staff'].map((role) {
                              return DropdownMenuItem(
                                value: role,
                                child: Text(role.toUpperCase(), style: const TextStyle(fontSize: 12)),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) _updateRole(user['id'], val);
                            },
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
    );
  }
}
