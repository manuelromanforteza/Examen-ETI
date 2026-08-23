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
      redirect_to waiting_path, notice: "Estrategia elegida: #{strategy.name}"
    else
      redirect_to strategies_path, alert: "No se pudo guardar la selección. Intenta de nuevo."
    end
  end
end
