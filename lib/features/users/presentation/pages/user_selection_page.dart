import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:movieswipe/core/providers/user_provider.dart';
import 'package:movieswipe/core/network/api_client.dart';
import 'package:movieswipe/features/movies/presentation/pages/swipe_page.dart';

/// User selection page for multi-user testing
class UserSelectionPage extends StatefulWidget {
  const UserSelectionPage({super.key});

  @override
  State<UserSelectionPage> createState() => _UserSelectionPageState();
}

class _UserSelectionPageState extends State<UserSelectionPage> {
  List<dynamic> _users = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _loading = true);

    try {
      final response = await ApiClient(client: null).get('/users');
      if (mounted) {
        setState(() {
          _users = response as List;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load users: $e')),
        );
      }
    }
  }

  Future<void> _createNewUser() async {
    setState(() => _loading = true);

    try {
      final response = await ApiClient(client: null).post('/users');
      final userId = response['user_id'];

      if (mounted) {
        await Provider.of<UserProvider>(context, listen: false)
            .setUserId(userId);
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const SwipePage()),
        );
      }
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create user: $e')),
        );
      }
    }
  }

  void _selectUser(String userId) {
    Provider.of<UserProvider>(context, listen: false).setUserId(userId);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const SwipePage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select User'),
        backgroundColor: Colors.black,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: _users.isEmpty
                      ? const Center(
                          child: Text(
                            'No users yet',
                            style: TextStyle(fontSize: 18),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _users.length,
                          itemBuilder: (context, index) {
                            final user = _users[index];
                            final userId = user['user_id'] as String;
                            final swipes = user['total_swipes'] ?? 0;
                            final likes = user['total_likes'] ?? 0;
                            final topGenres = user['top_genres'] as List? ?? [];

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                leading: CircleAvatar(
                                  child: Text('${index + 1}'),
                                ),
                                title: Text(
                                  'User ${userId.substring(0, 8)}...',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(
                                  '$swipes swipes • $likes likes\n'
                                  'Top: ${topGenres.isNotEmpty ? topGenres.first : 'None'}',
                                ),
                                isThreeLine: true,
                                onTap: () => _selectUser(userId),
                              ),
                            );
                          },
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _createNewUser,
                      icon: const Icon(Icons.add),
                      label: const Text('Create New User'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                        backgroundColor: Colors.purple,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
