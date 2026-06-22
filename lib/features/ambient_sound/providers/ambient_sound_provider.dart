import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/supabase_config.dart';
import '../models/ambient_sound.dart';

/// Ambil daftar ambient sound aktif (data global, read-only via RLS).
class AmbientSoundRepository {
  const AmbientSoundRepository();

  Future<List<AmbientSound>> fetchActive() async {
    final rows = await SupabaseConfig.client
        .from('ambient_sounds')
        .select()
        .eq('is_active', true)
        .order('sort_order', ascending: true);
    return (rows as List)
        .map((e) => AmbientSound.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

final ambientSoundRepositoryProvider =
    Provider<AmbientSoundRepository>((ref) => const AmbientSoundRepository());

/// Daftar ambient sound untuk dipilih di setup screen.
final ambientSoundsProvider = FutureProvider<List<AmbientSound>>((ref) async {
  return ref.watch(ambientSoundRepositoryProvider).fetchActive();
});
