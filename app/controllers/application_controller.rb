class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  helper_method :current_group, :active_session

  private

  def current_group
    return @current_group if defined?(@current_group)
    @current_group = Group.find_by(id: session[:group_id])
  end

  # Returns the one active TournamentSession (setup or collecting).
  # Creates a default one if none exists.
  def active_session
    @active_session ||= TournamentSession.where(status: %w[setup collecting])
                                         .order(created_at: :desc)
                                         .first_or_create!(rounds_per_match: 10, status: "collecting")
  end

  def require_group!
    unless current_group
      redirect_to join_path, alert: "Debes ingresar con tu nombre y PIN primero."
    end
  end
end
