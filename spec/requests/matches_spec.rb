require "rails_helper"

RSpec.describe "Match replay", type: :request do
  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------
  def login_as(group, pin)
    post join_path, params: { name: group.name, pin: pin }
  end

  # ---------------------------------------------------------------------------
  # Fixtures: tournament with 2 groups and 1 match result
  # Start as "collecting" so login works, then update to "done" before tests
  # ---------------------------------------------------------------------------
  let!(:tournament) { TournamentSession.create!(rounds_per_match: 5, status: "collecting") }

  let!(:s_tft) { Strategy.find_or_create_by!(key: "tit_for_tat") { |s|
    s.name = "Tit for Tat"; s.description = "d"; s.pros = "p"; s.cons = "c" } }
  let!(:s_ad)  { Strategy.find_or_create_by!(key: "always_defect") { |s|
    s.name = "Always Defect"; s.description = "d"; s.pros = "p"; s.cons = "c" } }

  let!(:group_a) { tournament.groups.create!(name: "Tigres", pin: "1111").tap { |g| g.create_selection!(strategy: s_tft) } }
  let!(:group_b) { tournament.groups.create!(name: "Dragones", pin: "2222").tap { |g| g.create_selection!(strategy: s_ad) } }

  # A deterministic match result (TfT vs AD, 5 rounds: A=9, B=14)
  let!(:match_result) do
    result = GameEngine.run_match(:tit_for_tat, :always_defect, 5)
    MatchResult.create!(
      group_a:     group_a,
      group_b:     group_b,
      score_a:     result[:score_a],
      score_b:     result[:score_b],
      rounds_json: result[:history].to_json
    )
  end

  # ---------------------------------------------------------------------------
  # GET /my_matches — requires login
  # ---------------------------------------------------------------------------
  describe "GET /my_matches" do
    it "redirects to join when not logged in" do
      get my_matches_path
      expect(response).to redirect_to(join_path)
    end

    it "redirects to waiting if tournament is not done" do
      login_as(group_a, "1111")
      # tournament is still "collecting" at this point — should redirect to waiting
      get my_matches_path
      follow_redirect!
      expect(request.path).to eq(waiting_path)
    end

    it "shows the matches list when logged in and tournament done" do
      login_as(group_a, "1111")
      tournament.update!(status: "done")
      get my_matches_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Dragones")
    end

    it "shows own matches (as group_b perspective too)" do
      login_as(group_b, "2222")
      tournament.update!(status: "done")
      get my_matches_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Tigres")
    end

    it "does not show matches for groups other than current group" do
      group_c = tournament.groups.create!(name: "Lobos", pin: "3333").tap { |g| g.create_selection!(strategy: s_ad) }
      login_as(group_c, "3333")
      tournament.update!(status: "done")
      get my_matches_path
      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("Tigres")
    end
  end

  # ---------------------------------------------------------------------------
  # GET /my_matches/:id — show replay
  # ---------------------------------------------------------------------------
  describe "GET /my_matches/:id" do
    it "redirects to join when not logged in" do
      tournament.update!(status: "done")
      get my_match_path(match_result)
      expect(response).to redirect_to(join_path)
    end

    it "shows the replay page for group_a" do
      login_as(group_a, "1111")
      tournament.update!(status: "done")
      get my_match_path(match_result)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Dragones")
      expect(response.body).to include("data-controller=\"match-replay\"")
    end

    it "shows the replay page for group_b perspective" do
      login_as(group_b, "2222")
      tournament.update!(status: "done")
      get my_match_path(match_result)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Tigres")
    end

    it "embeds rounds JSON in the data attribute" do
      login_as(group_a, "1111")
      tournament.update!(status: "done")
      get my_match_path(match_result)
      expect(response.body).to include("data-match-replay-rounds-value")
    end

    it "embeds the correct side ('a' or 'b') for the logged-in group" do
      login_as(group_a, "1111")
      tournament.update!(status: "done")
      get my_match_path(match_result)
      expect(response.body).to include('data-match-replay-my-side-value="a"')
    end

    it "returns 404 for unknown match" do
      login_as(group_a, "1111")
      tournament.update!(status: "done")
      get my_match_path(9999999)
      expect(response).to have_http_status(:not_found)
    end

    it "redirects to my_matches if group tries to view another group's match" do
      group_c = tournament.groups.create!(name: "Lobos", pin: "3333").tap { |g| g.create_selection!(strategy: s_ad) }
      other_result = GameEngine.run_match(:always_defect, :always_defect, 5)
      other_match = MatchResult.create!(
        group_a:     group_b,
        group_b:     group_c,
        score_a:     other_result[:score_a],
        score_b:     other_result[:score_b],
        rounds_json: other_result[:history].to_json
      )
      login_as(group_a, "1111")
      tournament.update!(status: "done")
      get my_match_path(other_match)
      expect(response).to redirect_to(my_matches_path)
    end
  end
end
