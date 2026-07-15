module ApplicationHelper
  # The visual editor is a separate deployment (FastAPI + React). Until the
  # two apps share auth, the site links signed-in users across to it.
  def editor_url
    ENV.fetch("EDITOR_URL", "https://wrapmycover-app-f7c9e884aa33.herokuapp.com")
  end
end
