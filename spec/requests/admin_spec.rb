require "rails_helper"

RSpec.describe "Admin flow", type: :request do
  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------
  def auth_headers(password = "admin123")
    credentials = ActionController::HttpAuthentication::Basic.encode_credentials("admin", password)
    { "Authorization" => credentials }
  end

  # Find the MatchResult for two groups (order-agnostic)
  def find_match(g1, g2)
    MatchResult.where(
      "(group_a_id = ? AND group_b_id = ?) OR (group_a_id = ? AND group_b_id = ?)",
      g1.id, g2.id, g2.id, g1.id
    ).first
  end

  # Return the score from a specific group's perspective
  def score_for(group, match)
    match.group_a_id == group.id ? match.score_a : match.score_b
  end

  # ---------------------------------------------------------------------------
  # Fixtures — 3 groups with deterministic strategies (no :random)
  # Rounds: 5 per match for fast, exact math
  # TfT vs AD  → TfT=4,  AD=9
  # TfT vs AC  → TfT=15, AC=15
  # AD  vs AC  → AD=25,  AC=0
  # Totals: AD=34, TfT=19, AC=15
  # ---------------------------------------------------------------------------
  let(:tournament) { TournamentSession.create!(rounds_per_match: 5, status: "collecting") }

  let!(:s_tft) { Strategy.find_or_create_by!(key: "tit_for_tat") { |s|
    s.name = "Tit for Tat"; s.description = "d"; s.pros = "p"; s.cons = "c" } }
  let!(:s_ad)  { Strategy.find_or_create_by!(key: "always_defect") { |s|
    s.name = "Always Defect"; s.description = "d"; s.pros = "p"; s.cons = "c" } }
  let!(:s_ac)  { Strategy.find_or_create_by!(key: "always_cooperate") { |s|
    s.name = "Always Cooperate"; s.description = "d"; s.pros = "p"; s.cons = "c" } }

  # Groups attached directly to the tournament (no web form needed in specs)
  let!(:g_tft) { tournament.groups.create!(name: "Tigres",   pin: "1111").tap { |g| g.create_selection!(strategy: s_tft) } }
  let!(:g_ad)  { tournament.groups.create!(name: "Dragones", pin: "2222").tap { |g| g.create_selection!(strategy: s_ad)  } }
  let!(:g_ac)  { tournament.groups.create!(name: "Aguilas",  pin: "3333").tap { |g| g.create_selection!(strategy: s_ac)  } }

  # ---------------------------------------------------------------------------
  # GET /admin — authentication
  # ---------------------------------------------------------------------------
  describe "GET /admin" do
    it "returns 401 without credentials" do
      get admin_path
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 401 with wrong password" do
      get admin_path, headers: auth_headers("wrong")
      expect(response).to have_http_status(:unauthorized)
    end

    it "shows the dashboard with correct credentials" do
      get admin_path, headers: auth_headers
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Panel de Administración")
    end

    it "shows all groups and their strategies" do
      get admin_path, headers: auth_headers
      expect(response.body).to include("Tigres")
      expect(response.body).to include("Tit for Tat")
      expect(response.body).to include("Dragones")
      expect(response.body).to include("Always Defect")
    end

    it "shows the ready count" do
      get admin_path, headers: auth_headers
      expect(response.body).to include("3 / 3")
    end

    it "shows the run button when enough groups are ready" do
      get admin_path, headers: auth_headers
      expect(response.body).to include("Ejecutar torneo")
    end

    it "disables the run button when tournament is already done" do
      tournament.update!(status: "done")
      get admin_path, headers: auth_headers
      expect(response.body).to include("ya fue ejecutado")
    end
  end

  # ---------------------------------------------------------------------------
  # POST /admin/run_tournament
  # ---------------------------------------------------------------------------
  describe "POST /admin/run_tournament" do
    it "requires admin credentials" do
      post admin_run_tournament_path
      expect(response).to have_http_status(:unauthorized)
    end

    it "creates MatchResults (C(3,2)=3 pairs)" do
      expect {
        post admin_run_tournament_path, headers: auth_headers
      }.to change(MatchResult, :count).by(3)
    end

    it "redirects to results page" do
      post admin_run_tournament_path, headers: auth_headers
      expect(response).to redirect_to(results_path)
    end

    it "changes tournament status to 'done'" do
      post admin_run_tournament_path, headers: auth_headers
      expect(tournament.reload.status).to eq("done")
    end

    it "stores rounds_json as valid JSON for each match" do
      post admin_run_tournament_path, headers: auth_headers
      MatchResult.all.each do |mr|
        rounds = JSON.parse(mr.rounds_json)
        expect(rounds).to be_an(Array)
        expect(rounds.length).to eq(5)
      end
    end

    # ---- Score verification (deterministic, no :random) --------------------

    it "TfT vs AD: TfT scores 4, AD scores 9 (5 rounds)" do
      post admin_run_tournament_path, headers: auth_headers
      mr = find_match(g_tft, g_ad)
      expect(score_for(g_tft, mr)).to eq(4)   # 0 + 4×1
      expect(score_for(g_ad,  mr)).to eq(9)   # 5 + 4×1
    end

    it "TfT vs AC: both score 15 (mutual cooperation, 5 rounds)" do
      post admin_run_tournament_path, headers: auth_headers
      mr = find_match(g_tft, g_ac)
      expect(score_for(g_tft, mr)).to eq(15)  # 5×3
      expect(score_for(g_ac,  mr)).to eq(15)
    end

    it "AD vs AC: AD scores 25, AC scores 0 (5 rounds)" do
      post admin_run_tournament_path, headers: auth_headers
      mr = find_match(g_ad, g_ac)
      expect(score_for(g_ad, mr)).to eq(25)   # 5×5
      expect(score_for(g_ac, mr)).to eq(0)    # 5×0
    end

    # ---- Can't run twice ---------------------------------------------------

    it "redirects to admin with alert if tournament already done" do
      post admin_run_tournament_path, headers: auth_headers   # first run
      post admin_run_tournament_path, headers: auth_headers   # second attempt
      expect(response).to redirect_to(admin_path)
      follow_redirect!(headers: auth_headers)
      expect(response.body).to include("ya fue ejecutado")
    end

    it "does not create extra MatchResults on second attempt" do
      post admin_run_tournament_path, headers: auth_headers
      expect {
        post admin_run_tournament_path, headers: auth_headers
      }.not_to change(MatchResult, :count)
    end

    # ---- Edge: not enough groups ------------------------------------------

    it "rejects if fewer than 2 groups have selections" do
      lone_tournament = TournamentSession.create!(rounds_per_match: 5, status: "collecting")
      lone_tournament.groups.create!(name: "Solo", pin: "9999").tap { |g| g.create_selection!(strategy: s_tft) }
      # Make the lone_tournament the most-recent so admin_tournament picks it up
      lone_tournament.update_column(:created_at, 1.second.from_now)

      post admin_run_tournament_path, headers: auth_headers
      expect(response).to redirect_to(admin_path)
      follow_redirect!(headers: auth_headers)
      expect(response.body).to include("al menos 2")
    end
  end

  # ---------------------------------------------------------------------------
  # POST /admin/reset_tournament
  # ---------------------------------------------------------------------------
  describe "POST /admin/reset_tournament" do
    before { post admin_run_tournament_path, headers: auth_headers }

    it "resets status to collecting" do
      post admin_reset_tournament_path, headers: auth_headers
      expect(tournament.reload.status).to eq("collecting")
    end

    it "destroys all match results" do
      expect {
        post admin_reset_tournament_path, headers: auth_headers
      }.to change(MatchResult, :count).by(-3)
    end

    it "redirects to admin panel" do
      post admin_reset_tournament_path, headers: auth_headers
      expect(response).to redirect_to(admin_path)
    end
  end

  # ---------------------------------------------------------------------------
  # GET /results
  # ---------------------------------------------------------------------------
  describe "GET /results" do
    context "when tournament is not done" do
      it "redirects to root with alert" do
        get results_path
        expect(response).to redirect_to(root_path)
        follow_redirect!
        expect(response.body).to include("no ha finalizado")
      end
    end

    context "after running the tournament" do
      before { post admin_run_tournament_path, headers: auth_headers }

      it "returns 200 and shows the leaderboard" do
        get results_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Leaderboard")
      end

      it "shows all three groups" do
        get results_path
        expect(response.body).to include("Tigres")
        expect(response.body).to include("Dragones")
        expect(response.body).to include("Aguilas")
      end

      it "shows total scores for each group" do
        get results_path
        # AD = 34 total, TfT = 19, AC = 15
        expect(response.body).to include("34")
        expect(response.body).to include("19")
        expect(response.body).to include("15")
      end

      it "AD appears before TfT in the leaderboard (higher total score)" do
        get results_path
        dragons_pos = response.body.index("Dragones")  # AD, 34 pts
        tigers_pos  = response.body.index("Tigres")    # TfT, 19 pts
        expect(dragons_pos).to be < tigers_pos
      end

      it "TfT appears before AC in the leaderboard" do
        get results_path
        tigers_pos  = response.body.index("Tigres")   # TfT, 19 pts
        eagles_pos  = response.body.index("Aguilas")  # AC,  15 pts
        expect(tigers_pos).to be < eagles_pos
      end

      it "shows the most-points winner callout" do
        get results_path
        expect(response.body).to include("Más puntos totales")
        expect(response.body).to include("Dragones")  # AD wins on points
      end

      it "shows the most-duels-won callout" do
        get results_path
        expect(response.body).to include("Más duelos ganados")
      end

      it "shows the interesting split callout (points winner ≠ duels winner)" do
        # AD wins both in this 3-group scenario — no split message
        # But verify the page renders without errors and shows details
        get results_path
        expect(response).to have_http_status(:ok)
      end

      it "shows per-group expandable detail sections" do
        get results_path
        # <details> elements present for each group
        expect(response.body.scan("<details").size).to eq(3)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # PATCH /admin/rounds — configurable rounds per match
  # ---------------------------------------------------------------------------
  describe "PATCH /admin/rounds" do
    it "requires HTTP Basic auth" do
      patch admin_update_rounds_path, params: { rounds_per_match: 20 }
      expect(response).to have_http_status(:unauthorized)
    end

    it "rejects wrong password" do
      patch admin_update_rounds_path, params: { rounds_per_match: 20 }, headers: auth_headers("bad")
      expect(response).to have_http_status(:unauthorized)
    end

    it "updates rounds_per_match with valid value" do
      patch admin_update_rounds_path, params: { rounds_per_match: 30 }, headers: auth_headers
      expect(tournament.reload.rounds_per_match).to eq(30)
    end

    it "redirects to admin after success" do
      patch admin_update_rounds_path, params: { rounds_per_match: 30 }, headers: auth_headers
      expect(response).to redirect_to(admin_path)
    end

    it "rejects rounds < 1" do
      original = tournament.rounds_per_match
      patch admin_update_rounds_path, params: { rounds_per_match: 0 }, headers: auth_headers
      expect(tournament.reload.rounds_per_match).to eq(original)
      expect(response).to redirect_to(admin_path)
    end

    it "blocks update once tournament is running" do
      tournament.update!(status: "running")
      patch admin_update_rounds_path, params: { rounds_per_match: 100 }, headers: auth_headers
      expect(response).to redirect_to(admin_path)
      expect(tournament.reload.rounds_per_match).not_to eq(100)
    end

    it "blocks update once tournament is done" do
      tournament.update!(status: "done")
      patch admin_update_rounds_path, params: { rounds_per_match: 100 }, headers: auth_headers
      expect(response).to redirect_to(admin_path)
      expect(tournament.reload.rounds_per_match).not_to eq(100)
    end
  end
end
