String? requiredField(String? value, [String label = 'Este campo']) {
  if (value == null || value.trim().isEmpty) return 'Completa $label.';
  return null;
}

String? validateName(String? value) {
  final text = value?.trim() ?? '';
  if (text.length < 3) return 'Ingresa tu nombre completo.';
  if (text.length > 60) return 'El nombre es demasiado largo.';
  if (!RegExp(r'^[A-Za-zÁÉÍÓÚÜÑáéíóúüñ ]+$').hasMatch(text)) {
    return 'Usa solo letras y espacios.';
  }
  return null;
}

String? validateEmail(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return 'Ingresa tu correo.';
  if (!RegExp(r'^[^\s@]{1,64}@[^\s@]+\.[^\s@]+$').hasMatch(text)) {
    return 'El correo no es válido.';
  }
  return null;
}

String? validateCedula(String? value) {
  final text = value?.trim() ?? '';
  if (!RegExp(r'^\d{10}$').hasMatch(text)) {
    return 'La cédula debe tener 10 dígitos.';
  }
  return null;
}

String? validatePassword(String? value) {
  final text = value ?? '';
  if (text.length < 10) return 'Mínimo 10 caracteres.';
  if (!RegExp(r'[A-Z]').hasMatch(text)) return 'Incluye una mayúscula.';
  if (!RegExp(r'[a-z]').hasMatch(text)) return 'Incluye una minúscula.';
  if (!RegExp(r'\d').hasMatch(text)) return 'Incluye un número.';
  if (!RegExp(r'[^\w\s]').hasMatch(text)) return 'Incluye un símbolo.';
  return null;
}

String? validateOtp(String? value) {
  if (!RegExp(r'^\d{6}$').hasMatch(value?.trim() ?? '')) {
    return 'El código debe tener 6 dígitos.';
  }
  return null;
}

String? validateCardNumber(String? value) {
  final digits = onlyDigits(value ?? '');
  if (digits.length < 13 || digits.length > 19) {
    return 'El número de tarjeta debe tener entre 13 y 19 dígitos.';
  }
  if (!luhn(digits)) return 'El número de tarjeta no es válido.';
  return null;
}

String? validateExpiry(String? value) {
  final text = value?.trim() ?? '';
  final match = RegExp(r'^(\d{2})/(\d{2})$').firstMatch(text);
  if (match == null) return 'Usa el formato MM/AA.';

  final month = int.parse(match.group(1)!);
  final year = int.parse(match.group(2)!);
  if (month < 1 || month > 12) return 'Mes inválido.';

  final now = DateTime.now();
  final expiry = DateTime(2000 + year, month + 1, 1);
  if (expiry.isBefore(DateTime(now.year, now.month, 1))) {
    return 'La tarjeta está vencida.';
  }
  return null;
}

String? validateCvv(String? value) {
  if (!RegExp(r'^\d{3,4}$').hasMatch(value?.trim() ?? '')) {
    return 'El CVV debe tener 3 o 4 dígitos.';
  }
  return null;
}

String onlyDigits(String value) => value.replaceAll(RegExp(r'\D'), '');

bool luhn(String digits) {
  var sum = 0;
  var doubleDigit = false;

  for (var i = digits.length - 1; i >= 0; i--) {
    var digit = int.parse(digits[i]);
    if (doubleDigit) {
      digit *= 2;
      if (digit > 9) digit -= 9;
    }
    sum += digit;
    doubleDigit = !doubleDigit;
  }

  return digits.isNotEmpty && sum % 10 == 0;
}
