require "rails_helper"

RSpec.describe "Sign-in security", type: :request do
  let(:user) { create(:user) }

  it "locks the account after 5 failed attempts" do
    5.times do
      post user_session_path, params: { user: { email: user.email, password: "wrong-password!" } }
    end
    expect(user.reload.locked_at).to be_present
    # Even the correct password is refused while locked.
    post user_session_path, params: { user: { email: user.email, password: user.password } }
    get account_path
    expect(response).to redirect_to(new_user_session_path)
  end

  it "does not reveal whether an email exists (paranoid mode)" do
    post user_password_path, params: { InvisibleCaptcha.honeypots.first => "", user: { email: "nobody@example.com" } }
    follow_redirect!
    expect(response.body).to match(/If your email address exists/i)
  end

  it "does not offer or honor remember-me (login required each session)" do
    get new_user_session_path
    expect(response.body).not_to match(/remember me/i)
    # No rememberable module: the User model must not respond to remember_me=
    # in a way that persists a cookie.
    expect(User.devise_modules).not_to include(:rememberable)
  end

  describe "session concurrency cap" do
    it "keeps at most #{User::MAX_ACTIVE_SESSIONS} devices and signs out the oldest" do
      sessions = (User::MAX_ACTIVE_SESSIONS + 1).times.map do
        device = open_session
        device.post "/users/sign_in", params: { user: { email: user.email, password: user.password } }
        device
      end

      expect(user.active_sessions.count).to eq(User::MAX_ACTIVE_SESSIONS)

      # The first device's session was revoked: next request is bounced to sign-in.
      sessions.first.get "/account"
      expect(sessions.first.response.status).to eq(302)
      expect(sessions.first.response.location).to include("/users/sign_in")

      # The newest device still works.
      sessions.last.get "/account"
      expect(sessions.last.response.status).to eq(200)
    end

    it "revoking a session from the account page signs that device out" do
      device_a = open_session
      device_a.post "/users/sign_in", params: { user: { email: user.email, password: user.password } }
      device_b = open_session
      device_b.post "/users/sign_in", params: { user: { email: user.email, password: user.password } }

      oldest = user.active_sessions.order(:created_at).first
      device_b.delete "/active_sessions/#{oldest.id}"

      device_a.get "/account"
      expect(device_a.response.status).to eq(302)
      expect(device_a.response.location).to include("/users/sign_in")
    end
  end
end
