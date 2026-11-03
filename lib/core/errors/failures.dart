import 'package:equatable/equatable.dart';

abstract class Failure extends Equatable {
  final String message;
  final int? statusCode;

  const Failure(this.message, {this.statusCode});

  @override
  List<Object> get props => [message];
}

class ServerFailure extends Failure {
  /// Cuerpo decodificado de la respuesta de error, si lo hubo.
  final Object? data;

  const ServerFailure(super.message, {super.statusCode, this.data});
}

/// El servidor rechazó cerrar la orden y devolvió lo que falta.
class IncompleteOrderFailure extends Failure {
  final List<String> missing;

  const IncompleteOrderFailure(super.message, this.missing)
      : super(statusCode: 400);
}

class NetworkFailure extends Failure {
  const NetworkFailure(super.message);
}

class CacheFailure extends Failure {
  const CacheFailure(super.message);
}

/// Datos inválidos detectados en la app antes de llamar al API.
class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}

class AuthFailure extends Failure {
  const AuthFailure(super.message, {super.statusCode});
}

extension FailureStatus on Failure {
  /// La orden no existe o ya no es del técnico (§13).
  bool get isNotFound => statusCode == 404;

  /// Otra acción se adelantó: hay que recargar la orden (§13).
  bool get isConflict => statusCode == 409;
}
