import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/supabase_config.dart';
import '../models/topic.dart';

/// Repository topik — CRUD ringan ke tabel `topics`
/// (RLS Supabase membatasi akses ke milik user yang sedang login).
class TopicRepository {
  const TopicRepository();

  String get _userId {
    final user = SupabaseConfig.client.auth.currentUser;
    if (user == null) {
      throw StateError('Tidak ada user yang login.');
    }
    return user.id;
  }

  Future<List<Topic>> fetchTopics() async {
    final rows = await SupabaseConfig.client
        .from('topics')
        .select()
        .eq('user_id', _userId)
        .eq('is_archived', false)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((e) => Topic.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Topic> createTopic(String name) async {
    final inserted = await SupabaseConfig.client
        .from('topics')
        .insert({'user_id': _userId, 'name': name.trim()})
        .select()
        .single();
    return Topic.fromJson(inserted);
  }
}

final topicRepositoryProvider =
    Provider<TopicRepository>((ref) => const TopicRepository());

/// Daftar topik user. Invalidate provider ini setelah membuat topik baru.
final topicsProvider = FutureProvider<List<Topic>>((ref) async {
  return ref.watch(topicRepositoryProvider).fetchTopics();
});
