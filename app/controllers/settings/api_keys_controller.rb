class Settings::ApiKeysController < ApplicationController
  def destroy
    current_user.update!(anthropic_api_key: nil)

    redirect_to edit_settings_path, notice: t(".notice")
  end
end
