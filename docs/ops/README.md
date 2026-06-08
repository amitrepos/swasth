# Swasth Ops — Monday Quickstart

Run this **every Monday in ~15 minutes**. Full reasoning lives in `OPS_PLAYBOOK.md`.

## The habit
1. Open **Swasth Admin** → log in.
2. Add one row to `OPS_TRACKER_TEMPLATE.csv` with this week's numbers (sources below).
3. Colour each cell **green/red vs the TARGET row**.
4. Turn every **red** cell into one **action + owner + date**.
5. Update `PATIENT_ONBOARDING_TRACKER.csv` and `DOCTOR_ONBOARDING_TRACKER.csv` so every person has a `status` + `next_action`.

## Where each tracker column comes from

| Tracker column | Admin page | Field / how |
|---|---|---|
| `new_patients` | Overview | `signups_by_day` (sum this week, patients) |
| `new_doctors` | Doctors / Ops Monitor | new doctor rows this week · `doctor_ops` |
| `activation_pct` | Users | of this week's signups, % with Readings > 0 |
| `median_hrs_to_first_reading` | Users | `signed_up` → first reading (eyeball median) |
| `weekly_adherence_pct` | Overview | `streak_distribution` — % with streak ≥3 |
| `active_users` / `dau` / `mau` / `stickiness_pct` | Overview | `dau`, `mau`, `stickiness_pct` |
| `dormant_count` / `dormant_pct` | **Reading Reminders** | count in `inactive-users` ÷ active |
| `d30_retention_pct` | Overview | `d30_retention_pct` |
| `doctors_pending_verify` | Doctors / Alerts | unverified count · `DOCTOR_PENDING_VERIFICATION` |
| `doctor_verify_sla_breaches` | Doctors | rows with `time_in_queue_hours` > 24 |
| `doctor_activation_pct` | Doctors | % verified doctors with `patient_count` ≥ 1 |
| `critical_unanswered` | **Alerts** | `CRITICAL_READING_UNADDRESSED` count |

## Daily (not weekly): the adherence chase
The **Reading Reminders** tab is your daily list. Work it top-down (longest dormant first), send the
one-click WhatsApp, and mark the patient `dormant → next_action` in the patient tracker. This protects
the North Star (*patients logging ≥3 readings/week*) and is the single highest-leverage thing you do.

## When to hire
When the Reading Reminders list grows faster than you can WhatsApp it → hire the **Patient Success**
owner (Beat 3 in the playbook). That's the first role the business needs.
