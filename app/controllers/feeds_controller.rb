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
  rescue ActiveRecord::RecordNotUnique
    # Two concurrent requests can both clear the uniqueness validation; the
    # unique index catches the loser, which belongs on the form, not in a 500.
    reject_as_taken
    render :new, status: :unprocessable_content
  end

  def edit
  end

  def update
    if @feed.update(feed_params)
      redirect_to feeds_path, notice: "フィードを更新しました。"
    else
      render :edit, status: :unprocessable_content
    end
  rescue ActiveRecord::RecordNotUnique
    reject_as_taken
    render :edit, status: :unprocessable_content
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

    def reject_as_taken
      @feed.errors.add(:url, :taken)
    end

    def feed_params
      params.expect(feed: [ :title, :url ])
    end
end
