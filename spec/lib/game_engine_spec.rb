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

  describe "random" do
    it "returns only :cooperate or :defect" do
      100.times do
        result = play(:random, [], [])
        expect([:cooperate, :defect]).to include(result)
      end
    end

    it "returns both values over many trials (probabilistic)" do
      results = 200.times.map { play(:random, [], []) }.uniq
      expect(results).to include(:cooperate)
      expect(results).to include(:defect)
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
  # Seeded random match is reproducible
  # ---------------------------------------------------------------------------
  describe "random with seed" do
    it "produces the same history when given the same seed" do
      r1 = GameEngine.run_match(:random, :random, 10, seed: 42)
      r2 = GameEngine.run_match(:random, :random, 10, seed: 42)
      expect(r1[:history]).to eq(r2[:history])
    end
  end
end
