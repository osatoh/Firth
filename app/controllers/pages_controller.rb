class PagesController < ApplicationController
  # The landing page is where signed-out visitors arrive, so it does not require a sign-in.
  # only: keeps that exception to this one action: any page added here stays signed-in only.
  skip_before_action :require_sign_in, only: :landing

  def landing
  end
end
