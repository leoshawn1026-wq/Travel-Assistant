/// 行程数据模型
class ItineraryItem {
  final String time;
  final String name;
  final String type;
  final String address;
  final int durationMinutes;
  final String tips;
  final bool isLocal;     // 是否是本地人推荐
  final String localTip;  // 本地人推荐理由

  ItineraryItem({
    required this.time,
    required this.name,
    required this.type,
    this.address = '',
    this.durationMinutes = 60,
    this.tips = '',
    this.isLocal = false,
    this.localTip = '',
  });

  factory ItineraryItem.fromJson(Map<String, dynamic> json) {
    return ItineraryItem(
      time: json['time'] ?? '09:00',
      name: json['name'] ?? '',
      type: json['type'] ?? 'attraction',
      address: json['address'] ?? '',
      durationMinutes: json['duration_minutes'] ?? 60,
      tips: json['tips'] ?? '',
      isLocal: json['is_local'] ?? false,
      localTip: json['local_tip'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'time': time,
    'name': name,
    'type': type,
    'address': address,
    'duration_minutes': durationMinutes,
    'tips': tips,
    'is_local': isLocal,
    'local_tip': localTip,
  };

  /// 是否是本地人推荐的美食或地点
  bool get isLocalFavorite => isLocal && (type == 'local_food' || type == 'local_spot');

  String get typeLabel {
    switch (type) {
      case 'food': return '美食';
      case 'local_food': return '本地美食';
      case 'transport': return '交通';
      case 'rest': return '休息';
      case 'local_spot': return '本地秘境';
      default: return '景点';
    }
  }

  String get typeEmoji {
    switch (type) {
      case 'food': return '🍽️';
      case 'local_food': return '🔥';
      case 'transport': return '🚌';
      case 'rest': return '🏨';
      case 'local_spot': return '✨';
      case 'sightseeing': return '📸';
      case 'shopping': return '🛍️';
      default: return '📍';
    }
  }
}

/// 住宿推荐
class Accommodation {
  final String name;
  final String area;
  final String priceRange;
  final String reason;
  final String tips;

  Accommodation({
    required this.name,
    required this.area,
    this.priceRange = '',
    this.reason = '',
    this.tips = '',
  });

  factory Accommodation.fromJson(Map<String, dynamic> json) {
    return Accommodation(
      name: json['name'] ?? '',
      area: json['area'] ?? '',
      priceRange: json['price_range'] ?? '',
      reason: json['reason'] ?? '',
      tips: json['tips'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'area': area,
    'price_range': priceRange,
    'reason': reason,
    'tips': tips,
  };
}

/// 单日行程计划
class DayPlan {
  final int day;
  final String date;
  final String title;
  final List<ItineraryItem> items;
  final String summary;
  final Accommodation? accommodation;

  DayPlan({
    required this.day,
    required this.date,
    required this.title,
    required this.items,
    this.summary = '',
    this.accommodation,
  });

  factory DayPlan.fromJson(Map<String, dynamic> json) {
    return DayPlan(
      day: json['day'] ?? 1,
      date: json['date'] ?? '',
      title: json['title'] ?? '',
      items: (json['items'] as List? ?? [])
          .map((e) => ItineraryItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      summary: json['summary'] ?? '',
      accommodation: json['accommodation'] != null
          ? Accommodation.fromJson(json['accommodation'] as Map<String, dynamic>)
          : null,
    );
  }

  /// 获取本地人推荐的项目
  List<ItineraryItem> get localFavorites =>
      items.where((i) => i.isLocalFavorite).toList();
}

class Itinerary {
  final String destination;
  final String date;
  final int days;
  final String title;
  final List<ItineraryItem> items;
  final List<DayPlan> dayPlans;
  final String summary;

  Itinerary({
    required this.destination,
    required this.date,
    this.days = 1,
    required this.title,
    this.items = const [],
    this.dayPlans = const [],
    this.summary = '',
  });

  bool get hasMultiDay => dayPlans.isNotEmpty;

  List<ItineraryItem> getItemsForDay(int dayIndex) {
    if (hasMultiDay && dayIndex < dayPlans.length) {
      return dayPlans[dayIndex].items;
    }
    return items;
  }

  factory Itinerary.fromJson(Map<String, dynamic> json) {
    final itemsList = (json['items'] as List? ?? [])
        .map((e) => ItineraryItem.fromJson(e as Map<String, dynamic>))
        .toList();
    final dayPlansList = (json['day_plans'] as List? ?? [])
        .map((e) => DayPlan.fromJson(e as Map<String, dynamic>))
        .toList();
    return Itinerary(
      destination: json['destination'] ?? '',
      date: json['date'] ?? '',
      days: json['days'] ?? 1,
      title: json['title'] ?? '',
      items: itemsList,
      dayPlans: dayPlansList,
      summary: json['summary'] ?? '',
    );
  }
}

/// 收藏行程
class SavedTrip {
  final String id;
  final String destination;
  final String date;
  final int days;
  final String title;
  final List<ItineraryItem> items;
  final List<DayPlan> dayPlans;
  final String summary;
  final String savedAt;

  SavedTrip({
    required this.id,
    required this.destination,
    required this.date,
    this.days = 1,
    required this.title,
    required this.items,
    this.dayPlans = const [],
    this.summary = '',
    required this.savedAt,
  });

  factory SavedTrip.fromItinerary(Itinerary itinerary) {
    return SavedTrip(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      destination: itinerary.destination,
      date: itinerary.date,
      days: itinerary.days,
      title: itinerary.title,
      items: itinerary.items,
      dayPlans: itinerary.dayPlans,
      summary: itinerary.summary,
      savedAt: DateTime.now().toIso8601String(),
    );
  }

  factory SavedTrip.fromJson(Map<String, dynamic> json) {
    final itemsList = (json['items'] as List? ?? [])
        .map((e) => ItineraryItem.fromJson(e as Map<String, dynamic>))
        .toList();
    final dayPlansList = (json['day_plans'] as List? ?? [])
        .map((e) => DayPlan.fromJson(e as Map<String, dynamic>))
        .toList();
    return SavedTrip(
      id: json['id'] ?? '',
      destination: json['destination'] ?? '',
      date: json['date'] ?? '',
      days: json['days'] ?? 1,
      title: json['title'] ?? '',
      items: itemsList,
      dayPlans: dayPlansList,
      summary: json['summary'] ?? '',
      savedAt: json['saved_at'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'destination': destination,
    'date': date,
    'days': days,
    'title': title,
    'items': items.map((e) => e.toJson()).toList(),
    'day_plans': dayPlans.map((d) => {
      'day': d.day,
      'date': d.date,
      'title': d.title,
      'items': d.items.map((e) => e.toJson()).toList(),
      'summary': d.summary,
      'accommodation': d.accommodation?.toJson(),
    }).toList(),
    'summary': summary,
    'saved_at': savedAt,
  };
}
