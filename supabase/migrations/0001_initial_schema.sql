-- =============================================================
-- Smart Learning Tracker — Initial Schema
-- Jalankan seluruh file ini di Supabase SQL Editor
-- =============================================================

-- Enable UUID extension (sudah aktif di Supabase secara default)
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =============================================================
-- TABEL MASTER
-- =============================================================

-- 1. profiles — data profil user (extend auth.users bawaan Supabase)
CREATE TABLE IF NOT EXISTS public.profiles (
  id           UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name    TEXT,
  avatar_url   TEXT,
  timezone     TEXT NOT NULL DEFAULT 'Asia/Jakarta',
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
COMMENT ON TABLE public.profiles IS 'Profil user yang berelasi 1-1 dengan auth.users';

-- 2. topics — mata pelajaran / topik belajar yang dibuat oleh user
CREATE TABLE IF NOT EXISTS public.topics (
  id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id      UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  name         TEXT NOT NULL,
  color_hex    TEXT NOT NULL DEFAULT '#4A90D9',
  icon_name    TEXT,
  is_archived  BOOLEAN NOT NULL DEFAULT FALSE,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
COMMENT ON TABLE public.topics IS 'Topik/mata pelajaran yang dibuat oleh masing-masing user';

-- 3. mood_parameters — definisi parameter psikologis yang dinilai setelah sesi
--    Contoh bawaan: mood_umum, fokus, kelelahan, motivasi
CREATE TABLE IF NOT EXISTS public.mood_parameters (
  id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name         TEXT NOT NULL UNIQUE,
  description  TEXT,
  scale_min    SMALLINT NOT NULL DEFAULT 1,
  scale_max    SMALLINT NOT NULL DEFAULT 5,
  icon_name    TEXT,
  sort_order   SMALLINT NOT NULL DEFAULT 0
);
COMMENT ON TABLE public.mood_parameters IS 'Definisi parameter mood/psikologis yang tersedia secara global';

-- 4. ambient_sounds — katalog suara latar yang tersedia di aplikasi
CREATE TABLE IF NOT EXISTS public.ambient_sounds (
  id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name         TEXT NOT NULL,
  file_path    TEXT NOT NULL,        -- path di Supabase Storage atau URL aset statis
  category     TEXT NOT NULL DEFAULT 'nature', -- nature, cafe, white_noise, dsb.
  duration_sec INTEGER,              -- NULL jika loop tanpa batas
  is_active    BOOLEAN NOT NULL DEFAULT TRUE,
  sort_order   SMALLINT NOT NULL DEFAULT 0
);
COMMENT ON TABLE public.ambient_sounds IS 'Katalog ambient sound yang tersedia di aplikasi';

-- 5. learning_goals — target belajar mingguan yang ditetapkan user
CREATE TABLE IF NOT EXISTS public.learning_goals (
  id                 UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id            UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  topic_id           UUID REFERENCES public.topics(id) ON DELETE SET NULL,
  target_minutes     INTEGER NOT NULL DEFAULT 60,
  period             TEXT NOT NULL DEFAULT 'weekly',  -- daily | weekly | monthly
  target_date        DATE,
  is_achieved        BOOLEAN NOT NULL DEFAULT FALSE,
  created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
COMMENT ON TABLE public.learning_goals IS 'Target belajar per periode yang ditetapkan user';

-- =============================================================
-- TABEL TRANSAKSI
-- =============================================================

-- 6. study_sessions — riwayat setiap sesi belajar
CREATE TABLE IF NOT EXISTS public.study_sessions (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id         UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  topic_id        UUID REFERENCES public.topics(id) ON DELETE SET NULL,
  ambient_sound_id UUID REFERENCES public.ambient_sounds(id) ON DELETE SET NULL,
  started_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  ended_at        TIMESTAMPTZ,
  planned_duration_sec  INTEGER NOT NULL,    -- durasi yang diset di timer
  actual_duration_sec   INTEGER,             -- durasi aktual (bisa < planned jika dihentikan awal)
  notes           TEXT,                       -- catatan singkat tentang sesi
  status          TEXT NOT NULL DEFAULT 'in_progress'
                  CHECK (status IN ('in_progress', 'completed', 'cancelled')),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
COMMENT ON TABLE public.study_sessions IS 'Riwayat setiap sesi belajar yang dilakukan user';

-- 7. mood_journals — jurnal kondisi psikologis setelah setiap sesi selesai
CREATE TABLE IF NOT EXISTS public.mood_journals (
  id                   UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id              UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  session_id           UUID NOT NULL REFERENCES public.study_sessions(id) ON DELETE CASCADE,
  mood_parameter_id    UUID NOT NULL REFERENCES public.mood_parameters(id) ON DELETE RESTRICT,
  score                SMALLINT NOT NULL CHECK (score BETWEEN 1 AND 5),
  note                 TEXT,
  recorded_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(session_id, mood_parameter_id)   -- satu nilai per parameter per sesi
);
COMMENT ON TABLE public.mood_journals IS 'Nilai kondisi psikologis user per parameter setelah setiap sesi';

-- 8. ai_evaluations — hasil laporan/evaluasi yang dihasilkan LLM
CREATE TABLE IF NOT EXISTS public.ai_evaluations (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id         UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  period_start    DATE NOT NULL,
  period_end      DATE NOT NULL,
  session_count   INTEGER NOT NULL DEFAULT 0,
  total_minutes   INTEGER NOT NULL DEFAULT 0,
  prompt_used     TEXT,           -- prompt yang dikirim ke LLM (untuk debugging/audit)
  report_markdown TEXT,           -- isi laporan dalam format Markdown
  model_used      TEXT,           -- model OpenRouter yang dipakai
  tokens_used     INTEGER,
  generated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
COMMENT ON TABLE public.ai_evaluations IS 'Laporan evaluasi performa yang dihasilkan AI per periode';

-- 9. session_tags — tag bebas yang bisa ditambahkan user ke sesi (relasi many-to-many)
CREATE TABLE IF NOT EXISTS public.session_tags (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id     UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  session_id  UUID NOT NULL REFERENCES public.study_sessions(id) ON DELETE CASCADE,
  tag         TEXT NOT NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(session_id, tag)
);
COMMENT ON TABLE public.session_tags IS 'Tag bebas per sesi untuk klasifikasi/filter tambahan';

-- =============================================================
-- INDEXES
-- =============================================================

CREATE INDEX IF NOT EXISTS idx_study_sessions_user_id    ON public.study_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_study_sessions_started_at ON public.study_sessions(started_at DESC);
CREATE INDEX IF NOT EXISTS idx_study_sessions_topic_id   ON public.study_sessions(topic_id);
CREATE INDEX IF NOT EXISTS idx_mood_journals_session_id  ON public.mood_journals(session_id);
CREATE INDEX IF NOT EXISTS idx_mood_journals_user_id     ON public.mood_journals(user_id);
CREATE INDEX IF NOT EXISTS idx_ai_evaluations_user_id    ON public.ai_evaluations(user_id);
CREATE INDEX IF NOT EXISTS idx_topics_user_id            ON public.topics(user_id);
CREATE INDEX IF NOT EXISTS idx_session_tags_session_id   ON public.session_tags(session_id);

-- =============================================================
-- TRIGGER: auto-update updated_at pada profiles
-- =============================================================

CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

CREATE TRIGGER profiles_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- =============================================================
-- TRIGGER: auto-create profile saat user baru mendaftar
-- =============================================================

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name, avatar_url)
  VALUES (
    NEW.id,
    NEW.raw_user_meta_data->>'full_name',
    NEW.raw_user_meta_data->>'avatar_url'
  );
  RETURN NEW;
END;
$$;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- =============================================================
-- ROW LEVEL SECURITY (RLS)
-- =============================================================

ALTER TABLE public.profiles        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.topics          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.learning_goals  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.study_sessions  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.mood_journals   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_evaluations  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.session_tags    ENABLE ROW LEVEL SECURITY;

-- mood_parameters dan ambient_sounds adalah data global (read-only untuk semua user)
ALTER TABLE public.mood_parameters ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ambient_sounds  ENABLE ROW LEVEL SECURITY;

-- profiles: user hanya bisa akses profil sendiri
CREATE POLICY "profiles: own data only"
  ON public.profiles FOR ALL
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- topics: user hanya bisa akses topik miliknya
CREATE POLICY "topics: own data only"
  ON public.topics FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- learning_goals: user hanya bisa akses goal miliknya
CREATE POLICY "learning_goals: own data only"
  ON public.learning_goals FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- study_sessions: user hanya bisa akses sesi miliknya
CREATE POLICY "study_sessions: own data only"
  ON public.study_sessions FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- mood_journals: user hanya bisa akses jurnal miliknya
CREATE POLICY "mood_journals: own data only"
  ON public.mood_journals FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- ai_evaluations: user hanya bisa akses evaluasi miliknya
CREATE POLICY "ai_evaluations: own data only"
  ON public.ai_evaluations FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- session_tags: user hanya bisa akses tag sesi miliknya
CREATE POLICY "session_tags: own data only"
  ON public.session_tags FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- mood_parameters: semua authenticated user bisa read (data global)
CREATE POLICY "mood_parameters: read for all authenticated"
  ON public.mood_parameters FOR SELECT
  USING (auth.role() = 'authenticated');

-- ambient_sounds: semua authenticated user bisa read (data global)
CREATE POLICY "ambient_sounds: read for all authenticated"
  ON public.ambient_sounds FOR SELECT
  USING (auth.role() = 'authenticated');

-- =============================================================
-- DATA SEED: mood_parameters default
-- =============================================================

INSERT INTO public.mood_parameters (name, description, icon_name, sort_order) VALUES
  ('mood_umum',   'Perasaan umum / suasana hati saat belajar',          'sentiment_satisfied', 1),
  ('fokus',       'Tingkat konsentrasi dan perhatian selama sesi',       'center_focus_strong', 2),
  ('kelelahan',   'Tingkat kelelahan fisik atau mental (1=sangat lelah, 5=sangat segar)', 'battery_charging_full', 3),
  ('motivasi',    'Dorongan dan semangat untuk belajar saat memulai sesi', 'rocket_launch',     4)
ON CONFLICT (name) DO NOTHING;

-- =============================================================
-- DATA SEED: ambient_sounds placeholder
-- =============================================================

INSERT INTO public.ambient_sounds (name, file_path, category, sort_order) VALUES
  ('Hujan Ringan',    'sounds/rain_light.mp3',    'nature',      1),
  ('Hutan',           'sounds/forest.mp3',         'nature',      2),
  ('Kafe',            'sounds/cafe.mp3',            'cafe',        3),
  ('White Noise',     'sounds/white_noise.mp3',     'white_noise', 4),
  ('Lo-fi Beats',     'sounds/lofi_beats.mp3',      'music',       5)
ON CONFLICT DO NOTHING;
