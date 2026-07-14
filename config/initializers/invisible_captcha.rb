InvisibleCaptcha.setup do |config|
  # Deterministic honeypot field name (also keeps specs stable).
  config.honeypots = [ "fax_number_confirm" ]
  # Minimum-time check: forms submitted faster than a human plausibly could
  # are treated as bots. Disabled in tests.
  config.timestamp_enabled = !Rails.env.test?
  # Spinner is a session-bound token minted when the form is rendered;
  # direct POSTs without a form fetch are rejected. Off in tests.
  config.spinner_enabled = !Rails.env.test?
  config.timestamp_threshold = 3 # seconds
end
