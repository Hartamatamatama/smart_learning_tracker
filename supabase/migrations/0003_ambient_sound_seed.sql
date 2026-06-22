-- =============================================================
-- Smart Learning Tracker — Migration 0003: Ambient Sound Seed
-- Jalankan SETELAH 0001 & 0002 di Supabase SQL Editor.
-- JANGAN edit migration yang sudah dijalankan — ini file tambahan.
--
-- Tujuan:
--  1. Tambah kolom `description` pada ambient_sounds (belum ada di 0001).
--  2. Ganti 5 baris seed placeholder dari 0001 dengan 5 ambient sound nyata
--     yang file-nya sudah diunduh ke assets/sounds/ (lihat CREDITS.md).
--     file_path mengarah ke asset bundel Flutter (bukan Supabase Storage),
--     dipakai langsung oleh just_audio via setAsset().
-- =============================================================

-- 1. Kolom deskripsi singkat.
ALTER TABLE public.ambient_sounds
  ADD COLUMN IF NOT EXISTS description TEXT;

COMMENT ON COLUMN public.ambient_sounds.description IS
  'Deskripsi singkat suara untuk ditampilkan di UI pemilihan.';

-- 2. Hapus seed placeholder lama dari 0001 (path pola 'sounds/%').
--    Aman karena belum ada study_session yang mereferensikannya.
DELETE FROM public.ambient_sounds
  WHERE file_path LIKE 'sounds/%';

-- 3. Insert 5 ambient sound nyata.
INSERT INTO public.ambient_sounds
  (name, description, file_path, category, is_active, sort_order)
VALUES
  ('Hujan',      'Suara hujan menerus yang menenangkan untuk fokus.',
   'assets/sounds/rain.mp3',     'nature',      TRUE, 1),
  ('Hutan',      'Kicau burung & suasana hutan yang segar.',
   'assets/sounds/forest.mp3',   'nature',      TRUE, 2),
  ('Kafe',       'Keramaian obrolan kafe yang hangat.',
   'assets/sounds/cafe.mp3',     'cafe',        TRUE, 3),
  ('Jangkrik Malam', 'Suara jangkrik & serangga malam yang ritmis.',
   'assets/sounds/crickets.mp3', 'nature',      TRUE, 4),
  ('Api Unggun', 'Gemeretak api unggun dengan hembusan angin.',
   'assets/sounds/campfire.mp3', 'nature',      TRUE, 5);
