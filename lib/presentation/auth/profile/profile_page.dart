import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../domain/entities/user.dart';
import '../../controllers/auth_controller.dart';
import '../../service_order/widgets/service_order_ui.dart';
import '../../widgets/user_avatar.dart';

class ProfilePage extends StatefulWidget {
  /// En la pestaña de Inicio la barra superior la pone [HomePage].
  final bool showAppBar;

  const ProfilePage({super.key, this.showAppBar = true});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  static const Color _green = Color(0xFF34C38F);
  static const Color _amber = Color(0xFFF5A524);
  static const Color _red = Color(0xFFF26D6D);

  static const String _noRecord = 'Sin registro';
  static const List<String> _months = [
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadProfile());
  }

  /// Los datos vienen de la sesión (`GET /login/me`); se vuelven a consultar
  /// al entrar y al deslizar hacia abajo para mostrarlos al día.
  Future<void> _loadProfile() =>
      context.read<AuthController>().refreshProfile();

  static String _orNoRecord(String? value) =>
      value == null || value.trim().isEmpty ? _noRecord : value.trim();

  static String _formatDate(DateTime? date) {
    if (date == null) return _noRecord;
    final local = date.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${local.day} ${_months[local.month - 1]} ${local.year}, '
        '${two(local.hour)}:${two(local.minute)}';
  }

  Future<void> _handleLogout(AuthController authController) async {
    await authController.logout();
    if (mounted && !authController.isAuthenticated) {
      Navigator.of(context).pushNamedAndRemoveUntil(
        AppConstants.loginRoute,
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authController = context.watch<AuthController>();
    final user = authController.user;

    final body = user == null
        ? const Center(
            child: Text(
              'No hay usuario autenticado',
              style: TextStyle(color: ServiceOrderColors.mutedText),
            ),
          )
        : RefreshIndicator(
            onRefresh: _loadProfile,
            color: ServiceOrderColors.accent,
            backgroundColor: ServiceOrderColors.card,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              children: [
                if (authController.isRefreshingProfile)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: LinearProgressIndicator(
                      minHeight: 2,
                      color: ServiceOrderColors.accent,
                      backgroundColor: ServiceOrderColors.card,
                    ),
                  ),
                if (authController.profileError != null) ...[
                  _buildProfileErrorBanner(authController.profileError!),
                  const SizedBox(height: 16),
                ],
                _buildHeaderCard(user),
                const SizedBox(height: 16),
                _buildAccountInfoCard(user),
                const SizedBox(height: 16),
                _buildAccountCard(authController),
              ],
            ),
          );

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: widget.showAppBar
          ? AppBar(
              backgroundColor: AppColors.backgroundDark,
              foregroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              centerTitle: false,
              titleSpacing: 0,
              leading: const ServiceOrderBackButton(
                fallbackRoute: AppConstants.homeRoute,
                fallbackArguments: 3,
              ),
              title: const Text(
                'Perfil',
                style: TextStyle(color: Colors.white, fontSize: 20),
              ),
            )
          : null,
      body: body,
    );
  }

  Widget _buildHeaderCard(User user) {
    return ServiceOrderCard(
      child: Row(
        children: [
          UserAvatar(imageUrl: user.avatarUrl, name: user.name, radius: 36),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name.trim().isEmpty ? 'Usuario' : user.name.trim(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  user.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: ServiceOrderColors.mutedText,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (user.isActive == false)
                      _buildTag(
                        'Inactivo',
                        Icons.pause_circle_outline,
                        ServiceOrderColors.disabledButton,
                      )
                    else
                      _buildTag('Activo', Icons.check_circle_outline, _green),
                    _buildTag(
                      user.role ?? 'Operador',
                      Icons.engineering_outlined,
                      ServiceOrderColors.accent,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountInfoCard(User user) {
    final rows = [
      (
        Icons.person_outline,
        ServiceOrderColors.violet,
        'Nombre completo',
        _orNoRecord(user.name)
      ),
      (
        Icons.mail_outline,
        ServiceOrderColors.accent,
        'Correo',
        _orNoRecord(user.email)
      ),
      (
        Icons.engineering_outlined,
        _amber,
        'Rol',
        _orNoRecord(user.role),
      ),
      (Icons.phone_outlined, _green, 'Teléfono', _orNoRecord(user.phone)),
      (
        Icons.business_outlined,
        ServiceOrderColors.accent,
        'Cliente',
        _orNoRecord(user.clientName),
      ),
      (
        Icons.schedule,
        ServiceOrderColors.violet,
        'Último acceso',
        _formatDate(user.lastLogin),
      ),
    ];

    return ServiceOrderCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ServiceOrderSectionHeader(
            icon: Icons.badge_outlined,
            title: 'Información de la cuenta',
          ),
          const SizedBox(height: 6),
          const Text(
            'Para modificar tus datos, contacta al administrador del sistema.',
            style: TextStyle(color: ServiceOrderColors.mutedText, fontSize: 14),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < rows.length; i++)
            _InfoRow(
              icon: rows[i].$1,
              color: rows[i].$2,
              label: rows[i].$3,
              value: rows[i].$4,
              showDivider: i < rows.length - 1,
            ),
        ],
      ),
    );
  }

  Widget _buildAccountCard(AuthController authController) {
    return ServiceOrderCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ServiceOrderSectionHeader(
            icon: Icons.shield_outlined,
            title: 'Cuenta y seguridad',
          ),
          const SizedBox(height: 8),
          _ActionTile(
            icon: Icons.lock_outline,
            color: _amber,
            title: 'Cambiar contraseña',
            subtitle: 'Actualiza tu contraseña de acceso',
            onTap: () => Navigator.of(context)
                .pushNamed(AppConstants.changePasswordRoute),
          ),
          _ActionTile(
            icon: Icons.history,
            color: ServiceOrderColors.accent,
            title: 'Mi historial',
            subtitle: 'Consulta tus órdenes realizadas',
            onTap: () => Navigator.of(context)
                .pushNamed(AppConstants.completedOrdersRoute),
          ),
          _ActionTile(
            icon: Icons.logout,
            color: _red,
            title: 'Cerrar sesión',
            subtitle: 'Salir de tu cuenta en este dispositivo',
            isDestructive: true,
            showDivider: false,
            onTap: authController.isLoading
                ? null
                : () => _handleLogout(authController),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileErrorBanner(String message) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      decoration: BoxDecoration(
        color: ServiceOrderColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_outlined,
              color: AppColors.error, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: ServiceOrderColors.mutedText,
                fontSize: 13,
                height: 1.3,
              ),
            ),
          ),
          TextButton(
            onPressed: _loadProfile,
            style: TextButton.styleFrom(
              foregroundColor: ServiceOrderColors.accent,
            ),
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  Widget _buildTag(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final bool showDivider;

  const _InfoRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: showDivider
            ? const Border(
                bottom: BorderSide(color: ServiceOrderColors.divider),
              )
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 21, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: ServiceOrderColors.mutedText,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                SelectableText(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool isDestructive;
  final bool showDivider;

  const _ActionTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isDestructive = false,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: showDivider
              ? const Border(
                  bottom: BorderSide(color: ServiceOrderColors.divider),
                )
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, size: 21, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isDestructive ? color : Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: ServiceOrderColors.mutedText,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right,
              color: isDestructive ? color : ServiceOrderColors.mutedText,
            ),
          ],
        ),
      ),
    );
  }
}
