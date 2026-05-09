import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:movieswipe/core/network/api_client.dart';
import 'package:movieswipe/core/providers/liked_movies_provider.dart';

/// A compact bar chart showing the user's daily swipe activity for the last 7 days.
/// Tapping a bar reveals the like/pass breakdown for that day.
class DailyActivityChart extends StatefulWidget {
  const DailyActivityChart({super.key});

  @override
  State<DailyActivityChart> createState() => _DailyActivityChartState();
}

class _DailyActivityChartState extends State<DailyActivityChart>
    with SingleTickerProviderStateMixin {
  final ApiClient _apiClient = ApiClient(client: null);
  List<Map<String, dynamic>> _days = [];
  bool _isLoading = true;
  int? _selectedIndex;
  late AnimationController _animController;
  late Animation<double> _animValue;
  int _lastKnownSwipes = -1;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _animValue = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    _fetchData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Watch totalSwipes so we can refresh automatically when the user swipes
    final currentSwipes = Provider.of<LikedMoviesProvider>(context).totalSwipes;
    if (_lastKnownSwipes != -1 && currentSwipes != _lastKnownSwipes) {
      _fetchData(isRefresh: true);
    }
    _lastKnownSwipes = currentSwipes;
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _fetchData({bool isRefresh = false}) async {
    try {
      if (!isRefresh) {
        setState(() => _isLoading = true);
      }
      final response = await _apiClient.get('/users/me/daily-activity');
      if (response is Map<String, dynamic>) {
        final list = response['daily_activity'] as List<dynamic>? ?? [];
        if (mounted) {
          setState(() {
            _days = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
            _isLoading = false;
          });
          _animController.forward(from: 0.0);
        }
      }
    } catch (e) {
      debugPrint('❌ Failed to load daily activity: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  int get _maxTotal {
    if (_days.isEmpty) return 1;
    final m = _days.map((d) => d['total'] as int? ?? 0).reduce((a, b) => a > b ? a : b);
    return m == 0 ? 1 : m;
  }

  String _dayLabel(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final target = DateTime(date.year, date.month, date.day);
      final diff = today.difference(target).inDays;

      if (diff == 0) return 'Bugün';
      if (diff == 1) return 'Dün';
      // Return short day name in Turkish
      const dayNames = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
      return dayNames[date.weekday - 1];
    } catch (_) {
      return dateStr.substring(5); // fallback: MM-DD
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(Icons.show_chart_rounded, color: Color(0xFF8B5CF6), size: 20),
              const SizedBox(width: 8),
              const Text(
                'Haftalık Aktivite',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              if (!_isLoading && _days.isNotEmpty)
                Text(
                  '${_days.map((d) => d['total'] as int? ?? 0).reduce((a, b) => a + b)} swipe',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),

          // Chart area
          if (_isLoading)
            const SizedBox(
              height: 120,
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF8B5CF6),
                  ),
                ),
              ),
            )
          else if (_days.isEmpty || _days.every((d) => (d['total'] as int? ?? 0) == 0))
            SizedBox(
              height: 120,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.swipe_rounded, color: Colors.white.withValues(alpha: 0.3), size: 36),
                    const SizedBox(height: 8),
                    Text(
                      'Bu hafta henüz aktivite yok',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            _buildChart(),

          // Selected day detail
          if (_selectedIndex != null && _days.isNotEmpty)
            _buildDayDetail(_days[_selectedIndex!]),
        ],
      ),
    );
  }

  Widget _buildChart() {
    return AnimatedBuilder(
      animation: _animValue,
      builder: (context, _) {
        return SizedBox(
          height: 120,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(_days.length, (index) {
              final day = _days[index];
              final total = day['total'] as int? ?? 0;
              final likes = day['likes'] as int? ?? 0;
              final fraction = total / _maxTotal;
              final isSelected = _selectedIndex == index;

              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedIndex = _selectedIndex == index ? null : index;
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // Count label
                        if (total > 0)
                          AnimatedOpacity(
                            opacity: _animValue.value,
                            duration: const Duration(milliseconds: 200),
                            child: Text(
                              '$total',
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : Colors.white.withValues(alpha: 0.5),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        const SizedBox(height: 4),

                        // Bar (stacked: likes + passes)
                        Flexible(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: double.infinity,
                            height: (80 * fraction * _animValue.value).clamp(total > 0 ? 4.0 : 0.0, 80.0),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              gradient: total > 0
                                  ? LinearGradient(
                                      begin: Alignment.bottomCenter,
                                      end: Alignment.topCenter,
                                      colors: isSelected
                                          ? [const Color(0xFFEC4899), const Color(0xFF8B5CF6)]
                                          : [
                                              const Color(0xFF8B5CF6).withValues(alpha: 0.6),
                                              const Color(0xFF8B5CF6).withValues(alpha: 0.3),
                                            ],
                                    )
                                  : null,
                              color: total == 0
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : null,
                              boxShadow: isSelected && total > 0
                                  ? [
                                      BoxShadow(
                                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.4),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ]
                                  : null,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),

                        // Day label
                        Text(
                          _dayLabel(day['date'] as String? ?? ''),
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.45),
                            fontSize: 10,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        );
      },
    );
  }

  Widget _buildDayDetail(Map<String, dynamic> day) {
    final total = day['total'] as int? ?? 0;
    final likes = day['likes'] as int? ?? 0;
    final passes = day['passes'] as int? ?? 0;
    final dateStr = day['date'] as String? ?? '';

    String formattedDate;
    try {
      final date = DateTime.parse(dateStr);
      const monthNames = [
        '', 'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
        'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'
      ];
      formattedDate = '${date.day} ${monthNames[date.month]}';
    } catch (_) {
      formattedDate = dateStr;
    }

    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: Container(
        margin: const EdgeInsets.only(top: 16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Column(
          children: [
            Text(
              formattedDate,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                // Likes
                Expanded(
                  child: _StatPill(
                    icon: Icons.favorite_rounded,
                    label: 'Beğeni',
                    value: likes,
                    color: const Color(0xFF4ADE80),
                  ),
                ),
                const SizedBox(width: 10),
                // Passes
                Expanded(
                  child: _StatPill(
                    icon: Icons.close_rounded,
                    label: 'Geçilen',
                    value: passes,
                    color: const Color(0xFFF87171),
                  ),
                ),
                const SizedBox(width: 10),
                // Total
                Expanded(
                  child: _StatPill(
                    icon: Icons.swipe_rounded,
                    label: 'Toplam',
                    value: total,
                    color: const Color(0xFF8B5CF6),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value;
  final Color color;

  const _StatPill({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 4),
          Text(
            '$value',
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
