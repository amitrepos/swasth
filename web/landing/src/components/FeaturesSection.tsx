import { Activity, Brain, Users, FileText, MessageSquare, LineChart } from "lucide-react";

const features = [
  {
    icon: Users,
    title: "Family Dashboard",
    description: "See how Maa and Papa are really doing — from Berlin, Toronto, or Singapore. Stay connected, stay informed.",
  },
  {
    icon: LineChart,
    title: "Weekly Health Reports",
    description: "A clear weekly picture of how they're doing. Verified by a real nurse who visits every 1–2 weeks — vitals checked in person, not just AI-read.",
    nurseVerified: true,
  },
  {
    icon: MessageSquare,
    title: "WhatsApp Easy Log",
    description: "Parents simply send a photo of their BP or sugar monitor on WhatsApp. AI records it automatically — no app to learn.",
  },
  {
    icon: Activity,
    title: "BP, Sugar, Weight — Watched Gently",
    description: "The numbers that age them quietly. Tracked daily, escalated only when they truly matter.",
  },
  {
    icon: Brain,
    title: "AI Health Insights",
    description: "Personalized guidance in Hindi & English. Not just numbers — what to do next, what to ignore, when to worry.",
  },
  {
    icon: FileText,
    title: "Doctor-Ready Reports",
    description: "Share complete health history with any doctor. No more lost prescriptions.",
  },
];

const FeaturesSection = () => {
  return (
    <section id="features" className="py-20 md:py-28 section-gradient">
      <div className="container">
        <div className="text-center max-w-2xl mx-auto mb-20">
          <span className="text-xs font-bold text-primary uppercase tracking-[0.2em] bg-primary/10 px-4 py-2 rounded-full border border-primary/20">Why Swasth</span>
          <h2 className="text-3xl md:text-5xl font-extrabold font-heading mt-6 text-foreground tracking-tight">
            Everything aging parents need — and everything <span className="text-primary italic">you</span> need to know they're okay.
          </h2>
          <p className="text-muted-foreground mt-6 text-lg font-body leading-relaxed">
            Built for the second half of life: gentle daily care, a real nurse who shows up, and a clear weekly picture for the daughter abroad.
          </p>
        </div>

        <div className="grid sm:grid-cols-2 lg:grid-cols-3 gap-8">
          {features.map((feature, i) => (
            <div
              key={feature.title}
              className={`group relative backdrop-blur-md bg-white/40 border rounded-[1.5rem] p-8 shadow-[0_8px_32px_rgba(14,165,233,0.05)] hover:shadow-[0_16px_48px_rgba(14,165,233,0.12)] transition-all duration-500 hover:-translate-y-2 animate-fade-up ${feature.nurseVerified ? 'border-accent/40' : 'border-white/60'}`}
              style={{ animationDelay: `${i * 0.1}s` }}
            >
              {feature.nurseVerified && (
                <span className="absolute -top-3 right-4 bg-accent text-white text-[10px] font-black tracking-[0.12em] uppercase px-3 py-1.5 rounded-full shadow-[0_6px_16px_rgba(245,158,11,0.4)]">
                  + Nurse-verified
                </span>
              )}
              <div className="w-14 h-14 rounded-2xl bg-primary/10 flex items-center justify-center mb-6 group-hover:bg-primary group-hover:scale-110 transition-all duration-300">
                <feature.icon className="w-7 h-7 text-primary group-hover:text-white transition-colors" />
              </div>
              <h3 className="text-xl font-bold font-heading text-foreground mb-3">{feature.title}</h3>
              <p className="text-muted-foreground text-sm leading-relaxed font-body font-medium">{feature.description}</p>
            </div>
          ))}
        </div>

      </div>
    </section>
  );
};

export default FeaturesSection;
