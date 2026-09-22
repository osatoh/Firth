class ArticlesController < ApplicationController
  # A cheap stand-in for pagination until the list outgrows it.
  LIMIT = 100

  def index
    @articles = current_user.articles.includes(:feed).newest_first.limit(LIMIT)
  end

  def show
    @article = current_user.articles.find(params[:id])
    # Turbo prefetches links on hover; only a real visit counts as reading.
    @article.mark_read! unless request.headers["X-Sec-Purpose"]&.include?("prefetch")
    @summary_language = current_user.summary_language
    @summary = @article.summaries.find_by(language: @summary_language)
  end

  # Marks the article read, then sends the browser on to its stored original URL.
  # Only that URL is ever used, so this cannot become an open redirect.
  def visit
    article = current_user.articles.find(params[:id])
    return head :unprocessable_content unless article.web_url?

    article.mark_read!
    # Matches the rel="noreferrer" the plain link used to have.
    response.headers["Referrer-Policy"] = "no-referrer"
    redirect_to article.url, allow_other_host: true
  end
end
