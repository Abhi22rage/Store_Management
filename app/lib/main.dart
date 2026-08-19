import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smart_store/src/core/env/env.dart';
import 'package:smart_store/src/presentation/themes/app_theme.dart';
import 'package:smart_store/src/core/services/auth_service.dart';
import 'package:smart_store/src/presentation/navigation/routes/app_router.dart';
import 'package:smart_store/src/presentation/screens/dashboard/bloc/dashboard_bloc.dart';
import 'package:smart_store/src/presentation/screens/dashboard/bloc/dashboard_event.dart';
import 'package:smart_store/src/presentation/screens/purchase/bloc/purchase_bloc.dart';
import 'package:smart_store/src/presentation/screens/purchase/bloc/purchase_event.dart';

import 'package:smart_store/src/core/services/branch_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(url: Env.supabaseUrl, publishableKey: Env.supabaseAnonKey);

  final branchService = BranchService();
  await branchService.init(null);

  final authService = AuthService();
  final router = AppRouter.createRouter(authService);

  runApp(SmartStoreApp(authService: authService, router: router));
}

class SmartStoreApp extends StatelessWidget {
  final AuthService authService;
  final GoRouter router;

  const SmartStoreApp({
    super.key,
    required this.authService,
    required this.router,
  });

  @override
  Widget build(BuildContext context) {
    return AuthProvider(
      authService: authService,
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (context) =>
                DashboardBloc()..add(const FetchDashboardData()),
          ),
          BlocProvider(
            create: (context) => PurchaseBloc()
              ..add(FetchPurchases(branch: BranchService().currentBranch))
              ..add(const FetchSuppliers()),
          ),
        ],
        child: MaterialApp.router(
          title: 'Smart Store',
          theme: AppTheme.lightTheme,
          routerConfig: router,
          debugShowCheckedModeBanner: false,
          scrollBehavior: const MaterialScrollBehavior().copyWith(
            physics: const BouncingScrollPhysics(),
          ),
        ),
      ),
    );
  }
}
