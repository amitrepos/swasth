import appFamilyView from "@/assets/app-family-view.png";
import weeklyWhatsappReport from "@/assets/weekly_whatsapp_report.png";
import sendReadingViaWhatsapp from "@/assets/Send_reading_via_whatsapp.png";
import DashboardMockup from "./DashboardMockup";

const AppDemoSection = () => {
  return (
    <section className="py-20 md:py-28 bg-card">
      <div className="container px-4">
        <div className="text-center max-w-2xl mx-auto mb-16">
          <span className="text-xs font-bold text-primary uppercase tracking-[0.2em] bg-primary/10 px-4 py-2 rounded-full border border-primary/20">App Preview</span>
          <h2 className="text-3xl md:text-5xl font-extrabold font-heading mt-6 text-foreground tracking-tight">
            Simple for parents, <span className="text-primary">powerful</span> for you
          </h2>
          <p className="text-muted-foreground mt-6 text-lg font-body leading-relaxed font-medium">
            Your parents log vitals in seconds via WhatsApp photos. You get the peace of mind knowing they are safe.
          </p>
        </div>


        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-12 lg:gap-8 items-start max-w-7xl mx-auto">
          <div className="text-center group flex flex-col items-center">
            <div className="relative w-full max-w-[260px]">
              <div className="absolute inset-0 hero-gradient rounded-[2.5rem] blur-xl opacity-10 scale-95 group-hover:opacity-20 transition-opacity duration-500" />
              <div className="relative rounded-[2.5rem] shadow-2xl overflow-hidden border-4 border-white/10 bg-white aspect-[9/19]">
                <DashboardMockup />
              </div>
            </div>
            <h3 className="text-lg font-bold font-heading mt-8 text-foreground group-hover:text-primary transition-colors">Health Dashboard</h3>
            <p className="text-muted-foreground text-xs mt-2 font-medium">All vitals at a glance</p>
          </div>

          <div className="text-center group flex flex-col items-center">
            <div className="relative w-full max-w-[260px]">
              <div className="absolute inset-0 hero-gradient rounded-[2.5rem] blur-xl opacity-10 scale-95 group-hover:opacity-20 transition-opacity duration-500" />
              <img
                src={appFamilyView}
                alt="Family View Mockup"
                className="relative rounded-[2.5rem] shadow-2xl w-full h-auto border-4 border-white/10 bg-white object-cover aspect-[9/19]"
                loading="lazy"
              />
            </div>
            <h3 className="text-lg font-bold font-heading mt-8 text-foreground group-hover:text-primary transition-colors">Family View</h3>
            <p className="text-muted-foreground text-xs mt-2 font-medium">Monitor from anywhere</p>
          </div>

          <div className="text-center group flex flex-col items-center">
            <div className="relative w-full max-w-[260px]">
              <div className="absolute inset-0 hero-gradient rounded-[2.5rem] blur-xl opacity-10 scale-95 group-hover:opacity-20 transition-opacity duration-500" />
              <img
                src={weeklyWhatsappReport}
                alt="Weekly WhatsApp Report Mockup"
                className="relative rounded-[2.5rem] shadow-2xl w-full h-auto border-4 border-white/10 bg-white object-cover aspect-[9/19]"
                loading="lazy"
              />
            </div>
            <h3 className="text-lg font-bold font-heading mt-8 text-foreground group-hover:text-primary transition-colors">WhatsApp Reports</h3>
            <p className="text-muted-foreground text-xs mt-2 font-medium">Weekly insights direct to your phone</p>
          </div>

          <div className="text-center group flex flex-col items-center">
            <div className="relative w-full max-w-[260px]">
              <div className="absolute inset-0 hero-gradient rounded-[2.5rem] blur-xl opacity-10 scale-95 group-hover:opacity-20 transition-opacity duration-500" />
              <img
                src={sendReadingViaWhatsapp}
                alt="WhatsApp Reading Mockup"
                className="relative rounded-[2.5rem] shadow-2xl w-full h-auto border-4 border-white/10 bg-white object-cover aspect-[9/19]"
                loading="lazy"
              />
            </div>
            <h3 className="text-lg font-bold font-heading mt-8 text-foreground group-hover:text-primary transition-colors">Easy Logging</h3>
            <p className="text-muted-foreground text-xs mt-2 font-medium">Share vitals via WhatsApp photos</p>
          </div>
        </div>

      </div>
    </section>
  );
};

export default AppDemoSection;
