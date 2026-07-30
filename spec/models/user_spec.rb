require "rails_helper"

RSpec.describe User, type: :model do
  it "creates with a strong password" do
    expect(build(:user)).to be_valid
  end

  it "rejects passwords under 12 characters" do
    user = build(:user, password: "short1short")
    expect(user).not_to be_valid
    expect(user.errors[:password]).to be_present
  end

  it "rejects passwords containing the email local part" do
    user = build(:user, email: "leepowell@example.com", password: "xx-leepowell-xx99")
    expect(user).not_to be_valid
    expect(user.errors[:password]).to include("cannot contain your email address")
  end

  it "normalises email case and whitespace" do
    user = create(:user, email: "  Reader@Example.COM ")
    expect(user.email).to eq("reader@example.com")
  end

  describe "#pro?" do
    it "is true with an active subscription" do
      user = create(:user)
      create(:subscription, user: user, status: "active")
      expect(user.reload).to be_pro
    end

    it "is false when the subscription lapsed" do
      user = create(:user)
      create(:subscription, user: user, status: "canceled")
      expect(user.reload).not_to be_pro
    end

    it "is false when the paid period is over" do
      user = create(:user)
      create(:subscription, user: user, status: "active", current_period_end: 2.days.ago)
      expect(user.reload).not_to be_pro
    end
  end

  describe "#authorize_export!" do
    it "allows an admin user for any export" do
      user = create(:user, admin: true)

      expect(user.authorize_export!(book_key: "any-book", fingerprint: "a" * 64)).to be(true)
    end
  end
end
