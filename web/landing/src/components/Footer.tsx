const Footer = () => {
  return (
    <footer className="bg-[#0C1A2E] text-white/70 py-16">
      <div className="container px-6">
        <div className="flex flex-col md:flex-row items-center justify-between gap-10">
          {/* Brand */}
          <div className="text-center md:text-left">
            <span className="text-3xl font-black font-heading text-white tracking-tighter">
              Swasth<span className="text-primary">.</span>
            </span>
            <p className="text-sm mt-3 font-medium text-white/50">Keep your parents healthy — from anywhere.</p>
          </div>

          {/* Nav links */}
          <div className="flex items-center gap-8 text-sm font-bold">
            <a href="/privacy" className="hover:text-primary transition-colors">
              Privacy
            </a>
          </div>
        </div>

        {/* Contact Us */}
        <div className="border-t border-white/10 mt-10 pt-10">
          <p className="text-xs font-black uppercase tracking-widest text-white/40 text-center mb-6">Contact Us</p>
          <div className="flex flex-col sm:flex-row items-center justify-center gap-6 text-sm font-semibold">
            <a
              href="https://mail.google.com/mail/?view=cm&to=support@swasth.health"
              target="_blank"
              rel="noopener noreferrer"
              className="flex items-center gap-2 px-5 py-3 rounded-full border border-white/10 hover:border-primary hover:text-primary transition-all"
            >
              <svg xmlns="http://www.w3.org/2000/svg" className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                <path strokeLinecap="round" strokeLinejoin="round" d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" />
              </svg>
              support@swasth.health
            </a>
            <a
              href="tel:+919742897375"
              className="flex items-center gap-2 px-5 py-3 rounded-full border border-white/10 hover:border-primary hover:text-primary transition-all"
            >
              <svg xmlns="http://www.w3.org/2000/svg" className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                <path strokeLinecap="round" strokeLinejoin="round" d="M3 5a2 2 0 012-2h3.28a1 1 0 01.948.684l1.498 4.493a1 1 0 01-.502 1.21l-2.257 1.13a11.042 11.042 0 005.516 5.516l1.13-2.257a1 1 0 011.21-.502l4.493 1.498a1 1 0 01.684.949V19a2 2 0 01-2 2h-1C9.716 21 3 14.284 3 6V5z" />
              </svg>
              +91 97428 97375
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
