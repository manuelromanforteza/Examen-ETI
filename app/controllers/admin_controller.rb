class AdminController < ApplicationController
  before_action :authenticate_admin!

  def index
    @tournament      = admin_tournament
    @groups          = @tournament.groups.includes(selection: :strategy).order(:name)
    @selected_count  = @groups.count { |g| g.selection.present? }
    @can_run         = @selected_count >= 2 && @tournament.status.in?(%w[setup collecting])
    @already_run     = @tournament.status.in?(%w[running done])
    @can_edit_rounds = @tournament.status.in?(%w[setup collecting])
  end

  def update_rounds
    tournament = admin_tournament

    unless tournament.status.in?(%w[setup collecting])
      redirect_to admin_path, alert: "No se puede cambiar las rondas una vez iniciado el torneo."
      return
    end

    rounds = params[:rounds_per_match].to_i
    if rounds < 1
      redirect_to admin_path, alert: "El número de rondas debe ser al menos 1."
      return
    end

    tournament.update!(rounds_per_match: rounds)
    redirect_to admin_path, notice: "Rondas por duelo actualizadas a #{rounds}."
  end

  def run_tournament
    tournament = admin_tournament

    unless tournament.status.in?(%w[setup collecting])
      redirect_to admin_path, alert: "El torneo ya fue ejecutado. Puedes ver los resultados o reiniciarlo."
      return
    end

    groups_with_selection = tournament.groups
                                      .joins(:selection)
                                      .includes(selection: :strategy)
                                      .to_a

    if groups_with_selection.size < 2
      redirect_to admin_path, alert: "Se necesitan al menos 2 grupos con estrategia elegida para ejecutar el torneo."
      return
    end

    tournament.update!(status: "running")

    groups_with_selection.combination(2).each do |a, b|
      seed   = GameEngine.deterministic_seed(tournament.id, a.id, b.id)
      result = GameEngine.run_match(
        a.strategy.key.to_sym,
        b.strategy.key.to_sym,
        tournament.rounds_per_match,
        seed: seed
      )

      MatchResult.create!(
        group_a:     a,
        group_b:     b,
        score_a:     result[:score_a],
        score_b:     result[:score_b],
        rounds_json: result[:history].to_json
      )
    end

    tournament.update!(status: "done")

    broadcast_tournament_done(tournament)

    redirect_to results_path, notice: "¡Torneo ejecutado exitosamente! #{groups_with_selection.size} grupos participaron."
  end

  def reset_tournament
    tournament = admin_tournament
    MatchResult.where("group_a_id IN (?) OR group_b_id IN (?)",
                      tournament.groups.ids, tournament.groups.ids).destroy_all
    tournament.update!(status: "collecting")
    redirect_to admin_path, notice: "Torneo reiniciado. Los grupos pueden cambiar su estrategia."
  end

  private

  # Always works on the most recent tournament; creates one if the DB is empty.
  def admin_tournament
    @admin_tournament ||= TournamentSession.order(created_at: :desc).first ||
                          TournamentSession.create!(rounds_per_match: 50, status: "collecting")
  end

  def authenticate_admin!
    password = ENV.fetch("ADMIN_PASSWORD", "admin123")
    authenticate_or_request_with_http_basic("Torneo Admin") do |_user, pass|
      ActiveSupport::SecurityUtils.secure_compare(pass, password)
    end
  end

  def broadcast_tournament_done(tournament)
    redirect_html = <<~HTML.strip
      <div id="tournament_redirect_trigger"
           data-controller="redirect"
           data-redirect-url-value="#{results_path}">
      </div>
    HTML

    Turbo::StreamsChannel.broadcast_replace_to(
      "tournament_#{tournament.id}",
      target: "tournament_redirect_trigger",
      html:   redirect_html
    )
  end
end
