class SeoController < ApplicationController
  # Public marketing/auth URLs to advertise to crawlers. Account/billing pages
  # are intentionally excluded (private, behind auth).
  PUBLIC_PATHS = [
    { path: "/",              changefreq: "weekly",  priority: "1.0" },
    { path: "/pricing",       changefreq: "monthly", priority: "0.8" },
    { path: "/case-studies",  changefreq: "monthly", priority: "0.7" },
    { path: "/founder",       changefreq: "monthly", priority: "0.7" },
    { path: "/users/sign_up", changefreq: "monthly", priority: "0.6" },
    { path: "/users/sign_in", changefreq: "monthly", priority: "0.4" }
  ].freeze

  def robots
    host = ApplicationController::CANONICAL_HOST || request.host
    body = <<~TXT
      User-agent: *
      Allow: /
      Disallow: /account
      Disallow: /checkout
      Disallow: /billing_portal

      Sitemap: https://#{host}/sitemap.xml
    TXT
    render plain: body, content_type: "text/plain"
  end

  def sitemap
    @host = ApplicationController::CANONICAL_HOST || request.host
    @paths = PUBLIC_PATHS
    render layout: false, content_type: "application/xml"
  end
end
