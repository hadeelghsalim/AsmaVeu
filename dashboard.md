# Nurse-facing dashboards

AsmaVeu's clinical interface is built in Metabase (open-source, self-hosted), reading directly from the same PostgreSQL database the n8n workflow writes to. There is no intermediate ETL step: what the conversational agent stores is what the nursing staff see.

Two linked dashboards cover the daily workflow:

1. **AsmaVeu Mailbox** — the triage queue. What arrived, who is urgent, who still needs contacting.
2. **Patient Details** — the individual record. Full symptom picture, medication use, and longitudinal history for one patient.

The Mailbox answers *who do I call next*. Patient Details answers *what do I need to know before I call them*.

All screenshots and figures in this repository use synthetic records. No real patient data appears in any committed file.

---

## Access

Metabase runs in Docker on the project's Raspberry Pi, exposed on port `3000`. The instance is reachable only over the private Tailscale network, not the public internet — there is no port forwarding and no public DNS entry. This matters given the data class involved: the dashboard is inside the private network perimeter by design, not protected by application login alone.

---

## Dashboard 1 — AsmaVeu Mailbox

Titled *Daily Patients Triage Overview*.

### Summary cards

Three scalar cards give the shape of the day before any table is read:

| Card | What it counts |
|------|----------------|
| **New today** | Assessments received today. The day's intake volume. |
| **High risk** | Assessments with `risk_score = 'High'`. Sets the urgency of the session. |
| **Prednisone started** | Patients who reported initiating or increasing oral corticosteroids. A direct exacerbation signal and, clinically, the strongest single indicator on the dashboard. |

### General Triage view

One row per assessment, with columns grouped to follow the clinical reasoning:

- **Identity** — `Patient` (contact ID) and `Contact → Cip`, the health-system identifier
- **Priority** — `Risk`, `Timestamp`
- **Alarm symptoms** — `Dyspnea`, `Thoracic Pain`, `Wheezing`
- **Other symptoms** — `Cough` (dry/wet/none), `Sputum` (colour, or none)
- **Corticosteroids** — `Prednisone`, `Since`
- **Follow-up state** — `Contacted`, `Contacted By`, `Contacted At`

Conditional formatting does the visual triage work. Red shading marks positive alarm symptoms, amber marks prednisone use, green marks completed contacts, and the `Risk` column is colour-coded by level. A nurse scanning the table sees the red-and-amber rows first without reading any text.

The `Contacted` group is what makes this a *mailbox* rather than a report: it distinguishes cases still awaiting a call from cases already handled, so the queue empties over the course of a shift.

### Drill-through

The `Patient` column is a click target. Selecting a contact ID opens Patient Details filtered to that patient, carrying the ID through as a dashboard parameter. This is the main navigation path — nurses are not expected to open the second dashboard directly.

---

## Dashboard 2 — Patient Details

Filtered by a single `Contact ID` parameter, shown top-left.

### Current assessment

Three cards break the most recent session into the categories a clinician actually asks about:

**Symptoms** — `Risk`, `Dyspnea`, `Chest Pain`, `Wheezing`, `Cough`, `Sputum`. One row, the latest assessment.

**Prednisone & Trigger** — `Taking prednisone`, `Since`, `Dosage (mg)`, `Trigger identified`, `Reason`. Groups the corticosteroid and trigger questions together because they are usually discussed in the same breath: *what changed, and did you escalate treatment*.

**Rescue inhaler** — `Used`, `Why didn't use`, `Time of day`, `Inhaler number`, `Hours between doses`, `Improvement`. Rescue-inhaler frequency is a core exacerbation metric; `Hours between doses` under 4 is one of the risk-score components. The `Why didn't use` column captures free-text reasons the agent extracted from the conversation ("does not have one", "patient did not use inhaler"), which is often more informative than the boolean.

### Assessment history

A scrollable table of every prior assessment for the patient, most recent first, with the full column set. This is where a single reading becomes a trajectory — a nurse can see whether this is a patient's first bad day or their fourth in a week, and whether prednisone dose has been climbing.

### Symptom trend over time

A line chart plotting `dyspnea`, `wheezing` and `chest_pain` against date. Turns the same history into a visual pattern, making clustering and escalation legible at a glance in a way the table cannot.

### Mark as contacted

A Metabase **action** — a write-back button, not a query. Clicking it opens a form with two fields:

- **Clinician Name** — free text, recorded in `assessments.contacted_by`
- **Contact ID** — pre-filled from the dashboard filter

Submitting writes `contacted = true`, `contacted_by = <name>`, and `contacted_at = <timestamp>` back to the `assessments` table.

This is the only point in the system where a clinician writes to the database, and it is what closes the loop: the patient disappears from the outstanding queue in the Mailbox, timestamped and attributed. Without it the Mailbox would be a read-only report that nurses would have to track separately on paper.

Enabling this requires model actions to be turned on for the database connection in Metabase, and a database user with write permission on `assessments`.

---

## The clinical loop

```
patient reports symptoms via Telegram
        ↓
n8n agent structures and stores the assessment
        ↓
Mailbox: case appears, risk-coded, contacted = false
        ↓
nurse opens Patient Details for context and history
        ↓
nurse calls the patient
        ↓
"Mark as contacted" → contacted = true, by whom, when
        ↓
case leaves the outstanding queue
```

---


