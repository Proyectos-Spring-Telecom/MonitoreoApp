import 'package:flutter/material.dart';
import '../../presentation/auth/login/login_page.dart';
import '../../presentation/home/home_page.dart';
import '../../presentation/auth/profile/profile_page.dart';
import '../../presentation/service_order/service_details_page.dart';
import '../../presentation/service_order/gps_data_page.dart';
import '../../presentation/service_order/service_review_page.dart';
import '../../presentation/orders/completed_orders_page.dart';
import '../../presentation/auth/change_password/change_password_page.dart';
import '../constants/app_constants.dart' as constants;

class AppRoutes {
  static Map<String, WidgetBuilder> getRoutes() {
    return {
      constants.AppConstants.loginRoute: (context) => const LoginPage(),
      constants.AppConstants.homeRoute: (context) => const HomePage(),
      constants.AppConstants.profileRoute: (context) => const ProfilePage(),
      constants.AppConstants.serviceDetailsRoute: (context) =>
          const ServiceDetailsPage(),
      constants.AppConstants.gpsDataRoute: (context) => const GpsDataPage(),
      constants.AppConstants.serviceReviewRoute: (context) =>
          const ServiceReviewPage(),
      constants.AppConstants.completedOrdersRoute: (context) =>
          const CompletedOrdersPage(),
      constants.AppConstants.changePasswordRoute: (context) =>
          const ChangePasswordPage(),
    };
  }

  static Route<dynamic>? generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case constants.AppConstants.loginRoute:
        return MaterialPageRoute(
          builder: (_) => const LoginPage(),
        );
      case constants.AppConstants.homeRoute:
        return MaterialPageRoute(
          builder: (_) => const HomePage(),
        );
      case constants.AppConstants.profileRoute:
        return MaterialPageRoute(
          builder: (_) => const ProfilePage(),
        );
      case constants.AppConstants.serviceDetailsRoute:
        return MaterialPageRoute(
          builder: (_) => const ServiceDetailsPage(),
        );
      case constants.AppConstants.gpsDataRoute:
        return MaterialPageRoute(
          builder: (_) => const GpsDataPage(),
        );
      case constants.AppConstants.serviceReviewRoute:
        return MaterialPageRoute(
          builder: (_) => const ServiceReviewPage(),
        );
      case constants.AppConstants.completedOrdersRoute:
        return MaterialPageRoute(
          builder: (_) => const CompletedOrdersPage(),
        );
      case constants.AppConstants.changePasswordRoute:
        return MaterialPageRoute(
          builder: (_) => const ChangePasswordPage(),
        );
      default:
        return null;
    }
  }
}
