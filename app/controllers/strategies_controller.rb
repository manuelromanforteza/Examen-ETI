class StrategiesController < ApplicationController
  before_action :require_group!

  def index
    @strategies = Strategy.all.order(:name)
    @current_selection = current_group.selection
    @tournament = current_group.session
    @can_change = @tournament.status.in?(%w[setup collecting])
  end

  def pick
    tournament = current_group.session

    unless tournament.status.in?(%w[setup collecting])
      redirect_to waiting_path, alert: "El torneo ya está en curso; no se puede cambiar la estrategia."
      return
    end

    strategy = Strategy.find(params[:id])
    selection = current_group.selection || current_group.build_selection
    selection.strategy = strategy

    if selection.save
      broadcast_counter(tournament)
      redirect_to waiting_path, notice: "Estrategia elegida: #{strategy.name}"
    else
      redirect_to strategies_path, alert: "No se pudo guardar la selección. Intenta de nuevo."
    end
  end

  private

  def broadcast_counter(tournament)
    ready = tournament.groups.joins(:selection).count
    total = tournament.groups.count
    html  = ready_counter_html(ready, total)

    Turbo::StreamsChannel.broadcast_replace_to(
      "tournament_#{tournament.id}",
      target: "ready_counter",
      html:   html
    )
  end

  def ready_counter_html(ready, total)
    <<~HTML.strip
      <span id="ready_counter">
        <span class="font-semibold text-indigo-600">#{ready}</span>
        de
        <span class="font-semibold text-indigo-600">#{total}</span>
        grupos han elegido su estrategia.
      </span>
    HTML
  end
end
