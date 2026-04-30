import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:movieswipe/core/providers/liked_movies_provider.dart';
import 'package:movieswipe/core/providers/collections_provider.dart';
import 'package:movieswipe/features/movies/domain/entities/movie.dart';
import 'package:movieswipe/features/movies/presentation/bloc/movies_bloc.dart';
import 'package:movieswipe/features/movies/presentation/pages/movie_detail_page.dart';
import 'package:movieswipe/features/movies/presentation/pages/collection_detail_page.dart';
import 'package:movieswipe/features/movies/presentation/widgets/dice_roll_animation.dart';
import 'dart:math' as math;

/// My List page with two tabs: Liked Movies & Collections
class MyListPage extends StatefulWidget {
  const MyListPage({super.key});

  @override
  State<MyListPage> createState() => _MyListPageState();
}

class _MyListPageState extends State<MyListPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<CollectionsProvider>();
      if (!provider.isLoaded) provider.loadCollections();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: const LinearGradient(
                    colors: [Color(0xFFEC4899), Color(0xFF8B5CF6)],
                  ),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white60,
                labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                unselectedLabelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                tabs: const [
                  Tab(text: '❤️ Beğenilenler'),
                  Tab(text: '📁 Koleksiyonlarım'),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _LikedMoviesTab(),
              _CollectionsTab(),
            ],
          ),
        ),
      ],
    );
  }
}

class _LikedMoviesTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<LikedMoviesProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading && !provider.isLoaded) {
          return const Center(child: CircularProgressIndicator(color: Colors.white));
        }
        if (provider.moviesByGenre.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.favorite_border, size: 100, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text('Henüz beğenilen film yok!',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.grey[600])),
                const SizedBox(height: 8),
                Text('Kaydırmaya başla ve koleksiyonunu oluştur',
                    style: TextStyle(color: Colors.grey[500])),
              ],
            ),
          );
        }
        return _MyListContent();
      },
    );
  }
}

class _CollectionsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<CollectionsProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading && !provider.isLoaded) {
          return const Center(child: CircularProgressIndicator(color: Colors.white));
        }
        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: GestureDetector(
                  onTap: () => _showCreateCollectionDialog(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(colors: [
                        const Color(0xFFEC4899).withValues(alpha: 0.3),
                        const Color(0xFF8B5CF6).withValues(alpha: 0.3),
                      ]),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_rounded, color: Colors.white, size: 28),
                        SizedBox(width: 8),
                        Text('Yeni Koleksiyon Oluştur',
                            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (provider.collections.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.folder_open_rounded, size: 80, color: Colors.grey[500]),
                      const SizedBox(height: 16),
                      Text('Henüz koleksiyonun yok',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey[500])),
                      const SizedBox(height: 8),
                      Text('"Hafta Sonu Maratonu" veya "Klasikler"\ngibi listeler oluştur!',
                          textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600])),
                    ],
                  ),
                ),
              ),
            if (provider.collections.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, childAspectRatio: 0.75, crossAxisSpacing: 12, mainAxisSpacing: 12),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _CollectionCard(collection: provider.collections[index]),
                    childCount: provider.collections.length,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  void _showCreateCollectionDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: const Color(0xFF1a1a2e),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          const Text('Yeni Koleksiyon', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          TextField(controller: nameCtrl, autofocus: true, style: const TextStyle(color: Colors.white),
              cursorColor: const Color(0xFFEC4899),
              decoration: InputDecoration(hintText: 'Koleksiyon adı (örn: "Hafta Sonu Filmleri")',
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)), filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.1),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFEC4899))))),
          const SizedBox(height: 12),
          TextField(controller: descCtrl, style: const TextStyle(color: Colors.white),
              cursorColor: const Color(0xFFEC4899), maxLines: 2,
              decoration: InputDecoration(hintText: 'Açıklama (isteğe bağlı)',
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)), filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.1),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFEC4899))))),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                final desc = descCtrl.text.trim();
                final provider = context.read<CollectionsProvider>();
                final result = await provider.createCollection(name: name, description: desc.isNotEmpty ? desc : null);
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  if (result != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('📁 "$name" koleksiyonu oluşturuldu!'), backgroundColor: const Color(0xFF4CAF50)));
                  }
                }
              },
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: const Color(0xFFEC4899), foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text('Oluştur', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ]),
      ),
    );
  }
}

class _CollectionCard extends StatelessWidget {
  final CollectionSummary collection;
  const _CollectionCard({required this.collection});

  @override
  Widget build(BuildContext context) {
    final posterUrl = collection.coverPosterPath != null
        ? 'https://image.tmdb.org/t/p/w500${collection.coverPosterPath}' : null;
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => BlocProvider.value(value: context.read<MoviesBloc>(),
              child: CollectionDetailPage(collectionId: collection.id, collectionName: collection.name)))),
      onLongPress: () => _showCollectionOptions(context),
      child: Container(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 6))]),
        child: ClipRRect(borderRadius: BorderRadius.circular(16),
          child: Stack(fit: StackFit.expand, children: [
            if (posterUrl != null)
              CachedNetworkImage(imageUrl: posterUrl, fit: BoxFit.cover,
                  placeholder: (_, __) => _gradientPlaceholder(), errorWidget: (_, __, ___) => _gradientPlaceholder())
            else _gradientPlaceholder(),
            Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black.withValues(alpha: 0.8)], stops: const [0.4, 1.0]))),
            Positioned(bottom: 12, left: 12, right: 12,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(collection.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold,
                        shadows: [Shadow(color: Colors.black45, offset: Offset(0, 1), blurRadius: 3)])),
                const SizedBox(height: 4),
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                    child: Text('${collection.movieCount} film',
                        style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500))),
              ])),
            if (collection.isPublic)
              Positioned(top: 8, right: 8,
                child: Container(padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.public, color: Colors.white60, size: 16))),
          ])),
      ),
    );
  }

  Widget _gradientPlaceholder() => Container(
      decoration: const BoxDecoration(gradient: LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFFEC4899)], begin: Alignment.topLeft, end: Alignment.bottomRight)),
      child: const Center(child: Icon(Icons.folder_rounded, size: 48, color: Colors.white54)));

  void _showCollectionOptions(BuildContext context) {
    showModalBottomSheet(context: context, backgroundColor: const Color(0xFF1a1a2e),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Text(collection.name, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ListTile(leading: const Icon(Icons.edit, color: Colors.white70),
              title: const Text('Düzenle', style: TextStyle(color: Colors.white)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onTap: () { Navigator.pop(ctx); _showEditDialog(context); }),
          ListTile(leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
              title: const Text('Sil', style: TextStyle(color: Colors.redAccent)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onTap: () async {
                Navigator.pop(ctx);
                final confirmed = await showDialog<bool>(context: context,
                    builder: (dCtx) => AlertDialog(backgroundColor: const Color(0xFF1a1a2e),
                        title: const Text('Koleksiyonu Sil', style: TextStyle(color: Colors.white)),
                        content: Text('"${collection.name}" koleksiyonunu silmek istediğine emin misin?',
                            style: const TextStyle(color: Colors.white70)),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('İptal')),
                          TextButton(onPressed: () => Navigator.pop(dCtx, true),
                              style: TextButton.styleFrom(foregroundColor: Colors.redAccent), child: const Text('Sil')),
                        ]));
                if (confirmed == true && context.mounted) {
                  context.read<CollectionsProvider>().deleteCollection(collection.id);
                }
              }),
        ])));
  }

  void _showEditDialog(BuildContext context) {
    final nameCtrl = TextEditingController(text: collection.name);
    final descCtrl = TextEditingController(text: collection.description ?? '');
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: const Color(0xFF1a1a2e),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          const Text('Koleksiyonu Düzenle', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          TextField(controller: nameCtrl, autofocus: true, style: const TextStyle(color: Colors.white),
              cursorColor: const Color(0xFFEC4899),
              decoration: InputDecoration(hintText: 'Koleksiyon adı',
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)), filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.1),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFEC4899))))),
          const SizedBox(height: 12),
          TextField(controller: descCtrl, style: const TextStyle(color: Colors.white),
              cursorColor: const Color(0xFFEC4899), maxLines: 2,
              decoration: InputDecoration(hintText: 'Açıklama (isteğe bağlı)',
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)), filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.1),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFEC4899))))),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                final desc = descCtrl.text.trim();
                await context.read<CollectionsProvider>().updateCollection(collection.id,
                    name: name, description: desc.isNotEmpty ? desc : null);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: const Color(0xFFEC4899), foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text('Kaydet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ]),
      ),
    );
  }
}



/// Stateful content widget for genre filtering
class _MyListContent extends StatefulWidget {
  const _MyListContent();

  @override
  State<_MyListContent> createState() => _MyListContentState();
}

class _MyListContentState extends State<_MyListContent> {
  String? _selectedGenre;
  String _searchQuery = '';
  bool _isCategoryOpen = false;
  bool _isRollingDice = false;
  Map<String, dynamic>? _selectedRandomMovie;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Map<String, List<Map<String, dynamic>>> _getFilteredMovies(LikedMoviesProvider provider) {
    // Start with genre filter and apply active sort logic from provider
    Map<String, List<Map<String, dynamic>>> result = {};
    if (_selectedGenre == null) {
      for (final genre in provider.moviesByGenre.keys) {
        // Limit each genre row to max 10 items when viewing "All"
        result[genre] = provider.getSortedMoviesByGenre(genre).take(10).toList();
      }
    } else {
      result[_selectedGenre!] = provider.getSortedMoviesByGenre(_selectedGenre);
    }

    // Apply search filter on top
    if (_searchQuery.isEmpty) {
      return result;
    }

    final query = _searchQuery.toLowerCase();
    final filtered = <String, List<Map<String, dynamic>>>{};
    for (final entry in result.entries) {
      final matchingMovies = entry.value
          .where((m) => (m['name'] as String? ?? '').toLowerCase().contains(query))
          .toList();
      if (matchingMovies.isNotEmpty) {
        filtered[entry.key] = matchingMovies;
      }
    }
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LikedMoviesProvider>();
    final filteredMoviesMap = _getFilteredMovies(provider);

    final scaffold = Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
          slivers: [
            SliverAppBar(
              floating: true,
              pinned: true,
              expandedHeight: 120,
              backgroundColor: Colors.transparent,
              actions: [
                IconButton(
                  onPressed: () {
                    final provider = context.read<LikedMoviesProvider>();
                    // Collect all liked movies, deduplicating by ID
                    final seenIds = <int>{};
                    final allMovies = <Map<String, dynamic>>[];
                    for (final movies in provider.moviesByGenre.values) {
                      for (final movie in movies) {
                        final id = movie['id'] as int;
                        if (seenIds.add(id)) {
                          allMovies.add(movie);
                        }
                      }
                    }

                    if (allMovies.isNotEmpty) {
                      final random = math.Random().nextInt(allMovies.length);
                      setState(() {
                        _selectedRandomMovie = allMovies[random];
                        _isRollingDice = true;
                      });
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Hiç beğenilen film bulunamadı!'),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.casino, color: Colors.amber, size: 28),
                  tooltip: 'Şansına bir film seç!',
                ),
                PopupMenuButton<SortCriteria>(
                  icon: const Icon(Icons.sort, color: Colors.white),
                  onSelected: (criteria) => provider.setSortCriteria(criteria),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: SortCriteria.recentlyAdded,
                      child: Text('En Son Eklenenler'),
                    ),
                    const PopupMenuItem(
                      value: SortCriteria.highestRated,
                      child: Text('En Yüksek Puanlılar'),
                    ),
                    const PopupMenuItem(
                      value: SortCriteria.alphabetical,
                      child: Text('A-Z'),
                    ),
                    const PopupMenuItem(
                      value: SortCriteria.releaseDate,
                      child: Text('Çıkış Tarihi'),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
              ],
              flexibleSpace: FlexibleSpaceBar(
                title: const Text(
                  'My List',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                centerTitle: false,
                titlePadding: const EdgeInsets.only(left: 24, bottom: 16),
              ),
            ),

            // Search Bar
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                  style: const TextStyle(color: Colors.white),
                  cursorColor: Colors.white,
                  decoration: InputDecoration(
                    hintText: 'Search your movies...',
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                    prefixIcon: Icon(Icons.search, color: Colors.white.withValues(alpha: 0.7)),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear, color: Colors.white.withValues(alpha: 0.7)),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.15),
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Colors.white, width: 1.5),
                    ),
                  ),
                ),
              ),
            ),
            
            // Recently Added Band
            if (_selectedGenre == null && _searchQuery.isEmpty && provider.recentlyAddedAll.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: _buildGenreSection(
                    'Son Eklenenler',
                    provider.recentlyAddedAll.take(10).toList(),
                  ),
                ),
              ),

            // Category Toggle Bar
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Column(
                  children: [
                    // Toggle Button — compact Netflix-style pill
                    Align(
                      alignment: Alignment.centerLeft,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _isCategoryOpen = !_isCategoryOpen;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _isCategoryOpen
                                  ? Colors.white.withValues(alpha: 0.5)
                                  : Colors.white.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _selectedGenre ?? 'Categories',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 4),
                              AnimatedRotation(
                                turns: _isCategoryOpen ? 0.5 : 0.0,
                                duration: const Duration(milliseconds: 200),
                                child: Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: Colors.white.withValues(alpha: 0.8),
                                  size: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Expandable Genre Panel
                    AnimatedCrossFade(
                      firstChild: const SizedBox.shrink(),
                      secondChild: Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.15),
                          ),
                        ),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildGenreChip('All', null, provider),
                            ...provider.moviesByGenre.keys.map(
                              (genre) => _buildGenreChip(genre, genre, provider),
                            ),
                          ],
                        ),
                      ),
                      crossFadeState: _isCategoryOpen
                          ? CrossFadeState.showSecond
                          : CrossFadeState.showFirst,
                      duration: const Duration(milliseconds: 250),
                      sizeCurve: Curves.easeInOut,
                    ),
                  ],
                ),
              ),
            ),
            
            // Movie List
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final genre = filteredMoviesMap.keys.elementAt(index);
                    final movies = filteredMoviesMap[genre]!;
                    
                    return _buildGenreSection(genre, movies);
                  },
                  childCount: filteredMoviesMap.length,
                ),
              ),
            ),
          ],
        ),
    );

    return Stack(
      children: [
        scaffold,
        if (_isRollingDice && _selectedRandomMovie != null)
          Container(
            color: Colors.black.withValues(alpha: 0.7),
            child: Center(
              child: DiceRollAnimation(
                onComplete: () {
                  final movie = _selectedRandomMovie!;
                  final movieEntity = Movie(
                    id: movie['id'],
                    name: movie['name'],
                    genre: movie['genre'] ?? 'General',
                    posterPath: movie['poster_path'],
                    voteAverage: (movie['vote_average'] as num?)?.toDouble(),
                    userRating: movie['user_rating'] as int?,
                  );

                  setState(() {
                    _isRollingDice = false;
                    _selectedRandomMovie = null;
                  });

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BlocProvider.value(
                        value: context.read<MoviesBloc>(),
                        child: MovieDetailPage(movie: movieEntity),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildGenreChip(String label, String? genreValue, LikedMoviesProvider provider) {
    final isSelected = _selectedGenre == genreValue;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedGenre = genreValue;
          _isCategoryOpen = false; // collapse after selection
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFEC4899)
              : Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? Colors.white.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenreSection(String genre, List<dynamic> movies) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 28,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFEC4899), Color(0xFF8B5CF6)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFEC4899).withValues(alpha: 0.5),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                genre,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      color: Colors.black26,
                      offset: Offset(0, 2),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  '${movies.length}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF6366F1),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 240,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            itemCount: movies.length,
            itemBuilder: (context, index) {
              final movie = movies[index];
              return _buildMovieCard(movie, index);
            },
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildMovieCard(dynamic movie, int index) {
    final posterPath = movie['poster_path'] as String?;
    final movieName = movie['name'] as String;
    final movieId = movie['id'] as int;
    final watchStatus = movie['watch_status'] as String?;
    final posterUrl = posterPath != null 
        ? 'https://image.tmdb.org/t/p/w500$posterPath'
        : null;

    return AnimatedOpacity(
      opacity: 1.0,
      duration: Duration(milliseconds: 300 + (index * 50)),
      child: GestureDetector(
        onTap: () {
          final movieEntity = Movie(
            id: movie['id'],
            name: movie['name'],
            genre: movie['genre'] ?? 'General',
            posterPath: movie['poster_path'],
            voteAverage: (movie['vote_average'] as num?)?.toDouble(),
            userRating: movie['user_rating'] as int?,
          );
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BlocProvider.value(
                  value: context.read<MoviesBloc>(),
                  child: MovieDetailPage(movie: movieEntity),
                ),
              ),
            );
        },
        onLongPress: () => _showWatchStatusSheet(context, movieId, watchStatus),
        child: Container(
          width: 150,
          margin: const EdgeInsets.only(right: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  // Poster
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: posterUrl != null
                        ? CachedNetworkImage(
                            imageUrl: posterUrl,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            placeholder: (context, url) => Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xFF6366F1).withValues(alpha: 0.3),
                                    const Color(0xFFEC4899).withValues(alpha: 0.3)
                                  ],
                                ),
                              ),
                              child: const Center(
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Color(0xFF6366F1), Color(0xFFEC4899)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: const Icon(Icons.movie,
                                  size: 50, color: Colors.white),
                            ),
                          )
                        : Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFF6366F1), Color(0xFFEC4899)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: const Icon(Icons.movie, size: 50, color: Colors.white),
                          ),
                  ),
                  // Watch status chip
                  if (watchStatus != null)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: _watchStatusMeta(watchStatus)['color'] as Color,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.4),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _watchStatusMeta(watchStatus)['emoji'] as String,
                              style: const TextStyle(fontSize: 10),
                            ),
                            const SizedBox(width: 2),
                            Text(
                              _watchStatusMeta(watchStatus)['short'] as String,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                movieName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      color: Colors.black45,
                      offset: Offset(0, 1),
                      blurRadius: 2,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  void _showWatchStatusSheet(BuildContext context, int movieId, String? currentStatus) {
    final statuses = [
      {'key': 'watched', 'emoji': '✅', 'label': 'İzledim', 'color': const Color(0xFF4CAF50)},
      {'key': 'watch_later', 'emoji': '⏰', 'label': 'Sonra İzle', 'color': const Color(0xFF42A5F5)},
      {'key': 'favorite', 'emoji': '⭐', 'label': 'Favori', 'color': const Color(0xFFFFB300)},
      {'key': 'dropped', 'emoji': '🚫', 'label': 'Bıraktım', 'color': const Color(0xFFEF5350)},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1a1a2e),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'İzleme Durumu',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...statuses.map((s) {
              final isActive = currentStatus == s['key'];
              return ListTile(
                leading: Text(s['emoji'] as String, style: const TextStyle(fontSize: 22)),
                title: Text(
                  s['label'] as String,
                  style: TextStyle(
                    color: isActive ? (s['color'] as Color) : Colors.white,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                trailing: isActive
                    ? Icon(Icons.check_circle, color: s['color'] as Color, size: 22)
                    : null,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                tileColor: isActive
                    ? (s['color'] as Color).withValues(alpha: 0.15)
                    : Colors.transparent,
                onTap: () {
                  final newStatus = isActive ? null : s['key'] as String;
                  context.read<LikedMoviesProvider>().updateWatchStatus(movieId, newStatus);
                  Navigator.pop(ctx);
                },
              );
            }),
            if (currentStatus != null) ...[
              const Divider(color: Colors.white12),
              ListTile(
                leading: const Icon(Icons.close, color: Colors.white38),
                title: const Text(
                  'Durumu Kaldır',
                  style: TextStyle(color: Colors.white38),
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onTap: () {
                  context.read<LikedMoviesProvider>().updateWatchStatus(movieId, null);
                  Navigator.pop(ctx);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Map<String, dynamic> _watchStatusMeta(String status) {
    switch (status) {
      case 'watched':
        return {'emoji': '✅', 'short': 'İzledim', 'color': const Color(0xFF4CAF50)};
      case 'watch_later':
        return {'emoji': '⏰', 'short': 'Sonra', 'color': const Color(0xFF42A5F5)};
      case 'favorite':
        return {'emoji': '⭐', 'short': 'Favori', 'color': const Color(0xFFFFB300)};
      case 'dropped':
        return {'emoji': '🚫', 'short': 'Bıraktım', 'color': const Color(0xFFEF5350)};
      default:
        return {'emoji': '', 'short': '', 'color': Colors.transparent};
    }
  }
}

