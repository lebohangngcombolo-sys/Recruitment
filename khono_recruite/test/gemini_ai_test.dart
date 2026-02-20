// c:\apps\Recruitment\khono_recruite\test\gemini_ai_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:khono_recruite/firebase_options.dart'; // Assuming this path is correct

void main() {
  // Initialize Flutter binding for tests
  TestWidgetsFlutterBinding.ensureInitialized();
  
  group('Gemini AI Integration Test', () {
    late GenerativeModel generativeModel;

    setUpAll(() async {
      // Ensure Firebase is initialized before running tests
      // For a true integration test, ensure your Firebase project is configured
      // and 'firebase_options.dart' is correctly generated for the 'web' platform.
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      // Initialize the Gemini model
      generativeModel = FirebaseAI.googleAI().generativeModel(model: 'gemini-2.5-flash');
    });

    test('should receive a non-empty response from Gemini AI', () async {
      // Given a simple prompt
      final prompt = [Content.text('Hello Gemini, what is Flutter?')];

      // When generating content
      final response = await generativeModel.generateContent(prompt);

      // Then the response text should not be null or empty
      expect(response.text, isNotNull);
      expect(response.text, isNotEmpty);
      print('Gemini AI Response: ${response.text}');
    });

    // You can add more tests here, e.g., for different prompts, error handling, etc.
  });
}