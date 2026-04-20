import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:app_links/app_links.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'core/network/dio_client.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/bloc/auth_event.dart';
import 'features/auth/presentation/pages/splash_page.dart';
import 'features/home/presentation/pages/join_event_page.dart';
import 'features/home/presentation/pages/self_checkin_page.dart';
import 'injection_container.dart' as di;
import 'package:intl/date_symbol_data_local.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inisialisasi Dependency Injection
  await di.init();

  // Inisialisasi format tanggal (inti)
  await initializeDateFormatting('id', null);

  // Status bar icons gelap untuk background terang
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const HadirInApp());
}

class HadirInApp extends StatelessWidget {
  const HadirInApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>(
          create: (ctx) {
            final bloc = GetIt.instance<AuthBloc>();

            // ─── Wire 401 auto-logout ke AuthBloc ───
            // Saat DioClient menerima 401, langsung trigger LogoutRequested
            GetIt.instance<DioClient>().onUnauthorized = () {
              if (!bloc.isClosed) {
                bloc.add(LogoutRequested());
              }
            };

            return bloc;
          },
        ),
      ],
      child: HadirInAppContent(),
    );
  }
}

class HadirInAppContent extends StatefulWidget {
  const HadirInAppContent({super.key});

  @override
  State<HadirInAppContent> createState() => _HadirInAppContentState();
}

class _HadirInAppContentState extends State<HadirInAppContent> {
  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  void _initDeepLinks() async {
    _appLinks = AppLinks();

    // 1. Handle initial link (when app is cold-started)
    final initialUri = await _appLinks.getInitialLink();
    if (initialUri != null) {
      _handleUri(initialUri);
    }

    // 2. Handle incoming links (when app is already running)
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _handleUri(uri);
    });
  }

  void _handleUri(Uri uri) {
    if (uri.scheme == 'hadirin' && uri.host == 'invite') {
      final code = uri.queryParameters['code'];
      if (code != null) {
        // Navigate to JoinEventPage
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => JoinEventPage(inviteCode: code),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'hadir.in',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const SplashPage(),
      onGenerateRoute: (settings) {
        if (settings.name != null && settings.name!.startsWith('/attend/')) {
          final parts = settings.name!.split('/');
          if (parts.length == 3) {
            final eventId = parts[2];
            return MaterialPageRoute(
              builder: (context) => SelfCheckInPage(eventId: eventId),
            );
          }
        }
        return null; // Let flutter fallback to default
      },
    );
  }
}
