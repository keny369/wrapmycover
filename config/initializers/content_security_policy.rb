# Strict Content Security Policy. Card entry happens on Stripe-hosted
# Checkout (a redirect), so no payment scripts or frames are needed here.
Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self
    policy.base_uri    :self
    policy.font_src    :self
    policy.img_src     :self, :data
    policy.object_src  :none
    policy.script_src  :self
    # Turbo injects a progress-bar <style>; styles are otherwise compiled.
    policy.style_src   :self, :unsafe_inline
    policy.connect_src :self
    policy.form_action :self
    policy.frame_ancestors :none
  end

  # Per-request random nonce for inline scripts (importmap tags get it
  # automatically). Never derive the nonce from session.id or any stable value
  # — a nonce must be unpredictable and unique per response.
  config.content_security_policy_nonce_generator = ->(_request) { SecureRandom.base64(16) }
  config.content_security_policy_nonce_directives = %w[script-src]
end
