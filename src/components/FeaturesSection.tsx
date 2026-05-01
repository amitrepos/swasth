import { Activity, Brain, Users, FileText, MessageSquare, LineChart } from "lucide-react";

const features = [
  {
    icon: MessageSquare,
    title: "WhatsApp Easy Log",
    description: "Parents can simply send a photo of their BP or Glucose monitor via WhatsApp. Our AI records it automatically.",
  },
  {
    icon: Activity,
    title: "Vitals & Steps",
    description: "Track BP, Glucose, Weight, and BMI. Automatic step tracking keeps them active and healthy.",
  },
  {
    icon: Users,
    title: "Family Dashboard",
    description: "See your parent's health readings from abroad. Stay connected, stay informed.",
  },
  {
    icon: Brain,
    title: "AI Health Insights",
    description: "Personalized tips in Hindi & English. Smart alerts when readings need immediate attention.",
  },
  {
    icon: LineChart,
    title: "Weekly Health Reports",
    description: "Receive a comprehensive weekly summary of health trends and progress directly in your inbox.",
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
            Everything your family needs for <span className="text-primary italic">complete</span> health
          </h2>
          <p className="text-muted-foreground mt-6 text-lg font-body leading-relaxed">
            Built for families that live apart, designed for the peace of mind knowing your parents are well.
          </p>
        </div>

        <div className="grid sm:grid-cols-2 lg:grid-cols-3 gap-8">
          {features.map((feature, i) => (
            <div
              key={feature.title}
              className="group relative backdrop-blur-md bg-white/40 border border-white/60 rounded-[1.5rem] p-8 shadow-[0_8px_32px_rgba(14,165,233,0.05)] hover:shadow-[0_16px_48px_rgba(14,165,233,0.12)] transition-all duration-500 hover:-translate-y-2 animate-fade-up"
              style={{ animationDelay: `${i * 0.1}s` }}
            >
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
