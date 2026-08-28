# AsmaVeu

A conversational triage system for non-urgent asthma symptom monitoring, built for the Severe Asthma Unit at Hospital Clínic de Barcelona.

Patients report worsening respiratory symptoms to a Telegram bot, by text or voice note, in whichever language they prefer. An LLM agent conducts a structured clinical interview, normalises the answers into English, and writes them to a PostgreSQL database. Nurses review incoming cases on a Metabase dashboard, prioritised by an automatically calculated risk score.

AsmaVeu is **not** a medical device and does not give medical advice. It is an intake and triage-support layer. Patients are told explicitly to use emergency services if symptoms worsen.

Master's thesis project, 2026.

---

## Why

Pulmonary exacerbations in severe asthma are common and costly, and much of the management burden falls on nurses doing manual telephone follow-up. Symptom information arrives unstructured, in several languages, and is rarely captured in a form that can be filtered or trended. AsmaVeu tests whether a conversational agent can collect that information reliably enough to be clinically useful, while leaving all clinical judgement with the care team.

---

## Architecture

```
Patient (Telegram)
        │  text or voice note
        ▼
  Telegram Bot API
        │  polled every 5s with offset tracking
        ▼
┌───────────────────────────────────────────────┐
│  n8n workflow                                 │
│                                               │
│   Switch: voice or text?                      │
│      ├── voice → Whisper transcription        │
│      └── text  → passthrough                  │
│                    │                          │
│                 Merge (single conversation)   │
│                    │                          │
│              AI Agent (GPT)                   │
│              + windowed memory                │
│              + system prompt                  │
│                    │                          │
│      ┌─────────────┴─────────────┐            │
│      ▼                           ▼            │
│  reply to patient        write assessment     │
└───────────────────────────────────────────────┘
                                    │
                                    ▼
                            PostgreSQL
                          contacts / assessments
                                    │
                                    ▼
                          Metabase dashboard
                              (nursing staff)
```

### Why polling rather than webhooks

The system runs on a Raspberry Pi behind a home network with no stable public HTTPS endpoint, so Telegram cannot deliver webhooks to it. Instead a schedule trigger calls `getUpdates` every five seconds and stores the `update_id` offset in an n8n data table, so each message is processed exactly once and nothing is lost across restarts.

---

## Repository contents

| Path | What it is |
|------|-----------|
| `workflow/asmaveu_workflow.json` | The complete n8n workflow, importable into any n8n instance. Credentials are referenced, never embedded. |
| `prompts/` | The agent's system prompt, kept as readable Markdown outside the workflow JSON. |
| `db/` | SQL schema for the `contacts` and `assessments` tables. |
| `.env.example` | Every environment variable the system needs, with values blanked. |

---

## Data model

**`contacts`** — one row per enrolled patient. Keyed on `contact_id`, linked to Telegram via `telegram_id`.

**`assessments`** — one row per completed conversation, foreign-keyed to `contacts.contact_id`:

- *Symptoms* — `dyspnea`, `thoracic_pain`, `cough_type`, `sputum_colour`, `wheezing`
- *Rescue medication* — `inhaler`, `inhaler_number`, `inhaler_cadence`, `inhaler_date`, `inhaler_time_of_day`, `inhaler_improve`, `inhaler_why`
- *Corticosteroids* — `prednisone`, `prednisone_dosage`, `prednisone_date`
- *Triggers* — `trigger`, `trigger_reason`
- *Metadata* — `session_id`, `contact_id`, `timestamp`, `risk_score`

The agent populates these through n8n's `$fromAI()` tool-calling mechanism, so the model fills typed database columns directly rather than emitting prose that has to be parsed.

### Risk score

A point is added for each of: any alarm symptom present (dyspnea at rest or chest pain); rescue inhaler used at intervals shorter than four hours; prednisone initiated or increased. The resulting 0–3 score orders the nurse's queue. It is a prioritisation aid, not a clinical grading.

---

## Running it

Requires Docker and Docker Compose.

```bash
git clone https://github.com/hadeelghsalim/AsmaVeu.git
cd AsmaVeu
cp .env.example .env    # then fill in every value
docker compose up -d
```

Services come up on: n8n `:5678`, Metabase `:3000`, pgAdmin `:5050`, PostgreSQL `:5432`.

Then:

1. Apply the schema in `db/` to the `asmaveu` database.
2. In n8n, import `workflow/asmaveu_workflow.json`.
3. Create the three credentials it expects — Telegram, OpenAI, PostgreSQL. The workflow references them by name, so it will bind automatically once they exist.
4. Activate the workflow.
5. Point Metabase at the same PostgreSQL database.

---

## Security and data protection

This system processes health data, which is special-category data under GDPR. Accordingly:

- No credentials are stored in this repository. The bot token is read at runtime from `$env.TELEGRAM_BOT_TOKEN`; API keys live in n8n's encrypted credential store.
- No real patient data is committed. Dashboard development uses synthetic records.
- `.env` and all data exports are git-ignored.
- The repository is private and access is limited to the project team.

If a credential is ever exposed, revoke it rather than deleting the commit — Git history preserves deleted content.

---

## Status

Telegram intake for text and voice, multilingual conversation with standardised English output, structured writes to PostgreSQL, risk scoring. Metabase dashboard separating new from historical cases, automated onboarding for first-time users (consent, name, contact details), unit-level severity trends.

---

## Acknowledgements

Supervised by Dr. Rubén and Isaac, with clinical input from the Severe Asthma Unit, Hospital Clínic de Barcelona.
