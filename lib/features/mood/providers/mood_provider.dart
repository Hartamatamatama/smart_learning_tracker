import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/supabase_config.dart';
import '../models/mood_parameter.dart';

/// Daftar parameter mood global, urut sort_order (mood_umum, fokus, dst.).
final moodParametersProvider =
    FutureProvider<List<MoodParameter>>((ref) async {
  final rows = await SupabaseConfig.client
      .from('mood_parameters')
      .select()
      .order('sort_order', ascending: true);
  return (rows as List)
      .map((e) => MoodParameter.fromJson(e as Map<String, dynamic>))
      .toList();
});
