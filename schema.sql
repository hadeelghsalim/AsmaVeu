-- =================================================================
-- AsmaVeu — PostgreSQL schema
--
-- Two tables in the `public` schema:
--   contacts     one row per enrolled patient (identity + contact details)
--   assessments  one row per completed conversation, linked via contact_id
--
-- Apply with:
--   psql -U <user> -d asmaveu -f db/schema.sql
--
-- NOTE: `trigger` and `timestamp` are reserved words in PostgreSQL and
-- must be double-quoted wherever they appear, including in queries.
-- =================================================================

BEGIN;

-- -----------------------------------------------------------------
-- contacts — patient register
--
-- Contains direct identifiers and Catalan health-system identifiers
-- (CIP, medical record number). Special-category data under GDPR.
-- Never export, dump or commit the contents of this table.
-- -----------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.contacts (
    contact_id            character varying     NOT NULL,
    patient_id            character varying,
    phone                 character varying,
    email                 character varying,
    created_at            timestamp without time zone DEFAULT now(),
    telegram_id           character varying,
    first_name            character varying,
    last_name             character varying,
    date_of_birth         character varying,
    sex                   character varying(10),
    cip                   character varying,
    medical_record_number character varying,

    CONSTRAINT contacts_pkey PRIMARY KEY (contact_id)
);

-- The workflow looks up a patient by Telegram ID on every incoming
-- message, so this lookup must be fast and must not return duplicates.
CREATE UNIQUE INDEX IF NOT EXISTS contacts_telegram_id_key
    ON public.contacts (telegram_id)
    WHERE telegram_id IS NOT NULL;


-- -----------------------------------------------------------------
-- assessments — one completed symptom-reporting session
-- -----------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.assessments (
    session_id          character varying NOT NULL,
    contact_id          character varying,
    "timestamp"         date,

    -- Symptoms
    dyspnea             boolean,
    thoracic_pain       boolean,
    wheezing            boolean,
    cough_type          text,
    sputum_colour       text,

    -- Rescue inhaler
    inhaler             boolean,
    inhaler_date        date,
    inhaler_time_of_day text,
    inhaler_number      integer,
    inhaler_cadence     integer,
    inhaler_improve     boolean,
    inhaler_why         text,

    -- Oral corticosteroids
    prednisone          boolean,
    prednisone_date     date,
    prednisone_dosage   integer,

    -- Triggers
    "trigger"           boolean,
    trigger_reason      text,

    -- Metadata and triage
    patient_id          character varying,
    risk_score          text,

    -- Clinical follow-up status
    contacted           boolean DEFAULT false,
    contacted_by        text,
    contacted_at        timestamp without time zone,

    CONSTRAINT assessments_pkey PRIMARY KEY (session_id),
    CONSTRAINT assessments_contact_id_fkey
        FOREIGN KEY (contact_id)
        REFERENCES public.contacts (contact_id)
);

-- The nurse dashboard filters on "new today" vs historical, and orders
-- the queue by risk. These indexes back those two views.
CREATE INDEX IF NOT EXISTS assessments_timestamp_idx
    ON public.assessments ("timestamp" DESC);

CREATE INDEX IF NOT EXISTS assessments_contact_id_idx
    ON public.assessments (contact_id);

CREATE INDEX IF NOT EXISTS assessments_pending_idx
    ON public.assessments (contacted, "timestamp" DESC)
    WHERE contacted IS NOT TRUE;

COMMIT;
