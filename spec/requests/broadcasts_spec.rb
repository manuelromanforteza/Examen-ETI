require "rails_helper"

# Tests that the correct Turbo Stream broadcasts are triggered
# by strategy picks and tournament execution.
RSpec.describe "Broadcasts", type: :request do
  # ---------------------------------------------------------------------------
  # Shared setup
  # ---------------------------------------------------------------------------
  let(:tournament) { TournamentSession.create!(rounds_per_match: 5, status: "collecting") }

  let!(:s_tft) { Strategy.find_or_create_by!(key: "tit_for_tat") { |s|
    s.name = "Tit for Tat"; s.description = "d"; s.pros = "p"; s.cons = "c" } }
  let!(:s_ad)  { Strategy.find_or_create_by!(key: "always_defect") { |s|
    s.name = "Always Defect"; s.description = "d"; s.pros = "p"; s.cons = "c" } }

  def sign_in_group(name, pin)
    post join_path, params: { name: name, pin: pin }
    Group.find_by!(name: name)
  end

  def auth_headers(password = "admin123")
    { "Authorization" =>
      ActionController::HttpAuthentication::Basic.encode_credentials("admin", password) }
  end

  # ---------------------------------------------------------------------------
  # Broadcast: counter update after strategy pick
  # ---------------------------------------------------------------------------
  describe "POST /strategies/:id/pick" do
    before do
      tournament  # ensure it exists so active_session finds it
      sign_in_group("Broadcaster", "1234")
      allow(Turbo::StreamsChannel).to receive(:broadcast_replace_to)
    end

    it "calls broadcast_replace_to on the tournament stream" do
      post pick_strategy_path(s_tft)
      expect(Turbo::StreamsChannel).to have_received(:broadcast_replace_to)
        .with("tournament_#{tournament.id}", hash_including(target: "ready_counter"))
    end

    it "broadcasts exactly once per pick" do
      post pick_strategy_path(s_tft)
      expect(Turbo::StreamsChannel).to have_received(:broadcast_replace_to).once
    end

    it "the broadcast html contains the updated group count" do
      post pick_strategy_path(s_tft)
      expect(Turbo::StreamsChannel).to have_received(:broadcast_replace_to)
        .with(anything, hash_including(html: /1/))
    end

    it "broadcasts again when the group changes their strategy" do
      post pick_strategy_path(s_tft)
      post pick_strategy_path(s_ad)
      expect(Turbo::StreamsChannel).to have_received(:broadcast_replace_to).twice
    end
  end

  # ---------------------------------------------------------------------------
  # Broadcast: tournament-done redirect trigger after run
  # ---------------------------------------------------------------------------
  describe "POST /admin/run_tournament" do
    let!(:g_tft) { tournament.groups.create!(name: "T1", pin: "1111").tap { |g| g.create_selection!(strategy: s_tft) } }
    let!(:g_ad)  { tournament.groups.create!(name: "T2", pin: "2222").tap { |g| g.create_selection!(strategy: s_ad)  } }

    before { allow(Turbo::StreamsChannel).to receive(:broadcast_replace_to) }

    it "calls broadcast_replace_to targeting the redirect trigger" do
      post admin_run_tournament_path, headers: auth_headers
      expect(Turbo::StreamsChannel).to have_received(:broadcast_replace_to)
        .with("tournament_#{tournament.id}",
              hash_including(target: "tournament_redirect_trigger"))
    end

    it "the broadcast html contains the results URL" do
      post admin_run_tournament_path, headers: auth_headers
      expect(Turbo::StreamsChannel).to have_received(:broadcast_replace_to)
        .with(anything, hash_including(html: /\/results/))
    end

    it "the broadcast html contains the Stimulus redirect controller" do
      post admin_run_tournament_path, headers: auth_headers
      expect(Turbo::StreamsChannel).to have_received(:broadcast_replace_to)
        .with(anything, hash_including(html: /data-controller="redirect"/))
    end

    it "broadcasts exactly once" do
      post admin_run_tournament_path, headers: auth_headers
      expect(Turbo::StreamsChannel).to have_received(:broadcast_replace_to).once
    end

    it "does NOT broadcast if the tournament is already done" do
      post admin_run_tournament_path, headers: auth_headers  # first run
      expect(Turbo::StreamsChannel).to have_received(:broadcast_replace_to).once
      post admin_run_tournament_path, headers: auth_headers  # blocked
      # still only 1 call (second attempt was rejected before broadcast)
      expect(Turbo::StreamsChannel).to have_received(:broadcast_replace_to).once
    end
  end
end
