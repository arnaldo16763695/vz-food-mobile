import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_session.dart';
import '../theme/app_colors.dart';
import '../../features/bag/infrastructure/bag_api.dart';

enum CustomerFooterTab {
  home,
  bag,
  orders,
  profile,
}

class CustomerFooterNav extends StatefulWidget {
  const CustomerFooterNav({
    super.key,
    required this.currentTab,
    this.tenantSlug,
    this.branchId,
    this.authSession,
    this.bagApi,
  });

  final CustomerFooterTab currentTab;
  final String? tenantSlug;
  final String? branchId;
  final AuthSession? authSession;
  final BagApi? bagApi;

  @override
  State<CustomerFooterNav> createState() => _CustomerFooterNavState();
}

class _CustomerFooterNavState extends State<CustomerFooterNav> {
  int? _bagCount;

  @override
  void initState() {
    super.initState();
    _loadBagCount();
  }

  @override
  void didUpdateWidget(covariant CustomerFooterNav oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tenantSlug != widget.tenantSlug ||
        oldWidget.branchId != widget.branchId ||
        oldWidget.authSession != widget.authSession ||
        oldWidget.bagApi != widget.bagApi) {
      _loadBagCount();
    }
  }

  Future<void> _loadBagCount() async {
    final tenantSlug = widget.tenantSlug;
    final branchId = widget.branchId;
    final authSession = widget.authSession;
    final bagApi = widget.bagApi;

    if (tenantSlug == null ||
        tenantSlug.isEmpty ||
        branchId == null ||
        branchId.isEmpty ||
        authSession == null ||
        bagApi == null) {
      if (mounted) {
        setState(() {
          _bagCount = null;
        });
      }
      return;
    }

    try {
      final accessToken = await authSession.getAccessToken();
      if (accessToken == null || accessToken.isEmpty) {
        if (mounted) {
          setState(() {
            _bagCount = null;
          });
        }
        return;
      }

      final bag = await bagApi.fetchBag(
        tenantSlug: tenantSlug,
        branchId: branchId,
        accessToken: accessToken,
      );

      if (mounted) {
        setState(() {
          _bagCount = bag.items.fold<int>(0, (sum, item) => sum + item.quantity);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _bagCount = null;
        });
      }
    }
  }

  void _navigate(CustomerFooterTab tab) {
    switch (tab) {
      case CustomerFooterTab.home:
        if ((widget.tenantSlug ?? '').isNotEmpty) {
          final branchQuery = (widget.branchId ?? '').isEmpty
              ? ''
              : '?branchId=${widget.branchId}';
          context.go('/storefront/${widget.tenantSlug}$branchQuery');
          return;
        }
        context.go('/');
      case CustomerFooterTab.bag:
        if ((widget.tenantSlug ?? '').isEmpty || (widget.branchId ?? '').isEmpty) {
          return;
        }
        context.go('/storefront/${widget.tenantSlug}/bag?branchId=${widget.branchId}');
      case CustomerFooterTab.orders:
        if ((widget.tenantSlug ?? '').isEmpty) {
          return;
        }
        final branchQuery = (widget.branchId ?? '').isEmpty
            ? ''
            : '?branchId=${widget.branchId}';
        context.go('/storefront/${widget.tenantSlug}/orders$branchQuery');
      case CustomerFooterTab.profile:
        final tenantQuery = (widget.tenantSlug ?? '').isEmpty
            ? ''
            : '?tenantSlug=${widget.tenantSlug}${(widget.branchId ?? '').isEmpty ? '' : '&branchId=${widget.branchId}'}';
        context.go('/account$tenantQuery');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.border),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 16,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _FooterItem(
              icon: Icons.home_rounded,
              label: 'Home',
              isActive: widget.currentTab == CustomerFooterTab.home,
              onTap: () => _navigate(CustomerFooterTab.home),
            ),
            _FooterItem(
              icon: Icons.person_rounded,
              label: 'Perfil',
              isActive: widget.currentTab == CustomerFooterTab.profile,
              onTap: () => _navigate(CustomerFooterTab.profile),
            ),
            _FooterItem(
              icon: Icons.receipt_long_rounded,
              label: 'Pedidos',
              isActive: widget.currentTab == CustomerFooterTab.orders,
              isEnabled: (widget.tenantSlug ?? '').isNotEmpty,
              onTap: () => _navigate(CustomerFooterTab.orders),
            ),
            _FooterItem(
              icon: Icons.shopping_bag_rounded,
              label: 'Bolsa',
              isActive: widget.currentTab == CustomerFooterTab.bag,
              isEnabled: (widget.tenantSlug ?? '').isNotEmpty && (widget.branchId ?? '').isNotEmpty,
              badgeCount: _bagCount,
              onTap: () => _navigate(CustomerFooterTab.bag),
            ),
          ],
        ),
      ),
    );
  }
}

class _FooterItem extends StatelessWidget {
  const _FooterItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
    this.isEnabled = true,
    this.badgeCount,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final bool isEnabled;
  final int? badgeCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final iconColor = !isEnabled
        ? AppColors.textMuted.withValues(alpha: 0.55)
        : isActive
            ? AppColors.brandPrimary
            : AppColors.textMuted;
    final labelStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          fontSize: 10,
          fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
          color: iconColor,
        );

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: isEnabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        width: 64,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.brandPrimary.withValues(alpha: 0.10)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Center(
                    child: AnimatedScale(
                      scale: isActive ? 1.06 : 1,
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOut,
                      child: Icon(icon, color: iconColor, size: 24),
                    ),
                  ),
                  if (badgeCount != null && badgeCount! > 0)
                    Positioned(
                      right: -6,
                      top: -4,
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 18),
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.brandPrimary,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: Text(
                          '${badgeCount! > 99 ? '99+' : badgeCount}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: labelStyle,
            ),
          ],
        ),
      ),
    );
  }
}
