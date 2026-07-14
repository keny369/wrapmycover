require "rails_helper"

RSpec.describe "Public pages", type: :request do
  it "serves the home page" do
    get root_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Turn your ebook cover into a print-ready book cover")
    expect(response.body).to include("The ebook-to-print cover converter")
  end

  describe "SEO markup" do
    it "sets the html lang attribute" do
      get root_path
      expect(response.body).to match(/<html[^>]*\blang="en"/)
    end

    it "has a self-referencing canonical link" do
      get root_path
      expect(response.body).to match(%r{<link rel="canonical" href="https?://[^"]+/">})
    end

    it "gives each page a unique meta description of 50-165 chars" do
      get root_path
      home_desc = response.body[/<meta name="description" content="([^"]+)"/, 1]
      get pricing_path
      pricing_desc = response.body[/<meta name="description" content="([^"]+)"/, 1]

      [ home_desc, pricing_desc ].each do |d|
        expect(d).to be_present
        expect(d.length).to be_between(50, 165)
      end
      expect(home_desc).not_to eq(pricing_desc)
    end

    it "has Open Graph title, description and image" do
      get root_path
      expect(response.body).to match(/<meta property="og:title" content="[^"]+"/)
      expect(response.body).to match(/<meta property="og:description" content="[^"]+"/)
      expect(response.body).to match(%r{<meta property="og:image" content="https?://[^"]+/og-image\.png"})
    end

    it "embeds JSON-LD with Organization and WebSite" do
      get root_path
      json = response.body[%r{<script type="application/ld\+json"[^>]*>(.+?)</script>}m, 1]
      expect(json).to be_present
      data = JSON.parse(json)
      types = data["@graph"].map { |n| n["@type"] }
      expect(types).to include("Organization", "WebSite")
    end
  end

  describe "robots.txt" do
    it "is reachable, plain text, and references the sitemap" do
      get "/robots.txt"
      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("text/plain")
      expect(response.body).to match(%r{Sitemap: https?://[^\s]+/sitemap\.xml})
      expect(response.body).to include("User-agent: *")
    end
  end

  describe "sitemap.xml" do
    it "is valid XML listing public URLs" do
      get "/sitemap.xml"
      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("application/xml")
      expect(response.body).to include("<urlset")
      expect(response.body).to match(%r{<loc>https?://[^<]+/</loc>})
      expect(response.body).to match(%r{<loc>https?://[^<]+/pricing</loc>})
    end
  end

  it "serves the pricing page" do
    get pricing_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("$14.99")
    expect(response.body).to include("$99")
  end

  it "sends a strict Content-Security-Policy" do
    get root_path
    csp = response.headers["Content-Security-Policy"]
    expect(csp).to include("default-src 'self'")
    expect(csp).to include("frame-ancestors 'none'")
    expect(csp).to include("object-src 'none'")
    expect(csp).to include("form-action 'self'")
  end

  it "sends X-Content-Type-Options and X-Frame-Options" do
    get root_path
    expect(response.headers["X-Content-Type-Options"]).to eq("nosniff")
    expect(response.headers["X-Frame-Options"]).to be_present
  end
end
