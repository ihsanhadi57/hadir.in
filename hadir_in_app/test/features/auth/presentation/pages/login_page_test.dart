import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mocktail/mocktail.dart';
import 'package:hadir_in_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:hadir_in_app/features/auth/presentation/bloc/auth_event.dart';
import 'package:hadir_in_app/features/auth/presentation/bloc/auth_state.dart';
import 'package:hadir_in_app/features/auth/presentation/pages/login_page.dart';

// 1. Mock the AuthBloc
class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

// 2. Mock Fake Events and States (Required for Mocktail with BLoC)
class FakeAuthEvent extends Fake implements AuthEvent {}
class FakeAuthState extends Fake implements AuthState {}

void main() {
  late MockAuthBloc mockAuthBloc;

  setUpAll(() {
    registerFallbackValue(FakeAuthEvent());
    registerFallbackValue(FakeAuthState());
  });

  setUp(() {
    mockAuthBloc = MockAuthBloc();
  });

  // Helper function to build the widget
  Widget makeTestableWidget(Widget body) {
    return BlocProvider<AuthBloc>.value(
      value: mockAuthBloc,
      child: MaterialApp(
        home: body,
      ),
    );
  }

  group('LoginPage Widget Tests', () {
    testWidgets('should render login page with all UI elements', (tester) async {
      // Arrange
      when(() => mockAuthBloc.state).thenReturn(AuthInitial());

      // Act
      await tester.pumpWidget(makeTestableWidget(const LoginPage()));

      // Assert
      expect(find.text('Masuk dulu, yuk!'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(2)); // Email and Password
      expect(find.text('Let\'s go →'), findsOneWidget);
      expect(find.text('Masuk dengan Google'), findsOneWidget);
    });

    testWidgets('should show validation error when login is pressed with empty fields', (tester) async {
      // Arrange
      when(() => mockAuthBloc.state).thenReturn(AuthInitial());

      // Act
      await tester.pumpWidget(makeTestableWidget(const LoginPage()));
      
      // Tap the login button without filling anything
      final loginButton = find.text('Let\'s go →');
      await tester.tap(loginButton);
      await tester.pump(); // trigger validation rebuild

      // Assert
      expect(find.text('Email wajib diisi'), findsOneWidget);
      expect(find.text('Password wajib diisi'), findsOneWidget);
    });

    testWidgets('should add LoginRequested event when credentials are valid', (tester) async {
      // Arrange
      when(() => mockAuthBloc.state).thenReturn(AuthInitial());

      // Act
      await tester.pumpWidget(makeTestableWidget(const LoginPage()));
      
      // Enter valid email and password
      final emailField = find.byType(TextFormField).first;
      final passwordField = find.byType(TextFormField).last;
      
      await tester.enterText(emailField, 'test@example.com');
      await tester.enterText(passwordField, 'password123');
      
      final loginButton = find.text('Let\'s go →');
      await tester.tap(loginButton);
      
      // Assert
      verify(() => mockAuthBloc.add(const LoginRequested(
        email: 'test@example.com',
        password: 'password123',
      ))).called(1);
    });
  });
}
