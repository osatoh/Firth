class ArticlesController < ApplicationController
  PER_PAGE = 50

  # Keyset pagination: ?before=<id> continues after that article, so pages
  # stay cheap and stable while new articles arrive.
  def index
    articles = current_user.articles.includes(:feed).newest_first
    articles = articles.older_than(current_user.articles.find(params[:before])) if params[:before]
    # One extra row tells whether an older page exists.
    @articles = articles.limit(PER_PAGE + 1).to_a
    if @articles.size > PER_PAGE
      @articles.pop
      @next_cursor = @articles.last.id
    end
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
