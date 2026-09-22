class SessionsController < ApplicationController
  # This controller handles both sides of signing in, so it does not require a sign-in.
  skip_before_action :require_sign_in

  # The OmniAuth callback. Google's POST carries no CSRF token, so the check is skipped here
  # (the request phase is protected by omniauth-rails_csrf_protection).
  skip_forgery_protection only: :create

  def create
    user = User.find_or_initialize_by(google_uid: auth[:uid])
    # Only the sign-in that creates the user is prompted; skipping needs nothing remembered.
    first_sign_in = user.new_record?
    # Pick up the latest email and name from Google on every sign-in.
    user.update!(email: auth[:info][:email], name: auth[:info][:name])

    reset_session
    session[:user_id] = user.id

    redirect_to first_sign_in ? onboarding_path : root_path, notice: t(".notice")
  end

  def destroy
    reset_session

    redirect_to root_path, notice: t(".notice")
  end

  def failure
    redirect_to root_path, alert: t(".alert")
  end

  private
    def auth
      request.env["omniauth.auth"]
    end
end
