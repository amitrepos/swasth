import { useLocation, useNavigate } from "react-router-dom";

const Navbar = () => {
  const location = useLocation();
  const navigate = useNavigate();
  const onHome = location.pathname === "/";

  // "Get Early Access":
  //   - on "/"        → smooth-scroll to #waitlist on this page
  //   - on "/survey"  → smooth-scroll to #survey on this page (the action that matters here)
  //   - elsewhere     → navigate home and let the hash do the scroll
  const handleEarlyAccess = () => {
    if (onHome) {
      document.getElementById("waitlist")?.scrollIntoView({ behavior: "smooth" });
      return;
    }
    if (location.pathname === "/survey") {
      document.getElementById("survey")?.scrollIntoView({ behavior: "smooth" });
      return;
    }
    navigate("/#waitlist");
  };

  // "Features":
  //   - on "/"        → smooth-scroll to #features on this page
  //   - elsewhere     → navigate home with #features hash
  const handleFeatures = (e: React.MouseEvent<HTMLAnchorElement>) => {
    if (onHome) return; // let the native anchor handle in-page scroll
    e.preventDefault();
    navigate("/#features");
  };

  return (
    <nav className="fixed top-0 left-0 right-0 z-50 bg-white/70 backdrop-blur-xl border-b border-primary/5">
      <div className="container flex items-center justify-between h-20">
        <a
          href="/"
          className="flex items-center gap-3 text-2xl font-black font-heading text-foreground tracking-tighter"
        >
          <img src="/logo.png" alt="Swasth Logo" className="w-9 h-9 object-contain" />
          <span>
            Swasth<span className="text-primary">.</span>
          </span>
        </a>
        <div className="flex items-center gap-8">
          <a
            href={onHome ? "#features" : "/#features"}
            onClick={handleFeatures}
            className="text-sm font-bold text-muted-foreground hover:text-primary transition-colors hidden sm:block"
          >
            Features
          </a>
          <button
            onClick={handleEarlyAccess}
            className="px-6 py-2.5 bg-primary text-white font-bold rounded-xl text-sm shadow-[0_10px_20px_-5px_rgba(14,165,233,0.3)] hover:scale-[1.02] transition-all"
          >
            Get Early Access
          </button>
        </div>
      </div>
    </nav>
  );
};

export default Navbar;
