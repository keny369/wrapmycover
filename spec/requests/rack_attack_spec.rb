require "rails_helper"

RSpec.describe "Rate limiting", :rack_attack, type: :request do
  it "throttles rapid sign-in attempts from one IP" do
    11.times do |i|
      post "/users/sign_in", params: { user: { email: "a#{i}@example.com", password: "x-long-password" } }
    end
    expect(response).to have_http_status(:too_many_requests)
    expect(response.headers["Retry-After"]).to be_present
  end

  it "throttles brute force against a single email across requests" do
    6.times do
      post "/users/sign_in",
           params: { user: { email: "victim@example.com", password: "guess-guess-guess" } },
           headers: { "REMOTE_ADDR" => "10.0.0.#{rand(255)}" }
    end
    expect(response).to have_http_status(:too_many_requests)
  end

  it "throttles signup floods" do
    6.times do |i|
      post "/users", params: { user: { email: "bot#{i}@example.com",
                                       password: "botbotbotbot1", password_confirmation: "botbotbotbot1" } }
    end
    expect(response).to have_http_status(:too_many_requests)
  end

  it "bans vulnerability scanners after repeated probes (not a single shared-IP strike)" do
    # First probe of a bad path is not an instant full-site ban (avoids
    # collateral lockout of shared/CGNAT egress IPs).
    get "/wp-admin/setup.php"
    get "/wp-login.php"
    get "/phpmyadmin/index.php"
    # After sustained scanning the IP is blocked outright, even on good paths.
    get "/pricing"
    expect(response).to have_http_status(:forbidden)
  end

  it "still throttles logins when a format suffix is appended (.json bypass closed)" do
    11.times do |i|
      post "/users/sign_in.json", params: { user: { email: "a#{i}@example.com", password: "x-long-password" } }
    end
    expect(response).to have_http_status(:too_many_requests)
  end

  it "still throttles logins with a trailing slash" do
    11.times do |i|
      post "/users/sign_in/", params: { user: { email: "b#{i}@example.com", password: "x-long-password" } }
    end
    expect(response).to have_http_status(:too_many_requests)
  end

  it "leaves normal browsing untouched" do
    get "/pricing"
    expect(response).to have_http_status(:ok)
  end
end
