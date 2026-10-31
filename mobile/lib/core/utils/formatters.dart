import '../utils/validators.dart';

String money(num value) => '\$${value.toStringAsFixed(2)}';

String shortId(String id) => id.length <= 8 ? id : id.substring(0, 8);

String maskCardInput(String value) {
  final digits = onlyDigits(value).substring(
    0,
    onlyDigits(value).length > 19 ? 19 : onlyDigits(value).length,
  );
  final buffer = StringBuffer();

  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && i % 4 == 0) buffer.write(' ');
    buffer.write(digits[i]);
  }

  return buffer.toString();
}

String formatExpiry(String value) {
  final digits = onlyDigits(value);
  final limited = digits.length > 4 ? digits.substring(0, 4) : digits;
  if (limited.length <= 2) return limited;
  return '${limited.substring(0, 2)}/${limited.substring(2)}';
}

String roleLabel(String role) {
  switch (role) {
    case 'cliente':
      return 'Cliente';
    case 'validador':
      return 'Validador';
    case 'soporte':
      return 'Soporte';
    case 'admin':
      return 'Administrador';
    default:
      return role;
  }
}

String seatStatusLabel(String status) {
  switch (status) {
    case 'free':
      return 'Libre';
    case 'mine':
      return 'Tu bloqueo';
    case 'locked':
      return 'Bloqueado';
    case 'sold':
      return 'Vendido';
    default:
      return status;
  }
}
