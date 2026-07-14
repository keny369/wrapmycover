class ActiveSessionsController < ApplicationController
  before_action :authenticate_user!

  def destroy
    current_user.active_sessions.find(params[:id]).destroy
    redirect_to account_path, notice: "Session signed out.", status: :see_other
  end
end
