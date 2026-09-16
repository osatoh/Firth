# Google サインインの設定。
# クライアント ID とシークレットは Rails credentials から読む
# (bin/rails credentials:edit で google_oauth2.client_id / client_secret を設定する)。
Rails.application.config.middleware.use OmniAuth::Builder do
  google_credentials = Rails.application.credentials.google_oauth2 || {}

  provider :google_oauth2,
           google_credentials[:client_id],
           google_credentials[:client_secret],
           scope: "email,profile"
end

# 認証失敗時は例外を投げず、失敗エンドポイントへ回す。
OmniAuth.config.on_failure = OmniAuth::FailureEndpoint
