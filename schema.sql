-- Rol de la aplicación: mínimo privilegio
CREATE ROLE app_user LOGIN PASSWORD 'app_pw_dev';
CREATE TABLE users(id serial PRIMARY KEY, email text UNIQUE NOT NULL, name text NOT NULL,
  cedula_hash text NOT NULL, cedula_last4 char(4) NOT NULL, pass_hash text NOT NULL,
  role text NOT NULL CHECK (role IN ('cliente','validador','soporte','admin')), created_at timestamptz DEFAULT now());
CREATE TABLE tickets(id uuid PRIMARY KEY DEFAULT gen_random_uuid(), seat text UNIQUE NOT NULL,
  owner_id int NOT NULL REFERENCES users(id), version int NOT NULL DEFAULT 1, used boolean NOT NULL DEFAULT false,
  pay_token text NOT NULL, last4 char(4) NOT NULL, created_at timestamptz DEFAULT now());
CREATE TABLE audit_logs(id bigserial PRIMARY KEY, ts text NOT NULL, event text NOT NULL, actor text NOT NULL,
  detail text NOT NULL, prev_hash text NOT NULL, hash text NOT NULL);
GRANT SELECT,INSERT,UPDATE ON users, tickets TO app_user;
GRANT SELECT,INSERT ON audit_logs TO app_user;          -- WORM: sin UPDATE/DELETE
GRANT USAGE,SELECT ON ALL SEQUENCES IN SCHEMA public TO app_user;
-- Inmutabilidad incluso para el dueño de la tabla
CREATE FUNCTION audit_immutable() RETURNS trigger AS $$ BEGIN RAISE EXCEPTION 'audit_logs es inmutable (WORM)'; END $$ LANGUAGE plpgsql;
CREATE TRIGGER no_mod BEFORE UPDATE OR DELETE ON audit_logs FOR EACH ROW EXECUTE FUNCTION audit_immutable();
CREATE TRIGGER no_trunc BEFORE TRUNCATE ON audit_logs FOR EACH STATEMENT EXECUTE FUNCTION audit_immutable();
