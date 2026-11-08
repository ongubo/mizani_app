import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/api_client.dart';
import 'data/client_repository.dart';
import 'data/session.dart';
import 'data/session_store.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/splash_screen.dart';
import 'theme/mizani_theme.dart';

void main() {
  final api = ApiClient();
  runApp(
    MizaniApp(
      session: SessionController(
        api: api,
        repository: ApiClientRepository(api),
        store: SessionStore(),
      ),
    ),
  );
}

class MizaniApp extends StatefulWidget {
  const MizaniApp({super.key, required this.session});

  final SessionController session;

  @override
  State<MizaniApp> createState() => _MizaniAppState();
}

class _MizaniAppState extends State<MizaniApp> {
  final _navigator = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    widget.session.onSignedOut = () {
      _navigator.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    };
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: widget.session,
      child: MaterialApp(
        title: 'Mizani',
        navigatorKey: _navigator,
        debugShowCheckedModeBanner: false,
        theme: buildMizaniTheme(),
        home: const SplashScreen(),
      ),
    );
  }
}
