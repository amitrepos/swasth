const Navbar = () => {
  const scrollToForm = () => {
    document.getElementById("waitlist")?.scrollIntoView({ behavior: "smooth" });
  };

  return (
    <nav className="fixed top-0 left-0 right-0 z-50 bg-white/70 backdrop-blur-xl border-b border-primary/5">
      <div className="container flex items-center justify-between h-20">
        <a href="/" className="flex items-center gap-3 text-2xl font-black font-heading text-foreground tracking-tighter">
          <img src="/logo.png" alt="Swasth Logo" className="w-9 h-9 object-contain" />
          <span>Swasth<span className="text-primary">.</span></span>
        </a>
        <div className="flex items-center gap-8">
          <a href="#features" className="text-sm font-bold text-muted-foreground hover:text-primary transition-colors hidden sm:block">
            Features
          </a>
          <button
            onClick={scrollToForm}
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
