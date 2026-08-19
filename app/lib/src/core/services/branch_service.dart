import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'api_service.dart';
import 'data_repository.dart';

class BranchService extends ChangeNotifier {
  static final BranchService _instance = BranchService._internal();
  factory BranchService() => _instance;
  BranchService._internal();

  String _currentBranch = 'Main Store';
  String get currentBranch => _currentBranch;

  List<Map<String, dynamic>> _branches = [];
  List<Map<String, dynamic>> get branches => _branches;

  Future<void> init(String? initialBranch) async {
    final prefs = await SharedPreferences.getInstance();
    // Priority: 1. Passed initial branch (from DB), 2. Local prefs, 3. Default
    _currentBranch = initialBranch ?? prefs.getString('selected_branch') ?? 'Main Store';
    DataRepository().init();
    refreshBranches(); // Run in the background to avoid blocking app startup
  }

  Future<void> refreshBranches() async {
    try {
      _branches = await ApiService().getBranches();
      
      // Safety check: if current branch is no longer in the list, fallback to first available
      if (_branches.isNotEmpty) {
        final currentInList = _branches.any((b) => b['name'] == _currentBranch);
        if (!currentInList) {
          _currentBranch = _branches[0]['name'];
          await _persistBranch(_currentBranch);
        }
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error refreshing branches: $e');
    }
  }

  Future<void> setBranch(String branch, {bool persistToDb = true}) async {
    if (_currentBranch == branch) return;
    _currentBranch = branch;
    await _persistBranch(branch, persistToDb: persistToDb);
    DataRepository().invalidateAll();
    notifyListeners();
  }

  Future<void> _persistBranch(String branch, {bool persistToDb = true}) async {
    // 1. Persist locally
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_branch', branch);

    // 2. Persist to Supabase if requested and logged in
    if (persistToDb) {
      final user = supabase.Supabase.instance.client.auth.currentUser;
      if (user != null) {
        try {
          await supabase.Supabase.instance.client
              .from('profiles')
              .update({'selected_branch': branch})
              .eq('id', user.id);
        } catch (e) {
          debugPrint('Error persisting branch to DB: $e');
        }
      }
    }
  }


}
