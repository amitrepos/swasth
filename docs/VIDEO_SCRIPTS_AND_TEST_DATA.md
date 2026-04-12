# Swasth — Video Scripts, Test Data, and Production Notes

**Started:** 2026-04-11
**Last updated:** 2026-04-11 (session pause)
**Project owner:** Amit
**Goal:** Four 2-minute videos, one per audience, each with matching seed data on the dev DB so the recording shows realistic state without manually logging data during capture.

---

## 📍 Session state — pause point (2026-04-11)

| Deliverable | Status | Notes |
|---|---|---|
| **Production model** | ✅ Locked | App walkthrough + AI-generated stills only. No live-action. English master scripts; Script 1 translated externally for Hindi dub. |
| **Script 1 — Patient (Hindi dub target)** | ✅ Draft v3 complete | 7 beats, 2:00 total, second-by-second shot lists, 3 Banana prompts written |
| **Script 1 — Seed data** | ✅ Seeded on dev | `backend/seed_video_demo_patient.py` ran successfully. Ramesh profile_id=47 on dev. Verified via `v_patient_overview`. |
| **Script 1 — Images generated** | ✅ Done (user-reported) | User confirmed generation in an earlier turn. Files assumed to be in `docs/video_assets/script_1/` locally. |
| **Script 1 — Recording** | ⏳ Not started | User pausing before recording; will do in a later session |
| **Script 1 — Hindi translation** | ⏳ Not started | Will outsource to native speaker after recording |
| **Script 2 — Patient's relative (English)** | ✅ Draft v1 complete | 7 beats, 1:54 total, reuses Script 1 seed data + 2 small seed additions queued |
| **Script 2 — Seed updates** | ⏳ Not applied | 2 tweaks pending: (a) Priya's own profile, (b) English version of doctor note. See Test Data — Script 2 section. Non-blocking for image generation. |
| **Script 2 — Images generated** | ⏳ Not started | 3 prompts ready — see Script 2 section |
| **Script 2 — Recording** | ⏳ Not started | |
| **Script 3 — Doctor portal (English)** | ⏳ Not drafted | Next when session resumes |
| **Script 4 — Investor pitch (English)** | ⏳ Not drafted | After Script 3 |
| **TASK_TRACKER.md sync** | ✅ Updated this session | Pending orphan work: Dashboard doctor-section bug (Pratika), unified history timeline Stage 1 |

**Nothing has been committed to git this session.** All work is uncommitted on master (patient video artifacts) or sitting in tmp on the dev server (seed script). Review and commit when resuming.

### What to do when you resume this project

See the **"Resume checklist"** at the very bottom of this doc. It's a copy-pasteable sequence of next steps, ordered by priority.

---

## Production model — read this first

**We are NOT shooting any live-action footage.** Every video is:

1. **Screen-recorded app walkthrough** (tight, intentional tap sequences on the dev app with seeded data), plus
2. **AI-generated still images** from Google Imagen / "Nano Banana" for emotional / contextual beats where the app alone can't carry the moment.

No humans on camera. No stock footage. No phone-in-hand shots.

Each beat in each script is marked as either:
- **`APP:`** — screen capture of a specific app flow (exact tap sequence given)
- **`IMAGE:`** — Banana-generated still (full generation prompt given, ready to paste)

All scripts are written in **English first**. Script 1 (patient) will be translated to Hindi externally by a native speaker after the English is locked. Scripts 2/3/4 ship in English.

## Audiences, tones, and voiceover decisions

| # | Audience | Primary viewer | Length | Final VO language | Subtitles | Tone |
|---|---|---|---|---|---|---|
| 1 | **Patient** | Elderly diabetic/hypertensive, Bihar / Tier-2 India, 55–70yo | ~2:00 | **Hindi** (translated externally from English script) | English | Warm, reassuring, slow pace (~110 wpm in Hindi ≈ ~150 wpm English source) |
| 2 | **Patient's relative** | Adult child caregiver (30–50), urban India or diaspora, parent lives in small town | ~2:00 | **English** | None (optional Hindi) | Emotional, concrete ("your mother in Patna"), mid pace (~150 wpm) |
| 3 | **Doctor** | Verified MBBS / Ayush physicians, Tier 2–3, general physicians and endocrinologists | ~2:00 | **English** | None | Clinical, credibility-forward, practical (~150 wpm) |
| 4 | **Investor** | Seed / pre-seed VCs, health-tech or India-focused funds | ~2:00 | **English** | None | Confident, data-driven, quiet conviction (~155 wpm) |

**Why Hindi for patients only:** The patient watches the video themselves, usually in Hindi. The adult child and doctors watch in English (they're fluent and the professional vocabulary lands better). Investors get pitched in English regardless. Claude Code writes the English master; native speaker does the Hindi dub afterward.

---

## Production checklist — applies to all four videos

Before recording anything, lock these in:

1. **Record environment**: Flutter web build served from a clean dev DB, not production. Never record real user data.
2. **Seed the DB before each recording**: use the `Test Data` section for each script to pre-populate exactly what needs to appear on screen. This means no dummy typing during capture.
3. **Screen capture**: 1080p 60fps using OBS or QuickTime on macOS. Crop the browser chrome out in post.
4. **App language**: match the final VO. Script 1 = Hindi UI (because the patient video will ship with a Hindi dub). Scripts 2/3/4 = English UI. Hindi translations already exist in `lib/l10n/app_hi.arb` — we just toggle the language in Profile → Settings before recording.
5. **Record screen first, VO second**: capture all UI flows silently, then record VO to match the edited cut. This is the opposite of what feels natural but gives you control over timing and lets you re-do the VO without re-recording the screens.
6. **Generate all stills BEFORE recording day**: every `IMAGE:` beat in the scripts has a ready-to-paste Banana/Imagen prompt. Generate 2–3 variants per prompt, pick the best, save to `docs/video_assets/script_<N>/` (gitignored — don't commit AI-generated imagery). Have every still approved before you begin screen capture, so you're not blocked mid-edit.
7. **First 3 seconds are 80% of the video's success**: hook hard, visual AND auditory. If the viewer scrolls past 3 seconds you have them.
8. **Subtitles**: 2–3 words at a time, positioned 15% from the bottom, sans-serif, high contrast. For the Hindi version of Script 1, use canonical English phrasing from `app_en.arb` where possible so the subs feel consistent with the app.
9. **CTA placement**: 5 seconds before end, not at the very end. Give the CTA time to register.
10. **Visual sources — strict list**:
    - **App walkthrough** → screen-record the real dev app with seeded data. Never mock screens.
    - **Stills** → Google Imagen / "Nano Banana" only. No stock footage. No stock photos. No generic WhatsApp-chat mockups. Every still generated from the per-script prompts in this doc.
    - **Logo / badges / QR** → static vector assets from `assets/`.
11. **VO recording — English scripts (2, 3, 4)**: ElevenLabs "Ryan Multilingual" at 0.95 speed works fine. Same voice across all three for brand consistency.
12. **VO recording — Hindi dub for Script 1**: outsourced. After English script is locked here, send the English text to a native Hindi translator (Bihari-friendly, respectful `aap` throughout), then get the Hindi text voiced by a native speaker on Fiverr (~₹2–5k for 2 min). Do NOT use Google TTS — elderly viewers will clock it as synthetic and lose trust instantly.
13. **Export**: MP4 H.264, target 720p for WhatsApp share, 1080p for YouTube.
14. **Image prompt style guide** (applies to every `IMAGE:` beat):
    - Describe subject (age, ethnicity — explicitly "Indian", clothing, expression)
    - Describe scene (indoor/outdoor, time of day, location cues: "modest Indian middle-class home", "Bangalore apartment", "Tier-2 clinic waiting room")
    - Describe mood + lighting ("warm golden afternoon light", "soft morning daylight", "clinical white fluorescent")
    - Technical cues: "photorealistic, cinematic, shallow depth of field, 16:9 aspect ratio, no text, no watermark"
    - 50–80 words per prompt
    - Always explicitly say "Indian" — Banana/Imagen default to white subjects otherwise
    - Avoid anything that implies medical treatment happening on camera (no IV drips, no stethoscopes in use) — that's "stock medical" territory and looks fake

---

## Script 1 — Patient (English master; will be translated to Hindi for final VO)

**Status:** 🟡 Draft v3 — merged hook+pain, second-by-second shot lists, expanded prompts
**Audience:** Elderly Indian patient (target: 64yo Ramesh, Patna, T2D + hypertension)
**Runtime:** exactly 2:00
**Hook angle:** *When it matters most — can you find the number you need?* The wife is the hero; the husband is peripheral.
**Final VO language:** Hindi (translated externally from the English below)
**Subtitles:** English
**App UI language during recording:** Hindi

### How to read this script

Each beat is annotated **second by second** (e.g. `0:00–0:03`) so you can line up the screen recording against the VO without guessing. Every beat tells you:

- **VO** — the English line to give the translator (translate to Hindi for the final dub)
- **Visual** — `IMAGE` (Banana still with full prompt) or `APP` (exact tap sequence) or both
- **Shot list** — frame-by-frame timing inside the beat
- **State prerequisites** — what must already be true in the seeded dev DB for the beat to work

Total runtime = 2:00. 7 beats. 3 generated images. The rest is app walkthrough on Ramesh's seeded profile in Hindi UI.

---

### Beat 1 — Hook + Pain merged (0:00 – 0:12, 12 seconds)

**VO (12s of spoken audio):**
> "When it matters most — can you find the number you need?
> A notebook. Scribbled readings. A doctor two cities away.
> And a daughter who doesn't even know anything is wrong."

**Visual:** `IMAGE` (single still, held for 12 seconds with a slow 4% push-in)

**Shot list:**

| Time | What's on screen | VO overlay |
|---|---|---|
| 0:00.0 – 0:00.3 | Hard cut from black to Image 1 (full frame, slight letterbox) | *(silence, 0.3s beat of tension)* |
| 0:00.3 – 0:04.0 | Hold on close-up of her hands flipping the notebook, slow 2% push-in begins | "When it matters most — can you find the number you need?" |
| 0:04.0 – 0:07.5 | Push-in continues imperceptibly, viewer starts to notice the blurred husband in the background | "A notebook. Scribbled readings." |
| 0:07.5 – 0:10.0 | Push-in settles; husband's silhouette now clearly visible in deep bokeh, hand resting on forehead | "A doctor two cities away." |
| 0:10.0 – 0:12.0 | Final frame hold; her fingers pause on one page, frozen for a heartbeat of stillness | "And a daughter who doesn't even know anything is wrong." |
| 0:12.0 | Hard cut to black for 2 frames (80ms) | Transition into Beat 2 |

**Image 1 — Banana/Imagen prompt (expanded):**
```
Photorealistic cinematic still life, extreme close-up medium shot, the weathered hands of a 55-year-old Indian woman flipping urgently through the pages of a worn A5 handwritten medical notebook, her fingertips showing the faintest tremor of worry, she wears a simple cotton pale-yellow saree with a thin gold-threaded border, two gold bangles on her right wrist catching the warm afternoon light, a thin gold wedding ring visible on her left ring finger, her thumb pressing down on one open page, the notebook pages dog-eared and yellowed with age, filled with rows of handwritten blood pressure readings like "130/85" and blood sugar numbers like "142 F" in cursive blue ballpoint ink, some numbers underlined in red pen, a thin ribbon bookmark hanging from the spine, a small pencil resting across the adjacent page, the notebook rests on the edge of an old polished wooden dining table.

In the deep background, softly out of focus with strong bokeh, the partial silhouette of her elderly husband, around 64 years old, sitting at the same wooden table across from her, wearing a plain white cotton kurta, one weathered hand resting on his own forehead in quiet concern, a brass tumbler of water in front of him, his posture slightly slumped but not collapsed, dignified and still, a small framed black-and-white photograph of an older family member visible on the wall behind him.

Warm golden late-afternoon light pours in at a low angle from a window on the left side of the frame, casting a soft golden rim on her hands and the notebook edge, dust particles suspended in the shaft of light. The overall palette is warm ochres, faded cotton whites, and deep wood browns.

Camera: 85mm equivalent lens, shallow depth of field with focus squarely on her fingertips and the handwritten page, everything else falling off into soft bokeh. Composition follows rule of thirds — her hands anchor the lower-left third, the husband bokeh sits in the upper-right third, negative space on the top-left for VO subtitle placement.

Mood: urgent but tender, a silent domestic moment of worry that every adult child recognizes. Documentary photography style, Portra 400 film aesthetic with subtle grain, natural skin tones, no HDR look, no stock-photo gloss.

Technical: 16:9 cinematic aspect ratio, photorealistic, no text overlays, no watermarks, no medical equipment visible in frame, no visible symptoms or distress on the husband's face (he is simply still), no harsh shadows, no cartoon or illustrated look.
```

**State prerequisites:** none — this is a pure image cut, no app involvement.

---

### Beat 2 — Introduce Swasth (0:12 – 0:24, 12 seconds)

**VO (10s):**
> "Swasth is one app that holds your health, your family's health, and your doctor's view of you — all in one place."

**Visual:** `APP` (logo animation → Home screen, Hindi UI)

**Shot list:**

| Time | What's on screen | VO overlay |
|---|---|---|
| 0:12.0 – 0:13.0 | Fade up from black to full-frame Swasth logo (blue brand color, white "स्वास्थ" wordmark with the Devanagari ligature) | *(silence, just a soft musical stinger)* |
| 0:13.0 – 0:14.5 | Tagline "आप अकेले नहीं हैं" fades in below the logo for 1.5s | *(stinger continues)* |
| 0:14.5 – 0:15.0 | Hard cut from logo to **app Home screen** (Ramesh's profile, Hindi UI, full frame) | "Swasth is one app..." |
| 0:15.0 – 0:18.5 | Slow camera push-in from full Home to the top third of the screen (greeting + Wellness Score ring) | "...that holds your health," |
| 0:18.5 – 0:21.0 | Camera pans down slightly to reveal the Care Circle card with Priya + Arjun avatars | "your family's health," |
| 0:21.0 – 0:23.5 | Camera pans further down to reveal the Primary Physician card with Dr. Rajesh's linked badge | "and your doctor's view of you —" |
| 0:23.5 – 0:24.0 | Quick pull back to full Home screen frame | "all in one place." |

**App screen state (must be true on dev before recording):**

- URL: `https://65.109.226.36:8443/` logged in as `ramesh.demo@swasth.app`
- Active profile: Ramesh's own "मेरा स्वास्थ्य" (My Health)
- Language: Hindi (toggle in Profile → Settings)
- Home screen visible items (in order top to bottom):
  1. Greeting: "नमस्ते रमेश जी" + language/streak/points row
  2. Wellness Score ring showing **72/100** (green), sub-text "अच्छा"
  3. Care Circle card with Priya + Arjun avatars + relationship labels ("बेटी — बैंगलोर", "बेटा — दिल्ली")
  4. Vitals row: Last BP **132/82** (green "सामान्य" badge), Last Glucose **128 mg/dL** (green "सामान्य" badge)
  5. AI Health Insight card with the seeded Hindi insight text visible
  6. Primary Physician card: "डॉ. राजेश वर्मा — General Physician — वर्मा क्लिनिक पटना" with green ✓ Active

No empty state, no "log your first reading" prompt. If you see any empty cards, the seed didn't run correctly — re-run it before recording.

---

### Beat 3 — Auto-capture (0:24 – 0:44, 20 seconds)

**VO (18s):**
> "You take your BP the way you always do. Swasth reads it straight from your device. No typing. No forgetting. Same for your sugar — one tap, done."

**Visual:** `APP` only. Two consecutive Bluetooth flows: BP first, glucose second.

**Shot list — BP flow (11 seconds):**

| Time | What's on screen | VO overlay |
|---|---|---|
| 0:24.0 – 0:25.0 | Home screen, camera zooms onto the "Last BP" card, finger cursor hovers near the "+" button | "You take your BP the way you always do." |
| 0:25.0 – 0:26.5 | Tap + → "Add Reading" bottom sheet slides up with 3 options (Camera / Bluetooth / Manual) | *(continue VO)* |
| 0:26.5 – 0:28.0 | Tap "Bluetooth" → device picker opens showing BP Meter / Glucometer / Armband tiles | "Swasth reads it straight from your device." |
| 0:28.0 – 0:29.5 | Tap BP Meter → Scan button → "Omron HEM-7140T1" appears in list (seeded) | *(continue VO)* |
| 0:29.5 – 0:31.0 | Tap the Omron row → brief "Connecting..." animation (1.5s) | *(continue VO)* |
| 0:31.0 – 0:33.0 | Reading animates on screen: **132/82 mmHg, pulse 76, सामान्य** with a subtle success pulse | "No typing. No forgetting." |
| 0:33.0 – 0:35.0 | Auto-return to Home → Last BP card now shows the fresh 132/82 with "अभी-अभी" timestamp | *(brief pause)* |

**Shot list — glucose flow (9 seconds):**

| Time | What's on screen | VO overlay |
|---|---|---|
| 0:35.0 – 0:36.0 | Home screen, camera zooms onto "Last Glucose" card, finger cursor hovers near "+" | "Same for your sugar —" |
| 0:36.0 – 0:37.5 | Tap + → same Bluetooth sheet slides up | *(continue VO)* |
| 0:37.5 – 0:39.0 | Tap Glucometer tile → Scan → "Accu-Chek Instant" appears in list | *(continue VO)* |
| 0:39.0 – 0:40.5 | Tap Accu-Chek row → "Connecting..." → "Reading..." animations | *(continue VO)* |
| 0:40.5 – 0:42.5 | Reading animates: **128 mg/dL, सामान्य**, pulse of success state | "one tap, done." |
| 0:42.5 – 0:44.0 | Return to Home → Last Glucose card shows fresh 128 value + timestamp | *(hold for next beat)* |

**State prerequisites:**

- Seeded devices in the device picker: Omron HEM-7140T1 + Accu-Chek Instant (pre-paired mocks, so no real Bluetooth pairing needed during recording)
- The "just-added" readings (132/82 BP and 128 mg/dL glucose) should be the NEWEST readings on Ramesh's profile so they appear in the Home card as "अभी-अभी"
- Since the app is in demo mode for recording, the Bluetooth flow should accept the mock device without errors — verify before pressing record

---

### Beat 4 — Family sees you (0:44 – 1:04, 20 seconds)

**VO (18s):**
> "Your daughter in Bangalore. Your son in Delhi. They see your readings the moment you take them. Because caring at a distance shouldn't be harder than it has to be."

**Visual:** `APP` as the main frame + `IMAGE` 2 as a picture-in-picture cutaway

**Shot list:**

| Time | What's on screen | VO overlay |
|---|---|---|
| 0:44.0 – 0:46.0 | Home screen, slow scroll down to center the Care Circle card in frame | "Your daughter in Bangalore." |
| 0:46.0 – 0:48.0 | Tap Priya's avatar → mini popup card: "प्रिया कुमार — बैंगलोर — Editor access — पिछला दर्शन 2 मिनट पहले" | "Your son in Delhi." |
| 0:48.0 – 0:50.0 | Dismiss popup, stay on Home; **Image 2 (Priya in Bangalore) fades in as picture-in-picture in bottom-right corner** at 28% frame size with a soft 4px rounded border | "They see your readings" |
| 0:50.0 – 0:55.0 | Hold composition: app full frame + PiP of Priya looking at her phone bottom-right; subtle 1% push-in on the PiP only | "the moment you take them." |
| 0:55.0 – 0:58.0 | PiP fades out over 1 second; app fills frame again | "Because caring at a distance" |
| 0:58.0 – 1:01.0 | Subtle camera pan up on Home to show BOTH Priya and Arjun in the Care Circle card | "shouldn't be harder" |
| 1:01.0 – 1:04.0 | Final hold on Care Circle card with both family members visible | "than it has to be." |

**Image 2 — Banana/Imagen prompt (expanded):**
```
Photorealistic cinematic medium close-up, a 30-year-old Indian woman standing at the marble kitchen island of a contemporary Bangalore apartment, soft bright morning daylight streaming through a tall window on her left that throws a gentle halo on her dark shoulder-length hair, she holds a modern smartphone at chest height in both hands, eyes resting on the screen with a small involuntary exhale of relief — not a posed smile but the specific expression of someone who just saw a notification and knows a loved one is okay.

She wears a casual olive-green cotton kurta top with subtle embroidery at the neckline, a soft charcoal dupatta draped loosely over her left shoulder, minimal jewelry — small gold stud earrings and a thin gold chain. Her hair is loosely pulled back. Her expression is warm but understated: the corner of her mouth lifted slightly, her eyes softened with relief, no teeth showing, a candid unguarded moment.

Background, intentionally soft-focused with shallow depth of field: a filter coffee in a stainless-steel tumbler sits on the marble counter beside a closed silver laptop, a single fresh orange marigold in a small glass vase near the window (grounding her in Indian domestic context), muted modern neutral tones in the kitchen cabinetry, a hint of plants on a shelf behind her, the window reveals a softly blurred Bangalore apartment skyline with gentle morning haze.

Camera: 50mm equivalent lens, medium close-up framed from mid-chest up, shallow depth of field with razor-sharp focus on her eyes and the edge of the phone, background falling off into creamy bokeh. Composition: she's positioned slightly right of center on the rule-of-thirds line, negative space on the left of the frame for PiP placement and subtitle readability.

Mood: quiet relief, the kind of morning moment when a grown child hears their parent is fine — genuinely felt, not performed. Warm color grade with soft cool balance, cinematic, subtle film grain, natural skin tones.

Technical: 16:9 cinematic aspect ratio, photorealistic, no text, no watermark, no stock-photo gloss, no awkward hand poses, no exaggerated smile, no multiple people in frame — she is alone.
```

**State prerequisites:**

- `ProfileAccess` rows exist linking Priya (`priya.demo@swasth.app`) and Arjun (`arjun.demo@swasth.app`) to Ramesh's profile with `access_level = 'editor'`
- The `relationship` column on each access row reads "बेटी" and "बेटा" respectively (Hindi)
- The Care Circle card renders both avatars with initials fallback (no real photo upload needed)
- Priya's last-viewed timestamp should be "2 मिनट पहले" (2 minutes ago) to imply she's actively watching

---

### Beat 5 — Doctor sees you (1:04 – 1:32, 28 seconds) **[THE MOST IMPORTANT BEAT]**

**VO (26s):**
> "Your doctor doesn't wait for your next appointment. When your sugar spikes, when your BP climbs — they see it today. Because you linked a verified doctor with one tap. And your safety isn't a question of appointment slots."

**Visual:** `APP` (patient view) → `IMAGE` 3 (doctor cutaway) → `APP` (doctor portal)

**Shot list — patient view (10 seconds):**

| Time | What's on screen | VO overlay |
|---|---|---|
| 1:04.0 – 1:06.0 | Back to Home screen, camera scrolls down to the Primary Physician section | "Your doctor doesn't wait" |
| 1:06.0 – 1:08.5 | Linked-doctor card in focus: "डॉ. राजेश वर्मा — General Physician — वर्मा क्लिनिक पटना" with green ✓ "सक्रिय" (Active) badge | "for your next appointment." |
| 1:08.5 – 1:10.5 | Tap the doctor card → "मेरे लिंक्ड डॉक्टर" (My Linked Doctors) screen transitions in | "When your sugar spikes," |
| 1:10.5 – 1:14.0 | Linked doctor detail visible: consent_type, examined_on, condition "मधुमेह और उच्च रक्तचाप follow-up", **doctor's latest note visible**: "BP control बेहतर है। Amlodipine जारी रखें। 2 हफ्ते में fasting sugar दोबारा जाँच करें।" | "when your BP climbs —" |

**Shot list — image cutaway (3 seconds):**

| Time | What's on screen | VO overlay |
|---|---|---|
| 1:14.0 – 1:17.0 | **Hard cut to Image 3** (Dr. Rajesh in his consulting room looking at a tablet), held for 3 full seconds as a contextual breath | "they see it today." |

**Shot list — doctor portal (14 seconds):**

| Time | What's on screen | VO overlay |
|---|---|---|
| 1:17.0 – 1:18.0 | Hard cut to the **doctor portal** in a separate browser tab (seeded as Dr. Rajesh Verma's login, English UI — doctors use English) | *(brief pause)* |
| 1:18.0 – 1:22.0 | Triage Board visible: 6 patient cards, Ramesh's card prominently in view with a soft yellow "attention" indicator (from the one CRITICAL glucose from 10 days ago still in his 30-day history) | "Because you linked a verified doctor" |
| 1:22.0 – 1:24.0 | Tap Ramesh's card → smooth transition to doctor's patient detail view | "with one tap." |
| 1:24.0 – 1:28.0 | Patient detail view showing recent readings list, the **245 mg/dL critical reading from 10 days ago** highlighted in red, a green upward-trend arrow showing the last 5 fasting glucose values improving from 160 down to 128 | "And your safety isn't a question" |
| 1:28.0 – 1:32.0 | Hold on that screen for 4 full seconds — this is the longest dwell in the video on purpose | "of appointment slots." |

**Image 3 — Banana/Imagen prompt (new, expanded):**
```
Photorealistic cinematic medium shot, a 45-year-old Indian male general physician sitting at his modest wooden desk in a Tier-2 Indian town consulting room in Patna, leaning slightly forward, focused intently on a tablet screen held in both hands at waist height, the screen's cool blue-white glow casting gentle light upward onto his face, reading glasses pushed partway down his nose, one eyebrow slightly raised in attentive concentration — not worried, not smiling, just professionally engaged with what he's reading.

He wears a simple short-sleeved blue-and-white small-checked cotton shirt (explicitly NOT a stock-photo white coat — he is a real working doctor, not a clinical stereotype), no tie, sleeves unbuttoned at the cuffs, a plain ballpoint pen in his shirt pocket, simple wristwatch with a worn leather strap on his left wrist.

Desk details visible in soft focus: an old spiral-bound prescription pad to his left, a small potted tulsi plant, a ceramic cup of tea with steam just barely visible, a worn stethoscope coiled and RESTING on the desk (not draped around his neck — this is the key difference from stock medical imagery), a small desk lamp with a warm tungsten bulb on the right side providing the key warm light source.

Background, softly out of focus with strong bokeh: a wooden bookshelf holding medical reference books and a few framed certificates, a framed MBBS degree on the wall behind him slightly angled, a small wall calendar with Hindi dates, a Venetian blind on a side window letting in soft diffused daylight, a blood-pressure cuff folded neatly on a shelf — never in use, just present as environmental context.

Lighting: a warm tungsten desk lamp from the right creates a soft key light on his face and hands, a cool blue glow from the tablet screen lifts his features from below creating gentle modeling, soft ambient daylight from the Venetian blind behind him provides a subtle rim/hair light. The overall palette is warm wood browns, desaturated cotton blues, and ochre wall tones.

Camera: 50mm equivalent lens, 3/4 angle from his slightly upper left, medium shot framed from waist up, shallow depth of field with focus on his eyes and the upper edge of the tablet, background falling into creamy bokeh. Composition: his face anchors the center-right third of the frame, negative space on the left for subtitle readability.

Mood: quiet competent focus, the visual opposite of a stock-photo "doctor posing with stethoscope" shot. He looks like a real Tier-2 Indian physician in the middle of his working day, not a glamorized model.

Technical: 16:9 cinematic aspect ratio, photorealistic, documentary style, Kodak Portra aesthetic with subtle grain, natural skin tones, no text overlays, no watermark, no other people in frame, no patients visible, no visible symptoms of distress anywhere in the scene, no clinical-theater lighting, no white coat, no stethoscope draped around the neck.
```

**State prerequisites (heavy — verify all before recording):**

- Dr. Rajesh Verma account exists (`dr.rajesh@swasth.app`, `doctor_code = DRRAJ52`, `is_verified = true`)
- An `active` `DoctorPatientLink` between Dr. Rajesh and Ramesh's profile, `examined_on` 21 days ago, condition "Diabetes + hypertension follow-up"
- Doctor's note already exists in `doctor_notes` table with the "BP control better..." text, `is_shared_with_patient = true`
- Ramesh's profile has a CRITICAL glucose reading (245 mg/dL) with `reading_timestamp` exactly 10 days ago — this drives the yellow attention flag on the triage board
- Ramesh's last 5 fasting glucose readings show a clear improving trend: 160 → 148 → 142 → 135 → 128 (most recent)
- 4–5 OTHER seeded patients exist linked to Dr. Rajesh so the triage board isn't lonely — see "Test data — Script 1" for full list
- Dr. Rajesh's portal login URL bookmarked and pre-authenticated in a second browser tab before recording starts

---

### Beat 6 — AI insight (1:32 – 1:46, 14 seconds)

**VO (12s):**
> "Swasth watches your numbers, week after week. When something's drifting — it tells you, in your own language, long before it becomes a problem."

**Visual:** `APP` only — Home → AI card → Discuss with AI chat

**Shot list:**

| Time | What's on screen | VO overlay |
|---|---|---|
| 1:32.0 – 1:33.0 | Cut back to Ramesh's Home screen, scroll up to the AI Health Insight card | "Swasth watches your numbers," |
| 1:33.0 – 1:35.0 | AI Health Insight card in focus, showing the seeded Hindi text | "week after week." |
| 1:35.0 – 1:36.5 | Tap the card → the card expands or the full insight opens as a bottom sheet | *(brief pause)* |
| 1:36.5 – 1:38.0 | Full Hindi insight visible: "आपके fasting glucose में सुधार हो रहा है। इस हफ़्ते 3 readings normal range में हैं। Amlodipine ठीक से ले रहे हैं। अच्छा काम।" | "When something's drifting —" |
| 1:38.0 – 1:39.0 | Tap "Discuss with AI" button | *(brief pause)* |
| 1:39.0 – 1:41.5 | Chat screen slides in; AI greeting message is the same seeded insight | "it tells you," |
| 1:41.5 – 1:43.0 | User message appears: "क्या मुझे दवा कम करनी चाहिए?" (typed by cursor, not real typing — instant paste) | "in your own language," |
| 1:43.0 – 1:45.5 | AI reply slides in: "आपके readings अच्छे हैं, लेकिन दवा बदलने से पहले डॉ. वर्मा से सलाह ज़रूर लें। वह आपकी पूरी history देख रहे हैं।" | "long before it becomes a problem." |
| 1:45.5 – 1:46.0 | Brief hold on the chat screen before next beat | *(transition)* |

**State prerequisites:**

- `ai_insight_logs` has at least one row for Ramesh's profile with the exact Hindi text shown in 1:36.5
- `chat_messages` has NO prior messages for Ramesh (or we'll show old chat history by accident) — new conversation
- The AI response for the "दवा कम करनी चाहिए" question should be pre-seeded as a mock response that defers to the doctor (don't hit the real Gemini API during recording)

---

### Beat 7 — CTA (1:46 – 2:00, 14 seconds)

**VO (8s, leaves 6s of music-only tail):**
> "Swasth. Your health, with your family, with your doctor — every day. Download today."

**Visual:** End card graphic

**Shot list:**

| Time | What's on screen | VO overlay |
|---|---|---|
| 1:46.0 – 1:47.5 | Fade from the last chat screen to white (1.5s gentle fade, not hard cut) | *(silence, music swell begins)* |
| 1:47.5 – 1:49.5 | Swasth logo fades up at center of frame on a clean off-white background | "Swasth." |
| 1:49.5 – 1:52.0 | Tagline "आप अकेले नहीं हैं।" (You are not alone) fades in below the logo in brand typography | "Your health, with your family," |
| 1:52.0 – 1:55.0 | Play Store + App Store badges slide in from below the tagline, side by side | "with your doctor —" |
| 1:55.0 – 1:57.0 | QR code appears in the bottom-right, 15% of frame width, with small label "QR से install करें" | "every day." |
| 1:57.0 – 1:59.0 | Hold full end card composition | "Download today." |
| 1:59.0 – 2:00.0 | Final hold with all elements on screen, music decays | *(silence, fade out)* |

---

### Script 1 — timing budget

| Beat | Visual type | Runtime | Cumulative |
|---|---|---|---|
| 1 Hook + Pain (merged) | Image only | 0:12 | 0:12 |
| 2 Introduce Swasth | App | 0:12 | 0:24 |
| 3 Auto-capture | App (2 Bluetooth flows) | 0:20 | 0:44 |
| 4 Family | App + image PiP | 0:20 | 1:04 |
| 5 Doctor | App + image + app | 0:28 | 1:32 |
| 6 AI insight | App | 0:14 | 1:46 |
| 7 CTA | End card | 0:14 | **2:00** |

### Script 1 — English word count (for translator)

~235 English words total. Hindi translation will land around 210–235 words at ~110 wpm, giving roughly 2:00 spoken. If the translator's draft runs >2:10, tighten Beat 5's middle portion first (the doctor-portal visuals carry meaning; fewer words there still works).

### Script 1 — images to generate upfront (3 total)

| # | Beat | Purpose | File |
|---|---|---|---|
| img-1 | Beat 1 (Hook+Pain) | Wife's hands flipping notebook + husband in bokeh background | `docs/video_assets/script_1/01_hook_wife_notebook_urgency.png` |
| img-2 | Beat 4 (Family PiP) | Priya looking at phone in Bangalore kitchen, relieved | `docs/video_assets/script_1/02_family_priya_bangalore_morning.png` |
| img-3 | Beat 5 (Doctor cutaway) | Dr. Rajesh focused on tablet in his consulting room | `docs/video_assets/script_1/03_doctor_rajesh_clinic.png` |

For each prompt, generate 3–4 variants in Google Imagen / Nano Banana, pick the best. The `docs/video_assets/` folder is gitignored — don't commit the images.

---

## Test data — Script 1

**Target persona:** Ramesh Kumar, 64, Patna. Type 2 diabetes diagnosed 6 years ago, hypertension diagnosed 4 years ago. Lives with wife. Two adult children — daughter Priya in Bangalore (daughter-in-law in same house helps him log), son Arjun in Delhi.

**What needs to be true in the DB before recording:**

1. **User account for Ramesh**
   - Email: `ramesh.demo@swasth.app`
   - Full name: Ramesh Kumar
   - Phone: +91 98765 00001
   - Language preference: Hindi (UI renders in Hindi)
   - Timezone: Asia/Kolkata

2. **Primary profile (Ramesh's own — "My Health" rendered as "मेरा स्वास्थ्य")**
   - Age 64, Male, height 168 cm, weight 72 kg
   - Conditions: `["Diabetes T2", "Hypertension"]`
   - Medications: "Metformin 500mg (twice daily), Amlodipine 5mg (once daily)"

3. **Shared-with-family profile access** (for the "beti Bangalore mein hai" shot)
   - Priya Kumar: `priya.demo@swasth.app`, editor access on Ramesh's profile
   - Arjun Kumar: `arjun.demo@swasth.app`, editor access on Ramesh's profile
   - Both show in the Care Circle card on the home screen

4. **Health readings — last 45 days** (mix of normal, elevated, one critical)
   - **Glucose (fasting, morning)**: 30 readings total, average 142, range 108–195. One CRITICAL reading at 245 ten days ago (drives the "doctor ko seedha pata chal jayega" beat). Last 5 readings trend improving: 160 → 148 → 142 → 135 → 128.
   - **Blood pressure**: 28 readings, average 138/88, range 120/78 to 162/102. One HIGH-STAGE-2 reading at 162/102 nine days ago. Last 3 readings: 138/86, 134/84, 132/82 (trending down).
   - **SpO2**: 10 readings, all 96–99 (normal).
   - **Steps**: 14 days of daily counts, 3,000–6,500 range (reasonable for a 64yo).

5. **Meals logged — last 14 days**
   - ~20 meals covering typical Bihari diet: `HIGH_CARB` (chawal-dal-sabzi, parathe), `MODERATE_CARB` (roti-sabzi), `LOW_CARB` (egg + sabzi), `SWEETS` (gulab jamun on festival day). Each with Hindi `tip_hi`.

6. **Linked doctor via new system**
   - Dr. Rajesh Verma (`dr.rajesh@swasth.app`, `doctor_code=DRRAJ52`, `is_verified=true`, specialty "General Physician", clinic "Verma Clinic Patna")
   - Link status: `active`, `examined_on` = 3 weeks ago, `examined_for_condition` = "Diabetes + hypertension follow-up"
   - Doctor's last note (shared with patient): "BP control better. Continue amlodipine. Recheck fasting sugar in 2 weeks."
   - `triage_status = "stable"`, `compliance_7d = 6` (6 readings in last 7 days — good compliance)

7. **Critical alert log row**
   - One `critical_alert_logs` row from the 245 mg/dL glucose reading, status `sent`, channel `whatsapp`, recipient Priya. Shows on the admin dashboard and proves the alert pipeline fired.

8. **AI insight for the screen**
   - Latest `ai_insight_logs` entry with response: "आपके fasting glucose में सुधार हो रहा है। इस हफ्ते 3 readings normal range में हैं। अच्छा काम। Amlodipine ठीक से ले रहे हैं।"
   - (The recording will show this insight on the Home screen during the AI Health Insight section.)

### Seed script — to be written

The test data will be loaded via a new `backend/seed_video_demo_patient.py` script (pattern: idempotent, safe to re-run, delete-and-replace the demo user on each run). The script takes an env flag so it only ever runs against dev:

```bash
# On dev server:
cd /var/www/swasth/backend
SWASTH_ENV=dev venv/bin/python seed_video_demo_patient.py
```

The seed script is NOT yet written. It will be next once the Hindi script draft above is approved.

---

## Script 2 — Patient's relative (English VO)

**Status:** 🟡 Draft v1 — walkthrough format, awaiting review
**Audience:** Adult child caregiver (30–45), usually a daughter or son living in a metro (Bangalore / Delhi / Mumbai / abroad) whose parent lives in a Tier-2 town with chronic disease. The POV throughout this script is **Priya Kumar in Bangalore watching her father Ramesh in Patna**.
**Runtime:** 1:54 (under 2:00 budget)
**Hook angle:** *You ask "how are you, Papa" and the answer is always "sab theek hai". You never actually know. That not-knowing is the hardest part.*
**Final VO language:** English (no translation needed)
**Subtitles:** None (optional Hindi for extended reach later)
**App UI language during recording:** English (urban viewers prefer English UI)
**Reuses:** The `ramesh.demo@swasth.app` seed data from Script 1 — **no new seed script required**. This video just logs in as `priya.demo@swasth.app` instead.

### How to read this script

Same format as Script 1. Each beat has:
- **VO** — English line, spoken directly (no translation step)
- **Visual** — `IMAGE` or `APP` with explicit state
- **Shot list** — second-by-second timing
- **State prerequisites** — what must already be true on dev

---

### Beat 1 — Hook (0:00 – 0:12, 12 seconds)

**VO:**
> "You're in Bangalore. Your father is in Patna. 1,500 kilometers apart. And every time you ask how he's doing, the answer is always the same. 'Sab theek hai.' But you don't actually know."

**Visual:** `IMAGE` (single still, held for 12 seconds with a slow 3% push-in)

**Shot list:**

| Time | What's on screen | VO overlay |
|---|---|---|
| 0:00.0 – 0:00.4 | Hard cut from black to Image 1 | *(0.4s beat of silence)* |
| 0:00.4 – 0:04.0 | Hold wide composition — Priya small in frame, Bangalore skyline through window | "You're in Bangalore. Your father is in Patna." |
| 0:04.0 – 0:08.0 | Slow 3% push-in begins, her silhouette against the window growing slightly | "1,500 kilometers apart." |
| 0:08.0 – 0:10.5 | Push-in continues, phone in her hand becomes more visible | "And every time you ask how he's doing, the answer is always the same." |
| 0:10.5 – 0:12.0 | Final frame holds on her profile, the phone screen faintly visible | "'Sab theek hai.' But you don't actually know." |

**Image 1 — Banana/Imagen prompt:**
```
Photorealistic cinematic wide shot of a 30-year-old Indian woman standing alone in her contemporary Bangalore apartment, her silhouette framed against a large floor-to-ceiling window that reveals the softly blurred Bangalore skyline at golden hour, warm late-afternoon orange-pink sunlight streaming into the room from the window, casting her in silhouette with just a soft rim of warm light on the edge of her shoulder and hair.

She stands slightly off-center, positioned on the right-hand third of the frame, holding a modern smartphone loosely in her right hand at hip level, screen facing down, not actively using it but aware of it. She wears a simple charcoal-grey cotton kurta, hair loosely pulled back, minimal jewelry — thin gold chain catching the sunset light. Her posture is contemplative: shoulders slightly dropped, head turned toward the window, her expression half-hidden in profile but unmistakably thoughtful, possibly about to make a call she's been putting off.

The room is visible but softly out of focus: a modern grey sofa with a light throw, a framed abstract print on one wall, a tall indoor plant in a ceramic pot near the window, a muted mid-century rug on the floor. A closed laptop sits on a side table. Nothing flashy — a lived-in urban Indian professional's apartment, not a lifestyle magazine set.

Lighting: warm golden-hour backlight from the window dominates, softly silhouetting her; a gentle cool ambient fill from room lights barely lifts the shadow side of her face to preserve mood; dust particles float in the shaft of window light.

Camera: 35mm equivalent lens wide shot, her figure occupies only the right third of the frame, the left two-thirds is the soft-focused window and skyline, creating deliberate visual space that reinforces the theme of distance and solitude. Shallow depth of field with focus on her silhouette edge, background Bangalore skyline softly bokehed.

Mood: quiet contemplation, the kind of late-afternoon moment when an adult child stops working and realizes they haven't heard from their parents today. Cinematic, Kodak Portra 400 film aesthetic, subtle film grain, natural warm color grade.

Technical: 16:9 cinematic aspect ratio, photorealistic, documentary style, no text overlays, no watermark, no stock-photo gloss, no forced smiles, no phone screen glowing brightly (it should be dark/off in her hand).
```

---

### Beat 2 — Introduce Swasth from Priya's POV (0:12 – 0:24, 12 seconds)

**VO:**
> "Swasth changes that. Your father's profile is shared with you. When he logs a reading, you see it. No WhatsApp group. No awkward 'send me the numbers' text."

**Visual:** `APP` — Priya logs in on her laptop, profile picker, taps Papa's profile

**Shot list:**

| Time | What's on screen | VO overlay |
|---|---|---|
| 0:12.0 – 0:13.0 | Fade up from black to Swasth login screen, English UI, Priya's email pre-filled | "Swasth changes that." |
| 0:13.0 – 0:14.5 | Password field animates fill, tap Login | *(brief pause)* |
| 0:14.5 – 0:17.0 | **Profile picker screen** — two profiles visible: "My Health — Priya" (her own, empty state) and **"मेरा स्वास्थ्य — Papa"** (Ramesh's shared profile) with a small "Editor access" tag | "Your father's profile is shared with you." |
| 0:17.0 – 0:19.5 | Camera pans over to Papa's profile card, highlighting the "Editor — बेटी" relationship label | "When he logs a reading, you see it." |
| 0:19.5 – 0:21.0 | Tap on Papa's profile card → transition animation | *(brief pause)* |
| 0:21.0 – 0:24.0 | Home screen for Ramesh's profile loads (English UI this time — Priya's UI language preference) | "No WhatsApp group. No awkward 'send me the numbers' text." |

**State prerequisites:**

- Priya (`priya.demo@swasth.app`) must have her OWN profile in addition to editor access on Ramesh's profile, so the picker shows two cards. **The current Script 1 seed does NOT create Priya's own profile** — a small seed update is needed before recording Script 2. See "Test data — Script 2" below.
- Priya's UI language is English (default)

---

### Beat 3 — Real-time visibility (0:24 – 0:42, 18 seconds)

**VO:**
> "It's your lunch break. You open Swasth. There it is — his BP from this morning. 132 over 82. Normal. His sugar — 128. Normal. The notebook of scribbled numbers your mother used to read out loud over the phone? It's here now. And it's real."

**Visual:** `APP` — Ramesh's Home screen from Priya's session

**Shot list:**

| Time | What's on screen | VO overlay |
|---|---|---|
| 0:24.0 – 0:26.0 | Ramesh's Home screen full frame, English UI, camera starts centered | "It's your lunch break." |
| 0:26.0 – 0:28.0 | Camera pans to the Vitals row, Last BP card (132/82) comes into focus | "You open Swasth." |
| 0:28.0 – 0:30.5 | Close-up on Last BP card: "132/82 mmHg • just now • Normal" green badge | "There it is — his BP from this morning. 132 over 82. Normal." |
| 0:30.5 – 0:33.0 | Pan to Last Glucose card: "128 mg/dL • just now • Normal" green badge | "His sugar — 128. Normal." |
| 0:33.0 – 0:36.0 | Pull back to show the full Home screen with Wellness Score, Vitals, Care Circle visible | "The notebook of scribbled numbers" |
| 0:36.0 – 0:39.0 | Camera pans slightly down to Care Circle card — Priya sees herself in the circle ("बेटी — Editor") alongside Arjun | "your mother used to read out loud over the phone?" |
| 0:39.0 – 0:42.0 | Brief hold on the whole Home screen | "It's here now. And it's real." |

**State prerequisites:**

- All Script 1 seed state is valid for Ramesh's profile
- Priya's profile list shows "Editor access — बेटी" on Ramesh's profile (already seeded)

---

### Beat 4 — The critical moment, retrospectively (0:42 – 1:04, 22 seconds) **[MOST IMPORTANT BEAT]**

**VO:**
> "Ten days ago, your father's fasting sugar spiked to 245. Before he could even tell your mother. Before he could call you. Your phone buzzed. You were the first to know. Not a week later. Not at the next visit. That moment."

**Visual:** `APP` (History screen showing the critical reading) + `IMAGE` (Priya's phone with notification) + `APP` (back to Alert log)

**Shot list:**

| Time | What's on screen | VO overlay |
|---|---|---|
| 0:42.0 – 0:44.0 | From Home, tap "History" tab → History screen opens showing Ramesh's last 45 days of readings in a timeline | "Ten days ago," |
| 0:44.0 – 0:47.0 | Scroll back ~10 days in the timeline, the **CRITICAL 245 mg/dL** reading highlighted in a red badge | "your father's fasting sugar spiked to 245." |
| 0:47.0 – 0:50.0 | Tap the critical reading → detail view with timestamp, glucose value, status flag, "Alert sent to family" notation | "Before he could even tell your mother. Before he could call you." |
| 0:50.0 – 0:53.0 | **Hard cut to Image 2** (Priya in her kitchen, phone on counter with notification visible, hand reaching for it, morning light) — hold for 3 seconds | "Your phone buzzed." |
| 0:53.0 – 0:56.0 | Cut back to app — **Notifications / Alert history** screen showing the WhatsApp alert that went out 10 days ago with timestamp: "CRITICAL glucose reading — Ramesh (Papa) — 245 mg/dL — 10 days ago — Delivered" | "You were the first to know." |
| 0:56.0 – 1:00.0 | Pan slightly to emphasize the timestamp and delivery confirmation | "Not a week later. Not at the next visit." |
| 1:00.0 – 1:04.0 | Slight hold on the alert entry, then fade begins | "That moment." |

**Image 2 — Banana/Imagen prompt:**
```
Photorealistic cinematic medium close-up, a 30-year-old Indian woman standing in her bright contemporary Bangalore apartment kitchen in the early morning, caught mid-stride as she reaches toward a modern smartphone lying face-up on a white marble kitchen counter. The phone screen is illuminated by an incoming notification — a simple WhatsApp-style banner at the top of the screen visible in the frame, showing an app icon and a short line of text (readable as a health alert but not literal), the screen's pale cool glow subtly lighting her fingers as they approach.

She wears a casual ivory cotton kurta and soft pajama bottoms — early morning at home clothes, not dressed for work yet. Her hair is loose, slightly tousled from sleep. Minimal jewelry: only a thin gold chain. Her expression is one of sudden concentrated attention — the exact micro-expression of someone whose morning coffee thought was just interrupted by a notification that might matter. Eyes focused on the screen, brow slightly furrowed, mouth very slightly open, her reaching hand not yet touching the phone — suspended in the instant before she picks it up. This is the "uh oh" moment captured at its most honest.

Background, softly out of focus with shallow depth of field: a French press coffee maker on the counter with steam just barely visible, a small bowl of fresh oranges, a closed laptop beyond the coffee, a hanging plant near a sunlit window on the left side of the frame, warm morning daylight pouring in and bouncing off the white marble. Everything warm and domestic but the moment itself is charged.

Camera: 50mm equivalent lens, medium close-up from her chest up and slightly over the counter, framing both her face (center-left of frame) and the phone (lower-right of frame) in the same composition, shallow depth of field with focus shared between her eyes and the phone screen, background softly bokehed. Composition emphasizes the visual tension between her face and the phone.

Lighting: bright soft morning daylight from a large window on the left provides the warm key light on her face and clothes, the cool glow from the phone screen subtly underlights her reaching fingers creating gentle modeling. Overall palette: warm ivory, soft neutrals, a hint of cool blue from the phone.

Mood: the instant a caregiver realizes something might be wrong — the shift from ordinary morning to focused attention, captured before she even fully processes what she's seeing. Cinematic, Portra 400 aesthetic, subtle grain, natural skin tones.

Technical: 16:9 cinematic aspect ratio, photorealistic, documentary style, no text overlays, no watermark, no stock-photo gloss, no exaggerated panicked expression (she is concerned, not panicking), no posed movement.
```

**State prerequisites:**

- The critical 245 mg/dL glucose reading is 10 days old on Ramesh's profile (already seeded)
- `critical_alert_logs` row exists linking that reading to Priya as recipient with channel=whatsapp, status=sent (already seeded)
- The app must have a visible alert history or notifications screen that shows this entry — **if no such screen exists in the app, the Beat 4 "back to alert log" cut needs to be replaced with something else**. See caveats below.

---

### Beat 5 — The doctor is watching too (1:04 – 1:24, 20 seconds)

**VO:**
> "Scroll down. A note from Dr. Rajesh Verma. Nine days ago. He saw the same reading you did. He adjusted the treatment. 'BP control better. Continue amlodipine.' Your father's doctor was watching too. You weren't alone."

**Visual:** `APP` only — Primary Physician section → My Linked Doctors → shared doctor note

**Shot list:**

| Time | What's on screen | VO overlay |
|---|---|---|
| 1:04.0 – 1:06.0 | Cut back to Ramesh's Home screen, camera scrolls down to the Primary Physician section | "Scroll down." |
| 1:06.0 – 1:08.5 | Linked doctor card visible: "Dr. Rajesh Verma — General Physician — Verma Clinic Patna — ✓ Active" | "A note from Dr. Rajesh Verma." |
| 1:08.5 – 1:11.0 | Tap the doctor card → "My Linked Doctors" screen | "Nine days ago." |
| 1:11.0 – 1:14.5 | Linked doctor detail view showing: active since 3 weeks ago, examined_on, and the note text highlighted: "BP control better. Continue amlodipine. Recheck fasting sugar in 2 weeks." with a "9 days ago" timestamp | "He saw the same reading you did. He adjusted the treatment." |
| 1:14.5 – 1:17.5 | Close-up push-in on the note text itself | "'BP control better. Continue amlodipine.'" |
| 1:17.5 – 1:21.0 | Slight pull back to show the full linked-doctor card with Dr. Rajesh's verified badge | "Your father's doctor was watching too." |
| 1:21.0 – 1:24.0 | Final hold on the linked doctor card | "You weren't alone." |

**State prerequisites:**

- Doctor note from Dr. Rajesh-demo dated 9 days ago exists with exact text "BP control बेहतर है। Amlodipine जारी रखें..." — **note**: the seeded note is in Hindi because Ramesh's UI would render it, but Priya's UI is English. The app must either show the note in its original language or provide an English version. For recording simplicity, **seed a second note in English** for Beat 5 visibility. See test data section.

---

### Beat 6 — Editor access: log for them (1:24 – 1:42, 18 seconds)

**VO:**
> "And sometimes — when he forgets, when he's tired, when the reading is in his notebook but not in the app — you can log it for him. From 1,500 kilometers away. That's what family does."

**Visual:** `APP` (manual entry flow from Priya's session) + `IMAGE` (small PiP of phone showing "Papa" calling)

**Shot list:**

| Time | What's on screen | VO overlay |
|---|---|---|
| 1:24.0 – 1:26.0 | Back to Ramesh's Home screen from Priya's view, camera moves toward the "+" add reading button | "And sometimes —" |
| 1:26.0 – 1:28.0 | Tap "+" → Add Reading bottom sheet opens with 3 options (Camera / Bluetooth / Manual) | "when he forgets, when he's tired," |
| 1:28.0 – 1:30.5 | Tap **Manual** (not Bluetooth — she's 1,500km away from the device, which is the whole point) | "when the reading is in his notebook but not in the app —" |
| 1:30.5 – 1:33.5 | Manual entry form opens; systolic field focuses, value appears: 130. Diastolic: 84. Pulse: 76. Sample type: morning. | "you can log it for him." |
| 1:33.5 – 1:36.0 | **Image 3 (phone with "Papa calling" incoming) fades in as PiP in the bottom-right corner** at 25% frame size, implying she's logging this during a phone call with him | "From 1,500 kilometers away." |
| 1:36.0 – 1:38.5 | Tap Save → reading confirmation animates on, Home card updates | *(continue VO)* |
| 1:38.5 – 1:42.0 | PiP fades out, final hold on Home showing the fresh 130/84 reading | "That's what family does." |

**Image 3 — Banana/Imagen prompt:**
```
Photorealistic cinematic close-up product shot of a modern smartphone lying screen-up on a pale marble desk, the screen showing a full-screen incoming call interface with a clean modern design and the contact name "Papa" displayed prominently in large friendly typography at the top center of the screen, a soft circular avatar placeholder with a simple "P" initial above the name, green "Accept" and red "Decline" buttons at the bottom in the standard iOS/Android pattern, the call UI unmistakable at a glance. The phone's screen glows softly, casting gentle cool light on the marble surface around it.

The phone is positioned slightly off-center, angled at about 15 degrees from parallel. Beside the phone on the desk: a steaming ceramic coffee cup in the background (softly blurred), a pair of reading glasses folded, and the edge of an open laptop keyboard just visible at the top of the frame — context cues suggesting an urban professional working from home.

Background, deeply out of focus: warm diffused daylight from a window beyond, hints of indoor plants in soft green bokeh, the general warmth of a contemporary Bangalore apartment workspace.

Lighting: warm soft daylight from the upper-left provides the key, the phone screen's cool blue-white glow provides a gentle contrasting under-light on the marble surface, creating a subtle warm/cool duality that emphasizes the phone as the focal point. Shallow depth of field with razor focus on the phone screen and the name "Papa" — everything else falls off into dreamy bokeh.

Camera: macro/close-up shot at 50mm equivalent, framed tight on the phone occupying roughly 70% of the frame horizontally, the screen text perfectly legible, shot from a slight three-quarter angle from above. Composition: phone anchors the center-right of the frame, negative space on the left for PiP subtitle readability.

Mood: the specific emotional register of a phone call from a parent — warm, expected, loved, with the gentle pulse of an incoming call being the emotional anchor of the frame. Cinematic, clean product-photography aesthetic crossed with documentary warmth, subtle film grain, natural color palette.

Technical: 16:9 cinematic aspect ratio, photorealistic, no extraneous text on the phone UI beyond "Papa" and Accept/Decline, no watermark, no stock-photo gloss, no visible brand logos (keep the phone generic), no cracked screen or dated phone model, no other notifications visible.
```

**State prerequisites:**

- Priya has editor access (not viewer) on Ramesh's profile (already seeded from Script 1)
- Manual entry flow on the app works and validates a BP reading without Bluetooth

---

### Beat 7 — CTA (1:42 – 1:54, 12 seconds)

**VO:**
> "Swasth. For the daughters and sons who ask 'how was your BP today, Papa' — and for the ones who can actually know the answer. Download today."

**Visual:** End card

**Shot list:**

| Time | What's on screen | VO overlay |
|---|---|---|
| 1:42.0 – 1:43.5 | Gentle fade from Home screen to clean white background | *(silence, soft music swell)* |
| 1:43.5 – 1:45.5 | Swasth logo fades up center-frame | "Swasth." |
| 1:45.5 – 1:49.0 | Tagline fades in below logo: **"For the people who care at a distance."** | "For the daughters and sons who ask 'how was your BP today, Papa' —" |
| 1:49.0 – 1:52.0 | Play Store + App Store badges slide up side-by-side | "and for the ones who can actually know the answer." |
| 1:52.0 – 1:54.0 | QR code appears bottom-right, final hold | "Download today." |

---

### Script 2 — timing budget

| Beat | Visual type | Runtime | Cumulative |
|---|---|---|---|
| 1 Hook | Image only | 0:12 | 0:12 |
| 2 Introduce (from Priya's POV) | App | 0:12 | 0:24 |
| 3 Real-time visibility | App | 0:18 | 0:42 |
| 4 The critical moment | App + image + app | 0:22 | 1:04 |
| 5 Doctor watching too | App | 0:20 | 1:24 |
| 6 Editor access (log for them) | App + image PiP | 0:18 | 1:42 |
| 7 CTA | End card | 0:12 | **1:54** |

Slightly under 2:00 — deliberately, leaves ~6 seconds of breathing room for music tail after the CTA.

### Script 2 — English word count

~265 English words total. At normal speaking pace (~150 wpm) = 1:46 of pure VO. Plus natural pauses, punctuation breaths, and the image-hold moments = lands on 1:54 – 2:00 depending on voice actor cadence.

### Script 2 — images to generate upfront (3 total)

| # | Beat | Purpose | File |
|---|---|---|---|
| img-1 | Beat 1 (Hook) | Priya silhouetted against Bangalore window at golden hour | `docs/video_assets/script_2/01_hook_priya_bangalore_window.png` |
| img-2 | Beat 4 (Critical moment) | Priya in kitchen reaching for phone with notification | `docs/video_assets/script_2/02_critical_priya_phone_kitchen.png` |
| img-3 | Beat 6 (Editor PiP) | Phone on desk showing "Papa calling" | `docs/video_assets/script_2/03_editor_papa_calling.png` |

---

## Test data — Script 2

**Most of the data is already seeded by Script 1's `seed_video_demo_patient.py`.** Two small additions needed before recording Script 2:

1. **Priya's own profile** — so the profile picker in Beat 2 shows TWO cards (her own + Papa's shared). The existing seed creates Priya as a user but gives her no profile of her own, only editor access on Ramesh's profile. A minimal profile for her is enough (name, age, empty or 1-2 readings). I'll update the seed script to add this.

2. **English-language doctor note** — the seeded Dr. Rajesh note for Ramesh is in Hindi (`"BP control बेहतर है..."`) because it was written for the Hindi-UI patient video. When Priya views the same note in English UI, the app has to either render it in the original language or display an English version. For Script 2 recording, the cleanest solution is to **seed an additional English version** of the same note so the English UI shows a readable line. I'll update the seed script to write the note in both.

3. **Alert history screen in the app** — Beat 4 relies on an in-app "Notifications" or "Alert history" screen that shows the WhatsApp alert that was sent to Priya 10 days ago. **Verify whether this screen exists in the app before recording.** If it doesn't exist, we can either:
    - Show the CriticalAlertLog row by querying it directly via the admin dashboard (uglier)
    - Or cut Beat 4's "back to alert log" portion and instead hold on the critical reading detail screen for the full 22 seconds (simpler, zero code change)
    - Or build a minimal "Alert History" screen if the feature justifies it — but that's a feature, not a video-prep task.

**Action items for seed script update** (non-urgent — needed before Script 2 recording, not before image generation):
- Add Priya's own profile with minimal data
- Duplicate the doctor's note in English for the English-UI view
- Verify or decide what to do about the alert history screen in Beat 4

No additional user accounts, no additional readings, no additional doctor links — everything else reuses Script 1's seed.

---

## Script 3 — Doctor portal (English VO)

**Status:** ⏳ Not yet drafted.

Scope sketch: Speaks to a practicing physician about the value of seeing patient readings between visits. Covers: NMC verification, patient linking flow, triage board, access to readings/meals, note-taking, revocation. Tone is clinical and credibility-forward, not marketing. One key beat: "we do not replace your clinical judgment — we give you more data points between the ones you already see."

---

## Script 4 — Investor pitch (English VO)

**Status:** ⏳ Not yet drafted.

Scope sketch: Market size (India chronic disease, ~100M diabetics, 200M hypertensives), the distribution wedge (family-shared model), defensible moat (doctor directory + consent infrastructure), current pilot metrics (to be filled from real dev data before recording), team, ask. Confident but not breathless. Investors smell exaggeration instantly.

---

## Change log

| Date | Section | Change |
|---|---|---|
| 2026-04-11 | New | Doc created with all 4 script slots, production checklist, and Script 1 v1 draft + test-data spec |
| 2026-04-11 | Production model + Script 1 | Rewrote for app-walkthrough-only approach (no live-action). Script 1 rewritten in English master format with explicit `APP:` vs `IMAGE:` beats and ready-to-paste Banana/Imagen prompts. Hindi VO will be outsourced to native translator after English is locked. |
| 2026-04-11 | Script 1 v3 | Merged old Beats 1+2 into one 12s "Hook+Pain" beat with wife as hero (hands flipping notebook, husband in blurred background — avoids compliance risk of showing medical symptoms directly). Freed 14s redistributed: +8s to Doctor beat (now 28s, the most important beat), +2s to Family, +4s to CTA. Added Image 3 (Dr. Rajesh cutaway) between patient view and doctor portal. Every beat now has a second-by-second shot list with VO overlay timing. Image prompts expanded to 200+ words each with explicit lens/composition/lighting/mood/technical cues. |
| 2026-04-11 | Script 1 seed | Created `backend/seed_video_demo_patient.py`. Seed ran successfully on dev: Ramesh profile 47, 44 glucose readings, 41 BP readings, 34 meals, linked doctor with note, 1 critical alert, 1 AI insight, 1 chat exchange, 4 filler patients for Dr. Rajesh-demo's triage board. Verified via `v_patient_overview`. Ready for Script 1 recording. |
| 2026-04-11 | Script 2 v1 | Drafted Script 2 (patient's relative, English VO, Priya's POV). 7 beats, 1:54 total. Reuses Script 1 seed data — no new user accounts or readings. Three new image prompts: (1) Priya silhouetted against Bangalore window at golden hour, (2) Priya reaching for phone with notification in kitchen, (3) phone showing "Papa calling" for PiP. Two small seed updates queued: add Priya's own profile + English version of doctor note. Open question: does the app have an alert-history screen for Beat 4? If not, Beat 4 dwells on the critical-reading detail screen instead. |
| 2026-04-11 | Session pause | Added the "📍 Session state — pause point" summary at the top of the doc and the "Resume checklist" section below. Nothing committed to git. Project parked in a clean state. |

---

## Resume checklist — when you pick this project back up

**Read this section first** when you return to the video project. It's a copy-pasteable ordered list of next actions.

### Where everything lives

| Artifact | Location | Committed? |
|---|---|---|
| This master doc | `docs/VIDEO_SCRIPTS_AND_TEST_DATA.md` | ❌ uncommitted on master |
| Script 1 seed script (local copy) | `backend/seed_video_demo_patient.py` | ❌ uncommitted on master |
| Script 1 seed script (dev server) | `/var/www/swasth/backend/seed_video_demo_patient.py` | Transient — will be wiped on next deploy's `git reset --hard` |
| Script 1 seed data on dev DB | `ramesh.demo@swasth.app` profile_id=47 + family + Dr. Rajesh-demo + fillers | ✅ Live on dev DB — persists across deploys because it's data, not code |
| Patient overview view | `v_patient_overview` on dev DB | ✅ Live (see `docs/DB_PATIENT_OVERVIEW_VIEW.md`) |
| Generated images — Script 1 | `docs/video_assets/script_1/*.png` (gitignored) | Local to your laptop, not in git |
| Generated images — Script 2 | `docs/video_assets/script_2/*.png` (not yet generated) | — |

### Path A — finish Script 1 recording (fastest path to one shipped video)

1. **Verify the dev DB still has the seed data.** Run:
   ```sql
   SELECT * FROM v_patient_overview WHERE email='ramesh.demo@swasth.app';
   ```
   Expected: 1 row, profile_id=47, active_links_total=1, linked_doctor_code=DRRAJDM, readings_total≈85, meals_total≈34.
   If the row is missing, re-run the seed:
   ```bash
   scp -i ~/.ssh/new-server-key backend/seed_video_demo_patient.py \
       root@65.109.226.36:/var/www/swasth/backend/
   ssh -i ~/.ssh/new-server-key root@65.109.226.36 \
       "cd /var/www/swasth/backend && SWASTH_ALLOW_SEED=1 ./venv/bin/python seed_video_demo_patient.py"
   ```
2. **Log in to dev web as Ramesh** (`ramesh.demo@swasth.app` / `Demo@1234`), switch UI to Hindi in Profile → Settings, and confirm the Home screen matches Beat 2 expectations (vitals, Care Circle, linked doctor, AI insight all visible).
3. **Record screen captures** beat by beat using the shot list in the "Script 1" section. Record silently first.
4. **Generate VO**:
   - Send the Script 1 VO text (copy from the doc) to a Hindi translator.
   - Record the Hindi dub with a native-speaker voice actor (Fiverr ~₹2–5k).
5. **Edit**: layer the images (already generated) + screen captures + Hindi VO + English subtitles in Descript or DaVinci Resolve.
6. **Export**: 1080p MP4 for YouTube, 720p for WhatsApp share.

### Path B — complete Script 2 before recording anything

1. **Update the seed script** to add the two Script 2 requirements:
   - Priya's own profile (minimal: name "Priya Kumar", age 30, Female, 1–2 readings)
   - English version of Dr. Rajesh's note to Ramesh (so Priya's English UI has readable text in Beat 5)
2. **Answer the open question**: does the app have an "Alert History" or "Notifications" screen that shows the WhatsApp alert sent to Priya? Check `lib/screens/` for anything matching. If not, accept the fallback (Beat 4 dwells on the critical-reading detail screen for the full 22s).
3. **Re-run the updated seed script** on dev.
4. **Generate the 3 Script 2 images** in Banana/Imagen using the prompts in the Script 2 section. Save to `docs/video_assets/script_2/`.
5. **Record Script 2 screen captures** — logging in as Priya, English UI.
6. **Record English VO** — ElevenLabs "Ryan Multilingual" 0.95 speed is the cheapest fast path. Fiverr voice actor if you want higher quality.
7. **Edit + export**.

### Path C — continue drafting the remaining scripts

1. **Script 3 — Doctor portal (English)**. Will reuse Dr. Rajesh-demo account + the 5 seeded patients (Ramesh + 4 fillers) on the triage board. Narrative arc: clinical credibility, not emotion. Features to showcase: directory/verification, patient linking via doctor code, triage board, patient detail view, note-taking, revocation/consent flow. Expected runtime ~2:00. Likely 1 Banana image (doctor in clinic), mostly app walkthrough.
2. **Script 4 — Investor pitch (English)**. Reuses admin dashboard data for pilot metrics. Narrative arc: market size, distribution wedge (family-shared model), moat (doctor directory + consent infrastructure), traction, ask. Expected runtime ~2:00. 1–2 Banana images (aspirational Bihar context). Confident but not breathless. **Write this one last** — the pilot metrics will be stronger by the time you actually need the video.

### Items to resolve before the project ships

- [ ] **Commit the seed script** to git via a proper PR (it's currently only locally in `backend/seed_video_demo_patient.py`). Should go through the review chain. Daniel + Priya (test review) will need to sign off. Consider adding a test that it runs end-to-end against a fresh dev DB snapshot.
- [ ] **Commit this doc** to git the same way. Single PR with seed + doc is clean.
- [ ] **Decide on final file locations** for generated images. Currently `docs/video_assets/` is gitignored. For launch, upload the final cuts to YouTube and keep source stills in a private Google Drive folder linked from this doc.
- [ ] **Dashboard doctor-section bug** (Pratika case) — separately tracked in `TASK_TRACKER.md` Session Log 2026-04-11. Not video-related but flagged for visibility in case it surfaces during Script 1 recording (if the recording reveals the bug visibly, we'll want to fix it before shipping the video).

### Items explicitly out of scope (don't spend time on these)

- **Feature tours**. The original 10-minute draft script walked through every screen. We're not doing that. If a feature isn't covered by the 4 scripts here, it doesn't get a video.
- **Stock footage / b-roll**. Production model is app + Banana stills only.
- **Voiceover for non-Hindi audiences on Script 1**. Hindi is the only language for Script 1. If there's demand for an English patient video later, it's a separate project.
- **Live demo during the video**. No on-camera typing. No dummy data entry. Everything is pre-seeded.

### Commands you'll need when resuming

```bash
# Check seed state
ssh -i ~/.ssh/new-server-key root@65.109.226.36 \
  "export PGPASSWORD='sw@sth_d6'; /usr/pgsql-16/bin/psql -U swasth_user -h localhost -d swasth_db \
   -c \"SELECT count(*) FROM v_patient_overview WHERE email LIKE '%.demo@swasth.app';\""

# Re-upload and re-run seed (idempotent)
scp -i ~/.ssh/new-server-key backend/seed_video_demo_patient.py \
    root@65.109.226.36:/var/www/swasth/backend/
ssh -i ~/.ssh/new-server-key root@65.109.226.36 \
    "cd /var/www/swasth/backend && SWASTH_ALLOW_SEED=1 ./venv/bin/python seed_video_demo_patient.py"

# Log into dev web
open https://65.109.226.36:8443/
# email: ramesh.demo@swasth.app  (or priya/arjun/dr.rajesh.demo)
# password: Demo@1234
```

### Open questions parked for future sessions

1. **Script 2 Beat 4 — does the app have an alert-history screen?** If not, Beat 4 falls back to holding on the critical-reading detail view for 22 seconds. Needs one code search to answer.
2. **Script 1 Wellness Score value** — I didn't hand-tune the score; it computes dynamically from seeded readings. Log in once before recording and confirm it's in the 60–75 range. If not, adjust seeded values.
3. **Bilingual doctor notes** — does the app render the doctor note in the patient's language or the doctor's language? Affects Script 2 Beat 5 shot list.
4. **Whether the Bluetooth flow in Beat 3 of Script 1 works with pre-paired mock devices** — if the flow hard-requires a real BLE handshake, Beat 3 needs to be re-shot with a different approach (maybe show camera-OCR instead of Bluetooth).
