/**
 * Lightweight analytics for the survey funnel.
 *
 * Events POST to GOOGLE_SCRIPT_URL. Uses sendBeacon for reliable delivery
 * even on visibilitychange (drop-off). Each event carries a sticky session_id
 * so the funnel can be reconstructed in the spreadsheet.
 */

const GOOGLE_SCRIPT_URL = import.meta.env.VITE_GOOGLE_SCRIPT_URL || "";
const SESSION_KEY = "swasth_survey_session";

function getSessionId(): string {
  let id = sessionStorage.getItem(SESSION_KEY);
  if (!id) {
    id = `sess_${Date.now()}_${Math.random().toString(36).slice(2, 10)}`;
    sessionStorage.setItem(SESSION_KEY, id);
  }
  return id;
}

export type EventName =
  | "survey_page_view"
  | "survey_story_scrolled"
  | "survey_q1_focus"
  | "survey_q1_blur"
  | "survey_q2_focus"
  | "survey_q2_blur"
  | "survey_q3_selected"
  | "survey_q4_focus"
  | "survey_q4_blur"
  | "survey_email_entered"
  | "survey_yes_cta_clicked"
  | "survey_visit_website_clicked"
  | "survey_submit_clicked"
  | "survey_submit_success"
  | "survey_submit_failed"
  | "survey_drop_off";

export function trackEvent(event: EventName, data: Record<string, unknown> = {}): void {
  const payload = {
    type: "event",
    event,
    session_id: getSessionId(),
    timestamp: new Date().toISOString(),
    page: typeof window !== "undefined" ? window.location.pathname : "",
    referrer: typeof document !== "undefined" ? document.referrer || "direct" : "",
    user_agent: typeof navigator !== "undefined" ? navigator.userAgent : "",
    ...data,
  };

  // Local debug — visible in browser console for dev review
  if (import.meta.env.DEV) {
    // eslint-disable-next-line no-console
    console.log("[analytics]", event, data);
  }

  if (!GOOGLE_SCRIPT_URL) return;

  try {
    const body = JSON.stringify(payload);
    if (typeof navigator !== "undefined" && navigator.sendBeacon) {
      const blob = new Blob([body], { type: "text/plain;charset=UTF-8" });
      navigator.sendBeacon(GOOGLE_SCRIPT_URL, blob);
      return;
    }
    fetch(GOOGLE_SCRIPT_URL, {
      method: "POST",
      mode: "no-cors",
      headers: { "Content-Type": "text/plain" },
      body,
      keepalive: true,
    }).catch(() => {
      /* swallow — analytics is fire-and-forget */
    });
  } catch {
    /* never let analytics break the page */
  }
}
