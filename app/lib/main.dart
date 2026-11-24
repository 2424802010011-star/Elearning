import 'package:material_ui/material_ui.dart';

import 'app_state.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';

void main() {
  final state = AppState()..restore();
  runApp(AppScope(state: state, child: const EduBoardApp()));
}

class EduBoardApp extends StatelessWidget {
  const EduBoardApp({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return MaterialApp(
      title: 'EduBoard',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: const Color(0xFF1F4E79), useMaterial3: true),
      darkTheme: ThemeData(colorSchemeSeed: const Color(0xFF1F4E79), brightness: Brightness.dark, useMaterial3: true),
      home: !app.ready
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : (app.user == null ? const LoginScreen() : const HomeScreen()),
    );
  }
}
