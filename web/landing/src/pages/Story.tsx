import { useEffect } from "react";

const Story = () => {
  useEffect(() => {
    document.title = "Swasth — The 3am Call You Don't Want";
  }, []);

  return (
    <>
      <style>{`
        .story-page{margin:0;padding:0;background:#f5f9fc;color:#0f172a;font-family:'Inter','Plus Jakarta Sans',sans-serif;line-height:1.55;-webkit-font-smoothing:antialiased}
        .story-page *{box-sizing:border-box}
        .story-page h1,.story-page h2,.story-page h3,.story-page h4{font-family:'Plus Jakarta Sans','Inter',sans-serif;letter-spacing:-0.02em;line-height:1.1;margin:0}
        .story-page p{margin:0}
        .story-page a{color:inherit;text-decoration:none}
        .story-container{max-width:1100px;margin:0 auto;padding:0 24px}
        .story-nav{position:sticky;top:0;z-index:50;background:rgba(255,255,255,.85);backdrop-filter:blur(14px);border-bottom:1px solid rgba(14,165,233,.08)}
        .story-nav-row{display:flex;align-items:center;justify-content:space-between;height:72px}
        .story-brand{display:flex;align-items:center;gap:10px;font-weight:900;font-size:22px;letter-spacing:-0.02em;color:#0f172a}
        .story-brand img{width:36px;height:36px;object-fit:contain}
        .story-brand .dot{color:#0ea5e9}
        .story-nav-links{display:flex;align-items:center;gap:24px}
        .story-nav-link{font-weight:700;font-size:14px;color:#64748b;padding:14px 4px;display:flex;align-items:center}
        .story-nav-link:hover{color:#0ea5e9}
        .story-nav-cta{padding:14px 22px;border-radius:12px;background:#0ea5e9;color:#fff;font-weight:800;font-size:14px;box-shadow:0 10px 20px -5px rgba(14,165,233,.4)}
        .story-hero{position:relative;background:#0a0e1a;color:#fff;min-height:88vh;display:flex;align-items:center;overflow:hidden}
        .story-hero-img{position:absolute;inset:0;z-index:0}
        .story-hero-img img{width:100%;height:100%;object-fit:cover;opacity:.82}
        .story-hero-img::after{content:"";position:absolute;inset:0;background:linear-gradient(180deg,rgba(10,14,26,.25) 0%,rgba(10,14,26,.4) 55%,rgba(10,14,26,.92) 100%)}
        .story-hero-content{position:relative;z-index:1;padding:120px 0 80px;width:100%}
        .story-pill{display:inline-flex;align-items:center;gap:8px;padding:10px 18px;border-radius:999px;background:rgba(245,158,11,.18);border:1px solid rgba(245,158,11,.45);font-weight:800;font-size:13px;letter-spacing:.04em;color:#fde68a;backdrop-filter:blur(10px)}
        .story-hero h1{font-size:80px;font-weight:900;margin-top:24px;color:#fff;line-height:1;letter-spacing:-0.03em;text-shadow:0 6px 30px rgba(0,0,0,.6)}
        .story-hero p.sub{font-size:21px;color:rgba(255,255,255,.92);margin-top:24px;max-width:620px;font-weight:500;text-shadow:0 2px 10px rgba(0,0,0,.6)}
        .story-hero-actions{display:flex;gap:14px;margin-top:32px;align-items:center;flex-wrap:wrap}
        .story-btn{display:inline-flex;align-items:center;gap:8px;cursor:pointer;font-weight:800;border-radius:14px;padding:16px 26px;font-size:16px;text-decoration:none;border:0;font-family:inherit}
        .story-btn-primary{background:#f59e0b;color:#fff;box-shadow:0 12px 28px rgba(245,158,11,.4)}
        .story-btn-ghost{background:rgba(255,255,255,.18);color:#fff;backdrop-filter:blur(10px);border:1px solid rgba(255,255,255,.3)}
        .story-band{background:linear-gradient(180deg,#0a0e1a 0%,#0c1024 100%);color:#e5e7eb;padding:80px 0 40px}
        .story-narr{max-width:760px;margin:0 auto}
        .story-act{margin-bottom:24px}
        .story-act-sep{text-align:center;color:rgba(229,231,235,.3);font-size:18px;letter-spacing:.6em;margin:0 0 32px;font-weight:300}
        .story-act h2{font-family:'Crimson Pro','Plus Jakarta Sans',serif;font-size:46px;font-weight:700;color:#fff;line-height:1.15;letter-spacing:-0.02em;margin-bottom:20px}
        .story-act p{font-size:21px;color:rgba(229,231,235,.92);line-height:1.65;margin-bottom:16px;font-weight:400}
        .story-act p.line{font-size:24px;font-weight:500;color:#fff}
        .story-act .quote{font-family:'Crimson Pro',serif;font-size:28px;font-style:italic;color:#fde68a;border-left:4px solid #f59e0b;padding:10px 0 10px 26px;margin:24px 0;line-height:1.45;font-weight:500}
        .story-act .quote-plain{font-family:'Crimson Pro',serif;font-size:23px;color:#fde68a;border-left:4px solid #f59e0b;padding:14px 0 14px 26px;margin:24px 0;line-height:1.55;font-weight:500}
        .story-act .punch{font-size:30px;font-weight:800;color:#fff;line-height:1.3;margin-top:14px;letter-spacing:-0.02em}
        .story-act .punch strong{color:#fbbf24;font-weight:900}
        .story-act .closer{font-size:21px;color:rgba(255,255,255,.95);margin-top:18px;font-weight:500;font-style:italic}
        .story-price-inline{display:inline-block;color:#fbbf24;font-weight:900;font-size:30px;letter-spacing:-0.02em;border-bottom:3px solid #f59e0b;padding-bottom:2px}
        .story-pivot{text-align:center;padding:60px 0;background:linear-gradient(180deg,#0c1024 0%,#0c4a6e 25%,#0c70a4 60%,#0ea5e9 100%);color:#fff;position:relative;overflow:hidden}
        .story-pivot h2{position:relative;z-index:1;font-family:'Crimson Pro',serif;font-size:48px;font-weight:700;font-style:italic;color:#fff;line-height:1.2;letter-spacing:-0.02em;text-shadow:0 4px 20px rgba(0,0,0,.4)}
        .story-pivot h2 span{color:#fff;border-bottom:4px solid #fbbf24;padding-bottom:2px}
        .story-pivot p{position:relative;z-index:1;margin-top:14px;font-size:16px;color:rgba(255,255,255,.88);font-weight:600;font-style:italic}
        .story-transition{height:60px;background:linear-gradient(180deg,#0ea5e9 0%,#7dd3fc 30%,#cbe4f3 60%,#eaf4fb 90%,#f5f9fc 100%)}
        .story-section{padding:80px 0}
        .story-section-white{background:#fff}
        .story-section-light{background:linear-gradient(180deg,#f5f9fc,#eaf4fb)}
        .story-sec-eyebrow{display:inline-block;font-size:11px;font-weight:900;letter-spacing:.22em;text-transform:uppercase;color:#0ea5e9;background:rgba(14,165,233,.1);padding:8px 16px;border-radius:999px;border:1px solid rgba(14,165,233,.2)}
        .story-sec-title{font-size:44px;font-weight:900;margin-top:20px;color:#0f172a}
        .story-sec-title .accent{color:#0ea5e9;font-style:italic}
        .story-sec-sub{color:#64748b;font-size:18px;margin-top:18px;max-width:680px;margin-left:auto;margin-right:auto;line-height:1.6;font-weight:500}
        .story-sec-head{text-align:center;max-width:780px;margin:0 auto 60px}
        .story-mom-img{max-width:1000px;margin:0 auto;display:block}
        .story-mom-img img{width:100%;height:auto;border-radius:20px;box-shadow:0 30px 70px -30px rgba(15,23,42,.2)}
        .story-price-section{padding:80px 0;background:linear-gradient(180deg,#f5f9fc,#eaf4fb)}
        .story-price-card{max-width:580px;margin:0 auto;background:#fff;border-radius:28px;padding:48px 40px;text-align:center;border:3px solid #f59e0b;box-shadow:0 40px 80px -30px rgba(245,158,11,.3);position:relative}
        .story-price-card::before{content:"Early-access waitlist · Free to join";position:absolute;top:-14px;left:50%;transform:translateX(-50%);background:#f59e0b;color:#fff;font-size:11px;font-weight:900;letter-spacing:.12em;text-transform:uppercase;padding:6px 18px;border-radius:999px;white-space:nowrap}
        .story-price-row{display:inline-flex;align-items:baseline;gap:6px;justify-content:center;color:#0f172a;letter-spacing:-0.03em;font-family:'Plus Jakarta Sans',sans-serif}
        .story-price-row .num{font-size:80px;font-weight:900;line-height:1}
        .story-price-row .per{font-size:30px;font-weight:800;color:#334155}
        .story-price-context{margin-top:8px;font-size:16px;color:#64748b;font-weight:600}
        .story-price-anchor{margin-top:18px;padding:14px 20px;background:linear-gradient(135deg,rgba(245,158,11,.08),rgba(245,158,11,.04));border:1px dashed rgba(245,158,11,.4);border-radius:14px;font-size:14px;font-weight:600;color:#334155;line-height:1.5}
        .story-price-anchor b{color:#f59e0b;font-weight:800}
        .story-closing{background:linear-gradient(135deg,#0c4a6e 0%,#0c70a4 50%,#0ea5e9 100%);color:#fff;text-align:center;padding:90px 0;position:relative;overflow:hidden}
        .story-closing::before,.story-closing::after{content:"";position:absolute;border-radius:50%;filter:blur(80px);opacity:.18;pointer-events:none}
        .story-closing::before{width:400px;height:400px;background:#fff;top:-15%;right:-8%}
        .story-closing::after{width:460px;height:460px;background:#fbbf24;bottom:-25%;left:-8%}
        .story-closing h2{position:relative;z-index:1;font-family:'Crimson Pro',serif;font-size:54px;font-weight:700;font-style:italic;color:#fff;line-height:1.2;letter-spacing:-0.02em;text-shadow:0 4px 20px rgba(0,0,0,.3)}
        .story-closing p{margin-top:20px;font-size:18px;color:rgba(255,255,255,.92);position:relative;z-index:1;font-weight:500}
        .story-closing-actions{margin-top:32px;display:flex;justify-content:center;gap:14px;position:relative;z-index:1;flex-wrap:wrap}
        .story-footer{background:#0c1a2e;color:rgba(255,255,255,.7);padding:60px 0 40px}
        .story-footer-row{display:flex;justify-content:space-between;align-items:flex-start;gap:40px;flex-wrap:wrap}
        .story-footer h4{color:#fff;font-size:22px;font-weight:900;letter-spacing:-0.02em}
        .story-footer h4 .dot{color:#0ea5e9}
        .story-footer-tag{margin-top:8px;font-size:14px;color:rgba(255,255,255,.6);font-weight:500}
        .story-footer-links{display:flex;gap:24px;font-weight:700;font-size:14px}
        .story-footer-contact{margin-top:30px;padding-top:30px;border-top:1px solid rgba(255,255,255,.08);display:flex;gap:14px;justify-content:center;flex-wrap:wrap}
        .story-footer-contact a{padding:14px 22px;border:1px solid rgba(255,255,255,.15);border-radius:999px;font-size:14px;font-weight:600;color:#fff}
        .story-footer-copy{margin-top:30px;text-align:center;font-size:11px;letter-spacing:.18em;text-transform:uppercase;color:rgba(255,255,255,.35)}
        @media(max-width:900px){
          .story-hero h1{font-size:44px}
          .story-act h2{font-size:30px}
          .story-act p{font-size:18px}
          .story-act .quote{font-size:22px}
          .story-act .quote-plain{font-size:19px}
          .story-act .punch{font-size:24px}
          .story-pivot{padding:48px 0}
          .story-pivot h2{font-size:32px}
          .story-sec-title,.story-closing h2{font-size:28px}
          .story-nav-links{display:none}
        }
      `}</style>
      <div className="story-page">
        <nav className="story-nav">
          <div className="story-container story-nav-row">
            <a href="/" className="story-brand">
              <img src="/logo.png" alt="Swasth Logo" />
              <span>Swasth<span className="dot">.</span></span>
            </a>
            <div className="story-nav-links">
              <a className="story-nav-link" href="/">Home</a>
              <a className="story-nav-link" href="/#waitlist">Get early access</a>
            </div>
            <a href="/#waitlist" className="story-nav-cta">Save my spot →</a>
          </div>
        </nav>

        <section className="story-hero">
          <div className="story-hero-img">
            <img src="/hero-survey.jpg" alt="A son rushing into the Cardiac Care Unit with his suitcase" />
          </div>
          <div className="story-container story-hero-content">
            <span className="story-pill">🩺 A 2-minute story for every son and daughter</span>
            <h1>The 3am call<br/>you don't want.</h1>
            <p className="sub">For every son and daughter whose parent is alone in India.</p>
            <div className="story-hero-actions">
              <a href="#story" className="story-btn story-btn-ghost">Read the story ↓</a>
            </div>
          </div>
        </section>

        <section id="story" className="story-band">
          <div className="story-container">
            <div className="story-narr">
              <div className="story-act">
                <p className="line"><strong>3am. Your phone rings. A call from home.</strong></p>
                <div className="quote">"We're taking Maa to hospital — chest pain."</div>
                <p>By the time you land, she's in ICU. Heart attack. She'll survive — barely.</p>
              </div>
              <div className="story-act-sep">• • •</div>
              <div className="story-act">
                <h2>She stood by you through every thick and thin of your life.</h2>
                <p className="punch">And on the one night she needed you the most,<br/><strong>thousands of kilometres stood between you.</strong></p>
              </div>
              <div className="story-act-sep">• • •</div>
              <div className="story-act">
                <p>As soon as you walk in, the doctor turns to you:</p>
                <div className="quote-plain">"Is your mother diabetic? I'm surprised to see her cholesterol is high — and her BP too. Was anyone monitoring her, or did this happen suddenly?"</div>
                <p className="punch">You don't have a single answer.<br/><strong>You didn't know.</strong></p>
              </div>
              <div className="story-act-sep">• • •</div>
              <div className="story-act">
                <p>Three nights in ICU. Angioplasty. Tests. Medicines. Three to four months of recovery for Maa. Unpaid leave. Flight back.</p>
                <p className="punch">Roughly <span className="story-price-inline">₹8–10 lakh.</span></p>
                <p className="closer">But the bill in rupees is the part you <em>can</em> pay.</p>
                <p className="closer">What you can't pay off is the trauma of watching her on a ventilator — and the guilt of not having been there when it mattered.</p>
              </div>
            </div>
          </div>
        </section>

        <section className="story-pivot">
          <div className="story-container">
            <h2>What if you'd known<br/><span>early enough</span> to act?</h2>
            <p>You can't reverse what's already happened. But you can know what's coming.</p>
          </div>
        </section>

        <div className="story-transition"></div>

        <section className="story-section story-section-white">
          <div className="story-container">
            <div className="story-sec-head">
              <span className="story-sec-eyebrow">How Swasth keeps Maa safe</span>
              <h2 className="story-sec-title">AI alone isn't enough.<br/><span className="accent">Real humans show up — safely.</span></h2>
              <p className="story-sec-sub">Technology watches. People care. Swasth combines both — so nothing falls through the gap between your calls and her doctor's visits.</p>
            </div>
            <div className="story-mom-img">
              <img src="/mom-is-never-alone.png" alt="AI alone isn't enough — Real humans show up safely. Mom is never alone: Doctor, Daughter/Son NRI, Mother, Swasth Ops Member, Swasth AI Agent." />
            </div>
          </div>
        </section>

        <section id="price" className="story-price-section">
          <div className="story-container">
            <div className="story-sec-head">
              <span className="story-sec-eyebrow">The promise</span>
              <h2 className="story-sec-title">Less than one <span className="accent">ICU night.</span></h2>
            </div>
            <div className="story-price-card">
              <div className="story-price-row">
                <span className="num">₹999</span>
                <span className="per">/ month per parent</span>
              </div>
              <div className="story-price-context">Early-access waitlist · Free to join</div>
              <div className="story-price-anchor">
                One ICU night: <b>₹40,000–80,000.</b><br/>
                One flight home from Europe: <b>₹60,000+.</b><br/>
                Swasth for a full year: <b>₹12,000.</b>
              </div>
              <a href="/#waitlist" className="story-btn story-btn-primary" style={{marginTop:30,width:"100%",justifyContent:"center",padding:18,fontSize:16}}>Reserve Maa's spot →</a>
              <div style={{marginTop:14,fontSize:13,color:"#64748b",fontWeight:600}}>We will email you the moment Swasth opens.</div>
            </div>
          </div>
        </section>

        <section className="story-closing">
          <div className="story-container">
            <h2>You sleep at night.<br/>She isn't alone.<br/>Neither are you.</h2>
            <p>Reserve Maa's spot. Free to join. We email you first.</p>
            <div className="story-closing-actions">
              <a href="/#waitlist" className="story-btn story-btn-primary">Save my spot →</a>
              <a href="https://wa.me/?text=I%20just%20read%20Swasth's%20story.%20Worth%20your%202%20minutes%3A%20https%3A%2F%2Fswasth.health%2Fstory" className="story-btn story-btn-ghost">Share Maa's story →</a>
            </div>
          </div>
        </section>

        <footer className="story-footer">
          <div className="story-container">
            <div className="story-footer-row">
              <div>
                <h4>Swasth<span className="dot">.</span></h4>
                <div className="story-footer-tag">Keep your parents healthy — from anywhere.</div>
              </div>
              <div className="story-footer-links">
                <a href="/">Home</a>
                <a href="/#waitlist">Get early access</a>
                <a href="/privacy">Privacy</a>
              </div>
            </div>
            <div className="story-footer-contact">
              <a href="mailto:support@swasth.health">📧 support@swasth.health</a>
              <a href="tel:+919742897375">📞 +91 97428 97375</a>
            </div>
            <div className="story-footer-copy">© 2026 Swasth Technologies · ABDM-compliant · Made in India</div>
          </div>
        </footer>
      </div>
    </>
  );
};

export default Story;
