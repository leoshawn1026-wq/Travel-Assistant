import 'package:flutter/material.dart';
import '../../core/storage/local_storage.dart';
import '../../core/theme/app_theme.dart';
import '../../models/itinerary.dart';
import '../../widgets/itinerary_card.dart';

/// 我的收藏行程页
class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => FavoritesPageState();
}

class FavoritesPageState extends State<FavoritesPage> {
  final _storage = LocalStorage();
  List<SavedTrip> _trips = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTrips();
  }

  /// 公开刷新方法，供父级调用
  Future<void> refresh() => _loadTrips();

  Future<void> _loadTrips() async {
    setState(() => _loading = true);
    final trips = await _storage.getSavedTrips();
    if (!mounted) return;
    setState(() { _trips = trips; _loading = false; });
  }

  Future<void> _deleteTrip(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('确认删除'),
        content: const Text('确定要删除这条收藏行程吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('删除', style: TextStyle(color: AppTheme.error))),
        ],
      ),
    );
    if (confirm == true) {
      await _storage.deleteTrip(id);
      await _loadTrips();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的收藏'),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _loadTrips, tooltip: '刷新')],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : _trips.isEmpty ? _buildEmptyState() : _buildTripList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 100, height: 100,
            decoration: BoxDecoration(color: AppTheme.pink.withAlpha(20), borderRadius: BorderRadius.circular(30)),
            child: const Icon(Icons.favorite_outline, size: 48, color: AppTheme.pink),
          ),
          const SizedBox(height: 24),
          const Text('暂无收藏行程', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
          const SizedBox(height: 8),
          const Text('在「目的地对比」中生成并收藏行程', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildTripList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _trips.length,
      itemBuilder: (context, index) {
        final trip = _trips[index];
        return Dismissible(
          key: Key(trip.id),
          direction: DismissDirection.endToStart,
          confirmDismiss: (_) async { await _deleteTrip(trip.id); return false; },
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 24),
            decoration: BoxDecoration(color: AppTheme.error, borderRadius: BorderRadius.circular(16)),
            child: const Icon(Icons.delete_outline, color: Colors.white, size: 28),
          ),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              children: [
                ItineraryCard(
                  itinerary: Itinerary(
                    destination: trip.destination,
                    date: trip.date,
                    days: trip.days,
                    title: trip.title,
                    items: trip.items,
                    dayPlans: trip.dayPlans,
                    summary: trip.summary,
                  ),
                  showSaveTime: trip.savedAt,
                  activeDay: 0,
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => _deleteTrip(trip.id),
                    icon: const Icon(Icons.favorite, size: 16, color: AppTheme.pink),
                    label: const Text('取消收藏', style: TextStyle(fontSize: 12, color: AppTheme.pink)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      backgroundColor: AppTheme.pink.withAlpha(15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
