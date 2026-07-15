-- =============================================================================
-- USER MANAGEMENT SCHEMA
-- PostgreSQL
-- Firebase handles: OAuth, Login, Password Reset
-- This DB handles: Authorization, Validation, Profile Data
-- =============================================================================

-- Enable UUID extension for primary key generation
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- -----------------------------------------------------------------------------
-- ENUMS
-- -----------------------------------------------------------------------------

CREATE TYPE user_role   AS ENUM ('user', 'admin');
CREATE TYPE user_status AS ENUM ('active', 'inactive', 'suspended', 'pending_verification');
CREATE TYPE gender_type AS ENUM ('male', 'female', 'non_binary', 'prefer_not_to_say', 'other');

-- -----------------------------------------------------------------------------
-- USERS TABLE
-- -----------------------------------------------------------------------------

CREATE TABLE users (
    -- Primary Key (UUID v4, compatible with Firebase UID style)
    id                  UUID            PRIMARY KEY DEFAULT gen_random_uuid(),

    -- Firebase Integration
    -- Stores the Firebase UID to link this record with the Firebase Auth user.
    -- Used for server-side token verification and authorization lookups.
    firebase_uid        VARCHAR(128)    UNIQUE,                         -- nullable if record created before Firebase link

    -- Identity
    username            VARCHAR(50)     UNIQUE NOT NULL,
    email               VARCHAR(255)    UNIQUE NOT NULL,

    -- Password (only populated for email/password sign-up; NULL for OAuth-only users)
    -- Firebase stores the actual credential; this hash is a local fallback/backup if needed.
    password_hash       TEXT,

    -- Profile
    first_name          VARCHAR(100)    NOT NULL,
    last_name           VARCHAR(100)    NOT NULL,
    gender              gender_type,
    phone_number        VARCHAR(20),                                     -- E.164 format recommended: +919876543210
    avatar_url          TEXT,                                            -- URL to storage bucket (Firebase Storage / S3)

    -- Authorization
    role                user_role       NOT NULL DEFAULT 'user',
    status              user_status     NOT NULL DEFAULT 'pending_verification',

    -- Audit Timestamps (auto-managed)
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

-- -----------------------------------------------------------------------------
-- INDEXES
-- -----------------------------------------------------------------------------

-- Fast lookups by Firebase UID (used on every authenticated request)
CREATE INDEX idx_users_firebase_uid    ON users (firebase_uid);

-- Fast lookups by email (login, reset checks)
CREATE INDEX idx_users_email           ON users (email);

-- Fast lookups by username (profile pages, mentions)
CREATE INDEX idx_users_username        ON users (username);

-- Filter active users quickly (dashboards, listings)
CREATE INDEX idx_users_status          ON users (status);

-- Filter by role (admin panels)
CREATE INDEX idx_users_role            ON users (role);

-- -----------------------------------------------------------------------------
-- AUTO-UPDATE updated_at TRIGGER
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW
    EXECUTE FUNCTION set_updated_at();

-- -----------------------------------------------------------------------------
-- CONSTRAINTS & VALIDATIONS
-- -----------------------------------------------------------------------------

-- Ensure email format is valid (basic check)
ALTER TABLE users
    ADD CONSTRAINT chk_users_email_format
    CHECK (email ~* '^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$');

-- Ensure phone number is in E.164 format if provided
ALTER TABLE users
    ADD CONSTRAINT chk_users_phone_format
    CHECK (phone_number IS NULL OR phone_number ~* '^\+[1-9]\d{6,14}$');

-- Ensure username contains only allowed characters (alphanumeric, underscores, hyphens)
ALTER TABLE users
    ADD CONSTRAINT chk_users_username_format
    CHECK (username ~* '^[A-Za-z0-9_\-]{3,50}$');

-- -----------------------------------------------------------------------------
-- ROW LEVEL SECURITY (Optional but recommended)
-- Enable if using Supabase or direct PostgREST access.
-- Comment out if access is only through a backend API.
-- -----------------------------------------------------------------------------

-- ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- Allow users to read/update only their own row
-- CREATE POLICY users_self_access ON users
--     USING (id = current_setting('app.current_user_id')::UUID);

-- Allow admins full access
-- CREATE POLICY users_admin_access ON users
--     USING (current_setting('app.current_user_role') = 'admin');

-- -----------------------------------------------------------------------------
-- COMMENTS (Documentation)
-- -----------------------------------------------------------------------------

COMMENT ON TABLE  users                    IS 'Core user records. Firebase handles auth; this table handles authorization and profile.';
COMMENT ON COLUMN users.id                 IS 'UUID primary key, auto-generated.';
COMMENT ON COLUMN users.firebase_uid       IS 'Firebase Auth UID. Nullable; set after Firebase user creation.';
COMMENT ON COLUMN users.username           IS 'Unique display handle. 3–50 chars, alphanumeric/underscore/hyphen.';
COMMENT ON COLUMN users.email              IS 'Unique verified email address.';
COMMENT ON COLUMN users.password_hash      IS 'bcrypt/argon2 hash. NULL for OAuth-only users (Google, Apple, etc.).';
COMMENT ON COLUMN users.first_name         IS 'User''s first name.';
COMMENT ON COLUMN users.last_name          IS 'User''s last name.';
COMMENT ON COLUMN users.gender             IS 'Self-reported gender identity.';
COMMENT ON COLUMN users.phone_number       IS 'Optional. E.164 format (e.g. +919876543210).';
COMMENT ON COLUMN users.avatar_url         IS 'URL to profile picture hosted on Firebase Storage or CDN.';
COMMENT ON COLUMN users.role               IS 'Authorization role: user | admin.';
COMMENT ON COLUMN users.status             IS 'Account lifecycle state: pending_verification | active | inactive | suspended.';
COMMENT ON COLUMN users.created_at         IS 'Record creation timestamp (UTC).';
COMMENT ON COLUMN users.updated_at         IS 'Last modification timestamp (UTC). Auto-updated by trigger.';
