class FeedsController < ApplicationController
  before_action :set_feed, only: %i[edit update destroy]

  def index
    @feeds = current_user.feeds.order(created_at: :desc)
  end

  def new
    @feed = current_user.feeds.new
  end

  def create
    @feed = current_user.feeds.new(feed_params)

    if @feed.save
      redirect_to feeds_path, notice: "フィードを追加しました。"
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @feed.update(feed_params)
      redirect_to feeds_path, notice: "フィードを更新しました。"
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @feed.destroy!

    redirect_to feeds_path, notice: "フィードを削除しました。"
  end

  private
    # Scoped to the current user, so another user's feed comes back as 404.
    def set_feed
      @feed = current_user.feeds.find(params[:id])
    end

    def feed_params
      params.expect(feed: [ :title, :url ])
    end
end
