class AppConfig {
  const AppConfig({
    required this.apiBaseUrl,
    required this.gatewayBaseUrl,
    required this.fallbackPrice,
    required this.devShowOtp,
  });

  final String apiBaseUrl;
  final String gatewayBaseUrl;
  final double fallbackPrice;
  final bool devShowOtp;

  factory AppConfig.fromEnvironment() {
    const api = String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://192.168.1.48:3000',
    );

    return AppConfig(
      apiBaseUrl: api,
      gatewayBaseUrl: _gatewayUrl(api),
      fallbackPrice: 25,
      devShowOtp: const bool.fromEnvironment('DEV_SHOW_OTP', defaultValue: true),
    );
  }
}

String _gatewayUrl(String apiBaseUrl) {
  final uri = Uri.parse(apiBaseUrl);
  return uri.replace(port: 4001, path: '', query: '', fragment: '').toString();
}
