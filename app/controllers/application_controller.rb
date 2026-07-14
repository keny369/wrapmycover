class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  # Single canonical host: 301 any other host (www, *.herokuapp.com) to it, so
  # search engines index one hostname. Disabled unless CANONICAL_HOST is set.
  CANONICAL_HOST = ENV["CANONICAL_HOST"].presence

  before_action :redirect_to_canonical_host
  helper_method :canonical_url

  # Absolute, self-referencing canonical for the current page on the canonical host.
  def canonical_url
    "https://#{CANONICAL_HOST || request.host}#{request.path}"
  end

  private

  def redirect_to_canonical_host
    return unless CANONICAL_HOST && Rails.env.production?
    return if request.host == CANONICAL_HOST
    return unless request.get? || request.head?

    redirect_to "https://#{CANONICAL_HOST}#{request.fullpath}",
                status: :moved_permanently, allow_other_host: true
  end
end
