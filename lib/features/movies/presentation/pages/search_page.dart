import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:movieswipe/features/movies/domain/entities/movie.dart';
import 'package:movieswipe/features/movies/presentation/bloc/movies_bloc.dart';
import 'package:movieswipe/features/movies/presentation/bloc/movies_event.dart';
import 'package:movieswipe/features/movies/presentation/bloc/movies_state.dart';
import 'package:provider/provider.dart';
import 'package:movieswipe/core/providers/auth_provider.dart';
import 'dart:async';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  List<Movie> _searchResults = [];

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (query.isNotEmpty) {
        context.read<MoviesBloc>().add(SearchMoviesEvent(query));
      } else {
        setState(() {
          _searchResults = [];
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final currentUserId = authProvider.currentUserId;

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          onChanged: _onSearchChanged,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Search movies...',
            hintStyle: TextStyle(color: Colors.white70),
            border: InputBorder.none,
          ),
          autofocus: true,
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF6366F1), Color(0xFFEC4899)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: BlocListener<MoviesBloc, MoviesState>(
        listener: (context, state) {
          if (state is MoviesSearchLoaded) {
            setState(() {
              _searchResults = state.movies;
            });
          } else if (state is MoviesError) {
             ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          }
        },
        child: _searchResults.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.search, size: 80, color: Colors.grey[300]),
                    const SizedBox(height: 16),
                    Text(
                      'Search for movies to add to your list',
                      style: TextStyle(color: Colors.grey[500], fontSize: 16),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final movie = _searchResults[index];
                  return _buildMovieListItem(movie, currentUserId);
                },
              ),
      ),
    );
  }

  Widget _buildMovieListItem(Movie movie, String? userId) {
    final posterUrl = movie.posterPath != null
        ? 'https://image.tmdb.org/t/p/w200${movie.posterPath}'
        : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(8),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: posterUrl != null
              ? Image.network(
                  posterUrl,
                  width: 50,
                  height: 75,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      Container(color: Colors.grey[300], width: 50, height: 75),
                )
              : Container(
                  color: Colors.grey[300],
                  width: 50,
                  height: 75,
                  child: const Icon(Icons.movie),
                ),
        ),
        title: Text(
          movie.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('Release: ${movie.releaseDate ?? "Unknown"}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.thumb_down_outlined, color: Colors.red),
              onPressed: () {
                if (userId != null) {
                  context.read<MoviesBloc>().add(
                    SwipeMovieEvent(
                      movieId: movie.id,
                      isLike: false,
                      userId: userId,
                    ),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Passed on ${movie.name}')),
                  );
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.favorite_border, color: Colors.green),
              onPressed: () {
                if (userId != null) {
                  context.read<MoviesBloc>().add(
                    SwipeMovieEvent(
                      movieId: movie.id,
                      isLike: true,
                      userId: userId,
                    ),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Liked ${movie.name}')),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
