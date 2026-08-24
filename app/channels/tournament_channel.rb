class TournamentChannel < ActionCable::Channel::Base
  def subscribed
    tournament_id = params[:tournament_id].to_i
    tournament    = TournamentSession.find_by(id: tournament_id)

    if tournament.nil?
      reject
    else
      stream_from "tournament_#{tournament_id}"
    end
  end

  def unsubscribed
    # Cleanup is handled automatically by Action Cable
  end
end
