import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../controllers/auth_controller.dart';
import '../../service_order/widgets/service_order_ui.dart';
import '../../widgets/user_avatar.dart';

class AppDrawer extends StatelessWidget {
  static const Color _green = Color(0xFF34C38F);
  static const Color _amber = Color(0xFFF5A524);
  static const Color _purple = Color(0xFFA78BFA);
  static const Color _red = Color(0xFFF26D6D);
  static const Color _cyan = Color(0xFF4FC3E8);

  /// Pestaña de Agenda en [HomePage].
  static const int _agendaTab = 1;

  const AppDrawer({super.key});

  /// Con [arguments] la ruta se vuelve a abrir aunque sea la actual (p. ej.
  /// para cambiar de pestaña en Inicio).
  void _navigate(
    BuildContext context,
    String route, {
    bool clearStack = false,
    Object? arguments,
  }) {
    final navigator = Navigator.of(context);
    final currentRoute = ModalRoute.of(context)?.settings.name;
    navigator.pop();
    if (route == currentRoute && arguments == null) return;
    if (clearStack) {
      navigator.pushNamedAndRemoveUntil(
        route,
        (route) => false,
        arguments: arguments,
      );
    } else {
      navigator.pushNamed(route, arguments: arguments);
    }
  }

  Future<void> _logout(
    BuildContext context,
    AuthController authController,
  ) async {
    // El drawer se desmonta al cerrarse; el navigator sigue vivo.
    final navigator = Navigator.of(context);
    navigator.pop();
    await authController.logout();
    if (!authController.isAuthenticated) {
      navigator.pushNamedAndRemoveUntil(
        AppConstants.loginRoute,
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authController = context.watch<AuthController>();
    final user = authController.user;
    final currentRoute = ModalRoute.of(context)?.settings.name;

    return Drawer(
      backgroundColor: AppColors.backgroundDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Image.asset(
                  'assets/images/logos/logo_horizontal.webp',
                  height: 30,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildProfileCard(
                context,
                user?.name,
                user?.email,
                user?.avatarUrl,
                user?.role ?? 'Operador',
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 24, 24, 8),
              child: Text(
                'MENÚ',
                style: TextStyle(
                  color: ServiceOrderColors.hintText,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  _DrawerItem(
                    icon: Icons.home_outlined,
                    color: ServiceOrderColors.accent,
                    label: 'Inicio',
                    selected: currentRoute == AppConstants.homeRoute,
                    onTap: () => _navigate(
                      context,
                      AppConstants.homeRoute,
                      clearStack: true,
                    ),
                  ),
                  _DrawerItem(
                    icon: Icons.event_note_outlined,
                    color: _cyan,
                    label: 'Agenda',
                    onTap: () => _navigate(
                      context,
                      AppConstants.homeRoute,
                      clearStack: true,
                      arguments: _agendaTab,
                    ),
                  ),
                  _DrawerItem(
                    icon: Icons.assignment_turned_in_outlined,
                    color: _green,
                    label: 'Servicios',
                    selected: currentRoute == AppConstants.completedOrdersRoute,
                    onTap: () => _navigate(
                      context,
                      AppConstants.completedOrdersRoute,
                    ),
                  ),
                  _DrawerItem(
                    icon: Icons.person_outline,
                    color: _purple,
                    label: 'Perfil',
                    selected: currentRoute == AppConstants.profileRoute,
                    onTap: () => _navigate(context, AppConstants.profileRoute),
                  ),
                  _DrawerItem(
                    icon: Icons.lock_outline,
                    color: _amber,
                    label: 'Cambio de contraseña',
                    selected: currentRoute == AppConstants.changePasswordRoute,
                    onTap: () => _navigate(
                      context,
                      AppConstants.changePasswordRoute,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(
              height: 1,
              color: ServiceOrderColors.divider,
              indent: 16,
              endIndent: 16,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: _DrawerItem(
                icon: Icons.logout,
                color: _red,
                label: 'Cerrar sesión',
                isDestructive: true,
                onTap: authController.isLoading
                    ? null
                    : () => _logout(context, authController),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard(
    BuildContext context,
    String? name,
    String? email,
    String? avatarUrl,
    String role,
  ) {
    final displayName = (name ?? '').trim().isEmpty ? 'Usuario' : name!.trim();

    return Material(
      color: ServiceOrderColors.card,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _navigate(context, AppConstants.profileRoute),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              UserAvatar(imageUrl: avatarUrl, name: name, radius: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if ((email ?? '').isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        email!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: ServiceOrderColors.mutedText,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: _green.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: _green.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.circle, size: 7, color: _green),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              role,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _green,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: ServiceOrderColors.mutedText,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback? onTap;
  final bool selected;
  final bool isDestructive;

  const _DrawerItem({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected ? ServiceOrderColors.card : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(icon, size: 20, color: color),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isDestructive ? color : Colors.white,
                      fontSize: 15,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
                if (selected)
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
