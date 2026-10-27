import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synco/engine/download_engine.dart';
import 'package:synco/main.dart';
import 'package:synco/services/app_updater_service.dart';

void main() {
  testWidgets('SyncoApp smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider(prefs)),
          ChangeNotifierProvider(create: (_) => DownloadEngine()),
          ChangeNotifierProvider(create: (_) => AppUpdaterService()),
        ],
        child: const SyncoApp(),
      ),
    );

    // Verify Synco header title and top mode switchers appear
    expect(find.text('Synco'), findsOneWidget);
    expect(find.text('Videos'), findsOneWidget);
    expect(find.text('Music / MP3'), findsOneWidget);
  });
}
