// utils/app_constants.dart

class AppConstants {
  // ─── Flask ML Backend ─────
  static const String flaskBaseUrl = 'http://10.0.2.2:5000';

  static const String recommendEndpoint = '$flaskBaseUrl/recommend';
  static const String skillGapEndpoint  = '$flaskBaseUrl/skill_gap';
  static const String healthEndpoint    = '$flaskBaseUrl/health';

  //  Gemini API
  // Key from: https://aistudio.google.com/app/apikey
  static const String geminiApiKey = '';

  // Gemini 2.0 Flash Lite
  static const String geminiEndpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-flash-lite-previewcd backend:generateContent';

  //  Asset path
  static const String jobsAssetPath = 'assets/data/jobs.json';

  //  UI 
  static const String appName            = 'Smart Job Recommender';
  static const int    httpTimeoutSeconds = 15;
}