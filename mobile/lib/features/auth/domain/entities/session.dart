class Session {
  const Session({
    required this.token,
    required this.name,
    required this.email,
    required this.role,
    this.cedula,
  });

  final String token;
  final String name;
  final String email;
  final String role;
  final String? cedula;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }
}
