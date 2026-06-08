# Swasth Operations Playbook

> **Purpose.** Run Swasth like a business, not a side-project. This is the single manual for how we
> track health of the business each week, who owns what, and what "good" looks like. It is **no-code**
> — every number below already exists in the **Swasth Admin** dashboard. You don't build anything;
> you *read* the dashboard, fill the tracker, and act.
>
> **Audience.** Today: the founder + 0–1 ops helper (roles collapse into one weekly checklist).
> Tomorrow: 3–5 owners. Role definitions below are written so you can hand each "beat" to a hire
> without rewriting anything.

---

## 0. The one sentence that matters

> A health app does not win on **signups**. It wins on **people who keep logging readings** —
> because only a tracked patient gets a useful alert, a useful coaching nudge, and a reason to stay.

So our **North Star Metric** is:

### ⭐ North Star = number of patients logging **≥3 readings per week**

Everything else (signups, doctors, alerts) is a *lever* that moves this number. If this number grows
week over week, the business is real. If it stalls while signups grow, we are leaking — and the
playbook tells us exactly where.

---

## 1. The KPI tree (how the business fits together)

```
                       ⭐ NORTH STAR
              Patients logging ≥3 readings/week
                              │
        ┌─────────────┬───────┴───────┬──────────────────┐
        ▼             ▼               ▼                  ▼
   ACQUISITION    ACTIVATION    ADHERENCE/RETENTION   DOCTOR FLYWHEEL
   get them in    first reading  keep them logging     + CLINICAL SAFETY
        │             │               │                  │
   new patients   % logging ≤48h  % still logging    doctors verified fast,
   new doctors    time-to-first   dormant rate        patients linked,
   (CHW/referral) reading         D30 retention       critical readings answered
```

Read the tree **left to right = the patient's journey**, and **a leak at any stage caps the North
Star.** 100 signups with 20% activation and 40% dormancy is a worse business than 30 signups with 70%
activation and 10% dormancy. The tracker makes the leak visible.

---

## 2. The four weekly "beats"

Each beat = a job. For a 1–2 person team, **you run all four as a Monday checklist.** When you hire,
hand the whole beat (its metrics, its target, its action) to one person. Each beat below lists:
**What it means · Where to read it · Target · The action when off-target.**

### Beat 1 — ACQUISITION ("are new people coming in?")
- **What:** new patients and new doctors entering the funnel.
- **Where to read it:** Admin → **Overview** (`/admin/metrics` → `signups_by_day`) and **Ops Monitor**
  (`/admin/ops-metrics` → `user_ops.new_registrations_today/yesterday`, `doctor_ops`).
- **Target:** **15 new patients/week** (then ramp), **2 new doctors/week**.
- **Action when off-target:** acquisition is a *push* channel at this stage — CHW visits, doctor
  referrals, family/WhatsApp invites. If signups < target, the gap is outreach effort, not product.
  Log every source in `PATIENT_ONBOARDING_TRACKER.csv` so you know which channel works.

### Beat 2 — ACTIVATION ("did the people we onboarded actually start?")
- **What:** % of new signups who log **≥1 reading within 48h**, and the median **time-to-first-reading**.
- **Where to read it:** Admin → **Users** (sort by *Last Login* / *signed_up*; look for **Readings = 0**
  on recent signups — those are stalled activations). The Users list shows Profiles + Readings per
  person directly.
- **Target:** **60% activate within 48h**; **median < 48h**.
- **Action when off-target:** a signup with 0 readings after 2 days = a person who installed but never
  felt value. WhatsApp/call them with one specific ask ("log your sugar once, takes 20 seconds"). This
  is the cheapest growth you have — you already paid to acquire them.

### Beat 3 — ADHERENCE & RETENTION ("is everyone we onboarded *still* tracking?")  ← founder's #1 worry
- **What:** of the people already onboarded, how many are still logging — and who went dark.
- **Where to read it:** Admin → **Reading Reminders** (`/admin/inactive-users`) lists every **dormant
  profile** (glucose or BP missing > 2 days) with `days_since_log` and a one-click WhatsApp nudge.
  Plus **Overview** → `streak_distribution` and `d30_retention_pct`.
- **Targets:** **weekly adherence ≥ 50%** of active users log ≥3 readings/week · **dormant rate < 30%**
  · **D30 retention ≥ 30%** · **stickiness (DAU/MAU) ≥ 20%**.
- **Action when off-target:** this beat is a *daily* chase, not weekly. Work the Reading Reminders list
  top-down (longest dormant first), send the WhatsApp, and mark the person in
  `PATIENT_ONBOARDING_TRACKER.csv` (`status: dormant → next_action`). A patient who's been dark 14+ days
  with a prior critical reading is the highest-priority call you can make — the Alerts tab flags them.

### Beat 4 — DOCTOR FLYWHEEL + CLINICAL SAFETY ("is the supply side healthy and safe?")
- **What:** doctors get verified fast, get patients linked, and **every critical reading gets answered**.
- **Where to read it:** Admin → **Doctors** (`/admin/doctors` → `is_verified`, `time_in_queue_hours`,
  `patient_count`) and **Alerts** (`/admin/alerts` → `CRITICAL_READING_UNADDRESSED`,
  `DOCTOR_PENDING_VERIFICATION`).
- **Targets:** **verify doctors < 24h** · **doctor activation: ≥1 patient linked within 14 days = 50%**
  · **critical reading answered < 2h, 100% of the time**.
- **Action when off-target:** verification is a same-day admin task — never let a doctor wait
  (a waiting doctor is a dead referral channel). An unanswered critical reading is a *safety* issue, not
  a metric: escalate immediately (call the linked doctor, or the patient).

---

## 3. Proposed benchmark targets (early-pilot — edit after you see baselines)

These are deliberately *ambitious-but-real* for a <100-user pilot. Replace with your own once the first
few weeks of the tracker show your true baseline.

| KPI | Target | Dashboard source |
|---|---|---|
| New patients / week | **15** (then ramp) | Overview · `metrics.signups_by_day` |
| New doctors / week | **2** | Ops Monitor · `ops-metrics.doctor_ops` |
| Activation (≥1 reading ≤48h) | **60%** | Users tab (Readings>0 on recent signups) |
| Median time-to-first-reading | **< 48h** | Users (`signed_up` vs first reading) |
| Weekly adherence (≥3 readings/wk) | **50%** of active | Overview · `streak_distribution` |
| Dormant rate (no reading 7d) | **< 30%** | Reading Reminders · `inactive-users` |
| D30 retention | **30%** | Overview · `metrics.d30_retention_pct` |
| Stickiness (DAU/MAU) | **20%** | Overview · `metrics.stickiness_pct` |
| Doctor verification SLA | **< 24h** | Doctors · `time_in_queue_hours` |
| Doctor activation (≥1 patient ≤14d) | **50%** | Doctors · `patient_count` |
| Critical reading answered | **< 2h, 100%** | Alerts · `CRITICAL_READING_UNADDRESSED` |

> **Reality check on "15/week":** today you have ~30–40 users total. 15/week is a stretch that forces
> real outreach. If that's not yet realistic given your time, set it to a number you'll actually hit and
> *raise it every month* — a target you always miss stops being a target.

---

## 4. The Monday ritual (15 minutes, every week)

1. Open Swasth Admin. Pull these **8 headline numbers** into a new row of `OPS_TRACKER_TEMPLATE.csv`:
   `new_patients, new_doctors, activation_pct, weekly_adherence_pct, dormant_pct, d30_retention_pct,
   doctors_pending_verify, critical_unanswered`.
2. **Colour each cell** vs its target (green = at/above, red = below). One glance = state of the business.
3. Turn every red cell into **one action** with an owner and a date:
   - low activation → list of 0-reading signups to WhatsApp.
   - high dormancy → work the Reading Reminders list, update `PATIENT_ONBOARDING_TRACKER.csv`.
   - doctors pending → verify them today.
   - critical unanswered → escalate now (safety).
4. Update the two pipeline trackers (patient + doctor) so every person has a `status` and a `next_action`.

That's it. The discipline is *weekly numbers → coloured vs target → action list*. Everything else is noise.

---

## 5. Ownership grid (RACI) — now vs when you hire

**R** = does the work · **A** = accountable (one person) · **C** = consulted · **I** = informed.

| Beat | Now (1–2 people) | When you hire (3–5) |
|---|---|---|
| Acquisition (patients + doctors) | **You (A/R)** | *Growth/Field Ops* (A/R), founder C |
| Activation (first reading) | **You (A/R)** | *Onboarding/Activation Owner* (A/R) |
| Adherence & Retention (the chase) | **You (A/R)** — daily | *Patient Success/CHW Lead* (A/R) — this is the first hire you need |
| Doctor flywheel + verification | **You (A/R)** | *Doctor Partnerships* (A/R) |
| Clinical safety (critical alerts) | **You (A)** | Founder/Clinical (A), doctor on-call R |

> **First hire signal:** when the Reading Reminders list grows faster than you can WhatsApp it, hire the
> **Patient Success** owner for Beat 3. That is the role that protects the North Star.

---

## 6. Files in this folder
- `OPS_PLAYBOOK.md` — this manual.
- `OPS_TRACKER_TEMPLATE.csv` — weekly scorecard (one row/week). Import to Google Sheets.
- `PATIENT_ONBOARDING_TRACKER.csv` — per-patient pipeline (the daily adherence-chase list).
- `DOCTOR_ONBOARDING_TRACKER.csv` — per-doctor pipeline.
- `README.md` — 1-page Monday quickstart.

> **What this intentionally is NOT (yet):** automated. Everything is manual copy from the dashboard.
> Once the cadence sticks, the natural upgrades are: a `/admin/export/*.csv` button, an in-app "Ops
> Funnel" tab, and a Monday auto-email of these numbers (the backend scheduler can already do it).
> Don't build those until the manual habit is real.
