import 'package:flutter/material.dart';
import 'package:flutter_nsfw_detector/safe_media_scanner.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter NSFW Detector Demo',
      theme: ThemeData(
        colorSchemeSeed: Colors.deepPurple,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: const DemoScreen(),
    );
  }
}

class DemoScreen extends StatefulWidget {
  const DemoScreen({super.key});

  @override
  State<DemoScreen> createState() => _DemoScreenState();
}

class _DemoScreenState extends State<DemoScreen> {
  bool _initialized = false;
  String _status = 'Tap "Initialize" to start';
  ScanResult? _lastResult;

  Future<void> _initialize() async {
    setState(() => _status = 'Initializing...');
    try {
      await FlutterNsfwDetector.initialize();
      setState(() {
        _initialized = true;
        _status = 'Ready! Integrate with image_picker to scan images.';
      });
    } catch (e) {
      setState(() => _status = 'Init failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('NSFW Detector Demo'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _initialized ? Icons.check_circle : Icons.pending,
                size: 64,
                color: _initialized ? Colors.green : Colors.grey,
              ),
              const SizedBox(height: 16),
              Text(
                _status,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 24),
              if (!_initialized)
                FilledButton.icon(
                  onPressed: _initialize,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Initialize'),
                ),
              if (_lastResult != null) ...[
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Scan Result',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        for (final label in _lastResult!.labels)
                          Text(
                              '${label.category}: ${(label.confidence * 100).toStringAsFixed(1)}%'),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
