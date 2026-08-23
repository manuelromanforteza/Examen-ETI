require "rails_helper"

RSpec.describe "Group join flow", type: :request do
  let(:tournament) { TournamentSession.create!(rounds_per_match: 10, status: "collecting") }
  let!(:strategy)  { Strategy.create!(key: "tit_for_tat", name: "Tit for Tat",
                                      description: "Copia al rival", pros: "Simple", cons: "Ninguna") }

  # ---------------------------------------------------------------------------
  # GET /join
  # ---------------------------------------------------------------------------
  describe "GET /join" do
    it "returns 200 and shows the form" do
      get join_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Bienvenido al Torneo")
    end

    it "redirects to strategies if already logged in" do
      tournament.groups.create!(name: "YaMiembro", pin: "5678")
      post join_path, params: { name: "YaMiembro", pin: "5678" }
      get join_path
      follow_redirect!
      expect(response.body).to include("Elige tu estrategia")
    end
  end

  # ---------------------------------------------------------------------------
  # POST /join — creating a new group
  # ---------------------------------------------------------------------------
  describe "POST /join — new group" do
    before { tournament } # ensure an active session exists

    it "creates a group and redirects to strategies" do
      expect {
        post join_path, params: { name: "Los Halcones", pin: "4321" }
      }.to change(Group, :count).by(1)

      expect(response).to redirect_to(strategies_path)
    end

    it "stores group_id in the session" do
      post join_path, params: { name: "Los Cóndores", pin: "1111" }
      expect(session[:group_id]).to eq(Group.last.id)
    end

    it "hashes the PIN (does not store it in plain text)" do
      post join_path, params: { name: "Hash Test", pin: "2222" }
      group = Group.last
      expect(group.pin_digest).to be_present
      expect(group.pin_digest).not_to eq("2222")
    end

    it "rejects a blank name" do
      post join_path, params: { name: "", pin: "1234" }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("obligatorios")
    end

    it "rejects a non-4-digit PIN" do
      post join_path, params: { name: "Bad PIN", pin: "12" }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("4 dígitos")
    end

    it "rejects a non-numeric PIN" do
      post join_path, params: { name: "Alpha PIN", pin: "abcd" }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("4 dígitos")
    end
  end

  # ---------------------------------------------------------------------------
  # POST /join — returning group with correct PIN
  # ---------------------------------------------------------------------------
  describe "POST /join — existing group, correct PIN" do
    let!(:group) { tournament.groups.create!(name: "Los Águilas", pin: "7777") }

    it "authenticates and redirects to strategies (no selection yet)" do
      post join_path, params: { name: "Los Águilas", pin: "7777" }
      expect(response).to redirect_to(strategies_path)
      expect(session[:group_id]).to eq(group.id)
    end

    it "redirects to waiting if group already has a selection" do
      group.create_selection(strategy: strategy)
      post join_path, params: { name: "Los Águilas", pin: "7777" }
      expect(response).to redirect_to(waiting_path)
    end
  end

  # ---------------------------------------------------------------------------
  # POST /join — wrong PIN
  # ---------------------------------------------------------------------------
  describe "POST /join — existing group, wrong PIN" do
    let!(:group) { tournament.groups.create!(name: "Los Pumas", pin: "3333") }

    it "returns 422 and shows an error" do
      post join_path, params: { name: "Los Pumas", pin: "9999" }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("PIN incorrecto")
    end

    it "does not set group_id in the session" do
      post join_path, params: { name: "Los Pumas", pin: "9999" }
      expect(session[:group_id]).to be_nil
    end
  end

  # ---------------------------------------------------------------------------
  # DELETE /leave
  # ---------------------------------------------------------------------------
  describe "DELETE /leave" do
    it "clears the session and redirects to join" do
      post join_path, params: { name: "Logout Test", pin: "5555" }
      delete leave_path
      expect(response).to redirect_to(join_path)
      expect(session[:group_id]).to be_nil
    end
  end

  # ---------------------------------------------------------------------------
  # GET /strategies — catalog
  # ---------------------------------------------------------------------------
  describe "GET /strategies" do
    it "redirects to join if not logged in" do
      get strategies_path
      expect(response).to redirect_to(join_path)
    end

    it "shows the catalog when logged in" do
      post join_path, params: { name: "Viewer", pin: "6666" }
      # Seed all strategies for this test
      Strategy::KEYS.each_with_index do |k, i|
        Strategy.find_or_create_by(key: k) { |s| s.name = k; s.description = "d"; s.pros = "p"; s.cons = "c" }
      end
      get strategies_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Elige tu estrategia")
      expect(response.body).to include("Tit for Tat")
    end
  end

  # ---------------------------------------------------------------------------
  # POST /strategies/:id/pick — choosing a strategy
  # ---------------------------------------------------------------------------
  describe "POST /strategies/:id/pick" do
    before { post join_path, params: { name: "Picker", pin: "8888" } }

    it "redirects to join if not logged in" do
      delete leave_path
      post pick_strategy_path(strategy)
      expect(response).to redirect_to(join_path)
    end

    it "creates a Selection and redirects to waiting" do
      expect {
        post pick_strategy_path(strategy)
      }.to change(Selection, :count).by(1)
      expect(response).to redirect_to(waiting_path)
    end

    it "shows the chosen strategy on the waiting page" do
      post pick_strategy_path(strategy)
      follow_redirect!
      expect(response.body).to include(strategy.name)
      expect(response.body).to include("Estrategia confirmada")
    end

    it "allows changing the strategy (overwrites the selection)" do
      strategy2 = Strategy.create!(key: "always_defect", name: "Always Defect",
                                   description: "Siempre traiciona", pros: "Gana solo", cons: "Represalia")
      post pick_strategy_path(strategy)
      expect { post pick_strategy_path(strategy2) }.not_to change(Selection, :count)
      expect(Group.find(session[:group_id]).strategy).to eq(strategy2)
    end

    it "blocks changing after the tournament starts" do
      tournament.update(status: "running")
      post pick_strategy_path(strategy)
      expect(response).to redirect_to(waiting_path)
      follow_redirect!
      expect(response.body).to include("torneo")
    end
  end

  # ---------------------------------------------------------------------------
  # GET /waiting
  # ---------------------------------------------------------------------------
  describe "GET /waiting" do
    it "redirects to join if not logged in" do
      get waiting_path
      expect(response).to redirect_to(join_path)
    end

    it "shows waiting room after selecting a strategy" do
      post join_path, params: { name: "Waiter", pin: "0000" }
      post pick_strategy_path(strategy)
      get waiting_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Estrategia confirmada")
      expect(response.body).to include(strategy.name)
    end
  end
end
