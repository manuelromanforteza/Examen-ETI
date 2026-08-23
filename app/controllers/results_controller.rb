class ResultsController < ApplicationController
  def index
    @tournament = TournamentSession.where(status: "done").order(created_at: :desc).first

    unless @tournament
      redirect_to root_path, alert: "El torneo aún no ha finalizado."
      return
    end

    groups      = @tournament.groups.includes(selection: :strategy).to_a
    group_ids   = groups.map(&:id)
    all_matches = MatchResult.where("group_a_id IN (?) OR group_b_id IN (?)", group_ids, group_ids)
                             .includes(:group_a, :group_b)
                             .to_a

    @leaderboard = groups.map do |group|
      my_matches = all_matches.select { |m| m.group_a_id == group.id || m.group_b_id == group.id }

      total_score = 0
      wins        = 0
      draws       = 0
      details     = []

      my_matches.each do |m|
        if m.group_a_id == group.id
          my_score, their_score, opponent = m.score_a, m.score_b, m.group_b
        else
          my_score, their_score, opponent = m.score_b, m.score_a, m.group_a
        end

        total_score += my_score
        wins        += 1 if my_score > their_score
        draws       += 1 if my_score == their_score

        details << {
          opponent:           opponent,
          opponent_strategy:  opponent.strategy,
          my_score:           my_score,
          their_score:        their_score,
          outcome:            my_score > their_score ? :win : (my_score == their_score ? :draw : :loss)
        }
      end

      {
        group:       group,
        strategy:    group.strategy,
        total_score: total_score,
        wins:        wins,
        draws:       draws,
        losses:      my_matches.size - wins - draws,
        matches:     details
      }
    end.sort_by { |e| [-e[:total_score], -e[:wins]] }

    # Pedagogical split: best total points vs most individual duels won
    @most_points_entry = @leaderboard.first
    @most_wins_entry   = @leaderboard.max_by { |e| [e[:wins], e[:total_score]] }
  end
end
