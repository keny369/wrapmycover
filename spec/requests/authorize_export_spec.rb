require "rails_helper"

# The server-to-server export gate the editor calls. The security-critical
# rules: only a valid HMAC is trusted, Pro passes, a book purchase unlocks only
# the one cover it was bound to, and everything else is refused.
RSpec.describe "POST /api/internal/authorize_export", type: :request do
  let(:secret) { "test-handoff-secret-0123456789abcdef" }
  let(:fingerprint) { "a" * 64 }
  let(:other_fingerprint) { "b" * 64 }
  let(:book_key) { "11111111-1111-4111-8111-111111111111" }

  around do |example|
    ClimateControl.modify(HANDOFF_SIGNING_SECRET: secret) { example.run }
  rescue NameError
    # No ClimateControl gem: fall back to setting the env directly.
    old = ENV["HANDOFF_SIGNING_SECRET"]
    ENV["HANDOFF_SIGNING_SECRET"] = secret
    example.run
    ENV["HANDOFF_SIGNING_SECRET"] = old
  end

  def post_authorize(body)
    raw = body.to_json
    sig = "sha256=" + OpenSSL::HMAC.hexdigest("SHA256", secret, raw)
    post "/api/internal/authorize_export", params: raw,
         headers: { "CONTENT_TYPE" => "application/json", "X-Signature" => sig }
  end

  it "rejects a request with no or wrong signature" do
    user = create(:user)
    raw = { user_id: user.id, book_key: book_key, fingerprint: fingerprint }.to_json
    post "/api/internal/authorize_export", params: raw,
         headers: { "CONTENT_TYPE" => "application/json", "X-Signature" => "sha256=deadbeef" }
    expect(response).to have_http_status(:unauthorized)
  end

  it "allows a Pro user for any book" do
    user = create(:user)
    create(:subscription, user: user, status: "active", current_period_end: 1.month.from_now)
    post_authorize(user_id: user.id, book_key: book_key, fingerprint: fingerprint)
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body["allowed"]).to be(true)
  end

  it "allows an admin user for any book" do
    user = create(:user, admin: true)
    post_authorize(user_id: user.id, book_key: book_key, fingerprint: fingerprint)
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body["allowed"]).to be(true)
  end

  it "binds a book purchase to the first cover exported, then only that cover" do
    user = create(:user)
    create(:purchase, :paid, user: user, book_key: book_key, content_fingerprint: nil)

    # First export binds the fingerprint and is allowed.
    post_authorize(user_id: user.id, book_key: book_key, fingerprint: fingerprint)
    expect(response.parsed_body["allowed"]).to be(true)

    # Re-exporting the same cover (same fingerprint) still passes.
    post_authorize(user_id: user.id, book_key: book_key, fingerprint: fingerprint)
    expect(response.parsed_body["allowed"]).to be(true)

    # A DIFFERENT cover under the same purchased book_key is refused.
    post_authorize(user_id: user.id, book_key: book_key, fingerprint: other_fingerprint)
    expect(response.parsed_body["allowed"]).to be(false)
    expect(response.parsed_body["buy_url"]).to include("/pricing")
  end

  it "refuses a user with no purchase for the book_key, and returns a buy_url" do
    user = create(:user)
    post_authorize(user_id: user.id, book_key: book_key, fingerprint: fingerprint)
    expect(response.parsed_body["allowed"]).to be(false)
    expect(response.parsed_body["buy_url"]).to include("book_key=#{book_key}")
  end

  it "does not let a purchase for one book_key unlock a different book_key" do
    user = create(:user)
    create(:purchase, :paid, user: user, book_key: book_key, content_fingerprint: fingerprint)
    post_authorize(user_id: user.id, book_key: "22222222-2222-4222-8222-222222222222", fingerprint: fingerprint)
    expect(response.parsed_body["allowed"]).to be(false)
  end

  it "does not honour a refunded purchase" do
    user = create(:user)
    create(:purchase, user: user, book_key: book_key, content_fingerprint: fingerprint, status: "refunded")
    post_authorize(user_id: user.id, book_key: book_key, fingerprint: fingerprint)
    expect(response.parsed_body["allowed"]).to be(false)
  end

  it "does not honour a still-pending (unpaid) purchase" do
    user = create(:user)
    create(:purchase, user: user, book_key: book_key, status: "pending")
    post_authorize(user_id: user.id, book_key: book_key, fingerprint: fingerprint)
    expect(response.parsed_body["allowed"]).to be(false)
  end

  it "returns a well-formed error for an unparseable body" do
    raw = "not json"
    sig = "sha256=" + OpenSSL::HMAC.hexdigest("SHA256", secret, raw)
    post "/api/internal/authorize_export", params: raw,
         headers: { "CONTENT_TYPE" => "application/json", "X-Signature" => sig }
    expect(response).to have_http_status(:bad_request)
  end
end
