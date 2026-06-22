-- =============================================================
-- Smart Learning Tracker — Migration 0004: AI Evaluation Summary Snapshot
-- Jalankan SETELAH 0001–0003 di Supabase SQL Editor.
-- JANGAN edit migration yang sudah dijalankan — ini file tambahan.
--
-- Tujuan: simpan snapshot data agregat (StudyAnalyticsSummary) saat laporan
-- AI dibuat, supaya saat membuka laporan lama, grafiknya bisa dirender ulang
-- persis seperti kondisi data waktu itu (tanpa re-query yang bisa berubah).
-- =============================================================

ALTER TABLE public.ai_evaluations
  ADD COLUMN IF NOT EXISTS summary_json JSONB;

COMMENT ON COLUMN public.ai_evaluations.summary_json IS
  'Snapshot StudyAnalyticsSummary (JSON) saat laporan dibuat — untuk render grafik laporan lama.';
