import { useEffect, useRef, useState } from "react";
import { Send, ExternalLink, ArrowRight, Heart } from "lucide-react";
import Navbar from "@/components/Navbar";
import Footer from "@/components/Footer";
import { trackEvent } from "@/lib/analytics";

const GOOGLE_SCRIPT_URL = import.meta.env.VITE_GOOGLE_SCRIPT_URL || "";

type SignupChoice = "" | "Yes" | "Maybe" | "No";

const Survey = () => {
  const [q1, setQ1] = useState("");
  const [q2, setQ2] = useState("");
  const [q3, setQ3] = useState<SignupChoice>("");
  const [q4, setQ4] = useState("");
  const [email, setEmail] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [submitted, setSubmitted] = useState(false);
  const [error, setError] = useState("");

  const emailLoggedRef = useRef(false);
  const storyEndRef = useRef<HTMLDivElement>(null);
  const storyScrolledRef = useRef(false);

  // Page view + drop-off tracking
  useEffect(() => {
    trackEvent("survey_page_view");

    const handleVisibility = () => {
      if (document.visibilityState === "hidden" && !submitted) {
        trackEvent("survey_drop_off", {
          q1_filled: q1.length > 0,
          q2_filled: q2.length > 0,
          q3_choice: q3 || "none",
          q4_filled: q4.length > 0,
          email_filled: email.length > 0,
          last_step: deriveLastStep({ q1, q2, q3, q4, email }),
        });
      }
    };
    document.addEventListener("visibilitychange", handleVisibility);
    window.addEventListener("pagehide", handleVisibility);
    return () => {
      document.removeEventListener("visibilitychange", handleVisibility);
      window.removeEventListener("pagehide", handleVisibility);
    };
  }, [q1, q2, q3, q4, email, submitted]);

  // Story scroll-through detection (fires once)
  useEffect(() => {
    if (!storyEndRef.current) return;
    const observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting && !storyScrolledRef.current) {
            storyScrolledRef.current = true;
            trackEvent("survey_story_scrolled");
          }
        });
      },
      { threshold: 0.5 }
    );
    observer.observe(storyEndRef.current);
    return () => observer.disconnect();
  }, []);

  const handleQ3 = (val: Exclude<SignupChoice, "">) => {
    setQ3(val);
    trackEvent("survey_q3_selected", { choice: val });
  };

  const handleEmailBlur = () => {
    if (email.length > 0 && !emailLoggedRef.current) {
      emailLoggedRef.current = true;
      trackEvent("survey_email_entered", { length: email.length });
    }
  };

  const onSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!q3) {
      setError("Please pick Yes, Maybe, or No for question 3.");
      return;
    }
    setError("");
    setSubmitting(true);
    trackEvent("survey_submit_clicked", { choice: q3 });

    const data = {
      type: "survey_submission",
      q1_health_scare: q1,
      q2_current_tracking: q2,
      q3_signup: q3,
      q4_reason: q4,
      email,
      timestamp: new Date().toISOString(),
      referrer: document.referrer || "direct",
      user_agent: navigator.userAgent,
    };

    try {
      if (GOOGLE_SCRIPT_URL) {
        await fetch(GOOGLE_SCRIPT_URL, {
          method: "POST",
          mode: "no-cors",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify(data),
        });
      } else {
        // eslint-disable-next-line no-console
        console.log("[survey] no GOOGLE_SCRIPT_URL — submission:", data);
      }
      trackEvent("survey_submit_success", { choice: q3 });
      setSubmitted(true);
    } catch {
      trackEvent("survey_submit_failed");
      setError("Something went wrong. Please try again.");
      setSubmitting(false);
    }
  };

  return (
    <>
      <Navbar />
      <main className="overflow-hidden">
        {/* ---------- Hero ---------- */}
        <section className="hero-gradient relative overflow-hidden pt-28 md:pt-32 pb-16 md:pb-24">
          <div className="absolute top-[-10%] right-[-5%] w-[400px] h-[400px] rounded-full bg-primary-foreground/5 blur-3xl" />
          <div className="absolute bottom-[-15%] left-[-10%] w-[500px] h-[500px] rounded-full bg-primary-foreground/5 blur-3xl" />

          <div className="container relative z-10 max-w-7xl">
            <div className="grid lg:grid-cols-12 gap-10 lg:gap-12 items-center">

              {/* Hero text */}
              <div className="lg:col-span-5 text-primary-foreground space-y-6 animate-fade-up text-center lg:text-left order-2 lg:order-1">
                <div className="inline-block">
                  <span className="inline-flex items-center gap-2 px-5 py-2.5 rounded-full bg-gradient-to-r from-accent/20 to-accent/10 text-sm font-bold backdrop-blur-xl border border-accent/40 tracking-wide shadow-[0_0_20px_rgba(245,158,11,0.2)]">
                    <span>🇮🇳</span> For NRIs Who Care From Far · 2 min read
                  </span>
                </div>
                <h1 className="text-3xl md:text-5xl lg:text-6xl font-extrabold leading-[1.05] tracking-tight font-heading">
                  The 3am call you don't want.
                </h1>
                <p
                  className="text-lg md:text-xl text-white/90 max-w-xl mx-auto lg:mx-0 leading-relaxed font-body"
                  style={{ textWrap: "balance" } as React.CSSProperties}
                >
                  A 2-minute story for every NRI son and daughter whose parents are alone in India.
                </p>
              </div>

              {/* Hero image — landscape, dominant */}
              <div className="lg:col-span-7 animate-fade-up order-1 lg:order-2" style={{ animationDelay: "0.15s" }}>
                <div className="relative">
                  <div className="absolute inset-0 bg-primary-foreground/10 rounded-[2rem] blur-2xl scale-95" aria-hidden="true" />
                  <div className="relative rounded-[2rem] overflow-hidden border-4 border-white/10 shadow-2xl aspect-[16/9] bg-gradient-to-br from-slate-900 to-blue-900">
                    <img
                      src="/hero-survey.jpg"
                      alt="An NRI daughter rushing into the Cardiac Care Unit with her suitcase after flying home for a parent's emergency."
                      className="w-full h-full object-cover"
                      loading="eager"
                      onError={(e) => {
                        (e.currentTarget as HTMLImageElement).style.display = "none";
                      }}
                    />
                    {/* Subtle bottom gradient for caption legibility */}
                    <div className="absolute inset-x-0 bottom-0 h-1/3 bg-gradient-to-t from-black/70 to-transparent pointer-events-none" />
                    <div className="absolute bottom-5 left-5 right-5 text-white/90 leading-snug">
                      <span className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full bg-white/15 backdrop-blur-md border border-white/20 text-xs font-bold uppercase tracking-wider">
                        <span className="w-1.5 h-1.5 rounded-full bg-accent animate-pulse" />
                        Nine hours after the call
                      </span>
                    </div>
                  </div>
                </div>
              </div>

            </div>
          </div>
        </section>

        {/* ---------- Story + sticky rail ---------- */}
        <section className="section-gradient py-16 md:py-20">
          <div className="container max-w-7xl">
            <div className="grid lg:grid-cols-12 gap-8 lg:gap-12 items-start">

              {/* Story column (wider on desktop) */}
              <article className="lg:col-span-8 bg-white rounded-[2rem] md:rounded-[2.5rem] shadow-[0_30px_80px_-20px_rgba(14,165,233,0.18)] border border-white p-8 md:p-14 lg:p-16 animate-fade-up">
                <div className="max-w-2xl mx-auto space-y-5 text-foreground leading-relaxed font-body text-[17px] md:text-[18px]">
                  <p>3am. Your phone rings. A call from home.</p>

                  <blockquote className="my-4 pl-5 border-l-4 border-accent italic font-semibold text-foreground text-[19px] md:text-[20px]">
                    "Maa ko hospital le ja rahe hain — chest pain."
                  </blockquote>

                  <p>By the time you land, she's in ICU. Heart attack. She'll survive — barely.</p>

                  <p>
                    Three days in ICU. Tests. Angioplasty. Flight back. Unpaid leave.{" "}
                    <strong className="text-primary">Rs 7 lakh in nine days.</strong>
                  </p>

                  <p>
                    The money isn't the worst part. The worst part is sitting outside the ICU at 2am, scrolling her WhatsApp, wondering when her health started to drift.{" "}
                    <span className="italic text-foreground/80">You weren't watching. She was alone.</span>
                  </p>

                  <p className="!mt-10 text-2xl md:text-3xl font-extrabold text-primary tracking-tight font-heading">
                    What if you could prevent this?
                  </p>

                  <p>
                    Swasth is the daily health companion her doctor recommends. She tracks her medical metrics, her food, her physical activity — all through Swasth. Her doctor reviews weekly. The Swasth coaching team checks in. The AI quietly notices the drift no one else would catch.
                  </p>

                  <p>
                    Three sets of eyes. Every day. The slow rise in week 4 becomes a doctor's call in week 5 — not an ambulance in week 52.
                  </p>

                  <p>
                    <strong className="text-primary">
                      Imagine she has people who watch over her — the way she once watched over you.
                    </strong>{" "}
                    Every quarter a report lands in your inbox:{" "}
                    <span className="italic text-foreground/80">
                      "BP was trending up. Medication was adjusted. Cardiac risk: stable."
                    </span>{" "}
                    You took proactive action — and we didn't even have to tell you.
                  </p>

                  <p>You sleep at night. She isn't alone. Neither are you.</p>

                  <a
                    href="#survey"
                    className="!mt-10 inline-flex items-center gap-2 px-6 py-3 rounded-full bg-primary text-white font-bold text-sm md:text-base shadow-[0_8px_24px_rgba(14,165,233,0.35)] hover:shadow-[0_12px_30px_rgba(14,165,233,0.5)] transition-all lg:hidden"
                  >
                    Tell us your story <ArrowRight className="w-4 h-4" />
                  </a>

                  <div ref={storyEndRef} className="h-2" aria-hidden="true" />
                </div>
              </article>

              {/* Sticky right rail */}
              <aside className="lg:col-span-4 lg:sticky lg:top-28 space-y-6 animate-fade-up" style={{ animationDelay: "0.1s" }}>

                {/* Three watchers card */}
                <div className="bg-white rounded-3xl shadow-[0_20px_60px_-20px_rgba(14,165,233,0.18)] border border-white p-7">
                  <p className="text-xs font-black uppercase tracking-widest text-primary mb-4">
                    Three sets of eyes
                  </p>
                  <div className="space-y-3">
                    <div className="flex items-center gap-3 p-3 rounded-xl bg-primary/5 border border-primary/10">
                      <div className="text-2xl">🩺</div>
                      <div>
                        <p className="font-bold text-foreground text-sm">Her doctor</p>
                        <p className="text-xs text-muted-foreground">Reviews trends weekly</p>
                      </div>
                    </div>
                    <div className="flex items-center gap-3 p-3 rounded-xl bg-primary/5 border border-primary/10">
                      <div className="text-2xl">💬</div>
                      <div>
                        <p className="font-bold text-foreground text-sm">Swasth coach</p>
                        <p className="text-xs text-muted-foreground">Checks in, listens, nudges</p>
                      </div>
                    </div>
                    <div className="flex items-center gap-3 p-3 rounded-xl bg-primary/5 border border-primary/10">
                      <div className="text-2xl">🤖</div>
                      <div>
                        <p className="font-bold text-foreground text-sm">AI watcher</p>
                        <p className="text-xs text-muted-foreground">Catches the drift no human would</p>
                      </div>
                    </div>
                  </div>
                </div>

                {/* Price card */}
                <div className="rounded-3xl p-7 bg-gradient-to-br from-accent/15 to-accent/5 border-2 border-accent/40 text-center shadow-[0_20px_60px_-20px_rgba(245,158,11,0.25)]">
                  <p className="text-xs font-black uppercase tracking-widest text-accent-foreground/70 mb-2">
                    Daily companion
                  </p>
                  <p className="text-4xl md:text-5xl font-extrabold text-foreground tracking-tight font-heading">
                    ₹999<span className="text-lg font-bold text-foreground/60">/mo</span>
                  </p>
                  <p className="text-sm font-semibold text-foreground/70 mt-2">
                    Less than the cost of one ICU night.
                  </p>
                </div>

                {/* Survey CTA */}
                <a
                  href="#survey"
                  className="hidden lg:flex items-center justify-between gap-3 w-full px-6 py-5 rounded-2xl bg-primary text-white font-extrabold text-base shadow-[0_10px_28px_rgba(14,165,233,0.35)] hover:shadow-[0_14px_36px_rgba(14,165,233,0.5)] transition-all"
                >
                  <span>Tell us your story →</span>
                  <span className="text-xs font-bold opacity-80 uppercase tracking-wider">2 min</span>
                </a>
              </aside>

            </div>
          </div>
        </section>

        {/* ---------- Survey ---------- */}
        <section id="survey" className="section-gradient pb-20 md:pb-28">
          <div className="container max-w-4xl">
            <div className="bg-white rounded-[2rem] md:rounded-[2.5rem] shadow-[0_30px_80px_-20px_rgba(14,165,233,0.18)] border border-white p-8 md:p-12 lg:p-14 animate-fade-up">
              {!submitted ? (
                <>
                  <div className="text-center mb-8">
                    <span className="inline-flex items-center gap-2 px-4 py-1.5 rounded-full bg-primary/10 text-primary text-xs font-black uppercase tracking-widest mb-3">
                      <Heart className="w-3.5 h-3.5" /> Your story shapes Swasth
                    </span>
                    <h2 className="text-2xl md:text-3xl font-extrabold font-heading text-foreground tracking-tight">
                      4 questions. ~2 minutes.
                    </h2>
                    <p className="text-muted-foreground mt-2">
                      Honest answers help most. We won't share your responses.
                    </p>
                  </div>

                  <form onSubmit={onSubmit} className="space-y-7" noValidate>
                    {/* Q1 */}
                    <div className="space-y-2">
                      <label htmlFor="q1" className="block text-base font-bold text-foreground leading-snug">
                        1. In the last 12 months, did you have a health scare with your parent? What happened?
                      </label>
                      <textarea
                        id="q1"
                        value={q1}
                        onChange={(e) => setQ1(e.target.value)}
                        onFocus={() => trackEvent("survey_q1_focus")}
                        onBlur={() => q1.length > 0 && trackEvent("survey_q1_blur", { length: q1.length })}
                        placeholder="e.g. Mom had chest pain in February. We flew home for two weeks…"
                        rows={3}
                        className="w-full px-4 py-3.5 rounded-xl border-2 border-slate-200 bg-slate-50 text-foreground placeholder:text-slate-400 focus:outline-none focus:border-primary focus:bg-white focus:ring-4 focus:ring-primary/10 transition-all font-body text-[15px] resize-y min-h-[88px]"
                      />
                    </div>

                    {/* Q2 */}
                    <div className="space-y-2">
                      <label htmlFor="q2" className="block text-base font-bold text-foreground leading-snug">
                        2. Today, how do you keep tabs on their health from where you live?
                      </label>
                      <textarea
                        id="q2"
                        value={q2}
                        onChange={(e) => setQ2(e.target.value)}
                        onFocus={() => trackEvent("survey_q2_focus")}
                        onBlur={() => q2.length > 0 && trackEvent("survey_q2_blur", { length: q2.length })}
                        placeholder="e.g. Daily WhatsApp call. I trust they'll tell me if something's wrong…"
                        rows={3}
                        className="w-full px-4 py-3.5 rounded-xl border-2 border-slate-200 bg-slate-50 text-foreground placeholder:text-slate-400 focus:outline-none focus:border-primary focus:bg-white focus:ring-4 focus:ring-primary/10 transition-all font-body text-[15px] resize-y min-h-[88px]"
                      />
                    </div>

                    {/* Q3 */}
                    <div className="space-y-3">
                      <label className="block text-base font-bold text-foreground leading-snug">
                        3. Would you sign up for Swasth's waitlist right now?
                      </label>
                      <div className="grid grid-cols-3 gap-3" role="radiogroup" aria-label="Sign up choice">
                        {(["Yes", "Maybe", "No"] as const).map((opt) => (
                          <label
                            key={opt}
                            className={`flex items-center justify-center gap-2 px-3 py-3.5 rounded-xl border-2 cursor-pointer font-bold text-sm md:text-base transition-all min-h-[52px] focus-within:ring-4 focus-within:ring-primary/20 ${
                              q3 === opt
                                ? "border-primary bg-primary/10 text-primary shadow-[0_4px_14px_rgba(14,165,233,0.18)]"
                                : "border-slate-200 bg-slate-50 text-foreground hover:border-primary/40"
                            }`}
                          >
                            <input
                              type="radio"
                              name="q3"
                              value={opt}
                              checked={q3 === opt}
                              onChange={() => handleQ3(opt)}
                              className="sr-only"
                            />
                            {opt}
                          </label>
                        ))}
                      </div>

                      {/* Yes box */}
                      {q3 === "Yes" && (
                        <div className="mt-4 p-5 md:p-6 rounded-2xl bg-gradient-to-br from-primary/10 to-primary/5 border-2 border-primary/40 text-center animate-fade-up">
                          <p className="text-base font-bold text-primary mb-3">
                            Wonderful 🙏 Visit our website to join the waitlist.
                          </p>
                          <a
                            href="https://swasth.health"
                            target="_blank"
                            rel="noopener noreferrer"
                            onClick={() => trackEvent("survey_yes_cta_clicked")}
                            className="inline-flex items-center justify-center gap-2 w-full px-6 py-4 bg-primary text-white font-extrabold rounded-xl text-base shadow-[0_8px_24px_rgba(14,165,233,0.35)] hover:shadow-[0_12px_30px_rgba(14,165,233,0.5)] transition-all min-h-[56px]"
                          >
                            Visit swasth.health <ExternalLink className="w-4 h-4" />
                          </a>
                          <p className="text-xs text-muted-foreground mt-3">
                            After visiting, please come back to submit your answers — your story still helps us.
                          </p>
                        </div>
                      )}

                      {/* No / Maybe — reason box */}
                      {(q3 === "No" || q3 === "Maybe") && (
                        <div className="mt-4 space-y-2 animate-fade-up">
                          <label htmlFor="q4" className="block text-base font-bold text-foreground leading-snug">
                            What's holding you back?
                          </label>
                          <p className="text-sm text-muted-foreground -mt-1">
                            Honest objections help us most. Price, trust, parent won't use it, already have something — anything.
                          </p>
                          <textarea
                            id="q4"
                            value={q4}
                            onChange={(e) => setQ4(e.target.value)}
                            onFocus={() => trackEvent("survey_q4_focus")}
                            onBlur={() => q4.length > 0 && trackEvent("survey_q4_blur", { length: q4.length })}
                            placeholder="What's the real reason?"
                            rows={3}
                            className="w-full px-4 py-3.5 rounded-xl border-2 border-slate-200 bg-slate-50 text-foreground placeholder:text-slate-400 focus:outline-none focus:border-primary focus:bg-white focus:ring-4 focus:ring-primary/10 transition-all font-body text-[15px] resize-y min-h-[88px]"
                          />
                        </div>
                      )}
                    </div>

                    {/* Email */}
                    <div className="space-y-2">
                      <label htmlFor="email" className="block text-base font-bold text-foreground leading-snug">
                        Your email{" "}
                        <span className="font-medium text-muted-foreground">
                          (optional — only for early-access updates)
                        </span>
                      </label>
                      <input
                        id="email"
                        type="email"
                        value={email}
                        onChange={(e) => setEmail(e.target.value)}
                        onBlur={handleEmailBlur}
                        autoComplete="email"
                        placeholder="you@example.com"
                        className="w-full px-4 py-3.5 rounded-xl border-2 border-slate-200 bg-slate-50 text-foreground placeholder:text-slate-400 focus:outline-none focus:border-primary focus:bg-white focus:ring-4 focus:ring-primary/10 transition-all font-body text-[15px] min-h-[52px]"
                      />
                    </div>

                    {error && (
                      <p className="text-destructive text-sm font-bold text-center">{error}</p>
                    )}

                    <button
                      type="submit"
                      disabled={submitting}
                      className="w-full px-6 py-4 bg-primary text-white font-extrabold rounded-xl text-base md:text-lg shadow-[0_10px_28px_rgba(14,165,233,0.35)] hover:shadow-[0_14px_36px_rgba(14,165,233,0.5)] active:scale-[0.99] transition-all flex items-center justify-center gap-3 min-h-[56px] disabled:opacity-60 disabled:cursor-not-allowed"
                    >
                      {submitting ? "Submitting…" : <>Submit my answers <Send className="w-5 h-5" /></>}
                    </button>

                    <p className="text-xs text-muted-foreground text-center">
                      We won't share your answers. Email is used only for Swasth early-access updates.
                    </p>
                  </form>
                </>
              ) : (
                <div className="text-center py-8">
                  <div className="w-20 h-20 mx-auto rounded-full bg-primary/10 flex items-center justify-center text-4xl mb-5">
                    🙏
                  </div>
                  <h2 className="text-2xl md:text-3xl font-extrabold font-heading text-primary mb-3">
                    Thank you
                  </h2>
                  <p className="text-muted-foreground mb-6 max-w-md mx-auto">
                    Your answer helps us build something real for families like yours.
                  </p>
                  <a
                    href="https://swasth.health"
                    onClick={() => trackEvent("survey_visit_website_clicked")}
                    className="inline-flex items-center justify-center gap-2 px-8 py-4 bg-primary text-white font-extrabold rounded-xl text-base shadow-[0_8px_24px_rgba(14,165,233,0.35)] hover:shadow-[0_12px_30px_rgba(14,165,233,0.5)] transition-all min-h-[56px]"
                  >
                    Visit swasth.health <ArrowRight className="w-5 h-5" />
                  </a>
                </div>
              )}
            </div>
          </div>
        </section>
      </main>
      <Footer />
    </>
  );
};

function deriveLastStep(state: {
  q1: string;
  q2: string;
  q3: SignupChoice;
  q4: string;
  email: string;
}): string {
  if (state.email) return "email";
  if (state.q4) return "q4_reason";
  if (state.q3) return `q3_${state.q3.toLowerCase()}`;
  if (state.q2) return "q2";
  if (state.q1) return "q1";
  return "story_only";
}

export default Survey;
