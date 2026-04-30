import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'package:movieswipe/core/network/api_client.dart';
import 'package:movieswipe/features/movies/data/datasources/movie_local_datasource.dart';
import 'package:movieswipe/features/movies/data/datasources/movie_remote_datasource.dart';
import 'package:movieswipe/features/movies/data/repositories/movie_repository_impl.dart';
import 'package:movieswipe/features/movies/domain/repositories/movie_repository.dart';
import 'package:movieswipe/features/movies/domain/usecases/get_recommended_movies.dart';
import 'package:movieswipe/features/movies/domain/usecases/swipe_movie.dart';
import 'package:movieswipe/features/movies/domain/usecases/search_movies.dart';
import 'package:movieswipe/features/movies/presentation/bloc/movies_bloc.dart';
import 'package:movieswipe/features/social/domain/repositories/social_repository.dart';
import 'package:movieswipe/features/social/data/repositories/social_repository_impl.dart';
import 'package:movieswipe/features/social/presentation/bloc/social_bloc.dart';

final sl = GetIt.instance;

/// Initialize dependency injection
Future<void> init() async {
  // Bloc
  sl.registerFactory(
    () => MoviesBloc(
      getRecommendedMovies: sl(),
      swipeMovie: sl(),
      searchMovies: sl(),
    ),
  );

  sl.registerFactory(
    () => SocialBloc(repository: sl()),
  );

  // Use cases
  sl.registerLazySingleton(() => GetRecommendedMovies(sl()));
  sl.registerLazySingleton(() => SwipeMovie(sl()));
  sl.registerLazySingleton(() => SearchMovies(sl()));

  // Repository
  sl.registerLazySingleton<MovieRepository>(
    () => MovieRepositoryImpl(
      remoteDataSource: sl(),
      localDataSource: sl(),
    ),
  );

  sl.registerLazySingleton<SocialRepository>(
    () => SocialRepositoryImpl(sl()),
  );

  // Data sources
  sl.registerLazySingleton<MovieRemoteDataSource>(
    () => MovieRemoteDataSourceImpl(apiClient: sl()),
  );
  sl.registerLazySingleton<MovieLocalDataSource>(
    () => MovieLocalDataSourceImpl(),
  );

  // Core
  sl.registerLazySingleton(() => ApiClient(client: sl()));
  sl.registerLazySingleton(() => http.Client());
}
