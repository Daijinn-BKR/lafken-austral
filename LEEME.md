# Lafken Austral · Registro de servicios

Web app (HTML + Supabase) para registrar servicios: cliente, fecha, operarios, tipo de servicio (Desratización, Desinfección, Desinsectación, Otros) y observaciones.

## Puesta en marcha

1. **Supabase**: crea un proyecto nuevo (separado de los otros).
2. En *SQL Editor* pega y ejecuta `schema.sql`.
3. En *Authentication > Users* crea los usuarios que van a entrar (correo + contraseña). En *Authentication > Providers > Email* desactiva "Allow new users to sign up" para que nadie más pueda registrarse.
4. En *Project Settings > API* copia la **Project URL** y la **anon public key** y pégalas en `config.js`.
5. Sube la carpeta a un repo de GitHub (ej. `lafken-austral`) y activa *Settings > Pages* (rama main, carpeta raíz).

## Uso

- **Clientes** y **Operarios**: se registran una vez; los operarios se pueden desactivar sin perder el historial.
- **Nuevo servicio**: elegir cliente, fecha, uno o varios operarios, uno o varios tipos de servicio (si marcas "Otros" se pide especificar) y observaciones.
- **Historial**: filtro por cliente, tipo de servicio y rango de fechas; editar o eliminar.
