import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:smart_store/src/presentation/themes/app_theme.dart';

class MainLayout extends StatelessWidget {
  final Widget child;

  const MainLayout({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    // Media Query breakpoints
    // < 600px: Mobile (BottomNav)
    // >= 600px: Tablet & Desktop (NavigationRail / Sidebar)
    final width = MediaQuery.of(context).size.width;
    final isDesktopOrTablet = width >= 600;
    final isCompact = width >= 600 && width < 1024;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Row(
        children: [
          if (isDesktopOrTablet) _buildSidebar(context, isCompact),
          Expanded(child: child),
        ],
      ),
      bottomNavigationBar: isDesktopOrTablet ? null : _buildBottomNavBar(context),
    );
  }

  Widget _buildSidebar(BuildContext context, bool isCompact) {
    final GoRouterState state = GoRouterState.of(context);
    final String location = state.uri.toString();

    return Container(
      width: isCompact ? 88 : 260,
      decoration: const BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        border: Border(
          right: BorderSide(color: AppTheme.outlineVariant, width: 1.0),
        ),
      ),
      child: Column(
        crossAxisAlignment: isCompact ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 48),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: isCompact ? 0.0 : 28.0),
            child: Row(
              mainAxisAlignment: isCompact ? MainAxisAlignment.center : MainAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.secondary,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.secondary.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.storefront, color: AppTheme.onSecondary, size: 24),
                ),
                if (!isCompact) ...[
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Smart',
                        style: GoogleFonts.outfit(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        'STORE',
                        style: GoogleFonts.outfit(
                          color: AppTheme.secondary,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          letterSpacing: 3.0,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 48),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  _sidebarItem(context, 'Dashboard', 'https://img.icons8.com/3d-fluency/94/control-panel.png', '/dashboard', location == '/dashboard', isCompact),
                  _sidebarItem(context, 'Inventory', 'https://img.icons8.com/3d-fluency/94/package.png', '/inventory', location.startsWith('/inventory'), isCompact),
                  _sidebarItem(context, 'Sales', 'https://img.icons8.com/3d-fluency/94/shopping-bag.png', '/sales', location == '/sales', isCompact),
                  _sidebarItem(context, 'Purchase', 'https://img.icons8.com/3d-fluency/94/money.png', '/purchase', location == '/purchase', isCompact),
                  const SizedBox(height: 24),
                  Divider(indent: isCompact ? 16 : 24, endIndent: isCompact ? 16 : 24, color: AppTheme.outlineVariant),
                  const SizedBox(height: 24),
                  _sidebarItem(context, 'Settings', 'https://img.icons8.com/3d-fluency/94/services.png', '/settings', location == '/settings', isCompact),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _sidebarItem(BuildContext context, String tooltip, String iconUrl, String path, bool isSelected, bool isCompact) {
    final itemContent = AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: isSelected ? AppTheme.secondary.withValues(alpha: 0.08) : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected ? AppTheme.secondary.withValues(alpha: 0.2) : Colors.transparent, 
          width: 1,
        ),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 4 : 16, 
        vertical: isCompact ? 10 : 14,
      ),
      width: isCompact ? 72 : null,
      alignment: Alignment.center,
      child: isCompact
          ? Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Opacity(
                  opacity: isSelected ? 1.0 : 0.6,
                  child: Image.network(
                    iconUrl,
                    width: 24,
                    height: 24,
                    errorBuilder: (context, error, stackTrace) => Icon(
                      Icons.circle, 
                      size: 24, 
                      color: isSelected ? AppTheme.secondary : AppTheme.outline.withValues(alpha: 0.4)
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  tooltip,
                  style: GoogleFonts.plusJakartaSans(
                    color: isSelected ? AppTheme.secondary : AppTheme.onSurfaceVariant,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 10,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ],
            )
          : Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  decoration: BoxDecoration(
                    boxShadow: isSelected ? [
                      BoxShadow(
                        color: AppTheme.secondary.withValues(alpha: 0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ] : [],
                  ),
                  child: Opacity(
                    opacity: isSelected ? 1.0 : 0.6,
                    child: Image.network(
                      iconUrl,
                      width: 24,
                      height: 24,
                      errorBuilder: (context, error, stackTrace) => Icon(
                        Icons.circle, 
                        size: 24, 
                        color: isSelected ? AppTheme.secondary : AppTheme.outline.withValues(alpha: 0.4)
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    tooltip,
                    style: GoogleFonts.plusJakartaSans(
                      color: isSelected ? AppTheme.secondary : AppTheme.onSurfaceVariant,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
                if (isSelected)
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: AppTheme.secondary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.secondary.withValues(alpha: 0.4),
                          blurRadius: 4,
                        )
                      ]
                    ),
                  ),
              ],
            ),
    );

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 8 : 16, 
        vertical: 4,
      ),
      child: Tooltip(
        message: isCompact ? tooltip : '',
        child: InkWell(
          onTap: () {
            context.go(path);
          },
          borderRadius: BorderRadius.circular(14),
          splashColor: AppTheme.secondary.withValues(alpha: 0.1),
          highlightColor: AppTheme.secondary.withValues(alpha: 0.05),
          child: itemContent,
        ),
      ),
    );
  }

  Widget _buildBottomNavBar(BuildContext context) {
    final GoRouterState state = GoRouterState.of(context);
    final String location = state.uri.toString();

    int currentIndex = 0;
    if (location.startsWith('/inventory')) {
      currentIndex = 1;
    } else if (location.startsWith('/sales')) {
      currentIndex = 2;
    } else if (location.startsWith('/purchase')) {
      currentIndex = 3;
    }

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        border: const Border(
          top: BorderSide(color: AppTheme.outlineVariant, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: NavigationBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        indicatorColor: AppTheme.secondaryContainer,
        selectedIndex: currentIndex,
        height: 72,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: (index) {
          if (index == 0) { context.go('/dashboard'); }
          else if (index == 1) { context.go('/inventory'); }
          else if (index == 2) { context.go('/sales'); }
          else if (index == 3) { context.go('/purchase'); }
        },
        destinations: [
          NavigationDestination(
            icon: Opacity(
              opacity: 0.6,
              child: Image.network(
                'https://img.icons8.com/3d-fluency/94/control-panel.png', 
                width: 24, height: 24,
                errorBuilder: (c, e, s) => const Icon(Icons.dashboard_outlined),
              ),
            ),
            selectedIcon: Image.network(
              'https://img.icons8.com/3d-fluency/94/control-panel.png', 
              width: 28, height: 28,
              errorBuilder: (c, e, s) => const Icon(Icons.dashboard, color: AppTheme.secondary),
            ),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Opacity(
              opacity: 0.6,
              child: Image.network(
                'https://img.icons8.com/3d-fluency/94/package.png', 
                width: 24, height: 24,
                errorBuilder: (c, e, s) => const Icon(Icons.inventory_2_outlined),
              ),
            ),
            selectedIcon: Image.network(
              'https://img.icons8.com/3d-fluency/94/package.png', 
              width: 28, height: 28,
              errorBuilder: (c, e, s) => const Icon(Icons.inventory_2, color: AppTheme.secondary),
            ),
            label: 'Inventory',
          ),
          NavigationDestination(
            icon: Opacity(
              opacity: 0.6,
              child: Image.network(
                'https://img.icons8.com/3d-fluency/94/shopping-bag.png', 
                width: 24, height: 24,
                errorBuilder: (c, e, s) => const Icon(Icons.shopping_bag_outlined),
              ),
            ),
            selectedIcon: Image.network(
              'https://img.icons8.com/3d-fluency/94/shopping-bag.png', 
              width: 28, height: 28,
              errorBuilder: (c, e, s) => const Icon(Icons.shopping_bag, color: AppTheme.secondary),
            ),
            label: 'Sales',
          ),
          NavigationDestination(
            icon: Opacity(
              opacity: 0.6,
              child: Image.network(
                'https://img.icons8.com/3d-fluency/94/money.png', 
                width: 24, height: 24,
                errorBuilder: (c, e, s) => const Icon(Icons.receipt_long_outlined),
              ),
            ),
            selectedIcon: Image.network(
              'https://img.icons8.com/3d-fluency/94/money.png', 
              width: 28, height: 28,
              errorBuilder: (c, e, s) => const Icon(Icons.receipt_long, color: AppTheme.secondary),
            ),
            label: 'Purchase',
          ),
        ],
      ),
    );
  }
}
