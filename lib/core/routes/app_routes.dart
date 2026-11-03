import 'package:flutter/material.dart';
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
}
