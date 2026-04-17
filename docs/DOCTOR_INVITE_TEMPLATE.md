# Doctor Invite — WhatsApp Templates

Ready-to-copy WhatsApp messages for sending the Swasth Play Store install link to pilot doctors.

---

## First install — English

```
Dr. [NAME], thanks for agreeing to try Swasth. 🙏

Install in 3 taps:
1. Open this link on your phone: [PLAY_STORE_OPT_IN_URL]
2. Tap "Become a tester"
3. Tap "Download on Google Play"

Takes 30 seconds. Reply ✅ once installed.

Any issues — message me. I'm happy to walk through it on a call.
```

---

## First install — हिन्दी

```
डॉ. [NAME], Swasth try करने के लिए धन्यवाद 🙏

इंस्टॉल करने के लिए:
1. यह लिंक अपने फ़ोन पर खोलें: [PLAY_STORE_OPT_IN_URL]
2. "Become a tester" पर टैप करें
3. "Download on Google Play" पर टैप करें

30 सेकंड लगेंगे। इंस्टॉल होने पर ✅ भेज दीजिए।

कोई दिक्कत हो — मुझे message करें। मैं call पर समझा दूँगा।
```

---

## Reminder (day 3, doctor hasn't installed)

```
Dr. [NAME], quick nudge — did you get a chance to install Swasth?

Link again: [PLAY_STORE_OPT_IN_URL]

If it's easier, I can come by the clinic for 10 min this week to set it up together.
```

---

## Reminder (day 7, installed but not using)

```
Dr. [NAME], saw you installed Swasth — thanks! 🙏

Want to try logging one reading together? It takes 20 seconds.

Here's what helps most patients:
• Open the app (Swasth icon)
• Tap "Add reading" → BP or glucose
• Enter the numbers → Save

Once you've done it once, you can start recommending to 1-2 patients who check their BP at home. Want me to come by for 15 min to show the patient flow?
```

---

## Usage notes

- **Timing**: send the first-install message immediately after an in-person demo, while the conversation is fresh.
- **Follow-through**: don't send the reminder messages via schedule. Check the Play Console → Internal Testing → Testers tab to see who has installed, then message just those who haven't.
- **Clinic visit > WhatsApp reminder**: if a doctor hasn't installed after 7 days, a 10-min clinic visit converts far better than a 5th reminder message. Offer the visit explicitly.
- **Track conversions**:
  | Event | How to measure |
  |-------|----------------|
  | Received invite | Count of WhatsApp sends |
  | Opened link | Play Console → Internal Testing → Testers → "Accepted" count |
  | Installed | Play Console → Internal Testing → Statistics → Installs |
  | Used weekly | Backend log for distinct auth tokens per week |
- **Expected conversion rates** for baseline: 60% installed, 30% active in week 1, 15% active in week 4. If your numbers are far below, the issue isn't distribution — it's the product or the onboarding.
