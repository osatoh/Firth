# The one-off prompt shown right after a brand-new user's first sign-in. It can be skipped.
class OnboardingsController < ApplicationController
  before_action { @user = current_user }

  def show
  end

  def update
    if @user.update(onboarding_params)
      redirect_to articles_path, notice: t(".notice")
    else
      render :show, status: :unprocessable_content
    end
  end

  private
    # A blank key field means "no key for now", the same as skipping.
    def onboarding_params
      params.expect(user: [ :anthropic_api_key, :summary_language ]).compact_blank
    end
end
