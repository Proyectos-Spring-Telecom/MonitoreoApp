import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import 'drawer/app_drawer.dart';
import 'bottom_navigation/bottom_navigation_widget.dart';
import '../auth/profile/profile_page.dart';
import '../service_order/service_order_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  List<Widget> _getPages() {
    return [
      _HomeTab(
        onStartPressed: () {
          setState(() {
            _currentIndex = 1;
          });
        },
      ),
      const ServiceOrderPage(),
      const ProfilePage(),
    ];
  }

  String _getAppBarTitle(int index) {
    switch (index) {
      case 0:
        return 'Inicio';
      case 1:
        return 'Orden de Servicio';
      case 2:
        return 'Perfil';
      default:
        return 'Inicio';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDark,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          _getAppBarTitle(_currentIndex),
          style: const TextStyle(color: Colors.white),
        ),
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

class _HomeTab extends StatefulWidget {
  final VoidCallback onStartPressed;
  
  const _HomeTab({required this.onStartPressed});

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  bool _isImageLoaded = false;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Imagen de fondo
        Image.asset(
          'assets/images/backgrounds/bienvenida.jpg',
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            if (wasSynchronouslyLoaded || frame != null) {
              // La imagen está cargada
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  setState(() {
                    _isImageLoaded = true;
                  });
                }
              });
            }
            return child;
          },
          errorBuilder: (context, error, stackTrace) {
            // Debug: imprimir el error
            debugPrint('Error loading image: $error');
            debugPrint('Stack trace: $stackTrace');
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  _isImageLoaded = true;
                });
              }
            });
            return Container(
              color: AppColors.backgroundDark,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.image_not_supported,
                      color: Colors.white54,
                      size: 64,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Error al cargar imagen',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        // Loading mientras carga la imagen
        if (!_isImageLoaded)
          Container(
            color: AppColors.backgroundDark,
            child: const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryBlue),
              ),
            ),
          ),
        // Overlay oscuro para mejorar legibilidad
        if (_isImageLoaded)
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.3),
                  Colors.black.withOpacity(0.6),
                ],
              ),
            ),
          ),
        // Contenido
        if (_isImageLoaded)
          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Spacer(flex: 45),
                // Logo SPRING telecom
                _buildLogo(),
                const SizedBox(height: 24),
                // Slogan
                const Text(
                  'Explora el internet de las cosas',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1.6,
                  ),
                ),
                const Spacer(flex: 1),
                const SizedBox(height: 15),
                // Botón Comenzar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: widget.onStartPressed,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 4,
                      ),
                      child: const Text(
                        'Comenzar',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildLogo() {
    return Image.asset(
      'assets/images/logos/SPRING-HORIZONTAL.png',
      height: 80,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return const Icon(
          Icons.image_not_supported,
          color: Colors.white54,
          size: 64,
        );
      },
    );
  }
}

