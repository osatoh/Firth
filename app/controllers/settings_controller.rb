class SettingsController < ApplicationController
  # Taken before any update, so a rejected key is never what the page shows as stored.
  before_action :set_user_and_masked_api_key

  def edit
  end

  def update
    if @user.update(settings_params)
      redirect_to edit_settings_path, notice: t(".notice")
    else
      render :edit, status: :unprocessable_content
    end
  end

  private
    def set_user_and_masked_api_key
      @user = current_user
      @masked_api_key = @user.masked_anthropic_api_key
    end

    # A blank key field means "keep the current key"; deleting it has its own action.
    def settings_params
      params.expect(user: [ :anthropic_api_key, :summary_language ]).compact_blank
    end
end
