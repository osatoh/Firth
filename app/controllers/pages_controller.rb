class PagesController < ApplicationController
  # ランディングはサインインしていない訪問者の受け口なので認証を求めない。
  # ここに増えるページは既定どおり認証必須にしたいので only: を付けている。
  skip_before_action :require_sign_in, only: :landing

  def landing
  end
end
