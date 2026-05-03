/**
 * Swasth — single-endpoint data collector for Google Apps Script.
 *
 * Routes incoming POSTs by `type` field into three tabs of the same Sheet:
 *   - "Waitlist" — landing page interest form (legacy: no `type` field)
 *   - "Survey"   — /survey page submissions (type: "survey_submission")
 *   - "Events"   — funnel analytics events  (type: "event")
 *
 * Both application/json and text/plain (sendBeacon) bodies are accepted.
 *
 * To deploy:
 *   1. Open the Sheet → Extensions → Apps Script
 *   2. Replace `Code.gs` with this file's contents
 *   3. Deploy → New deployment → type: Web app → execute as: Me, access: Anyone
 *   4. Copy the deployed URL → set as `VITE_GOOGLE_SCRIPT_URL` in the build env
 *      (only if URL changes; existing URL keeps working)
 *
 * After first POST per type, the corresponding tab auto-creates with headers.
 */

const SHEETS = {
  waitlist: {
    name: "Waitlist",
    headers: ["timestamp", "name", "email", "phone", "city", "parentCity", "interests"],
  },
  survey_submission: {
    name: "Survey",
    headers: [
      "timestamp",
      "q1_health_scare",
      "q2_current_tracking",
      "q3_signup",
      "q4_reason",
      "email",
      "referrer",
      "user_agent",
    ],
  },
  event: {
    name: "Events",
    headers: ["timestamp", "event", "session_id", "page", "referrer", "user_agent", "data_json"],
  },
};

function doPost(e) {
  try {
    const raw = e && e.postData && e.postData.contents ? e.postData.contents : "{}";
    const data = JSON.parse(raw);

    // Default to "waitlist" when no type — keeps the legacy WaitlistForm working.
    const type = data.type || "waitlist";
    const cfg = SHEETS[type] || SHEETS.waitlist;

    const sheet = getOrCreateSheet(cfg.name, cfg.headers);
    const row = buildRow(type, data, cfg.headers);
    sheet.appendRow(row);

    return jsonOk({ ok: true, type, sheet: cfg.name });
  } catch (err) {
    return jsonOk({ ok: false, error: String(err) });
  }
}

function doGet() {
  return jsonOk({ ok: true, service: "swasth-collector" });
}

function buildRow(type, d, headers) {
  if (type === "event") {
    return headers.map((h) => {
      if (h === "data_json") return JSON.stringify(d);
      return d[h] !== undefined ? d[h] : "";
    });
  }
  return headers.map((h) => (d[h] !== undefined ? d[h] : ""));
}

function getOrCreateSheet(name, headers) {
  const ss = SpreadsheetApp.getActive();
  let sheet = ss.getSheetByName(name);
  if (!sheet) {
    sheet = ss.insertSheet(name);
    sheet.appendRow(headers);
    sheet.setFrozenRows(1);
    sheet.getRange(1, 1, 1, headers.length).setFontWeight("bold");
  }
  return sheet;
}

function jsonOk(obj) {
  return ContentService.createTextOutput(JSON.stringify(obj)).setMimeType(
    ContentService.MimeType.JSON
  );
}
