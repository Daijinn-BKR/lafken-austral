-- Lafken Austral: roles (admin / operario) + historial de cambios
-- Ejecutar UNA vez en Supabase > SQL Editor > Run (después de schema.sql)

-- ============ 1. Perfiles y roles ============
create table if not exists perfiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  rol text not null default 'operario' check (rol in ('admin','operario')),
  created_at timestamptz not null default now()
);

create or replace function es_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from perfiles where id = auth.uid() and rol = 'admin');
$$;

-- Cada usuario nuevo queda como operario automáticamente
create or replace function crear_perfil() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into perfiles (id, email) values (new.id, new.email) on conflict (id) do nothing;
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function crear_perfil();

-- Usuarios que ya existen: pasan a operario...
insert into perfiles (id, email)
select id, email from auth.users on conflict (id) do nothing;

-- ...y si todavía no hay ningún admin, el usuario más antiguo queda como admin
update perfiles set rol = 'admin'
where id = (select id from auth.users order by created_at limit 1)
  and not exists (select 1 from perfiles where rol = 'admin');

alter table perfiles enable row level security;
drop policy if exists "perfiles ver" on perfiles;
drop policy if exists "perfiles cambiar rol" on perfiles;
create policy "perfiles ver" on perfiles for select to authenticated
  using (id = auth.uid() or es_admin());
create policy "perfiles cambiar rol" on perfiles for update to authenticated
  using (es_admin() and id <> auth.uid()) with check (es_admin() and id <> auth.uid());

-- ============ 2. Permisos por tabla ============
-- Todos los usuarios: leer, crear y editar. Eliminar: solo admin.
-- (excepción: quitar un operario asignado a un servicio es parte de editarlo)
do $$
declare t text;
begin
  foreach t in array array['clientes','operarios','servicios','servicio_operarios'] loop
    execute format('drop policy if exists "auth todo %s" on %I', t, t);
    execute format('drop policy if exists "leer %s" on %I', t, t);
    execute format('drop policy if exists "crear %s" on %I', t, t);
    execute format('drop policy if exists "editar %s" on %I', t, t);
    execute format('drop policy if exists "eliminar %s" on %I', t, t);
    execute format('create policy "leer %s" on %I for select to authenticated using (true)', t, t);
    execute format('create policy "crear %s" on %I for insert to authenticated with check (true)', t, t);
    execute format('create policy "editar %s" on %I for update to authenticated using (true) with check (true)', t, t);
  end loop;
end $$;

drop policy if exists "eliminar clientes" on clientes;
create policy "eliminar clientes" on clientes for delete to authenticated using (es_admin());
drop policy if exists "eliminar operarios" on operarios;
create policy "eliminar operarios" on operarios for delete to authenticated using (es_admin());
drop policy if exists "eliminar servicios" on servicios;
create policy "eliminar servicios" on servicios for delete to authenticated using (es_admin());
drop policy if exists "eliminar servicio_operarios" on servicio_operarios;
create policy "eliminar servicio_operarios" on servicio_operarios for delete to authenticated using (true);

-- ============ 3. Historial de cambios ============
create table if not exists auditoria (
  id bigint generated always as identity primary key,
  fecha timestamptz not null default now(),
  usuario_id uuid,
  usuario_email text,
  tabla text not null,
  accion text not null check (accion in ('INSERT','UPDATE','DELETE')),
  registro_id uuid,
  antes jsonb,
  despues jsonb
);
create index if not exists auditoria_fecha_idx on auditoria (fecha desc);

alter table auditoria enable row level security;
drop policy if exists "auditoria solo admin" on auditoria;
create policy "auditoria solo admin" on auditoria for select to authenticated using (es_admin());
-- Sin políticas de insert/update/delete: nadie puede escribir ni borrar el historial desde la app.
-- Solo el trigger (security definer) lo llena.

create or replace function registrar_cambio() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_antes jsonb; v_despues jsonb;
begin
  if tg_op = 'INSERT' then v_despues := to_jsonb(new);
  elsif tg_op = 'UPDATE' then v_antes := to_jsonb(old); v_despues := to_jsonb(new);
  else v_antes := to_jsonb(old);
  end if;

  if tg_op = 'UPDATE' and v_antes = v_despues then return null; end if;

  insert into auditoria (usuario_id, usuario_email, tabla, accion, registro_id, antes, despues)
  values (
    auth.uid(),
    (select email from perfiles where id = auth.uid()),
    tg_table_name, tg_op,
    coalesce(v_despues->>'servicio_id', v_antes->>'servicio_id', v_despues->>'id', v_antes->>'id')::uuid,
    v_antes, v_despues
  );
  return null;
end $$;

do $$
declare t text;
begin
  foreach t in array array['clientes','operarios','servicios','servicio_operarios','perfiles'] loop
    execute format('drop trigger if exists auditar on %I', t);
    execute format('create trigger auditar after insert or update or delete on %I for each row execute function registrar_cambio()', t);
  end loop;
end $$;

-- Ajuste: clientes y operarios (catálogos)
-- Operario (rol): solo puede VER las listas. Crear, editar y eliminar: solo administrador.
do $$
declare t text;
begin
  foreach t in array array['clientes','operarios'] loop
    execute format('drop policy if exists "crear %s" on %I', t, t);
    execute format('drop policy if exists "editar %s" on %I', t, t);
    execute format('create policy "crear %s" on %I for insert to authenticated with check (es_admin())', t, t);
    execute format('create policy "editar %s" on %I for update to authenticated using (es_admin()) with check (es_admin())', t, t);
  end loop;
end $$;
