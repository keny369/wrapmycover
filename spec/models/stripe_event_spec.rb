require "rails_helper"

RSpec.describe StripeEvent, type: :model do
  it "records an event exactly once" do
    expect(StripeEvent.record_once("evt_1", "checkout.session.completed")).to be(true)
    expect(StripeEvent.record_once("evt_1", "checkout.session.completed")).to be(false)
    expect(StripeEvent.where(event_id: "evt_1").count).to eq(1)
  end
end
