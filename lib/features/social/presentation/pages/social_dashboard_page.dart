import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/social_bloc.dart';
import '../bloc/social_event.dart';
import '../bloc/social_state.dart';
import '../../domain/entities/social_entities.dart';
import 'friend_profile_page.dart';

class SocialDashboardPage extends StatefulWidget {
  const SocialDashboardPage({super.key});

  @override
  State<SocialDashboardPage> createState() => _SocialDashboardPageState();
}

class _SocialDashboardPageState extends State<SocialDashboardPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  int _currentTab = 0;
  List<FriendEntity>? _cachedFriends;
  List<FriendRequestEntity>? _cachedRequests;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index != _currentTab) {
        setState(() => _currentTab = _tabController.index);
        if (_tabController.index == 0 && _cachedFriends == null) {
          _loadTabData(0);
        } else if (_tabController.index == 1 && _cachedRequests == null) {
          _loadTabData(1);
        }
      }
    });
    // Initial load
    context.read<SocialBloc>().add(LoadFriendsEvent());
  }

  void _loadTabData(int index) {
    if (index == 0) {
      context.read<SocialBloc>().add(LoadFriendsEvent());
    } else {
      context.read<SocialBloc>().add(LoadIncomingRequestsEvent());
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            _buildTabBar(),
            Expanded(
              child: BlocListener<SocialBloc, SocialState>(
                listener: (context, state) {
                  if (state is SocialSuccess) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(state.message),
                        backgroundColor: Colors.green,
                        behavior: SnackBarBehavior.fixed,
                      ),
                    );
                    // Clear caches to force reload
                    setState(() {
                      _cachedFriends = null;
                      _cachedRequests = null;
                    });
                    _loadTabData(_currentTab);
                  } else if (state is SocialError) {
                    final isInfo = state.message.contains('Kendi kendine');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(state.message),
                        backgroundColor: isInfo ? Colors.blue : const Color(0xFFE94560),
                        behavior: SnackBarBehavior.fixed,
                      ),
                    );
                  }
                },

                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildFriendsTab(),
                    _buildRequestsTab(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 16, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Social',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          Row(
            children: [
              IconButton(
                onPressed: () => _showSearchSheet(context),
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.search_rounded,
                      color: Colors.white, size: 20),
                ),
              ),
              IconButton(
                onPressed: () => _showAddFriendDialog(context),
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE94560).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.person_add_rounded,
                      color: Color(0xFFE94560), size: 20),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorColor: const Color(0xFFE94560),
              indicatorWeight: 3,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white54,
              labelStyle: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 14),
              tabs: const [
                Tab(text: 'Arkadaşlar'),
                Tab(text: 'İstekler'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFriendsTab() {
    return BlocBuilder<SocialBloc, SocialState>(
      buildWhen: (prev, current) =>
          current is FriendsLoaded || current is SocialLoading || current is SocialError,
      builder: (context, state) {
        if (state is FriendsLoaded) _cachedFriends = state.friends;
        
        final friends = _cachedFriends;
        if (friends == null) {
          if (state is SocialError) {
             return Center(child: Text(state.message, style: const TextStyle(color: Colors.white)));
          }
          return const Center(child: CircularProgressIndicator(color: Color(0xFFE94560)));
        }

        return RefreshIndicator(
          onRefresh: () async {
            context.read<SocialBloc>().add(LoadFriendsEvent());
            await Future.delayed(const Duration(seconds: 1));
          },
          color: const Color(0xFFE94560),
          backgroundColor: const Color(0xFF1a1a2e),
          child: friends.isEmpty
              ? Stack(
                  children: [
                    ListView(), // Scrollable view required for RefreshIndicator
                    _buildEmptyState(
                      icon: Icons.group_outlined,
                      title: 'Henüz arkadaşın yok',
                      subtitle: 'Sağ üstteki + butonuyla arkadaş ekle!',
                    ),
                  ],
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: friends.length,
                  itemBuilder: (context, index) =>
                      _buildFriendTile(context, friends[index]),
                ),
        );
      },
    );
  }

  Widget _buildRequestsTab() {
    return BlocBuilder<SocialBloc, SocialState>(
      buildWhen: (prev, current) =>
          current is IncomingRequestsLoaded || current is SocialLoading || current is SocialError,
      builder: (context, state) {
        if (state is IncomingRequestsLoaded) _cachedRequests = state.requests;
        
        final requests = _cachedRequests;
        if (requests == null) {
          if (state is SocialError) {
             return Center(child: Text(state.message, style: const TextStyle(color: Colors.white)));
          }
          return const Center(child: CircularProgressIndicator(color: Color(0xFFE94560)));
        }

        return RefreshIndicator(
          onRefresh: () async {
            context.read<SocialBloc>().add(LoadIncomingRequestsEvent());
            await Future.delayed(const Duration(seconds: 1));
          },
          color: const Color(0xFFE94560),
          backgroundColor: const Color(0xFF1a1a2e),
          child: requests.isEmpty
              ? Stack(
                  children: [
                    ListView(), // Scrollable view required for RefreshIndicator
                    _buildEmptyState(
                      icon: Icons.mail_outline,
                      title: 'Bekleyen istek yok',
                      subtitle: 'Yeni istekler burada görünecek.',
                    ),
                  ],
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: requests.length,
                  itemBuilder: (context, index) =>
                      _buildRequestTile(context, requests[index]),
                ),
        );
      },
    );
  }

  Widget _buildFriendTile(BuildContext context, FriendEntity friend) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: _buildAvatar(friend),
              title: Text(
                friend.displayName ?? friend.username,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                '@${friend.username}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 13,
                ),
              ),
              trailing: Icon(Icons.chevron_right_rounded,
                  color: Colors.white.withValues(alpha: 0.3)),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BlocProvider.value(
                      value: context.read<SocialBloc>(),
                      child: FriendProfilePage(friendId: friend.id),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRequestTile(BuildContext context, FriendRequestEntity request) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: _buildAvatar(request.sender),
              title: Text(
                request.sender.displayName ?? request.sender.username,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                'Arkadaşlık isteği gönderdi',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 13,
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildActionButton(
                    icon: Icons.check_rounded,
                    color: const Color(0xFF27AE60),
                    onTap: () => context
                        .read<SocialBloc>()
                        .add(AcceptRequestEvent(request.id)),
                  ),
                  const SizedBox(width: 8),
                  _buildActionButton(
                    icon: Icons.close_rounded,
                    color: const Color(0xFFE94560),
                    onTap: () => context
                        .read<SocialBloc>()
                        .add(RejectRequestEvent(request.id)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(FriendEntity friend) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: const Color(0xFFE94560).withValues(alpha: 0.3),
          width: 2,
        ),
        color: Colors.white.withValues(alpha: 0.05),
        image: (friend.avatarUrl != null &&
                friend.avatarUrl!.startsWith('http'))
            ? DecorationImage(
                image: NetworkImage(friend.avatarUrl!),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: Center(
        child: friend.avatarUrl == null
            ? const Icon(Icons.person, color: Colors.white54, size: 24)
            : (!friend.avatarUrl!.startsWith('http')
                ? Text(friend.avatarUrl!,
                    style: const TextStyle(fontSize: 22))
                : null),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          shape: BoxShape.circle,
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: Colors.white.withValues(alpha: 0.15)),
          const SizedBox(height: 16),
          Text(title,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(subtitle,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5), fontSize: 14)),
        ],
      ),
    );
  }

  void _showAddFriendDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AlertDialog(
          backgroundColor: const Color(0xFF1a1a2e).withValues(alpha: 0.95),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('Arkadaş Ekle',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: TextField(
            controller: controller,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Kullanıcı adını gir',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              prefixIcon:
                  const Icon(Icons.alternate_email, color: Colors.white54),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('İptal',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5))),
            ),
            ElevatedButton(
              onPressed: () {
                if (controller.text.isNotEmpty) {
                  context
                      .read<SocialBloc>()
                      .add(SendFriendRequestEvent(controller.text.trim()));
                  Navigator.pop(dialogContext);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE94560),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child:
                  const Text('Gönder', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showSearchSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => BlocProvider.value(
        value: context.read<SocialBloc>(),
        child: _SearchSheet(cachedFriends: _cachedFriends),
      ),
    );
  }
}

class _SearchSheet extends StatefulWidget {
  final List<FriendEntity>? cachedFriends;
  
  const _SearchSheet({this.cachedFriends});

  @override
  State<_SearchSheet> createState() => _SearchSheetState();
}


class _SearchSheetState extends State<_SearchSheet> {
  final TextEditingController _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            color: const Color(0xFF1a1a2e).withValues(alpha: 0.95),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _controller,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Kullanıcı ara...',
                    hintStyle:
                        TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon:
                        const Icon(Icons.search, color: Colors.white54),
                  ),
                  onChanged: (query) {
                    setState(() {}); // Trigger rebuild to handle empty state
                    if (query.length >= 2) {
                      context.read<SocialBloc>().add(SearchUsersEvent(query));
                    }
                  },

                ),
              ),
              Expanded(
                child: BlocBuilder<SocialBloc, SocialState>(
                  buildWhen: (prev, current) =>
                      current is UserSearchResults || current is SocialLoading,
                  builder: (context, state) {
                    if (_controller.text.isEmpty) {
                      return Center(
                        child: Text('Kullanıcı aramak için yazmaya başla...',
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5))),
                      );
                    }

                    if (state is SocialLoading) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (state is UserSearchResults) {
                      if (state.results.isEmpty) {
                        return Center(
                          child: Text('Sonuç bulunamadı',
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.5))),
                        );
                      }
                      return ListView.builder(
                        itemCount: state.results.length,
                        itemBuilder: (context, index) => _buildUserTile(context, state.results[index]),
                      );
                    }
                    return const SizedBox();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserTile(BuildContext context, FriendEntity user) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.white.withValues(alpha: 0.05),
        child: user.avatarUrl != null && !user.avatarUrl!.startsWith('http')
            ? Text(user.avatarUrl!, style: const TextStyle(fontSize: 20))
            : const Icon(Icons.person, color: Colors.white54),
      ),
      title: Text(
        user.displayName ?? user.username,
        style: const TextStyle(color: Colors.white),
      ),
      subtitle: Text('@${user.username}',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
      trailing: user.isSelf
          ? const Text('Sen', style: TextStyle(color: Colors.white54))
          : user.isFriend
              ? const Icon(Icons.check_circle, color: Colors.green)
              : IconButton(
                  icon: const Icon(Icons.person_add, color: Color(0xFFE94560)),
                  onPressed: () {
                    context.read<SocialBloc>().add(SendFriendRequestEvent(user.username));
                    Navigator.pop(context);
                  },
                ),
      onTap: user.isFriend
          ? () {
              final bloc = context.read<SocialBloc>();
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BlocProvider.value(
                    value: bloc,
                    child: FriendProfilePage(friendId: user.id),
                  ),
                ),
              );
            }
          : null,
    );
  }
}

