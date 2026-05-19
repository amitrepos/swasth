import DashboardMockup from "./DashboardMockup";

const HeroSection = () => {
  const scrollToForm = () => {
    document.getElementById("waitlist")?.scrollIntoView({ behavior: "smooth" });
  };

  return (
    <section className="hero-gradient relative overflow-hidden min-h-[90vh] flex items-center pt-10 md:pt-0">
      {/* Decorative circles */}
      <div className="absolute top-[-10%] right-[-5%] w-[400px] h-[400px] rounded-full bg-primary-foreground/5 blur-3xl" />
      <div className="absolute bottom-[-15%] left-[-10%] w-[500px] h-[500px] rounded-full bg-primary-foreground/5 blur-3xl" />

      <div className="container relative z-10 py-16 md:py-24">
        <div className="flex flex-col lg:flex-row gap-12 lg:gap-16 items-center">
          {/* Text */}
          <div className="w-full lg:w-2/3 text-primary-foreground space-y-8 animate-fade-up">
            <div className="inline-block group">
              <span className="inline-block px-6 py-2.5 rounded-full bg-gradient-to-r from-accent/20 to-accent/10 text-sm font-bold backdrop-blur-xl border border-accent/40 tracking-wide shadow-[0_0_20px_rgba(245,158,11,0.2)] group-hover:shadow-[0_0_30px_rgba(245,158,11,0.4)] transition-all duration-300 group-hover:border-accent/60">
                <span className="inline-block animate-bounce-soft" style={{ animationDelay: "0s" }}>🇮🇳</span> For NRIs Who Care From Far
              </span>
            </div>
            <h1 className="text-4xl md:text-5xl lg:text-7xl font-extrabold leading-[1.1] tracking-tight font-heading">
              Keep your parents <span className="text-accent">healthy</span> - from anywhere.
            </h1>
            <p className="text-lg md:text-xl text-white/90 max-w-xl leading-relaxed font-body">
              The simplest way to look after Maa and Papa from another timezone.{" "}
              <strong className="text-accent">A real nurse visits every 1–2 weeks</strong>, gentle daily tracking covers the things that age them quietly — BP, sugar, weight, sleep — and you get a clear weekly picture instead of "sab theek hai."
            </p>
            <div className="flex flex-col sm:flex-row gap-5 pt-4">
              <a
                href="/story"
                className="px-10 py-4 bg-accent text-white font-bold rounded-2xl text-lg shadow-[0_8px_30px_rgb(245,158,11,0.3)] hover:shadow-[0_8px_30px_rgb(245,158,11,0.5)] hover:scale-[1.03] transition-all duration-300 text-center"
              >
                No more "sab theek hai" →
              </a>
              <button
                onClick={scrollToForm}
                className="px-10 py-4 bg-white/15 text-white font-semibold rounded-2xl text-lg backdrop-blur-md border border-white/20 hover:bg-white/25 transition-all duration-300 text-center"
              >
                Get early access
              </button>
            </div>
            <div className="flex items-center gap-2 pt-2 animate-pulse-soft">
              <div className="w-2 h-2 rounded-full bg-accent animate-pulse" />
              <p className="text-sm font-medium text-white/70">
                Free to join · Early access opens end of May 2026 · We email you first
              </p>
            </div>
          </div>

          {/* App mockup */}
          <div className="w-full lg:w-1/3 flex justify-center lg:justify-end animate-fade-up" style={{ animationDelay: "0.2s" }}>
            <div className="relative w-full max-w-[280px]">
              <div className="absolute inset-0 bg-primary-foreground/10 rounded-[2.5rem] blur-2xl scale-95" />
              <div className="relative rounded-[2.5rem] shadow-2xl overflow-hidden border-4 border-white/10 aspect-[9/19] bg-white">
                <DashboardMockup />
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
};

export default HeroSection;
