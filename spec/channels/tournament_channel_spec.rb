require "rails_helper"

RSpec.describe TournamentChannel, type: :channel do
  let(:tournament) { TournamentSession.create!(rounds_per_match: 10, status: "collecting") }

  describe "subscription" do
    it "confirms subscription and streams when given a valid tournament_id" do
      subscribe(tournament_id: tournament.id)
      expect(subscription).to be_confirmed
      expect(subscription).to have_stream_from("tournament_#{tournament.id}")
    end

    it "rejects subscription when tournament does not exist" do
      subscribe(tournament_id: 999_999)
      expect(subscription).to be_rejected
    end

    it "rejects subscription when tournament_id is nil" do
      subscribe(tournament_id: nil)
      expect(subscription).to be_rejected
    end
  end
end
