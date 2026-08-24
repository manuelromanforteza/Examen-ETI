require "rails_helper"

RSpec.describe GameEngine do
  # ---------------------------------------------------------------------------
  # Helper: call a strategy lambda directly
  # ---------------------------------------------------------------------------
  def play(key, my_history, opponent_history)
    GameEngine::STRATEGIES.fetch(key).call(my_history, opponent_history)
  end

  # ---------------------------------------------------------------------------
  # Payoff matrix
  # ---------------------------------------------------------------------------
  describe "PAYOFFS" do
    it "rewards mutual cooperation with 3/3" do
      expect(GameEngine::PAYOFFS[:cooperate][:cooperate]).to eq([3, 3])
    end

    it "gives temptation 5 to defector, 0 to cooperator" do
      expect(GameEngine::PAYOFFS[:defect][:cooperate]).to eq([5, 0])
      expect(GameEngine::PAYOFFS[:cooperate][:defect]).to eq([0, 5])
    end

    it "punishes mutual defection with 1/1" do
      expect(GameEngine::PAYOFFS[:defect][:defect]).to eq([1, 1])
    end
  end

  # ---------------------------------------------------------------------------
  # Individual strategy specs
  # ---------------------------------------------------------------------------

  describe "always_cooperate" do
    it "cooperates on first round" do
      expect(play(:always_cooperate, [], [])).to eq(:cooperate)
    end

    it "cooperates after any history" do
      expect(play(:always_cooperate, [:defect, :defect], [:cooperate, :defect])).to eq(:cooperate)
    end
  end

  describe "always_defect" do
    it "defects on first round" do
      expect(play(:always_defect, [], [])).to eq(:defect)
    end

    it "defects after any history" do
      expect(play(:always_defect, [:cooperate, :cooperate], [:cooperate, :cooperate])).to eq(:defect)
    end
  end

  describe "tit_for_tat" do
    it "cooperates on the first round" do
      expect(play(:tit_for_tat, [], [])).to eq(:cooperate)
    end

    it "copies the opponent's last move (cooperate)" do
      expect(play(:tit_for_tat, [:cooperate], [:cooperate])).to eq(:cooperate)
    end

    it "copies the opponent's last move (defect)" do
      expect(play(:tit_for_tat, [:cooperate], [:defect])).to eq(:defect)
    end

    it "returns to cooperation after opponent cooperates again" do
      expect(play(:tit_for_tat, [:cooperate, :defect], [:defect, :cooperate])).to eq(:cooperate)
    end
  end

  describe "suspicious_tit_for_tat" do
    it "defects on the first round" do
      expect(play(:suspicious_tit_for_tat, [], [])).to eq(:defect)
    end

    it "copies the opponent's last move (cooperate)" do
      expect(play(:suspicious_tit_for_tat, [:defect], [:cooperate])).to eq(:cooperate)
    end

    it "copies the opponent's last move (defect)" do
      expect(play(:suspicious_tit_for_tat, [:defect], [:defect])).to eq(:defect)
    end
  end

  describe "grudger" do
    it "cooperates when opponent has always cooperated" do
      expect(play(:grudger, [], [])).to eq(:cooperate)
      expect(play(:grudger, [:cooperate, :cooperate], [:cooperate, :cooperate])).to eq(:cooperate)
    end

    it "defects forever once opponent defects" do
      expect(play(:grudger, [:cooperate], [:defect])).to eq(:defect)
      # even if opponent cooperated afterwards
      expect(play(:grudger, [:cooperate, :defect], [:defect, :cooperate])).to eq(:defect)
    end
  end

  describe "tit_for_two_tats" do
    it "cooperates on first round" do
      expect(play(:tit_for_two_tats, [], [])).to eq(:cooperate)
    end

    it "tolerates a single defection" do
      expect(play(:tit_for_two_tats, [:cooperate], [:defect])).to eq(:cooperate)
    end

    it "defects after two consecutive opponent defections" do
      expect(play(:tit_for_two_tats, [:cooperate, :cooperate], [:defect, :defect])).to eq(:defect)
    end

    it "forgives after opponent cooperates again" do
      # opponent defected twice but then cooperated; last two are [:defect, :cooperate]
      expect(play(:tit_for_two_tats, [:cooperate, :cooperate, :defect], [:defect, :defect, :cooperate])).to eq(:cooperate)
    end
  end

  describe "pavlov" do
    it "cooperates on the first round" do
      expect(play(:pavlov, [], [])).to eq(:cooperate)
    end

    it "stays on cooperate after mutual cooperation (score 3 >= 3)" do
      expect(play(:pavlov, [:cooperate], [:cooperate])).to eq(:cooperate)
    end

    it "stays on defect after defecting against cooperator (score 5 >= 3)" do
      expect(play(:pavlov, [:defect], [:cooperate])).to eq(:defect)
    end

    it "switches from cooperate after being exploited (score 0 < 3)" do
      expect(play(:pavlov, [:cooperate], [:defect])).to eq(:defect)
    end

    it "switches from defect after mutual defection (score 1 < 3)" do
      expect(play(:pavlov, [:defect], [:defect])).to eq(:cooperate)
    end
  end

  describe "tester" do
    it "defects on round 1" do
      expect(play(:tester, [], [])).to eq(:defect)
    end

    it "cooperates on round 2 if opponent retaliated (defended) in round 1" do
      expect(play(:tester, [:defect], [:defect])).to eq(:cooperate)
    end

    it "defects on round 2 if opponent did NOT retaliate in round 1" do
      expect(play(:tester, [:defect], [:cooperate])).to eq(:defect)
    end

    it "plays TfT from round 3 when opponent defended (copies last opponent move)" do
      # Opponent defended r1, we cooperated r2, opponent cooperated r2
      expect(play(:tester, [:defect, :cooperate], [:defect, :cooperate])).to eq(:cooperate)
      expect(play(:tester, [:defect, :cooperate], [:defect, :defect])).to eq(:defect)
    end

    it "keeps defecting from round 3 when opponent was a pushover" do
      expect(play(:tester, [:defect, :defect], [:cooperate, :cooperate])).to eq(:defect)
      expect(play(:tester, [:defect, :defect, :defect], [:cooperate, :cooperate, :cooperate])).to eq(:defect)
    end
  end

  describe "joss" do
    it "cooperates on first round (deterministic, no RNG)" do
      srand(0)
      # With seed 0, first rand < 0.1 produces 0.5488... → cooperate
      expect(play(:joss, [], [])).to eq(:cooperate)
    end

    it "defects when TfT would defect (no RNG involved)" do
      expect(play(:joss, [:cooperate], [:defect])).to eq(:defect)
    end

    it "occasionally defects opportunistically (probabilistic, ~10%)" do
      srand(123)
      results = 500.times.map { play(:joss, [], []) }
      defects = results.count(:defect)
      # Expect roughly 10% defections (allow generous range 2-25%)
      expect(defects).to be_between(10, 125)
    end

    it "always cooperates when TfT would cooperate and seed eliminates the 10% chance" do
      srand(42)
      # Run enough times that a totally-defecting strategy would fail
      cooperates = 50.times.count { play(:joss, [], []) == :cooperate }
      expect(cooperates).to be > 35  # overwhelmingly cooperates
    end
  end

  # ---------------------------------------------------------------------------
  # run_match core mechanics
  # ---------------------------------------------------------------------------
  describe ".run_match" do
    it "returns the correct keys" do
      result = GameEngine.run_match(:always_cooperate, :always_cooperate, 3)
      expect(result).to include(:history, :score_a, :score_b)
    end

    it "runs the exact number of rounds" do
      result = GameEngine.run_match(:always_cooperate, :always_defect, 7)
      expect(result[:history].length).to eq(7)
    end

    it "each round entry has the expected keys" do
      result = GameEngine.run_match(:always_cooperate, :always_cooperate, 1)
      round = result[:history].first
      expect(round).to include(:a, :b, :score_a, :score_b)
    end

    it "calculates scores correctly for mutual cooperation" do
      result = GameEngine.run_match(:always_cooperate, :always_cooperate, 5)
      expect(result[:score_a]).to eq(15)
      expect(result[:score_b]).to eq(15)
    end

    it "calculates scores correctly for mutual defection" do
      result = GameEngine.run_match(:always_defect, :always_defect, 5)
      expect(result[:score_a]).to eq(5)
      expect(result[:score_b]).to eq(5)
    end

    it "calculates scores correctly when A defects and B cooperates always" do
      # Each round: A gets 5, B gets 0
      result = GameEngine.run_match(:always_defect, :always_cooperate, 4)
      expect(result[:score_a]).to eq(20)
      expect(result[:score_b]).to eq(0)
    end

    it "raises ArgumentError for unknown strategy key" do
      expect { GameEngine.run_match(:unknown_strategy, :always_defect, 3) }
        .to raise_error(ArgumentError, /Unknown strategy/)
    end

    it "raises ArgumentError for non-callable, non-Symbol strategy" do
      expect { GameEngine.run_match("bad", :always_defect, 3) }
        .to raise_error(ArgumentError)
    end
  end

  # ---------------------------------------------------------------------------
  # Cross-match: Tit for Tat vs Always Defect
  # ---------------------------------------------------------------------------
  describe "Tit for Tat vs Always Defect" do
    subject(:result) { GameEngine.run_match(:tit_for_tat, :always_defect, 10) }

    it "TfT cooperates on round 1, then defects for the rest" do
      expect(result[:history].first[:a]).to eq(:cooperate)
      result[:history][1..].each do |round|
        expect(round[:a]).to eq(:defect)
      end
    end

    it "Always Defect defects every round" do
      result[:history].each do |round|
        expect(round[:b]).to eq(:defect)
      end
    end

    it "TfT scores lower than Always Defect (exploited on round 1)" do
      # TfT: 0 (round 1, sucker) + 9*1 = 9
      # AD:  5 (round 1) + 9*1   = 14
      expect(result[:score_a]).to eq(9)
      expect(result[:score_b]).to eq(14)
    end
  end

  # ---------------------------------------------------------------------------
  # Cross-match: Tit for Tat vs Always Cooperate
  # ---------------------------------------------------------------------------
  describe "Tit for Tat vs Always Cooperate" do
    subject(:result) { GameEngine.run_match(:tit_for_tat, :always_cooperate, 10) }

    it "both cooperate every round" do
      result[:history].each do |round|
        expect(round[:a]).to eq(:cooperate)
        expect(round[:b]).to eq(:cooperate)
      end
    end

    it "both score 30 over 10 rounds" do
      expect(result[:score_a]).to eq(30)
      expect(result[:score_b]).to eq(30)
    end
  end

  # ---------------------------------------------------------------------------
  # Cross-match: Grudger vs Always Defect
  # ---------------------------------------------------------------------------
  describe "Grudger vs Always Defect" do
    subject(:result) { GameEngine.run_match(:grudger, :always_defect, 10) }

    it "Grudger cooperates only on round 1, then defects" do
      expect(result[:history].first[:a]).to eq(:cooperate)
      result[:history][1..].each do |round|
        expect(round[:a]).to eq(:defect)
      end
    end

    it "scores match the pattern (0 + 9*1 vs 5 + 9*1)" do
      expect(result[:score_a]).to eq(9)
      expect(result[:score_b]).to eq(14)
    end
  end

  # ---------------------------------------------------------------------------
  # Cross-match: Pavlov vs Always Defect
  # ---------------------------------------------------------------------------
  describe "Pavlov vs Always Defect" do
    subject(:result) { GameEngine.run_match(:pavlov, :always_defect, 6) }

    # Round 1: Pavlov cooperates, AD defects -> Pavlov gets 0 (loses, switches to defect)
    # Round 2: Pavlov defects, AD defects -> Pavlov gets 1 (loses, switches to cooperate)
    # Round 3: Pavlov cooperates, AD defects -> 0 (switches to defect)
    # ... alternates C/D vs D
    it "Pavlov alternates cooperate/defect starting from round 1" do
      moves = result[:history].map { |r| r[:a] }
      expect(moves).to eq([:cooperate, :defect, :cooperate, :defect, :cooperate, :defect])
    end
  end

  # ---------------------------------------------------------------------------
  # Cross-match: Tit for Two Tats vs Always Defect
  # ---------------------------------------------------------------------------
  describe "Tit for Two Tats vs Always Defect" do
    subject(:result) { GameEngine.run_match(:tit_for_two_tats, :always_defect, 5) }

    it "TfTT cooperates rounds 1-2, then defects from round 3 onwards" do
      moves = result[:history].map { |r| r[:a] }
      expect(moves[0]).to eq(:cooperate)
      expect(moves[1]).to eq(:cooperate)
      moves[2..].each { |m| expect(m).to eq(:defect) }
    end
  end

  # ---------------------------------------------------------------------------
  # Suspicious TfT vs Always Cooperate
  # ---------------------------------------------------------------------------
  describe "Suspicious Tit for Tat vs Always Cooperate" do
    subject(:result) { GameEngine.run_match(:suspicious_tit_for_tat, :always_cooperate, 5) }

    it "STfT defects on round 1, then cooperates every subsequent round" do
      moves = result[:history].map { |r| r[:a] }
      expect(moves.first).to eq(:defect)
      moves[1..].each { |m| expect(m).to eq(:cooperate) }
    end
  end

  # ---------------------------------------------------------------------------
  # Cross-match: Tester vs Always Cooperate
  # ---------------------------------------------------------------------------
  describe "Tester vs Always Cooperate" do
    subject(:result) { GameEngine.run_match(:tester, :always_cooperate, 5) }

    it "Tester defects every round (opponent never defended)" do
      result[:history].each { |r| expect(r[:a]).to eq(:defect) }
    end

    it "Tester exploits fully: 5 pts/round, AC gets 0" do
      expect(result[:score_a]).to eq(25)  # 5×5
      expect(result[:score_b]).to eq(0)
    end
  end

  # ---------------------------------------------------------------------------
  # Cross-match: Tester vs Always Defect (opponent defends r1)
  # ---------------------------------------------------------------------------
  describe "Tester vs Always Defect" do
    subject(:result) { GameEngine.run_match(:tester, :always_defect, 5) }

    it "Tester defects r1, cooperates r2 (apology), then mirrors AD (defects r3+)" do
      moves = result[:history].map { |r| r[:a] }
      expect(moves[0]).to eq(:defect)    # probe
      expect(moves[1]).to eq(:cooperate) # apology (opponent defended)
      moves[2..].each { |m| expect(m).to eq(:defect) }  # TfT mirrors AD
    end

    it "scores: Tester=1+0+3×1=4, AD=1+5+3×1=9" do
      # r1: T defects, AD defects → 1/1
      # r2: T cooperates, AD defects → 0/5
      # r3-r5: both defect → 1/1 each = 3/3
      expect(result[:score_a]).to eq(4)
      expect(result[:score_b]).to eq(9)
    end
  end

  # ---------------------------------------------------------------------------
  # Cross-match: Joss vs Always Cooperate (reproducible with seed)
  # ---------------------------------------------------------------------------
  describe "Joss with seed for reproducibility" do
    it "produces identical history on two runs with the same seed" do
      r1 = GameEngine.run_match(:joss, :always_cooperate, 20, seed: 7777)
      r2 = GameEngine.run_match(:joss, :always_cooperate, 20, seed: 7777)
      expect(r1[:history]).to eq(r2[:history])
    end

    it "produces different history with a different seed" do
      r1 = GameEngine.run_match(:joss, :always_cooperate, 50, seed: 1)
      r2 = GameEngine.run_match(:joss, :always_cooperate, 50, seed: 999)
      # With 50 rounds and 10% chance, almost certainly at least one difference
      expect(r1[:history]).not_to eq(r2[:history])
    end
  end

  # ---------------------------------------------------------------------------
  # deterministic_seed helper
  # ---------------------------------------------------------------------------
  describe ".deterministic_seed" do
    it "returns an integer" do
      expect(GameEngine.deterministic_seed(1, 2, 3)).to be_an(Integer)
    end

    it "is the same for the same inputs" do
      s1 = GameEngine.deterministic_seed(10, 5, 7)
      s2 = GameEngine.deterministic_seed(10, 5, 7)
      expect(s1).to eq(s2)
    end

    it "is symmetric (group order doesn't matter)" do
      expect(GameEngine.deterministic_seed(1, 3, 5)).to eq(GameEngine.deterministic_seed(1, 5, 3))
    end

    it "differs when tournament changes" do
      expect(GameEngine.deterministic_seed(1, 3, 5)).not_to eq(GameEngine.deterministic_seed(2, 3, 5))
    end

    it "differs when groups change" do
      expect(GameEngine.deterministic_seed(1, 3, 5)).not_to eq(GameEngine.deterministic_seed(1, 4, 5))
    end
  end
end
