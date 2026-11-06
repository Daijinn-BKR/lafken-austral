-- Lafken Austral: ejecutar UNA vez en Supabase > SQL Editor (después de migracion_roles.sql)

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
