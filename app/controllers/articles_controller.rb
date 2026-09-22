class ArticlesController < ApplicationController
  # A cheap stand-in for pagination until the list outgrows it.
  LIMIT = 100

  def index
    @articles = current_user.articles.includes(:feed).newest_first.limit(LIMIT)
  end
end
