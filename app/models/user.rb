class User < ApplicationRecord
  # No :rememberable by design — the app requires an active login each session
  # (durable, revocable server-side sessions via ActiveSession). A persistent
  # remember-me cookie would survive session revocation and defeat the device cap.
  devise :database_authenticatable, :registerable,
         :recoverable, :validatable,
         :confirmable, :lockable, :timeoutable, :trackable

  has_many :purchases, dependent: :destroy
  has_many :active_sessions, dependent: :destroy
  has_one :subscription, dependent: :destroy

  # Concurrent device/session cap; oldest session is revoked beyond this.
  MAX_ACTIVE_SESSIONS = 3

  validate :password_cannot_contain_email

  def pro?
    subscription.present? && subscription.active?
  end

  def paid_books
    purchases.where(status: "paid")
  end

  # The export gate. Pro users always pass. Otherwise there must be a paid
  # purchase for this book_key, and it must be bound to the cover being
  # exported: the fingerprint (computed server-side by the engine from the
  # actual artwork) is recorded on the first authorized export and every later
  # export must match it, so one purchase unlocks re-exports of the same cover
  # and nothing else. Writes the binding on first use.
  def authorize_export!(book_key:, fingerprint:)
    return true if admin? || pro?
    return false if book_key.blank? || fingerprint.blank?

    purchase = paid_books.for_book_key(book_key).order(:created_at).first
    return false unless purchase

    if purchase.content_fingerprint.blank?
      purchase.update!(content_fingerprint: fingerprint)
      true
    else
      ActiveSupport::SecurityUtils.secure_compare(purchase.content_fingerprint, fingerprint)
    end
  end

  private

  def password_cannot_contain_email
    return if password.blank? || email.blank?

    local_part = email.split("@").first.to_s.downcase
    if local_part.length >= 4 && password.downcase.include?(local_part)
      errors.add(:password, "cannot contain your email address")
    end
  end
end
