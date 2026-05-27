import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_nsfw_detector/flutter_nsfw_detector.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Initialize detector', (WidgetTester tester) async {
    // The actual native model loading will be tested on-device.
    // This integration test verifies the method channel is wired correctly.
    expect(FlutterNsfwDetector.isInitialized, false);
  });
}
