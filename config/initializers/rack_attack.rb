# Request throttling and abuse protection. Every limit returns 429 with
# Retry-After rather than erroring, so legitimate users self-recover.
class Rack::Attack
  # Rate-limit counter store. A DB-backed store (Solid Cache) would turn every
  # throttle check into a locked write transaction and fail open under load, so
  # use Redis when available and a fast in-process MemoryStore otherwise.
  # NOTE: MemoryStore is per-process — fine for a single dyno; multi-dyno
  # deployments should set REDIS_URL so limits are shared and global.
  Rack::Attack.cache.store =
    if ENV["REDIS_URL"].present?
      ActiveSupport::Cache::RedisCacheStore.new(url: ENV["REDIS_URL"])
    else
      ActiveSupport::Cache::MemoryStore.new
    end

  # Match on the routed path with the optional format suffix and any trailing
  # slash stripped, so /users/sign_in.json and /users/sign_in/ cannot slip past
  # an exact-string throttle.
  def self.normalized_path(req)
    req.path.sub(/\.\w+\z/, "").chomp("/")
  end

  def self.login_request?(req)
    req.post? && normalized_path(req) == "/users/sign_in"
  end

  ### Global request flood guard (per IP, excludes static assets) ###
  throttle("req/ip", limit: 300, period: 5.minutes) do |req|
    req.ip unless req.path.start_with?("/assets", "/up", "/api/internal")
  end

  ### Internal export-authorization endpoint (signature-gated already) ###
  # Its own generous, separately-keyed limit so a burst of legitimate editor
  # traffic can't trip the global req/ip guard and fail-close paying users.
  throttle("authorize_export/ip", limit: 120, period: 1.minute) do |req|
    req.ip if req.post? && normalized_path(req) == "/api/internal/authorize_export"
  end

  ### Credential attacks ###
  # Brute force one account from many IPs: throttle by target email.
  throttle("logins/email", limit: 5, period: 20.seconds) do |req|
    if login_request?(req)
      req.params.dig("user", "email").to_s.downcase.strip.presence
    end
  end
  # Credential stuffing from one IP.
  throttle("logins/ip", limit: 10, period: 20.seconds) do |req|
    req.ip if login_request?(req)
  end
  # Persistent offenders: ban an IP for an hour after sustained login abuse.
  blocklist("fail2ban/logins") do |req|
    Rack::Attack::Allow2Ban.filter("login-abuse:#{req.ip}", maxretry: 30, findtime: 10.minutes, bantime: 1.hour) do
      login_request?(req)
    end
  end

  ### Account-creation and email spam ###
  throttle("signups/ip", limit: 5, period: 1.hour) do |req|
    req.ip if req.post? && normalized_path(req) == "/users"
  end
  throttle("password_resets/ip", limit: 5, period: 1.hour) do |req|
    req.ip if req.post? && normalized_path(req) == "/users/password"
  end
  # Cap reset emails per destination address too, so one inbox can't be bombed
  # from rotating IPs.
  throttle("password_resets/email", limit: 5, period: 1.hour) do |req|
    if req.post? && normalized_path(req) == "/users/password"
      req.params.dig("user", "email").to_s.downcase.strip.presence
    end
  end
  throttle("confirmations/ip", limit: 5, period: 1.hour) do |req|
    req.ip if req.post? && normalized_path(req) == "/users/confirmation"
  end
  throttle("confirmations/email", limit: 5, period: 1.hour) do |req|
    if req.post? && normalized_path(req) == "/users/confirmation"
      req.params.dig("user", "email").to_s.downcase.strip.presence
    end
  end

  ### Billing endpoints ###
  throttle("checkouts/ip", limit: 10, period: 1.hour) do |req|
    req.ip if req.post? && normalized_path(req) == "/checkouts"
  end

  ### Vulnerability scanners ###
  # Two strikes, one-hour ban: a single probe no longer locks out an entire
  # shared/CGNAT egress IP for a full day.
  BAD_PATHS = %r{\.(php|asp|aspx|env)$|wp-admin|wp-login|phpmyadmin|/\.git}i
  blocklist("fail2ban/scanners") do |req|
    Rack::Attack::Fail2Ban.filter("scanner:#{req.ip}", maxretry: 2, findtime: 1.day, bantime: 1.hour) do
      req.path.match?(BAD_PATHS)
    end
  end

  ### Responses ###
  self.throttled_responder = lambda do |request|
    match_data = request.env["rack.attack.match_data"]
    retry_after = (match_data || {})[:period]
    [ 429,
      { "Content-Type" => "text/plain", "Retry-After" => retry_after.to_s },
      [ "Rate limit exceeded. Try again in #{retry_after} seconds.\n" ] ]
  end

  self.blocklisted_responder = lambda do |_request|
    [ 403, { "Content-Type" => "text/plain" }, [ "Forbidden\n" ] ]
  end
end

ActiveSupport::Notifications.subscribe("throttle.rack_attack") do |_name, _start, _finish, _id, payload|
  req = payload[:request]
  Rails.logger.warn("[rack-attack] throttled #{req.env['rack.attack.matched']} ip=#{req.ip} path=#{req.path}")
end
