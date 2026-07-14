-- 「保存した図書館（ウィッシュリスト）」を端末をまたいで保持するためのテーブル。
-- Supabase の SQL Editor で一度だけ実行してください。
-- （visited_libraries と同じ構成に、地図表示用の緯度経度を加えたもの）

create table if not exists public.wishlist_libraries (
    id           uuid primary key default gen_random_uuid(),
    device_id    text        not null,
    stable_key   text        not null,
    library_name text        not null,
    prefecture   text        not null default '',
    city         text        not null default '',
    address      text        not null default '',
    latitude     double precision not null default 0,
    longitude    double precision not null default 0,
    lib_id       text,
    created_at   timestamptz not null default now(),
    unique (device_id, stable_key)
);

-- device_id での絞り込みを速くする
create index if not exists wishlist_libraries_device_id_idx
    on public.wishlist_libraries (device_id);

-- 匿名キー（publishable key）から読み書きできるようにする。
-- ※ visited_libraries と同じポリシー方針に合わせています。
alter table public.wishlist_libraries enable row level security;

create policy "wishlist read"   on public.wishlist_libraries for select using (true);
create policy "wishlist insert" on public.wishlist_libraries for insert with check (true);
create policy "wishlist update" on public.wishlist_libraries for update using (true) with check (true);
create policy "wishlist delete" on public.wishlist_libraries for delete using (true);
