# Figures

Screenshots of the AsmaVeu nurse-facing dashboards, captured from the working system running on the project's Raspberry Pi.

**All figures show synthetic records.** Contact IDs are sequential (`C002`, `C022`), CIP identifiers mirror them (`CIP002`, `CIP022`), and the clinician name is a placeholder. No real patient data appears in any image in this repository.

Full descriptions of every card and its clinical purpose are in [`../dashboard.md`](../dashboard.md).

---

### `01_mailbox_triage_overview.png`

**AsmaVeu Mailbox — Daily Patients Triage Overview.** The triage queue.

Three summary cards give the shape of the day (assessments received today, how many scored High risk, how many patients started or increased prednisone). Below them, the General Triage view lists one row per assessment with conditional formatting: red for positive alarm symptoms, amber for prednisone use, green for cases already contacted.

The `Contacted` / `Contacted By` / `Contacted At` columns are what make this a working queue rather than a static report — outstanding cases are visually distinct from handled ones, and the queue empties over a shift.

*Suggested caption:* Mailbox dashboard showing the daily triage queue. Summary cards report intake volume, high-risk count and prednisone initiations; the table below lists individual assessments with symptom-based conditional formatting and follow-up status.

---

### `02_patient_details.png`

**Patient Details.** The individual record, reached by clicking a contact ID in the Mailbox.

The most recent assessment is split across three cards following clinical reasoning — Symptoms, Prednisone & Trigger, and Rescue inhaler — with the full Assessment history table beneath. This is where a single reading becomes a trajectory: whether this is the patient's first bad day or their fourth in a week, and whether prednisone dose has been climbing.

*Suggested caption:* Patient Details dashboard for a single contact, filtered by contact ID. Current symptoms, corticosteroid use and rescue-inhaler pattern are shown alongside the complete assessment history.

---

### `03_mark_as_contacted_action.png`

**The write-back action.** A Metabase action, not a query.

Submitting the form writes `contacted = true`, `contacted_by` and `contacted_at` back to the `assessments` table. This is the only point in the system where a clinician writes to the database, and it is what closes the loop — the patient leaves the outstanding queue, timestamped and attributed.

Worth showing explicitly in the thesis: it distinguishes AsmaVeu from a read-only reporting layer.

*Suggested caption:* Write-back action recording clinical follow-up. The clinician's name and the contact ID are written to the assessments table, removing the case from the outstanding queue.

---

### `04_symptom_trend_over_time.png`

**Symptom trend over time.** Dyspnoea, wheezing and chest pain plotted by date for one patient.

Turns the assessment history into a visual pattern, making symptom clustering and escalation legible at a glance in a way the table cannot.

Note: the chart legend reads `chest_pain` while the underlying database column is `thoracic_pain`. Worth unifying before this figure is finalised for the report.

*Suggested caption:* Longitudinal symptom trend for a single patient, showing reported dyspnoea, wheezing and chest pain over time.

---

## Adding new figures

Keep the `NN_snake_case_name.png` convention so figures stay ordered, and add an entry here when you add an image. Before committing any screenshot, confirm the visible data is synthetic — Git history preserves deleted files, so a screenshot containing a real name, CIP or medical record number cannot simply be removed later.
