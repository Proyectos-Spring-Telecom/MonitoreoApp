import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../controllers/auth_controller.dart';
import 'drawer/app_drawer.dart';
import 'bottom_navigation/bottom_navigation_widget.dart';
import '../auth/profile/profile_page.dart';
import '../orders/completed_orders_page.dart';
import '../../domain/repositories/service_order_repository.dart';
import '../agenda/agenda_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  bool _readInitialTab = false;

  @override
  void initState() {
    super.initState();
    // Catálogos al iniciar sesión (§2); se guardan en memoria.
    final orders = context.read<ServiceOrderRepository>();
    orders.getCatalog().ignore();
    orders.getReasons().ignore();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_readInitialTab) return;
    _readInitialTab = true;
    final initialTab = ModalRoute.of(context)?.settings.arguments;
    if (initialTab is int && initialTab >= 0 && initialTab <= 3) {
      _currentIndex = initialTab;
    }
  }

  List<Widget> _getPages() {
    return [
      _HomeTab(
        onStartPressed: () {
          setState(() {
            _currentIndex = 1;
          });
        },
        onHistoryPressed: () {
          setState(() {
            _currentIndex = 2;
          });
        },
      ),
      const AgendaPage(),
      const CompletedOrdersPage(showAppBar: false),
      const ProfilePage(showAppBar: false),
    ];
  }

  Widget _getAppBarTitle(int index) {
    switch (index) {
      case 1:
        return const Text('Mi agenda');
      case 2:
        return const Text('Servicios');
      case 3:
        return const Text('Perfil');
      default:
        return Align(
          alignment: Alignment.centerLeft,
          child: Image.asset(
            'assets/images/logos/logo_horizontal.webp',
            height: 32,
            fit: BoxFit.contain,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDark,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: false,
        titleSpacing: 0,
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20),
        title: _getAppBarTitle(_currentIndex),
      ),
      drawer: const AppDrawer(),
      body: _getPages()[_currentIndex],
      bottomNavigationBar: BottomNavigationWidget(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }
}

class _HomeTab extends StatelessWidget {
  static const Color _accent = Color(0xFF4FC3E8);

  final VoidCallback onStartPressed;
  final VoidCallback onHistoryPressed;

  const _HomeTab({
    required this.onStartPressed,
    required this.onHistoryPressed,
  });

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthController>().user;
    final name = user?.name.trim() ?? '';
    final role = (user?.role ?? 'Operador').toUpperCase();
    final firstName = name.isEmpty ? '' : name.split(' ').first;
    final greeting =
        firstName.isEmpty ? 'Bienvenido' : 'Bienvenido,\n$firstName';

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/images/backgrounds/bienvenida.jpg',
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            if (wasSynchronouslyLoaded) return child;
            return AnimatedOpacity(
              opacity: frame == null ? 0 : 1,
              duration: const Duration(milliseconds: 300),
              child: child,
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return const ColoredBox(color: AppColors.backgroundDark);
          },
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0.0, 0.45, 0.7, 1.0],
              colors: [
                Color(0x0009081C),
                Color(0x0009081C),
                Color(0x9909081C),
                Color(0xF209081C),
              ],
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  role,
                  style: const TextStyle(
                    color: _accent,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  greeting,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 54,
                  child: ElevatedButton(
                    onPressed: onStartPressed,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Ver mi agenda',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward, size: 22),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 54,
                  child: OutlinedButton(
                    onPressed: onHistoryPressed,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _accent,
                      side: const BorderSide(color: Color(0x994FC3E8)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Ver mi historial',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
