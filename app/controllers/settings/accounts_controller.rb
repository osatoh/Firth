class Settings::AccountsController < ApplicationController
  def destroy
    current_user.destroy!
    reset_session

    redirect_to root_path, notice: t(".notice")
  end
end
