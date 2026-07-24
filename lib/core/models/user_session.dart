import 'scan_result.dart';

class UserSession {
  final String userName;
  final int totalXP;
  final int scanCount;
  final int correctionCount;
  final List<ScanResult> scanHistory;

  const UserSession({
    this.userName = '',
    this.totalXP = 0,
    this.scanCount = 0,
    this.correctionCount = 0,
    this.scanHistory = const [],
  });

  UserSession copyWith({
    String? userName,
    int? totalXP,
    int? scanCount,
    int? correctionCount,
    List<ScanResult>? scanHistory,
  }) {
    return UserSession(
      userName: userName ?? this.userName,
      totalXP: totalXP ?? this.totalXP,
      scanCount: scanCount ?? this.scanCount,
      correctionCount: correctionCount ?? this.correctionCount,
      scanHistory: scanHistory ?? this.scanHistory,
    );
  }

  int get uniqueCategoryCount {
    return scanHistory.map((r) => r.dynamicCategoryName ?? r.category.name).toSet().length;
  }

  double get averageConfidence {
    if (scanHistory.isEmpty) return 0;
    return scanHistory.map((r) => r.confidence).reduce((a, b) => a + b) /
        scanHistory.length;
  }

  String get accuracyPercent => '${(averageConfidence * 100).toStringAsFixed(0)}%';

  Map<String, dynamic> toJson() => {
        'userName': userName,
        'totalXP': totalXP,
        'scanCount': scanCount,
        'correctionCount': correctionCount,
      };

  factory UserSession.fromJson(Map<String, dynamic> json) => UserSession(
        userName: json['userName'] as String? ?? '',
        totalXP: json['totalXP'] as int? ?? 0,
        scanCount: json['scanCount'] as int? ?? 0,
        correctionCount: json['correctionCount'] as int? ?? 0,
      );
}
