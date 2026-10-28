import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Reads secrets from the git-ignored `.env` file (see `.env.example`).
abstract final class Env {
  static Future<void> load() => dotenv.load(fileName: '.env', isOptional: true);

  /// Empty when the key is not configured; the Satellites screen then shows
  /// a "configure your key" state instead of calling the API.
  static String get n2yoApiKey => dotenv.maybeGet('N2YO_API_KEY') ?? '';
}
