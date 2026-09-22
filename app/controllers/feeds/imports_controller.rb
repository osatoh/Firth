class Feeds::ImportsController < ApplicationController
  def new
  end

  def create
    file = params[:file]
    return reject t(".missing") unless file.respond_to?(:read)

    result = OpmlImport.new(user: current_user, io: file).call
    redirect_to feeds_path, notice: t(".notice", **result.to_h)
  rescue OpmlImport::TooLarge
    reject t(".too_large", size: OpmlImport::MAX_BYTES / 1.megabyte)
  rescue OpmlImport::InvalidFile
    reject t(".invalid_file")
  end

  private
    def reject(message)
      flash.now[:alert] = message
      render :new, status: :unprocessable_content
    end
end
