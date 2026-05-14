-- AI Phone Assistant — PostgreSQL schema (no Supabase)
-- Run once against your database, or wire into your migration tool.

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  phone_e164 TEXT NOT NULL UNIQUE,
  password_hash TEXT NOT NULL,
  display_name TEXT NOT NULL DEFAULT '',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE ai_profiles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  instructions TEXT NOT NULL DEFAULT 'You are a helpful phone assistant.',
  voice_id TEXT NOT NULL DEFAULT 'alloy',
  language TEXT NOT NULL DEFAULT 'en',
  is_default BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX ai_profiles_one_default_per_user
  ON ai_profiles (user_id)
  WHERE is_default;

CREATE TABLE contacts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  phone_e164 TEXT NOT NULL,
  display_name TEXT NOT NULL DEFAULT '',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user_id, phone_e164)
);

CREATE TABLE call_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  direction TEXT NOT NULL CHECK (direction IN ('inbound', 'outbound')),
  peer_e164 TEXT NOT NULL,
  started_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  ended_at TIMESTAMPTZ,
  ai_profile_id UUID REFERENCES ai_profiles (id) ON DELETE SET NULL,
  ai_handled BOOLEAN NOT NULL DEFAULT false,
  user_approved_ai BOOLEAN,
  transcript JSONB,
  summary TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX call_logs_user_started ON call_logs (user_id, started_at DESC);

CREATE OR REPLACE FUNCTION touch_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER users_touch_updated
BEFORE UPDATE ON users
FOR EACH ROW EXECUTE PROCEDURE touch_updated_at();

CREATE TRIGGER ai_profiles_touch_updated
BEFORE UPDATE ON ai_profiles
FOR EACH ROW EXECUTE PROCEDURE touch_updated_at();
