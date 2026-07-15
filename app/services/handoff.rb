require "jwt"

# Cross-app handoff between the Rails site and the FastAPI editor.
#
# The site mints a short-lived, signed *identity* token (no entitlements — those
# would go stale) that the editor exchanges for its own session. The same shared
# secret signs the HMAC on the editor's server-to-server "may this user export
# this book?" call, so the money decision stays live on this side. The secret
# lives only on the two servers, never in a browser.
module Handoff
  ALGORITHM = "HS256"
  ISSUER = "wrapmycover"
  AUDIENCE = "editor"
  TTL_SECONDS = 600 # 10 minutes; the token is consumed immediately on arrival.

  module_function

  def signing_secret
    ENV.fetch("HANDOFF_SIGNING_SECRET")
  end

  # A short-lived identity-only JWT for the editor.
  def identity_token(user)
    now = Time.now.to_i
    JWT.encode(
      {
        iss: ISSUER,
        aud: AUDIENCE,
        sub: user.id.to_s,
        email: user.email,
        iat: now,
        exp: now + TTL_SECONDS,
        jti: SecureRandom.uuid
      },
      signing_secret,
      ALGORITHM
    )
  end

  # Constant-time check of the `X-Signature: sha256=<hex>` header on an internal
  # server-to-server request, computed over the exact raw request body.
  def valid_signature?(raw_body, signature_header)
    return false if signature_header.blank?

    expected = "sha256=" + OpenSSL::HMAC.hexdigest("SHA256", signing_secret, raw_body.to_s)
    ActiveSupport::SecurityUtils.secure_compare(expected, signature_header)
  end
end
