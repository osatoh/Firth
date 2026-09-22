# Asks for a summary of the article in the user's current language (spec 4.2).
# The page then shows it, and updates live as the job finishes.
class Articles::SummariesController < ApplicationController
  def create
    article = current_user.articles.find(params[:article_id])
    return redirect_to edit_settings_path, alert: t(".missing_api_key") unless current_user.anthropic_api_key

    article.request_summary(current_user.summary_language)
    redirect_to article
  end
end
