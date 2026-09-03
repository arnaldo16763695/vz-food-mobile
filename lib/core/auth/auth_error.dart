import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

/// Maps auth SDK failures to short, customer-facing Spanish messages. Keeps the
/// raw SDK text out of the UI while still forwarding anything we do not
/// specifically recognize.
String describeAuthError(Object error) {
  if (error is AuthException) {
    final message = error.message.toLowerCase();
    if (message.contains('invalid login credentials')) {
      return 'Email o contrasena incorrectos.';
    }
    if (message.contains('already registered') ||
        message.contains('already been registered') ||
        message.contains('user already exists')) {
      return 'Ese email ya tiene una cuenta. Inicia sesion.';
    }
    if (message.contains('password should be at least') ||
        message.contains('password is too short')) {
      return 'La contrasena es demasiado corta.';
    }
    if (message.contains('email not confirmed')) {
      return 'Debes confirmar tu email antes de iniciar sesion.';
    }
    if (message.contains('rate limit') || message.contains('too many')) {
      return 'Demasiados intentos. Espera un momento e intentalo de nuevo.';
    }
    if (message.contains('unable to validate email') ||
        message.contains('invalid email')) {
      return 'El email no es valido.';
    }
    return error.message;
  }

  final text = error.toString().toLowerCase();
  if (text.contains('socketexception') ||
      text.contains('failed host lookup') ||
      text.contains('network') ||
      text.contains('timeout')) {
    return 'Sin conexion. Revisa tu internet e intentalo de nuevo.';
  }

  return 'No se pudo completar la accion. Intentalo de nuevo.';
}
