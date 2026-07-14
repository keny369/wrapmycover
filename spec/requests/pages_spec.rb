require "rails_helper"

RSpec.describe "Public pages", type: :request do
  it "serves the home page" do
    get root_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Turn your ebook cover into a print-ready book cover")
    expect(response.body).to include("The ebook-to-print cover converter")
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
