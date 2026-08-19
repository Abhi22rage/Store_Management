import 'package:go_router/go_router.dart';
import 'package:smart_store/src/core/services/auth_service.dart';
import 'package:smart_store/src/presentation/screens/auth/login_screen.dart';
import 'package:smart_store/src/presentation/screens/auth/signup_screen.dart';
import 'package:smart_store/src/presentation/screens/dashboard/dashboard_screen.dart';
import 'package:smart_store/src/presentation/screens/inventory/inventory_screen.dart';
import 'package:smart_store/src/presentation/screens/sales/sales_screen.dart';
import 'package:smart_store/src/presentation/screens/sales/manual_sale_screen.dart';
import 'package:smart_store/src/presentation/screens/purchase/purchase_screen.dart';
import 'package:smart_store/src/presentation/screens/purchase/add_purchase_screen.dart';
import 'package:smart_store/src/presentation/screens/supplier/supplier_screen.dart';
import 'package:smart_store/src/presentation/screens/settings/settings_screen.dart';
import 'package:smart_store/src/presentation/screens/settings/user_management_screen.dart';
import 'package:smart_store/src/presentation/screens/settings/branch_management_screen.dart';
import 'package:smart_store/src/presentation/screens/inventory/category_management_screen.dart';
import 'package:smart_store/src/presentation/screens/layout/main_layout.dart';

class AppRouter {
  static GoRouter createRouter(AuthService authService) {
    return GoRouter(
      initialLocation: '/dashboard',
      refreshListenable: authService,
      redirect: (context, state) {
        if (authService.isLoading) return null;
        
        final isAuth = authService.isAuthenticated;
        final isLoginOrSignup = state.uri.toString() == '/login' || state.uri.toString() == '/signup';

        if (!isAuth && !isLoginOrSignup) {
          return '/login';
        }
        
        if (isAuth && isLoginOrSignup) {
          return '/dashboard';
        }
        
        // RBAC constraints:
        // Restricted routes for staff (User management stays admin-only, Settings screen remains accessible)
        if (isAuth) {
          final role = authService.currentUser?.role ?? 'staff';
          if (role == 'staff') {
            final restrictedForStaff = ['/settings/users'];
            if (restrictedForStaff.any((route) => state.uri.toString().startsWith(route))) {
              return '/settings'; // Redirect unauthorized user management attempts back to settings root
            }
          }
        }
        
        return null;
      },
      routes: [
        GoRoute(
          path: '/login',
          builder: (context, state) => LoginScreen(authService: authService),
        ),
        GoRoute(
          path: '/signup',
          builder: (context, state) => SignupScreen(authService: authService),
        ),
        ShellRoute(
          builder: (context, state, child) {
            return MainLayout(child: child);
          },
          routes: [
            GoRoute(
              path: '/dashboard',
              builder: (context, state) => const DashboardScreen(),
            ),
            GoRoute(
              path: '/inventory',
              builder: (context, state) {
                final lowStock = state.uri.queryParameters['low_stock'] == 'true';
                return InventoryScreen(showLowStockOnly: lowStock);
              },
            ),
            GoRoute(
              path: '/inventory/categories',
              builder: (context, state) => const CategoryManagementScreen(),
            ),
            GoRoute(
              path: '/sales',
              builder: (context, state) => const SalesScreen(),
            ),
            GoRoute(
              path: '/sales/new',
              builder: (context, state) => const ManualSaleScreen(),
            ),
            GoRoute(
              path: '/purchase',
              builder: (context, state) => const PurchaseScreen(),
              routes: [
                GoRoute(
                  path: 'new',
                  builder: (context, state) => const AddPurchaseScreen(),
                ),
              ],
            ),
            GoRoute(
              path: '/suppliers',
              builder: (context, state) => const SupplierScreen(),
            ),
            GoRoute(
              path: '/settings',
              builder: (context, state) => const SettingsScreen(),
            ),
            GoRoute(
              path: '/settings/users',
              builder: (context, state) => UserManagementScreen(authService: authService),
            ),
            GoRoute(
              path: '/settings/branches',
              builder: (context, state) => const BranchManagementScreen(),
            ),
          ],
        ),
      ],
    );
  }
}

