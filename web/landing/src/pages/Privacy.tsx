import Navbar from "@/components/Navbar";
import Footer from "@/components/Footer";

const Privacy = () => {
  return (
    <>
      <Navbar />
      <main className="pt-24 pb-16">
        <div className="container max-w-3xl">
          <h1 className="text-3xl md:text-4xl font-bold font-heading text-foreground mb-8">
            Privacy Policy
          </h1>
          <div className="prose prose-gray max-w-none space-y-6 text-muted-foreground">
            <p className="text-sm">Last updated: April 2026</p>

            <section>
              <h2 className="text-xl font-semibold font-heading text-foreground mt-8 mb-3">What We Collect</h2>
              <p>When you sign up for the Swasth waitlist, we collect:</p>
              <ul className="list-disc pl-6 space-y-1">
                <li>Your name and email address</li>
                <li>Your current city of residence</li>
                <li>Your parent's city in India</li>
                <li>Health topics that interest you (e.g., diabetes management, blood pressure monitoring, general wellness)</li>
              </ul>
            </section>

            <section>
              <h2 className="text-xl font-semibold font-heading text-foreground mt-8 mb-3">How We Use It</h2>
              <p>Your information is used solely to:</p>
              <ul className="list-disc pl-6 space-y-1">
                <li>Add you to our waitlist and notify you when Swasth launches in your area</li>
                <li>Send you occasional updates about Swasth (no spam, we promise)</li>
                <li>Help us understand which regions and health topics to prioritize</li>
              </ul>
            </section>

            <section>
              <h2 className="text-xl font-semibold font-heading text-foreground mt-8 mb-3">Data Sharing</h2>
              <p>We do not sell, rent, or share your personal data with any third parties. Period.</p>
            </section>

            <section>
              <h2 className="text-xl font-semibold font-heading text-foreground mt-8 mb-3">Data Deletion</h2>
              <p>
                You can request deletion of your data at any time by emailing us at{" "}
                <a href="mailto:hello@swasth.health" className="text-primary underline">hello@swasth.health</a>.
                We will remove your information within 7 business days.
              </p>
            </section>

            <section>
              <h2 className="text-xl font-semibold font-heading text-foreground mt-8 mb-3">Security</h2>
              <p>
                Your data is stored securely with encryption at rest and in transit. We follow industry best practices to protect your information.
              </p>
            </section>

            <section>
              <h2 className="text-xl font-semibold font-heading text-foreground mt-8 mb-3">Contact</h2>
              <p>
                Questions about this policy? Reach us at{" "}
                <a href="mailto:hello@swasth.health" className="text-primary underline">hello@swasth.health</a>.
              </p>
            </section>
          </div>
        </div>
      </main>
      <Footer />
    </>
  );
};

export default Privacy;
