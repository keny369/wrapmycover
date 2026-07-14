# Device/session concurrency enforcement (User::MAX_ACTIVE_SESSIONS).
#
# A fresh sign-in mints a random token, stored client-side in the session
# cookie and server-side as a SHA-256 digest. Every subsequent request must
# present a token that still exists server-side; revoking the record (from
# the account page, or by the cap evicting the oldest session) ends that
# device's session on its next request.

Warden::Manager.after_set_user except: :fetch do |user, warden, _opts|
  if user.is_a?(User)
    token = ActiveSession.activate!(
      user,
      ip: warden.request.ip,
      user_agent: warden.request.user_agent
    )
    warden.raw_session["active_session_token"] = token
  end
end

Warden::Manager.after_set_user only: :fetch do |user, warden, opts|
  if user.is_a?(User)
    record = ActiveSession.find_by_token(warden.raw_session["active_session_token"])
    if record.nil? || record.user_id != user.id
      warden.raw_session.delete("active_session_token")
      warden.logout(opts[:scope])
      throw :warden, scope: opts[:scope], message: :unauthenticated
    else
      record.touch_last_seen
    end
  end
end

Warden::Manager.before_logout do |user, warden, _opts|
  if user.is_a?(User)
    ActiveSession.find_by_token(warden.raw_session["active_session_token"])&.destroy
    warden.raw_session.delete("active_session_token")
  end
end
