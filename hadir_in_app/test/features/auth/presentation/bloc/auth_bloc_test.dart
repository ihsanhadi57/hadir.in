import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:hadir_in_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:hadir_in_app/features/auth/presentation/bloc/auth_event.dart';
import 'package:hadir_in_app/features/auth/presentation/bloc/auth_state.dart';
import 'package:hadir_in_app/features/auth/data/repositories/auth_repository.dart';
import 'package:hadir_in_app/features/auth/data/models/user_model.dart';

// 1. Create a Mock class for the Repository using Mocktail
class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late AuthBloc authBloc;
  late MockAuthRepository mockAuthRepository;

  // Setup runs before each test
  setUp(() {
    mockAuthRepository = MockAuthRepository();
    authBloc = AuthBloc(authRepository: mockAuthRepository);
  });

  // TearDown runs after each test
  tearDown(() {
    authBloc.close();
  });

  // Dummy user data for testing
  final tUser = const UserModel(
    id: '1',
    name: 'Test User',
    email: 'test@example.com',
    role: 'user',
    emailQuota: 50,
    totalEmailsSent: 0,
  );

  group('AuthBloc Tests', () {
    test('initial state is AuthInitial', () {
      expect(authBloc.state, equals(AuthInitial()));
    });

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthLoginSuccess] when LoginRequested succeeds',
      build: () {
        // Arrange: configure the mock to return a successful response
        when(() => mockAuthRepository.login('test@example.com', 'password123'))
            .thenAnswer((_) async => tUser);
        return authBloc;
      },
      act: (bloc) => bloc.add(const LoginRequested(email: 'test@example.com', password: 'password123')),
      expect: () => [
        AuthLoading(),
        AuthLoginSuccess(user: tUser),
      ],
      verify: (_) {
        // Verify that the repository method was called exactly once
        verify(() => mockAuthRepository.login('test@example.com', 'password123')).called(1);
      },
    );

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthFailure] when LoginRequested fails',
      build: () {
        // Arrange: configure the mock to throw an exception
        when(() => mockAuthRepository.login('test@example.com', 'wrongpassword'))
            .thenThrow(Exception('Invalid credentials'));
        return authBloc;
      },
      act: (bloc) => bloc.add(const LoginRequested(email: 'test@example.com', password: 'wrongpassword')),
      expect: () => [
        AuthLoading(),
        const AuthFailure(message: 'Invalid credentials'),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthLoggedOut] when LogoutRequested is called',
      build: () {
        when(() => mockAuthRepository.logout()).thenAnswer((_) async => {});
        return authBloc;
      },
      act: (bloc) => bloc.add(LogoutRequested()),
      expect: () => [
        AuthLoading(),
        AuthLoggedOut(),
      ],
    );
  });
}
