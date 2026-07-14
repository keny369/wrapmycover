class ActiveSession < ApplicationRecord
  belongs_to :user

  validates :token_digest, presence: true, uniqueness: true

  # Creates a session record and enforces the per-user concurrency cap by
  # revoking the oldest sessions. Returns the raw token for cookie storage.
  def self.activate!(user, ip:, user_agent:)
    token = SecureRandom.hex(32)
    user.active_sessions.create!(
      token_digest: digest(token),
      ip: ip,
      user_agent: user_agent.to_s.first(255),
      last_seen_at: Time.current
    )
    overflow = user.active_sessions.order(last_seen_at: :desc)
                   .offset(User::MAX_ACTIVE_SESSIONS)
    overflow.destroy_all
    token
  end

  def self.find_by_token(token)
    return nil if token.blank?

    find_by(token_digest: digest(token))
  end

  def self.digest(token)
    Digest::SHA256.hexdigest(token)
  end

  def touch_last_seen
    update_column(:last_seen_at, Time.current) if last_seen_at.nil? || last_seen_at < 5.minutes.ago
  end
end
