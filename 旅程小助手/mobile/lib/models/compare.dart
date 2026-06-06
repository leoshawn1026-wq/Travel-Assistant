/// 目的地对比数据模型

class CompareRow {
  final String dimension;
  final List<String> values;
  final String detail;

  CompareRow({required this.dimension, required this.values, this.detail = ''});

  factory CompareRow.fromJson(Map<String, dynamic> json) {
    return CompareRow(
      dimension: json['dimension'] ?? '',
      values: List<String>.from(json['values'] ?? []),
      detail: json['detail'] as String? ?? '',
    );
  }
}

class CompareTable {
  final List<String> headers;
  final List<CompareRow> rows;

  CompareTable({required this.headers, required this.rows});

  factory CompareTable.fromJson(Map<String, dynamic> json) {
    final rowsList = (json['rows'] as List? ?? [])
        .map((e) => CompareRow.fromJson(e as Map<String, dynamic>))
        .toList();
    return CompareTable(
      headers: List<String>.from(json['headers'] ?? []),
      rows: rowsList,
    );
  }
}

class DestinationScore {
  final String destination;
  final double overall;
  final Map<String, double> details;

  DestinationScore({
    required this.destination,
    required this.overall,
    this.details = const {},
  });

  factory DestinationScore.fromJson(Map<String, dynamic> json) {
    final detailsRaw = json['details'] as Map<String, dynamic>? ?? {};
    final details = detailsRaw.map((k, v) => MapEntry(k, (v as num).toDouble()));
    return DestinationScore(
      destination: json['destination'] ?? '',
      overall: (json['overall'] as num?)?.toDouble() ?? 0,
      details: details,
    );
  }
}

class WeatherInfo {
  final String city;
  final String weather;
  final String temperature;
  final String wind;
  final String humidity;

  WeatherInfo({required this.city, this.weather = '', this.temperature = '', this.wind = '', this.humidity = ''});

  factory WeatherInfo.fromJson(Map<String, dynamic> json) {
    return WeatherInfo(
      city: json['city'] ?? '',
      weather: json['weather'] ?? '',
      temperature: json['temperature'] ?? '',
      wind: json['wind'] ?? '',
      humidity: json['humidity'] ?? '',
    );
  }
}

class CompareResult {
  final CompareTable table;
  final String recommendation;
  final String verdict;
  final List<DestinationScore> scores;
  final List<WeatherInfo> weather;

  CompareResult({
    required this.table,
    required this.recommendation,
    this.verdict = '',
    this.scores = const [],
    this.weather = const [],
  });

  factory CompareResult.fromJson(Map<String, dynamic> json) {
    return CompareResult(
      table: CompareTable.fromJson(json['table'] as Map<String, dynamic>),
      recommendation: json['recommendation'] ?? '',
      verdict: json['verdict'] ?? '',
      scores: (json['scores'] as List? ?? [])
          .map((e) => DestinationScore.fromJson(e as Map<String, dynamic>))
          .toList(),
      weather: (json['weather'] as List? ?? [])
          .map((e) => WeatherInfo.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// 对比历史记录
class CompareHistoryItem {
  final String id;
  final List<String> destinations;
  final String createdAt;
  final String summary;
  final String chosen;

  CompareHistoryItem({
    required this.id,
    required this.destinations,
    required this.createdAt,
    this.summary = '',
    this.chosen = '',
  });

  factory CompareHistoryItem.fromJson(Map<String, dynamic> json) {
    return CompareHistoryItem(
      id: json['id'] ?? '',
      destinations: List<String>.from(json['destinations'] ?? []),
      createdAt: json['created_at'] ?? '',
      summary: json['summary'] ?? '',
      chosen: json['chosen'] ?? '',
    );
  }
}

/// 旅行画像常量
class TravelProfile {
  static const purposes = {
    'leisure': '休闲度假',
    'culture': '文化历史',
    'food': '美食之旅',
    'adventure': '探险户外',
    'honeymoon': '蜜月浪漫',
    'family': '亲子家庭',
    'shopping': '购物血拼',
  };

  static const withWho = {
    'alone': '独自旅行',
    'couple': '情侣/伴侣',
    'family': '带孩子/家人',
    'friends': '和朋友一起',
  };

  static const styles = {
    'free': '自由行',
    'guided': '跟团游',
    'half': '半自由行',
  };
}
