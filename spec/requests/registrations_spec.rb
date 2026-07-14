require "rails_helper"

RSpec.describe "Sign-up", type: :request do
  include ActiveJob::TestHelper

  let(:honeypot) { InvisibleCaptcha.honeypots.first }
  let(:valid_params) do
    { honeypot => "",
      user: { email: "author@example.com",
              password: "a-long-and-strong-pass",
              password_confirmation: "a-long-and-strong-pass" } }
  end

  it "creates an unconfirmed account and sends a confirmation email" do
    expect {
      post user_registration_path, params: valid_params
    }.to change(User, :count).by(1)
    user = User.find_by(email: "author@example.com")
    expect(user.confirmed_at).to be_nil
    expect(ActionMailer::Base.deliveries.map(&:subject).join).to match(/confirm/i)
  end

  it "rejects a password shorter than 12 characters" do
    post user_registration_path, params: {
      honeypot => "",
      user: { email: "a@example.com", password: "short1", password_confirmation: "short1" }
    }
    expect(User.find_by(email: "a@example.com")).to be_nil
    expect(response.body).to include("too short")
  end

  it "does not reveal that an email already has an account" do
    create(:user, email: "author@example.com")
    expect {
      post user_registration_path, params: valid_params
    }.not_to change(User, :count)
    # Same generic response a brand-new signup gets; no "already been taken".
    expect(response).to redirect_to(root_path)
    expect(response.body).not_to match(/already been taken/i)
  end

  it "emails the real owner when their address is used to sign up" do
    create(:user, email: "author@example.com")
    expect {
      perform_enqueued_jobs { post user_registration_path, params: valid_params }
    }.to change { ActionMailer::Base.deliveries.size }.by(1)
    expect(ActionMailer::Base.deliveries.last.subject).to match(/tried to sign up/i)
  end

  it "silently swallows honeypot submissions without creating a user" do
    expect {
      post user_registration_path, params: valid_params.merge(honeypot => "http://spam.example")
    }.not_to change(User, :count)
    expect(response).to have_http_status(:ok)
    expect(response.body).to be_blank
  end
end
