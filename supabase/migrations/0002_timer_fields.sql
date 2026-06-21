-- =============================================================
-- Smart Learning Tracker — Migration 0002: Timer Fields
-- Jalankan SETELAH 0001 di Supabase SQL Editor.
-- JANGAN edit 0001 yang sudah dijalankan — ini file tambahan.
--
-- Tujuan: melengkapi tabel study_sessions agar mendukung
-- mode Pomodoro & Stopwatch sesuai kebutuhan Fase 2.
-- =============================================================

-- 1. Tambah kolom `mode` (pomodoro | stopwatch).
--    Default 'pomodoro' supaya baris lama (jika ada) tetap valid.
ALTER TABLE public.study_sessions
  ADD COLUMN IF NOT EXISTS mode TEXT NOT NULL DEFAULT 'pomodoro'
  CHECK (mode IN ('pomodoro', 'stopwatch'));

COMMENT ON COLUMN public.study_sessions.mode IS
  'Jenis timer sesi: pomodoro (ada target durasi) atau stopwatch (hitung naik).';

-- 2. planned_duration_sec harus NULLABLE.
--    Mode stopwatch tidak punya target durasi, jadi nilainya NULL.
ALTER TABLE public.study_sessions
  ALTER COLUMN planned_duration_sec DROP NOT NULL;

-- 3. Perbarui CHECK constraint status agar mendukung 'stopped_early'.
--    Nilai lama (in_progress, completed, cancelled) tetap dipertahankan
--    demi kompatibilitas; 'stopped_early' ditambahkan untuk sesi yang
--    dihentikan paksa sebelum target tercapai.
ALTER TABLE public.study_sessions
  DROP CONSTRAINT IF EXISTS study_sessions_status_check;

ALTER TABLE public.study_sessions
  ADD CONSTRAINT study_sessions_status_check
  CHECK (status IN ('in_progress', 'completed', 'cancelled', 'stopped_early'));

-- =============================================================
-- Catatan field per kebutuhan Fase 2 (sudah ada sejak 0001,
-- dikonfirmasi di sini sebagai dokumentasi):
--   topic_id              -> FK ke topics (sudah ada)
--   mode                  -> ditambahkan di migration ini
--   started_at, ended_at  -> sudah ada
--   planned_duration_sec  -> sudah ada (kini nullable)
--   actual_duration_sec   -> sudah ada (dihitung dari timestamp)
--   status                -> sudah ada (kini termasuk stopped_early)
-- =============================================================
