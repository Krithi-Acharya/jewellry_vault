# Database — User Management

## Overview

PostgreSQL schema for user profiles, authorization, and validation.
**Firebase** is the source of truth for authentication (OAuth, email/password, password reset).
This database handles everything **after** authentication: role-based access control, profile data, and account lifecycle.

---

## Files

| File | Purpose |
|---|---|
| [`schema.sql`](./schema.sql) | Full DDL — table, enums, indexes, triggers, constraints |

---

## Table: `users`

| Column | Type | Nullable | Default | Notes |
|---|---|---|---|---|
| `id` | `UUID` | NO | `gen_random_uuid()` | Primary key |
| `firebase_uid` | `VARCHAR(128)` | YES | — | Firebase Auth UID; links this record to Firebase user |
| `username` | `VARCHAR(50)` | NO | — | Unique; 3–50 chars, alphanumeric/`_`/`-` |
| `email` | `VARCHAR(255)` | NO | — | Unique; validated via regex constraint |
| `password_hash` | `TEXT` | YES | — | `NULL` for OAuth-only users (Google, Apple, etc.) |
| `first_name` | `VARCHAR(100)` | NO | — | |
| `last_name` | `VARCHAR(100)` | NO | — | |
| `gender` | `gender_type` | YES | — | Enum: `male`, `female`, `non_binary`, `prefer_not_to_say`, `other` |
| `phone_number` | `VARCHAR(20)` | YES | — | E.164 format: `+919876543210` |
| `avatar_url` | `TEXT` | YES | — | URL to Firebase Storage or CDN |
| `role` | `user_role` | NO | `'user'` | Enum: `user`, `admin` |
| `status` | `user_status` | NO | `'pending_verification'` | Enum: `active`, `inactive`, `suspended`, `pending_verification` |
| `created_at` | `TIMESTAMPTZ` | NO | `NOW()` | Auto-set on insert |
| `updated_at` | `TIMESTAMPTZ` | NO | `NOW()` | Auto-updated on every row change via trigger |

---

## Enums

```sql
user_role   → 'user' | 'admin'
user_status → 'active' | 'inactive' | 'suspended' | 'pending_verification'
gender_type → 'male' | 'female' | 'non_binary' | 'prefer_not_to_say' | 'other'
```

---

## Firebase Integration Notes

```
Firebase Auth ──► Verify ID Token (server-side)
                        │
                        ▼
                  Decode firebase_uid
                        │
                        ▼
              SELECT * FROM users WHERE firebase_uid = $1
                        │
                        ▼
               Check role / status in DB
                        │
                        ▼
                 Grant / Deny Access
```

- **`firebase_uid`** is the link between Firebase Auth and this table.
- On **first login**, create a row in `users` and store `firebase_uid`.
- On **every subsequent request**, verify the Firebase ID token, extract `firebase_uid`, query this table for `role` + `status`, and apply authorization logic.
- **`password_hash`** is only populated if you want a local fallback or dual-store strategy. For a pure Firebase setup, leave it `NULL`.

---

## Indexes

| Index | Column | Purpose |
|---|---|---|
| `idx_users_firebase_uid` | `firebase_uid` | Fast lookup on every authenticated request |
| `idx_users_email` | `email` | Login, uniqueness checks |
| `idx_users_username` | `username` | Profile pages, search |
| `idx_users_status` | `status` | Dashboard filtering |
| `idx_users_role` | `role` | Admin panel queries |

---

## Constraints

| Constraint | Rule |
|---|---|
| `chk_users_email_format` | Validates email via regex |
| `chk_users_phone_format` | Enforces E.164 format if phone is provided |
| `chk_users_username_format` | Alphanumeric + `_` `-`, 3–50 chars |

---

## Running the Schema

```bash
# Apply to a local PostgreSQL instance
psql -U <user> -d <database> -f database/schema.sql

# Or via a migration tool (e.g., Flyway, Liquibase, node-pg-migrate)
# Rename to: V1__create_users_table.sql
```
