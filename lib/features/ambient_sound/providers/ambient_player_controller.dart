import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../models/ambient_sound.dart';

/// State pemutar ambient sound.
class AmbientPlayerState {
  const AmbientPlayerState({
    this.sound,
    this.isPlaying = false,
    this.isMuted = false,
  });

  final AmbientSound? sound;
  final bool isPlaying;
  final bool isMuted;

  bool get isActive => sound != null;

  AmbientPlayerState copyWith({
    AmbientSound? sound,
    bool clearSound = false,
    bool? isPlaying,
    bool? isMuted,
  }) {
    return AmbientPlayerState(
      sound: clearSound ? null : (sound ?? this.sound),
      isPlaying: isPlaying ?? this.isPlaying,
      isMuted: isMuted ?? this.isMuted,
    );
  }
}

/// Mengontrol playback ambient sound (looping) lewat just_audio.
///
/// Terpisah dari timer: play/pause/mute di sini TIDAK memengaruhi timer.
/// Playback berlanjut saat app di-background/layar terkunci karena proses
/// tetap hidup oleh foreground service timer (Android). Di Web, berhenti
/// otomatis saat tab ditutup (sesuai pendekatan timer Fase 2).
class AmbientPlayerController extends Notifier<AmbientPlayerState> {
  AudioPlayer? _player;

  @override
  AmbientPlayerState build() {
    ref.onDispose(() {
      _player?.dispose();
      _player = null;
    });
    return const AmbientPlayerState();
  }

  AudioPlayer _ensurePlayer() => _player ??= AudioPlayer();

  /// Mulai memutar [sound] secara loop. Dipanggil saat sesi dimulai.
  Future<void> start(AmbientSound sound) async {
    try {
      final player = _ensurePlayer();
      await player.setLoopMode(LoopMode.one);
      await player.setAsset(sound.filePath);
      await player.setVolume(1.0);
      unawaited(player.play());
      state = AmbientPlayerState(sound: sound, isPlaying: true, isMuted: false);
    } catch (e) {
      debugPrint('[AMBIENT] gagal memutar ${sound.filePath}: $e');
      state = const AmbientPlayerState();
    }
  }

  /// Play/pause manual dari UI (tidak menghentikan sesi).
  Future<void> togglePlayPause() async {
    final player = _player;
    if (player == null || !state.isActive) return;
    if (state.isPlaying) {
      await player.pause();
      state = state.copyWith(isPlaying: false);
    } else {
      unawaited(player.play());
      state = state.copyWith(isPlaying: true);
    }
  }

  /// Mute/unmute (volume 0 atau 1). Timer tetap berjalan.
  Future<void> toggleMute() async {
    final player = _player;
    if (player == null || !state.isActive) return;
    final muted = !state.isMuted;
    await player.setVolume(muted ? 0.0 : 1.0);
    state = state.copyWith(isMuted: muted);
  }

  /// Hentikan total — dipanggil saat sesi berakhir.
  Future<void> stop() async {
    final player = _player;
    if (player != null) {
      await player.stop();
    }
    state = const AmbientPlayerState();
  }
}

final ambientPlayerControllerProvider =
    NotifierProvider<AmbientPlayerController, AmbientPlayerState>(
  AmbientPlayerController.new,
);
