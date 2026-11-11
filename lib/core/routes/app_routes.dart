import 'package:flutter/material.dart';
import '../../domain/entities/service_order_record.dart';
import '../../presentation/auth/change_password/change_password_page.dart';
import '../../presentation/auth/forgot_password/forgot_password_page.dart';
import '../../presentation/auth/login/login_page.dart';
import '../../presentation/auth/profile/profile_page.dart';
import '../../presentation/home/home_page.dart';
import '../../presentation/orders/completed_orders_page.dart';
import '../../presentation/orders/order_detail_page.dart';
import '../../presentation/service_order/service_order_flow_page.dart';
import '../constants/app_constants.dart';

class AppRoutes {
  AppRoutes._();

  /// Pantallas que se abren sin sesión.
  static const Set<String> publicRoutes = {
    AppConstants.loginRoute,
    AppConstants.forgotPasswordRoute,
  };

  /// Pantallas de una orden: llevan el id en la URL (`?id=42`) para que en
  /// el navegador se puedan recargar.
  static const Set<String> orderRoutes = {
    AppConstants.serviceOrderRoute,
    AppConstants.orderDetailRoute,
  };

  /// Cada ruta recibe sus `arguments` en `ModalRoute.of(context).settings`.
  static Map<String, WidgetBuilder> getRoutes() {
    return {
      AppConstants.loginRoute: (context) => const LoginPage(),
      AppConstants.forgotPasswordRoute: (context) => const ForgotPasswordPage(),
      AppConstants.homeRoute: (context) => const HomePage(),
      AppConstants.profileRoute: (context) => const ProfilePage(),
      AppConstants.serviceOrderRoute: (context) => const ServiceOrderFlowPage(),
      AppConstants.completedOrdersRoute: (context) =>
          const CompletedOrdersPage(),
      AppConstants.orderDetailRoute: (context) => const OrderDetailPage(),
      AppConstants.changePasswordRoute: (context) => const ChangePasswordPage(),
    };
  }

  /// Resuelve [settings] con la sesión actual:
  /// - sin sesión, cualquier pantalla protegida abre el login;
  /// - con sesión, el login abre el inicio;
  /// - una ruta desconocida abre el inicio (o el login sin sesión);
  /// - las pantallas de una orden ponen su id en el nombre (la URL en web) y
  ///   lo pasan como argumento cuando llegan sin la orden (al recargar).
  static Route<dynamic> onGenerateRoute(
    RouteSettings settings, {
    required bool isAuthenticated,
  }) {
    final resolved = resolve(settings, isAuthenticated: isAuthenticated);
    final path = Uri.parse(resolved.name!).path;
    final builder = getRoutes()[path]!;
    return MaterialPageRoute<dynamic>(settings: resolved, builder: builder);
  }

  /// Rutas al abrir la app. En web vienen de la URL; una pantalla que no es
  /// el inicio queda encima de él para que "Regresar" tenga a dónde ir.
  static List<Route<dynamic>> onGenerateInitialRoutes(
    String initialRoute, {
    required bool isAuthenticated,
  }) {
    final target = resolve(
      RouteSettings(name: initialRoute),
      isAuthenticated: isAuthenticated,
    );
    final path = Uri.parse(target.name!).path;
    return [
      if (isAuthenticated && path != AppConstants.homeRoute)
        onGenerateRoute(
          const RouteSettings(name: AppConstants.homeRoute),
          isAuthenticated: isAuthenticated,
        ),
      onGenerateRoute(target, isAuthenticated: isAuthenticated),
    ];
  }

  @visibleForTesting
  static RouteSettings resolve(
    RouteSettings settings, {
    required bool isAuthenticated,
  }) {
    final uri = Uri.tryParse(settings.name ?? '') ?? Uri();
    final path = uri.path;
    final fallback =
        isAuthenticated ? AppConstants.homeRoute : AppConstants.loginRoute;

    if (!getRoutes().containsKey(path)) {
      return RouteSettings(name: fallback);
    }
    if (!isAuthenticated && !publicRoutes.contains(path)) {
      return const RouteSettings(name: AppConstants.loginRoute);
    }
    if (isAuthenticated && path == AppConstants.loginRoute) {
      return const RouteSettings(name: AppConstants.homeRoute);
    }
    if (orderRoutes.contains(path)) {
      final argument = settings.arguments;
      final id = argument is ServiceOrderRecord
          ? argument.id
          : argument is String
              ? argument
              : uri.queryParameters['id'];
      if (id == null || id.isEmpty) {
        return RouteSettings(name: path, arguments: argument);
      }
      return RouteSettings(
        name: Uri(path: path, queryParameters: {'id': id}).toString(),
        arguments: argument ?? id,
      );
    }
    return settings;
  }
}
