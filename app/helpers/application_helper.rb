module ApplicationHelper
  # The visual editor is a separate deployment (FastAPI + React). For a
  # signed-in user we append a short-lived identity token in the URL fragment
  # (kept out of logs and Referer); the editor exchanges it for its own session
  # and strips it. Signed-out visitors just get the plain editor URL.
  def editor_url
    base = ENV.fetch("EDITOR_URL", "https://wrapmycover-app-f7c9e884aa33.herokuapp.com")
    return base unless user_signed_in?

    "#{base}#t=#{Handoff.identity_token(current_user)}"
  end
end
