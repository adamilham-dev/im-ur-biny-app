-- ============================================================================
-- I'm ur Biny — Koleksi dataset dari kios (sample collection)
-- ============================================================================
-- Tujuan: tiap kios menyimpan scan terkonfirmasi secara LOKAL (offline-first),
-- lalu menyinkronkan ke sini secara best-effort saat online. Data ini menjadi
-- gudang terpusat untuk retraining model.
--
-- MODEL: APPEND-ONLY. Tiap scan/koreksi = satu baris baru. Koreksi manual masuk
-- sebagai baris baru (label_source='human', captured_at lebih baru). Dedup &
-- "ambil label terbaru" dilakukan saat TRAINING, bukan di DB. Ini membuat RLS
-- bisa MURNI insert-only (paling aman: anon key yang bocor tak bisa baca/ubah),
-- karena upsert/ON CONFLICT membutuhkan SELECT visibility yang sengaja tidak
-- kita berikan.
--
-- Cara pakai (project Supabase BARU milikmu — BUKAN project mana pun yang sudah
-- terhubung): jalankan file ini di SQL Editor, atau via `supabase db push`.
--
-- Kontrak label kelas (stabil, JANGAN diubah artinya):
--   kaca, kertas, logam, organik, plastik, residu, lainnya
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. Tabel metadata sample
-- ---------------------------------------------------------------------------
create table if not exists public.samples (
  id            uuid primary key default gen_random_uuid(),

  -- Identitas konten
  sha256        text        not null,                 -- hash isi gambar (kunci dedup)
  phash         bigint,                               -- perceptual hash 64-bit (a/d-hash)

  -- Label & asal
  label         text        not null,                 -- 'kaca'|'kertas'|...|'lainnya'
  label_source  text        not null default 'model'  -- 'model' | 'human' (koreksi manual)
                  check (label_source in ('model', 'human')),
  item_name     text,                                 -- nama item bebas (opsional)
  confidence    real,                                 -- 0..1 dari model

  -- Konteks scan
  scan_mode     text        check (scan_mode in ('single', 'mixed')),
  model_version text,                                 -- versi model yang menghasilkan label

  -- Identitas device & file
  device_id     text        not null,                 -- id kios (stabil per device)
  image_path    text,                                 -- path di bucket storage 'waste-samples'

  -- Waktu
  captured_at   timestamptz not null,                 -- saat di-scan di device
  created_at    timestamptz not null default now()    -- saat baris masuk DB

  -- Append-only: TIDAK ada unique constraint. (device_id, sha256) boleh muncul
  -- lebih dari sekali (mis. koreksi). Lihat samples_dedup_idx di bawah.
);

comment on table public.samples is
  'Sample scan dari kios untuk retraining (append-only). label_source=human diberi bobot lebih tinggi; ambil baris captured_at terbaru per (device_id, sha256) saat training.';

create index if not exists samples_label_idx        on public.samples (label);
create index if not exists samples_device_idx       on public.samples (device_id);
create index if not exists samples_created_at_idx   on public.samples (created_at desc);
create index if not exists samples_label_source_idx on public.samples (label_source);
-- Bantu dedup / ambil-terbaru saat training.
create index if not exists samples_dedup_idx
  on public.samples (device_id, sha256, captured_at desc);

-- ---------------------------------------------------------------------------
-- 2. Row Level Security
-- ---------------------------------------------------------------------------
-- Model keamanan MVP: kios hanya boleh INSERT/UPSERT. Tidak boleh membaca,
-- mengubah, atau menghapus data kios lain. Pembacaan untuk analitik/training
-- dilakukan lewat service_role (server/Studio), BUKAN dari app.
--
-- CATATAN PRODUKSI: untuk pengetatan, ganti `anon` dengan sesi anonymous-auth
-- (auth.signInAnonymously) dan batasi `device_id = auth.uid()`. Untuk MVP,
-- insert-only via publishable/anon key sudah cukup selama key TIDAK punya hak
-- baca dan bucket bersifat privat.
alter table public.samples enable row level security;

drop policy if exists "kiosk can insert samples" on public.samples;
create policy "kiosk can insert samples"
  on public.samples
  for insert
  to anon, authenticated
  with check (true);

-- TIDAK ada policy SELECT/UPDATE/DELETE untuk anon -> tabel MURNI insert-only.
-- Pembacaan untuk analitik/training lewat service_role (server/Studio).
-- Advisor akan menandai INSERT check(true) sebagai "RLS Policy Always True" —
-- ini DISENGAJA untuk MVP koleksi (key client write-only). Pengetatan produksi:
-- anonymous-auth + check (device_id = auth.uid()).

-- ---------------------------------------------------------------------------
-- 3. Storage bucket untuk gambar (privat)
-- ---------------------------------------------------------------------------
insert into storage.buckets (id, name, public)
values ('waste-samples', 'waste-samples', false)
on conflict (id) do nothing;

-- Kios boleh upload (insert object) ke bucket ini; tidak boleh baca/list/hapus.
drop policy if exists "kiosk can upload sample images" on storage.objects;
create policy "kiosk can upload sample images"
  on storage.objects
  for insert
  to anon, authenticated
  with check (bucket_id = 'waste-samples');

-- ---------------------------------------------------------------------------
-- 4. (Opsional, future) registry versi model + metrik
-- ---------------------------------------------------------------------------
-- create table if not exists public.models (
--   version     text primary key,
--   labels      text[] not null,
--   metrics     jsonb,            -- {"val_map50":..,"per_class_f1":{..}}
--   created_at  timestamptz not null default now()
-- );
