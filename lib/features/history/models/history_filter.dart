import '../../timer/models/timer_enums.dart';
import 'session_history_item.dart';

/// Kriteria filter riwayat. Semua null/empty = tampilkan semua.
class HistoryFilter {
  const HistoryFilter({
    this.topicIds = const {},
    this.from,
    this.to,
    this.mode,
  });

  /// Filter berdasarkan beberapa topik (multi-select). Kosong = semua topik.
  final Set<String> topicIds;

  /// Rentang tanggal (inklusif). Null = tak dibatasi.
  final DateTime? from;
  final DateTime? to;

  /// Filter mode. Null = semua mode.
  final TimerMode? mode;

  bool get isActive =>
      topicIds.isNotEmpty || from != null || to != null || mode != null;

  HistoryFilter copyWith({
    Set<String>? topicIds,
    DateTime? from,
    bool clearFrom = false,
    DateTime? to,
    bool clearTo = false,
    TimerMode? mode,
    bool clearMode = false,
  }) {
    return HistoryFilter(
      topicIds: topicIds ?? this.topicIds,
      from: clearFrom ? null : (from ?? this.from),
      to: clearTo ? null : (to ?? this.to),
      mode: clearMode ? null : (mode ?? this.mode),
    );
  }
}

/// Satu halaman hasil query riwayat.
class HistoryPage {
  const HistoryPage({
    required this.items,
    required this.totalCount,
    required this.pageIndex,
    required this.pageSize,
  });

  final List<SessionHistoryItem> items;

  /// Total baris yang cocok dengan filter (bukan hanya halaman ini).
  final int totalCount;
  final int pageIndex; // 0-based
  final int pageSize;

  int get totalPages =>
      totalCount == 0 ? 0 : ((totalCount + pageSize - 1) ~/ pageSize);

  /// Nomor halaman tampilan (1-based). 0 jika kosong.
  int get displayPage => totalCount == 0 ? 0 : pageIndex + 1;

  bool get hasPrev => pageIndex > 0;
  bool get hasNext => displayPage < totalPages;
}
