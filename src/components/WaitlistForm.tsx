import { useState } from "react";
import { useForm } from "react-hook-form";
import { z } from "zod";
import { zodResolver } from "@hookform/resolvers/zod";
import { toast } from "sonner";
import { Send, CheckCircle2, Heart, MapPin, Mail, User, Phone } from "lucide-react";

const waitlistSchema = z.object({
  name: z.string().trim().min(1, "Name is required").max(100),
  email: z.string().trim().email("Please enter a valid email").max(255),
  phone: z.string().trim().min(7, "Please enter a valid phone number").max(20),
  city: z.string().trim().min(1, "Your city is required").max(100),
  parentCity: z.string().trim().min(1, "Parent's city is required").max(100),
  interests: z.array(z.string()).optional(),
});

type WaitlistData = z.infer<typeof waitlistSchema>;

const healthTopics = [
  { label: "Diabetes management", emoji: "🩺" },
  { label: "BP monitoring", emoji: "❤️‍🩹" },
  { label: "Overall health", emoji: "✨" },
  { label: "Weight & BMI", emoji: "⚖️" },
  { label: "Step tracking", emoji: "👣" },
  { label: "Weekly reports", emoji: "📊" },
];

// Replace with your deployed Google Apps Script web app URL
const GOOGLE_SCRIPT_URL = import.meta.env.VITE_GOOGLE_SCRIPT_URL;

const WaitlistForm = () => {
  const [submitted, setSubmitted] = useState(false);
  const [isSubmitting, setIsSubmitting] = useState(false);

  const {
    register,
    handleSubmit,
    formState: { errors },
  } = useForm<WaitlistData>({
    resolver: zodResolver(waitlistSchema),
    defaultValues: { interests: [] },
  });

  const onSubmit = async (data: WaitlistData) => {
    setIsSubmitting(true);
    try {
      if (GOOGLE_SCRIPT_URL) {
        await fetch(GOOGLE_SCRIPT_URL, {
          method: "POST",
          mode: "no-cors",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            ...data,
            interests: data.interests?.join(", ") || "",
            timestamp: new Date().toISOString(),
          }),
        });
      } else {
        console.log("Waitlist signup (no Google Sheet URL configured):", data);
      }
      setSubmitted(true);
      toast.success("You're on the list! 🎉");
    } catch {
      toast.error("Something went wrong. Please try again.");
    } finally {
      setIsSubmitting(false);
    }
  };

  if (submitted) {
    return (
      <section id="waitlist" className="py-20 md:py-28 section-gradient">
        <div className="container max-w-lg text-center animate-fade-up">
          <div className="relative bg-card rounded-[2.5rem] p-12 shadow-2xl overflow-hidden border border-white">
            <div className="absolute inset-0 bg-gradient-to-br from-primary/10 via-transparent to-accent/10" />
            <div className="relative z-10">
              <div className="w-24 h-24 rounded-full bg-secondary flex items-center justify-center mx-auto mb-8 ring-8 ring-primary/5">
                <CheckCircle2 className="w-12 h-12 text-primary" />
              </div>
              <h2 className="text-3xl font-bold font-heading text-foreground mb-4 tracking-tight">
                You're authenticated!
              </h2>
              <p className="text-muted-foreground leading-relaxed font-medium">
                We'll notify you the moment Swasth becomes available for early access. Keep an eye on your inbox!
              </p>
            </div>
          </div>
        </div>
      </section>
    );
  }

  return (
    <section id="waitlist" className="py-20 md:py-32 section-gradient relative">
      <div className="container max-w-6xl">
        <div className="relative bg-white rounded-[2.5rem] shadow-[0_50px_100px_-20px_rgba(14,165,233,0.15)] overflow-hidden border border-white animate-fade-up">
          <div className="flex flex-col lg:flex-row min-h-[600px]">
            
            {/* Left Box - Heading & Branding */}
            <div className="lg:w-2/5 relative bg-gradient-to-br from-primary to-blue-700 p-10 md:p-16 flex flex-col justify-center overflow-hidden">
              {/* Decorative Bubbles */}
              <div className="absolute top-[-10%] left-[-10%] w-64 h-64 bg-white/10 rounded-full blur-2xl" />
              <div className="absolute bottom-[-15%] right-[-5%] w-80 h-80 bg-blue-400/20 rounded-full blur-3xl animate-pulse-soft" />
              <div className="absolute top-[20%] right-[-10%] w-40 h-40 bg-white/5 rounded-full blur-xl" />
              <div className="absolute bottom-[10%] left-[10%] w-32 h-32 bg-primary-foreground/10 rounded-full blur-lg" />
              
              <div className="relative z-10 space-y-8">
                <div className="inline-flex items-center gap-2 px-4 py-2 rounded-full bg-white/20 backdrop-blur-md border border-white/30 text-white/90 text-xs font-bold uppercase tracking-widest">
                  <Heart className="w-4 h-4 text-white" />
                  Family First
                </div>
                
                <div className="space-y-4">
                  <h2 className="text-4xl md:text-5xl font-black font-heading text-white leading-[1.1] tracking-tighter">
                    Early Access <br />
                    <span className="text-white/80">Registration</span>
                  </h2>
                  <p className="text-white/70 text-lg font-medium leading-relaxed max-w-sm">
                    Reserve your spot for the Swasth launch. It takes less than 30 seconds to join our global community.
                  </p>
                </div>

                <div className="flex items-center gap-4 pt-4">
                  <div className="flex -space-x-3">
                    {[1, 2, 3, 4].map((i) => (
                      <div key={i} className="w-10 h-10 rounded-full border-2 border-primary bg-secondary/50 flex items-center justify-center text-[10px] font-bold text-primary">
                        NRI
                      </div>
                    ))}
                  </div>
                  <p className="text-xs font-bold text-white/60 tracking-wide uppercase">
                    500+ Families Joined
                  </p>
                </div>
              </div>
            </div>

            {/* Right Side - Form */}
            <div className="lg:w-3/5 p-8 md:p-16 bg-white flex flex-col justify-center">
              <form onSubmit={handleSubmit(onSubmit)} className="space-y-6 max-w-md mx-auto w-full text-left">
                <div className="space-y-2 text-left">
                  <label htmlFor="name" className="text-[10px] font-black text-foreground/70 uppercase tracking-widest ml-1">Full Name</label>
                  <div className="relative">
                    <User className="absolute left-4 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-400" />
                    <input
                      id="name"
                      type="text"
                      placeholder="Amit Sharma"
                      {...register("name")}
                      className="w-full pl-11 pr-5 py-4 rounded-xl border-2 border-slate-100 bg-slate-50 text-foreground placeholder:text-slate-400 focus:outline-none focus:border-primary/30 focus:bg-white focus:ring-4 focus:ring-primary/5 transition-all font-body text-sm font-semibold"
                    />
                  </div>
                  {errors.name && <p className="text-destructive text-[10px] font-bold ml-1 uppercase">{errors.name.message}</p>}
                </div>

                <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                  {/* Email */}
                  <div className="space-y-2 text-left">
                    <label htmlFor="email" className="text-[10px] font-black text-foreground/70 uppercase tracking-widest ml-1">Email</label>
                    <div className="relative">
                      <Mail className="absolute left-4 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-400" />
                      <input
                        id="email"
                        type="email"
                        placeholder="amit@example.com"
                        {...register("email")}
                        className="w-full pl-11 pr-5 py-4 rounded-xl border-2 border-slate-100 bg-slate-50 text-foreground placeholder:text-slate-400 focus:outline-none focus:border-primary/30 focus:bg-white focus:ring-4 focus:ring-primary/5 transition-all font-body text-sm font-semibold"
                      />
                    </div>
                    {errors.email && <p className="text-destructive text-[10px] font-bold ml-1 uppercase">{errors.email.message}</p>}
                  </div>

                  {/* Phone */}
                  <div className="space-y-2 text-left">
                    <label htmlFor="phone" className="text-[10px] font-black text-foreground/70 uppercase tracking-widest ml-1">Phone Number</label>
                    <div className="relative">
                      <Phone className="absolute left-4 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-400" />
                      <input
                        id="phone"
                        type="tel"
                        placeholder="+1 234 567 8900"
                        {...register("phone")}
                        className="w-full pl-11 pr-5 py-4 rounded-xl border-2 border-slate-100 bg-slate-50 text-foreground placeholder:text-slate-400 focus:outline-none focus:border-primary/30 focus:bg-white focus:ring-4 focus:ring-primary/5 transition-all font-body text-sm font-semibold"
                      />
                    </div>
                    {errors.phone && <p className="text-destructive text-[10px] font-bold ml-1 uppercase">{errors.phone.message}</p>}
                  </div>
                </div>

                <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                  {/* Your City */}
                  <div className="space-y-2 text-left">
                    <label htmlFor="city" className="text-[10px] font-black text-foreground/70 uppercase tracking-widest ml-1">Your City</label>
                    <div className="relative">
                      <MapPin className="absolute left-4 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-400" />
                      <input
                        id="city"
                        type="text"
                        placeholder="e.g. London"
                        {...register("city")}
                        className="w-full pl-11 pr-5 py-4 rounded-xl border-2 border-slate-100 bg-slate-50 text-foreground placeholder:text-slate-400 focus:outline-none focus:border-primary/30 focus:bg-white focus:ring-4 focus:ring-primary/5 transition-all font-body text-sm font-semibold"
                      />
                    </div>
                    {errors.city && <p className="text-destructive text-[10px] font-bold ml-1 uppercase">{errors.city.message}</p>}
                  </div>

                  {/* Parents City */}
                  <div className="space-y-2 text-left">
                    <label htmlFor="parentCity" className="text-[10px] font-black text-foreground/70 uppercase tracking-widest ml-1">Parent's City</label>
                    <div className="relative">
                      <MapPin className="absolute left-4 top-1/2 -translate-y-1/2 w-4 h-4 text-accent/60" />
                      <input
                        id="parentCity"
                        type="text"
                        placeholder="e.g. Ranchi"
                        {...register("parentCity")}
                        className="w-full pl-11 pr-5 py-4 rounded-xl border-2 border-slate-100 bg-slate-50 text-foreground placeholder:text-slate-400 focus:outline-none focus:border-primary/30 focus:bg-white focus:ring-4 focus:ring-primary/5 transition-all font-body text-sm font-semibold"
                      />
                    </div>
                    {errors.parentCity && <p className="text-destructive text-[10px] font-bold ml-1 uppercase">{errors.parentCity.message}</p>}
                  </div>
                </div>

                {/* Topics */}
                <div className="space-y-4 pt-2 text-left">
                  <label className="text-[10px] font-black text-foreground/70 uppercase tracking-widest ml-1">Health Priorities</label>
                  <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
                    {healthTopics.map((topic) => (
                      <label key={topic.label} className="relative flex flex-col items-center justify-center p-4 cursor-pointer group bg-slate-50 border-2 border-slate-100 hover:border-primary/30 rounded-xl transition-all">
                        <input type="checkbox" value={topic.label} {...register("interests")} className="peer sr-only" />
                        <span className="text-2xl mb-2 grayscale group-hover:grayscale-0 transition-all">{topic.emoji}</span>
                        <span className="text-[10px] font-black text-slate-500 text-center uppercase leading-tight group-hover:text-primary transition-colors">{topic.label}</span>
                        <div className="absolute inset-0 rounded-xl border-2 border-primary opacity-0 peer-checked:opacity-100 transition-all pointer-events-none" />
                      </label>
                    ))}
                  </div>
                </div>

                <button
                  type="submit"
                  disabled={isSubmitting}
                  className="w-full py-5 bg-primary text-white font-black rounded-xl text-lg hover:shadow-xl hover:shadow-primary/20 active:scale-[0.98] transition-all disabled:opacity-50 flex items-center justify-center gap-3 uppercase tracking-widest mt-6"
                >
                  {isSubmitting ? "Processing..." : <>Confirm Interest <Send className="w-5 h-5" /></>}
                </button>
              </form>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
};

export default WaitlistForm;
