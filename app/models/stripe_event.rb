class StripeEvent < ApplicationRecord
  validates :event_id, presence: true, uniqueness: true

  # Records the event id; returns false if we've already processed it.
  def self.record_once(event_id, event_type)
    create!(event_id: event_id, event_type: event_type)
    true
  rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
    false
  end
end
