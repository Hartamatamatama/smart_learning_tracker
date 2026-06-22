import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/history_filter.dart';
import '../models/session_history_item.dart';
import 'history_repository.dart';

/// State layar riwayat: filter aktif, halaman saat ini, dan data halaman.
class HistoryState {
  const HistoryState({
    required this.filter,
    required this.pageIndex,
    required this.pageSize,
    required this.page,
  });

  final HistoryFilter filter;
  final int pageIndex;
  final int pageSize;
  final AsyncValue<HistoryPage> page;

  HistoryState copyWith({
    HistoryFilter? filter,
    int? pageIndex,
    int? pageSize,
    AsyncValue<HistoryPage>? page,
  }) {
    return HistoryState(
      filter: filter ?? this.filter,
      pageIndex: pageIndex ?? this.pageIndex,
      pageSize: pageSize ?? this.pageSize,
      page: page ?? this.page,
    );
  }
}

class HistoryController extends Notifier<HistoryState> {
  int _reqId = 0;

  @override
  HistoryState build() {
    // Muat halaman pertama setelah build selesai.
    Future.microtask(_load);
    return const HistoryState(
      filter: HistoryFilter(),
      pageIndex: 0,
      pageSize: HistoryRepository.defaultPageSize,
      page: AsyncValue.loading(),
    );
  }

  Future<void> _load() async {
    final reqId = ++_reqId;
    state = state.copyWith(page: const AsyncValue.loading());
    try {
      final result = await ref.read(historyRepositoryProvider).fetchPage(
            filter: state.filter,
            pageIndex: state.pageIndex,
            pageSize: state.pageSize,
          );
      if (reqId != _reqId) return; // hasil basi, abaikan
      state = state.copyWith(page: AsyncValue.data(result));
    } catch (e, st) {
      if (reqId != _reqId) return;
      state = state.copyWith(page: AsyncValue.error(e, st));
    }
  }

  /// Terapkan filter baru; selalu kembali ke halaman pertama.
  void applyFilter(HistoryFilter filter) {
    state = state.copyWith(filter: filter, pageIndex: 0);
    _load();
  }

  void resetFilter() => applyFilter(const HistoryFilter());

  void nextPage() {
    final current = state.page.valueOrNull;
    if (current != null && current.hasNext) {
      state = state.copyWith(pageIndex: state.pageIndex + 1);
      _load();
    }
  }

  void prevPage() {
    if (state.pageIndex > 0) {
      state = state.copyWith(pageIndex: state.pageIndex - 1);
      _load();
    }
  }

  Future<void> refresh() => _load();
}

final historyControllerProvider =
    NotifierProvider<HistoryController, HistoryState>(HistoryController.new);

/// Detail rekap mood untuk satu sesi (dipakai di layar detail).
final sessionMoodProvider =
    FutureProvider.family<SessionMoodDetail, String>((ref, sessionId) {
  return ref.read(historyRepositoryProvider).fetchSessionMoods(sessionId);
});
