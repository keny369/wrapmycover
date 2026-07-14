require "rails_helper"

RSpec.describe "Account page", type: :request do
  it "requires sign-in" do
    get account_path
    expect(response).to redirect_to(new_user_session_path)
  end

  it "shows purchases, subscription state and devices" do
    user = create(:user)
    create(:purchase, :paid, user: user, book_title: "Vacancy")
    sign_in user

    get account_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Vacancy")
    expect(response.body).to include("Unlocked")
    expect(response.body).to include("Signed-in devices")
  end

  it "does not allow revoking another user's session" do
    victim = create(:user)
    ActiveSession.activate!(victim, ip: "9.9.9.9", user_agent: "victim")
    attacker = create(:user)
    sign_in attacker

    delete active_session_path(victim.active_sessions.sole)
    expect(response).to have_http_status(:not_found)
    expect(victim.active_sessions.count).to eq(1)
  end
end
