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

  private

  def password_cannot_contain_email
    return if password.blank? || email.blank?

    local_part = email.split("@").first.to_s.downcase
    if local_part.length >= 4 && password.downcase.include?(local_part)
      errors.add(:password, "cannot contain your email address")
    end
  end
end
