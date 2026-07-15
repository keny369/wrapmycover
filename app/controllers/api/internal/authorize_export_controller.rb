module Api
  module Internal
    # Server-to-server: the editor asks whether a user may export a specific
    # book. Authenticated only by the shared-secret HMAC over the raw body (no
    # Devise, no CSRF, no cookies). The user id is taken from the signed body,
    # never trusted from a browser. Returns the live entitlement decision plus a
    # buy URL for the "not entitled" case.
    class AuthorizeExportController < ActionController::API
      def create
        raw = request.raw_post
        unless Handoff.valid_signature?(raw, request.headers["X-Signature"])
          Rails.logger.warn("[authorize_export] bad signature from #{request.remote_ip}")
          return render json: { error: "bad_signature" }, status: :unauthorized
        end

        data = JSON.parse(raw)
        user = User.find_by(id: data["user_id"])
        return render json: { allowed: false, buy_url: buy_url(data["book_key"]) } unless user

        allowed = user.authorize_export!(
          book_key: data["book_key"].to_s,
          fingerprint: data["fingerprint"].to_s
        )
        render json: { allowed: allowed, buy_url: buy_url(data["book_key"]) }
      rescue JSON::ParserError
        render json: { error: "bad_request" }, status: :bad_request
      end

      private

      # A pricing link carrying the book_key so the purchase binds to the same
      # project. Built from a trusted host constant, never from request data.
      def buy_url(book_key)
        host = ENV.fetch("CANONICAL_HOST", "wrapmycover.com")
        key = book_key.to_s
        query = key.match?(/\A[0-9a-fA-F-]{16,64}\z/) ? "?book_key=#{CGI.escape(key)}" : ""
        "https://#{host}/pricing#{query}"
      end
    end
  end
end
