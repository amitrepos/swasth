const Footer = () => {
  return (
    <footer className="bg-[#0C1A2E] text-white/70 py-16">
      <div className="container px-6">
        <div className="flex flex-col md:flex-row items-center justify-between gap-10">
          <div className="text-center md:text-left">
            <span className="text-3xl font-black font-heading text-white tracking-tighter">
              Swasth<span className="text-primary">.</span>
            </span>
            <p className="text-sm mt-3 font-medium text-white/50">Keep your parents healthy — from anywhere.</p>
          </div>
          <div className="flex items-center gap-8 text-sm font-bold">
            <a href="/privacy" className="hover:text-primary transition-colors">
              Privacy commitment
            </a>
            <a href="mailto:hello@swasth.app" className="hover:text-primary transition-colors">
              Get in touch
            </a>
          </div>
        </div>
        <div className="border-t border-white/5 mt-10 pt-8 text-center text-xs font-medium text-white/30 tracking-widest uppercase">
          © {new Date().getFullYear()} SWASTH TECHNOLOGIES. ALL RIGHTS RESERVED.
        </div>
      </div>
    </footer>

  );
};

export default Footer;
