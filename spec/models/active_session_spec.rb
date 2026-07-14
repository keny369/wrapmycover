require "rails_helper"

RSpec.describe ActiveSession, type: :model do
  let(:user) { create(:user) }

  it "returns a raw token and stores only a digest" do
    token = ActiveSession.activate!(user, ip: "1.2.3.4", user_agent: "RSpec")
    expect(token).to be_present
    record = user.active_sessions.sole
    expect(record.token_digest).to eq(Digest::SHA256.hexdigest(token))
    expect(record.token_digest).not_to eq(token)
  end

  it "caps concurrent sessions and evicts the oldest" do
    tokens = 4.times.map do |i|
      travel_to((4 - i).hours.ago) do
        ActiveSession.activate!(user, ip: "1.2.3.#{i}", user_agent: "RSpec")
      end
    end
    expect(user.active_sessions.count).to eq(User::MAX_ACTIVE_SESSIONS)
    expect(ActiveSession.find_by_token(tokens.first)).to be_nil
    expect(ActiveSession.find_by_token(tokens.last)).to be_present
  end

  it "finds sessions only by exact token" do
    ActiveSession.activate!(user, ip: "1.2.3.4", user_agent: "RSpec")
    expect(ActiveSession.find_by_token("wrong")).to be_nil
    expect(ActiveSession.find_by_token(nil)).to be_nil
  end
end
