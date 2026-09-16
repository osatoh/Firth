# Google sign-in setup.
# The client ID and secret come from the Rails credentials
# (set google_oauth2.client_id / client_secret with bin/rails credentials:edit).
Rails.application.config.middleware.use OmniAuth::Builder do
  google_credentials = Rails.application.credentials.google_oauth2 || {}

  provider :google_oauth2,
           google_credentials[:client_id],
           google_credentials[:client_secret],
           scope: "email,profile"
end

# On an authentication failure, hand off to the failure endpoint instead of raising.
OmniAuth.config.on_failure = OmniAuth::FailureEndpoint
