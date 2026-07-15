class Purchase < ApplicationRecord
  belongs_to :user

  STATUSES = %w[pending paid refunded].freeze

  validates :book_title, presence: true, length: { maximum: 120 }
  validates :stripe_checkout_session_id, presence: true, uniqueness: true
  validates :status, inclusion: { in: STATUSES }

  scope :paid, -> { where(status: "paid") }
  scope :for_book_key, ->(key) { where(book_key: key) }

  def mark_paid!(payment_intent_id:, amount_cents:, currency:)
    update!(
      status: "paid",
      stripe_payment_intent_id: payment_intent_id,
      amount_cents: amount_cents,
      currency: currency,
      paid_at: Time.current
    )
  end
end
