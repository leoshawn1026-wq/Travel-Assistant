import 'package:flutter/material.dart';
import '../models/itinerary.dart';
import '../core/theme/app_theme.dart';

/// 行程卡片组件 - 支持本地人推荐标签和住宿推荐
class ItineraryCard extends StatelessWidget {
  final Itinerary itinerary;
  final String? showSaveTime;
  final int activeDay;
  final VoidCallback? onCopy;
  final VoidCallback? onDownload;
  final VoidCallback? onViewMap;

  const ItineraryCard({
    super.key,
    required this.itinerary,
    this.showSaveTime,
    this.activeDay = 0,
    this.onCopy,
    this.onDownload,
    this.onViewMap,
  });

  DayPlan? get _currentDayPlan {
    if (activeDay >= 0 && activeDay < itinerary.dayPlans.length) {
      return itinerary.dayPlans[activeDay];
    }
    return null;
  }

  List<ItineraryItem> get _currentItems {
    final plan = _currentDayPlan;
    if (plan != null) return plan.items;
    return itinerary.items;
  }

  @override
  Widget build(BuildContext context) {
    final plan = _currentDayPlan;
    final summary = plan?.summary ?? itinerary.summary;
    final items = _currentItems;
    final accommodation = plan?.accommodation;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.softShadow,
      ),
      padding: const EdgeInsets.all(AppTheme.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题区域
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: AppTheme.horizonGradient,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: AppTheme.cardShadow,
                ),
                child: const Icon(Icons.map, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan?.title ?? itinerary.title,
                      style: AppTheme.headingMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 14, color: AppTheme.primary.withAlpha(180)),
                        const SizedBox(width: 4),
                        Text(itinerary.destination,
                            style: TextStyle(color: AppTheme.primary.withAlpha(180), fontSize: 13)),
                        const SizedBox(width: 8),
                        Icon(Icons.calendar_today, size: 13, color: AppTheme.textSecondary),
                        const SizedBox(width: 4),
                        Text(plan?.date ?? itinerary.date, style: AppTheme.bodySmall),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (showSaveTime != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.favorite, size: 14, color: AppTheme.pink),
                const SizedBox(width: 4),
                Text('收藏于 $showSaveTime',
                    style: TextStyle(color: AppTheme.pink.withAlpha(180), fontSize: 12)),
              ],
            ),
          ],

          // 摘要
          if (summary.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.auto_awesome, size: 16, color: AppTheme.primary),
                  const SizedBox(width: 8),
                  Expanded(child: Text(summary, style: const TextStyle(fontSize: 14, height: 1.5))),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),

          // 时间线
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                  child: Text('暂无行程项目', style: TextStyle(color: AppTheme.textSecondary))),
            )
          else
            ...items.asMap().entries.map(
              (entry) => _buildTimelineItem(entry.value, entry.key, items.length),
            ),

          // 住宿推荐
          if (accommodation != null) ...[
            const SizedBox(height: 16),
            _buildAccommodationCard(accommodation),
          ],

          // 操作按钮
          if (onViewMap != null || onCopy != null || onDownload != null) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (onViewMap != null)
                  TextButton.icon(
                    onPressed: onViewMap,
                    icon: const Icon(Icons.map, size: 16, color: AppTheme.primary),
                    label: const Text('地图', style: TextStyle(color: AppTheme.primary)),
                  )
                else
                  const Spacer(),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (onCopy != null)
                      TextButton.icon(
                        onPressed: onCopy,
                        icon: const Icon(Icons.copy, size: 16),
                        label: const Text('复制'),
                        style: TextButton.styleFrom(foregroundColor: AppTheme.textSecondary),
                      ),
                    if (onDownload != null)
                      TextButton.icon(
                        onPressed: onDownload,
                        icon: const Icon(Icons.download, size: 16),
                        label: const Text('下载'),
                        style: TextButton.styleFrom(foregroundColor: AppTheme.textSecondary),
                      ),
                  ],
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAccommodationCard(Accommodation acc) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF4A90D9).withAlpha(20), const Color(0xFF4A90D9).withAlpha(8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF4A90D9).withAlpha(30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.hotel, size: 18, color: Color(0xFF4A90D9)),
              const SizedBox(width: 8),
              const Text('🏨 住宿推荐', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 10),
          Text(acc.name,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: AppTheme.textPrimary)),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.location_on, size: 14, color: AppTheme.textSecondary.withAlpha(150)),
              const SizedBox(width: 4),
              Text(acc.area, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
              if (acc.priceRange.isNotEmpty) ...[
                const SizedBox(width: 12),
                Icon(Icons.monetization_on, size: 14, color: AppTheme.textSecondary.withAlpha(150)),
                const SizedBox(width: 4),
                Text(acc.priceRange, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
              ],
            ],
          ),
          if (acc.reason.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.thumb_up, size: 14, color: AppTheme.primary),
                const SizedBox(width: 4),
                Expanded(child: Text(acc.reason,
                    style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary, height: 1.4))),
              ],
            ),
          ],
          if (acc.tips.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lightbulb, size: 14, color: AppTheme.accent),
                const SizedBox(width: 4),
                Expanded(child: Text(acc.tips,
                    style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary, height: 1.4))),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'food':
        return AppTheme.accent;
      case 'local_food':
        return AppTheme.primary;
      case 'transport':
        return const Color(0xFF4A90D9);
      case 'rest':
        return const Color(0xFF4CAF50);
      case 'local_spot':
        return const Color(0xFF9C27B0);
      case 'sightseeing':
        return AppTheme.pink;
      default:
        return AppTheme.primary;
    }
  }

  Widget _buildTimelineItem(ItineraryItem item, int index, int total) {
    final color = _getTypeColor(item.type);
    final isLast = index == total - 1;
    final isLocal = item.isLocalFavorite;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 56,
            child: Column(
              children: [
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withAlpha(20),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    item.time,
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: color),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [BoxShadow(color: color.withAlpha(80), blurRadius: 4)],
                  ),
                ),
                if (!isLast)
                  Expanded(child: Container(width: 2, color: color.withAlpha(40))),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              margin: EdgeInsets.only(bottom: isLast ? 0 : 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color.withAlpha(8),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: color.withAlpha(20)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(item.typeEmoji, style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(item.name,
                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                                ),
                                if (isLocal) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primary.withAlpha(20),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.thumb_up, size: 11, color: AppTheme.primary),
                                        SizedBox(width: 2),
                                        Text('本地推荐',
                                            style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                color: AppTheme.primary)),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withAlpha(20),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          item.typeLabel,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
                        ),
                      ),
                    ],
                  ),
                  if (item.address.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 14, color: AppTheme.textSecondary.withAlpha(150)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(item.address,
                              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                        ),
                      ],
                    ),
                  ],
                  Row(
                    children: [
                      const Icon(Icons.timer_outlined, size: 14, color: AppTheme.textHint),
                      const SizedBox(width: 4),
                      Text('约 ${item.durationMinutes} 分钟',
                          style: TextStyle(color: AppTheme.textHint, fontSize: 12)),
                    ],
                  ),
                  if (isLocal && item.localTip.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withAlpha(12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('💡', style: TextStyle(fontSize: 14)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              item.localTip,
                              style: TextStyle(
                                  color: AppTheme.primary,
                                  fontSize: 13,
                                  height: 1.4,
                                  fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else if (item.tips.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.accent.withAlpha(15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('💡', style: TextStyle(fontSize: 14)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              item.tips,
                              style: TextStyle(
                                  color: AppTheme.textPrimary.withAlpha(200),
                                  fontSize: 13,
                                  height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
