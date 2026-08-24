class MatchesController < ApplicationController
  before_action :require_group!
  before_action :require_done_tournament!

  def index
    @group   = current_group
    @tournament = @group.session
    group_id = @group.id

    @my_matches = MatchResult
                    .where("group_a_id = ? OR group_b_id = ?", group_id, group_id)
                    .includes(:group_a, :group_b,
                              group_a: { selection: :strategy },
                              group_b: { selection: :strategy })
                    .to_a
                    .map { |mr| decorate_match(mr, @group) }
                    .sort_by { |m| -m[:my_score] }
  end

  def show
    @group     = current_group
    match      = MatchResult.find(params[:id])

    # Security: group can only view matches they participated in
    unless match.group_a_id == @group.id || match.group_b_id == @group.id
      redirect_to my_matches_path, alert: "No tienes acceso a ese duelo."
      return
    end

    @match     = decorate_match(match, @group)
    @rounds    = match.rounds   # parsed array of { "a" => ..., "b" => ..., ... }
    @tournament = @group.session
  end

  private

  def require_done_tournament!
    unless current_group&.session&.status == "done"
      redirect_to waiting_path, alert: "Los resultados estarán disponibles cuando el torneo haya finalizado."
    end
  end

  def decorate_match(mr, group)
    if mr.group_a_id == group.id
      my_score    = mr.score_a
      their_score = mr.score_b
      opponent    = mr.group_b
      my_side     = :a
    else
      my_score    = mr.score_b
      their_score = mr.score_a
      opponent    = mr.group_a
      my_side     = :b
    end

    outcome = if my_score > their_score
                :win
              elsif my_score == their_score
                :draw
              else
                :loss
              end

    {
      id:             mr.id,
      match:          mr,
      opponent:       opponent,
      opponent_strategy: opponent.strategy,
      my_score:       my_score,
      their_score:    their_score,
      outcome:        outcome,
      my_side:        my_side
    }
  end
end
