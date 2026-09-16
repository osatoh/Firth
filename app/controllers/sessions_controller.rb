class SessionsController < ApplicationController
  # サインインの前後を扱うコントローラなので、認証を求めない。
  skip_before_action :require_sign_in

  # OmniAuth のコールバック。CSRF トークンは Google からの POST には載らないため検証しない
  # (リクエストフェーズは omniauth-rails_csrf_protection で保護している)。
  skip_forgery_protection only: :create

  def create
    user = User.find_or_initialize_by(google_uid: auth[:uid])
    # サインインのたびに Google 側の最新のメールアドレスと名前を反映する
    user.update!(email: auth[:info][:email], name: auth[:info][:name])

    reset_session
    session[:user_id] = user.id

    redirect_to root_path, notice: "サインインしました。"
  end

  def destroy
    reset_session

    redirect_to root_path, notice: "サインアウトしました。"
  end

  def failure
    redirect_to root_path, alert: "サインインできませんでした。"
  end

  private
    def auth
      request.env["omniauth.auth"]
    end
end
