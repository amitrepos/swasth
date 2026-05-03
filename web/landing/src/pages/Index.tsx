import { useEffect } from "react";
import { useLocation } from "react-router-dom";
import Navbar from "@/components/Navbar";
import HeroSection from "@/components/HeroSection";
import FeaturesSection from "@/components/FeaturesSection";
import AppDemoSection from "@/components/AppDemoSection";
import WaitlistForm from "@/components/WaitlistForm";
import Footer from "@/components/Footer";

const Index = () => {
  const location = useLocation();

  // When arriving at "/" with a hash (e.g. clicking "Get Early Access" from
  // /survey navigates to "/#waitlist"), React Router does not auto-scroll.
  // This effect scrolls the target into view once the page mounts.
  useEffect(() => {
    if (!location.hash) return;
    const id = location.hash.replace("#", "");
    const el = document.getElementById(id);
    if (!el) return;
    // Defer to next tick so the element is fully laid out.
    const t = setTimeout(() => el.scrollIntoView({ behavior: "smooth" }), 50);
    return () => clearTimeout(t);
  }, [location.hash]);

  return (
    <>
      <Navbar />
      <main>
        <HeroSection />
        <FeaturesSection />
        <AppDemoSection />
        <WaitlistForm />
      </main>
      <Footer />
    </>
  );
};

export default Index;
