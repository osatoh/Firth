class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  # ランディングと認証まわり以外の全ページはサインインを必須にする。
  before_action :require_sign_in

  helper_method :signed_in?

  private
    def current_user
      # nil もメモ化する。サインアウト状態でリクエストごとに空クエリを撃たないため。
      return @current_user if defined?(@current_user)

      @current_user = session[:user_id] && User.find_by(id: session[:user_id])
    end

    def signed_in?
      current_user.present?
    end

    def require_sign_in
      redirect_to root_path, alert: "サインインしてください。" unless signed_in?
    end
end
