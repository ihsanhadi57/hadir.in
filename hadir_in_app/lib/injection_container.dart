import 'package:get_it/get_it.dart';
import 'core/network/dio_client.dart';
import 'core/network/secure_storage_service.dart';
import 'features/auth/data/repositories/auth_repository.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/event/data/repositories/event_repository.dart';
import 'features/event/data/repositories/payment_repository.dart';

final sl = GetIt.instance;

Future<void> init() async {
  // ─── Features: Auth ───
  sl.registerFactory(() => AuthBloc(authRepository: sl()));
  sl.registerLazySingleton(
    () => AuthRepository(dioClient: sl(), storageService: sl()),
  );

  // ─── Features: Event ───
  sl.registerLazySingleton(() => EventRepository(dioClient: sl()));
  sl.registerLazySingleton(() => PaymentRepository(sl()));

  // ─── Core ───
  sl.registerLazySingleton(() => DioClient());
  sl.registerLazySingleton(() => SecureStorageService());
}
