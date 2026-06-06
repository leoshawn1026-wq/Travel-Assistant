/// 高德 POI 数据模型
class PoiItem {
  final String id;
  final String name;
  final String address;
  final String location;
  final String type;

  PoiItem({
    required this.id,
    required this.name,
    required this.address,
    required this.location,
    this.type = '',
  });

  factory PoiItem.fromJson(Map<String, dynamic> json) {
    return PoiItem(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      address: json['address'] ?? '',
      location: json['location'] ?? '',
      type: json['type'] ?? '',
    );
  }

  /// 获取高德地图打开链接
  String get mapUrl {
    final coords = location.split(',');
    if (coords.length == 2) {
      return 'https://uri.amap.com/marker?position=${coords[0]},${coords[1]}&name=$name';
    }
    return 'https://ditu.amap.com/search?query=$name';
  }
}

class PoiSearchResult {
  final List<PoiItem> pois;

  PoiSearchResult({required this.pois});

  factory PoiSearchResult.fromJson(Map<String, dynamic> json) {
    return PoiSearchResult(
      pois: (json['pois'] as List? ?? [])
          .map((e) => PoiItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
