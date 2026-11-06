-- Lafken Austral: registro de servicios
-- Pegar completo en Supabase > SQL Editor > Run

create table if not exists clientes (
  id uuid primary key default gen_random_uuid(),
  nombre text not null unique,
  created_at timestamptz not null default now()
);

create table if not exists operarios (
  id uuid primary key default gen_random_uuid(),
  nombre text not null unique,
  activo boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists servicios (
  id uuid primary key default gen_random_uuid(),
  cliente_id uuid not null references clientes(id),
  fecha date not null default current_date,
  tipos text[] not null default '{}',
  otros_detalle text,
  observaciones text,
  created_at timestamptz not null default now(),
  constraint tipos_validos check (tipos <@ array['Desratización','Desinfección','Desinsectación','Otros'])
);

create table if not exists servicio_operarios (
  servicio_id uuid not null references servicios(id) on delete cascade,
  operario_id uuid not null references operarios(id),
  primary key (servicio_id, operario_id)
);

create index if not exists servicios_fecha_idx on servicios (fecha desc);
create index if not exists servicios_cliente_idx on servicios (cliente_id);

-- Seguridad: solo usuarios con sesión iniciada pueden leer/escribir
alter table clientes enable row level security;
alter table operarios enable row level security;
alter table servicios enable row level security;
alter table servicio_operarios enable row level security;

create policy "auth todo clientes" on clientes for all to authenticated using (true) with check (true);
create policy "auth todo operarios" on operarios for all to authenticated using (true) with check (true);
create policy "auth todo servicios" on servicios for all to authenticated using (true) with check (true);
create policy "auth todo servicio_operarios" on servicio_operarios for all to authenticated using (true) with check (true);
