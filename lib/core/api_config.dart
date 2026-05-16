enum Environment { local, ngrok, render }

class ApiConfig {
  static const Environment currentEnvironment = Environment.local;
  static const String _ngrokBackendUrl = 'https://pretty-candles-tell.loca.lt';
  static const String _ngrokAiUrl = 'https://wicked-meals-lay.loca.lt';
  static const String _localBackendUrl = 'http://192.168.100.8:5000';
  static const String _localAiUrl = 'http://192.168.100.8:8000';
  static const String _renderBackendUrl = 'https://your-backend.onrender.com';
  static const String _renderAiUrl = 'https://your-ai.onrender.com';
  static String get backendBaseUrl {
    switch (currentEnvironment) {
      case Environment.local:
        return _localBackendUrl;
      case Environment.ngrok:
        return _ngrokBackendUrl;
      case Environment.render:
        return _renderBackendUrl;
    }
  }

  static String get aiBaseUrl {
    switch (currentEnvironment) {
      case Environment.local:
        return _localAiUrl;
      case Environment.ngrok:
        return _ngrokAiUrl;
      case Environment.render:
        return _renderAiUrl;
    }
  }

  static String get authEndpoint => '$backendBaseUrl/api/auth';
  static String get projectsEndpoint => '$backendBaseUrl/api/projects';
  // Get your free API key from https://platform.stability.ai/
  static const String stabilityApiKey = 'YOUR_API_KEY_HERE';

  // The Stability AI endpoint for image-to-image
  static const String stabilityBaseUrl =
      'https://api.stability.ai/v1/generation/stable-diffusion-xl-1024-v1-0/image-to-image';
}
