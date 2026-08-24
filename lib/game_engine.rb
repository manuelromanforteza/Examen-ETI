module GameEngine
  # Payoff matrix (classic Prisoner's Dilemma)
  # T=5 (Temptation), R=3 (Reward), P=1 (Punishment), S=0 (Sucker)
  PAYOFFS = {
    cooperate: { cooperate: [3, 3], defect: [0, 5] },
    defect:    { cooperate: [5, 0], defect:  [1, 1] }
  }.freeze

  # --------------------------------------------------------------------------
  # Strategy implementations
  # Each strategy is a lambda that receives (my_history, opponent_history)
  # and returns :cooperate or :defect.
  # Both arrays are ordered oldest-first; empty on the first round.
  # --------------------------------------------------------------------------

  STRATEGIES = {
    # Always cooperates regardless of history
    always_cooperate: ->(_mine, _theirs) { :cooperate },

    # Always defects regardless of history
    always_defect: ->(_mine, _theirs) { :defect },

    # Cooperates first, then mirrors the opponent's last move
    tit_for_tat: ->(_mine, theirs) { theirs.empty? ? :cooperate : theirs.last },

    # Like TfT but starts with a defection
    suspicious_tit_for_tat: ->(_mine, theirs) { theirs.empty? ? :defect : theirs.last },

    # Cooperates until the opponent defects once; then always defects
    grudger: ->(_mine, theirs) { theirs.include?(:defect) ? :defect : :cooperate },

    # Defects only if the opponent defected on BOTH of the last two rounds
    tit_for_two_tats: lambda { |_mine, theirs|
      if theirs.length >= 2 && theirs[-1] == :defect && theirs[-2] == :defect
        :defect
      else
        :cooperate
      end
    },

    # Win-Stay / Lose-Shift:
    # Repeats its last move if it scored 3 or 5; switches otherwise.
    # Starts by cooperating.
    pavlov: lambda { |mine, theirs|
      if mine.empty?
        :cooperate
      else
        last_my    = mine.last
        last_their = theirs.last
        score, _   = PAYOFFS[last_my][last_their]
        score >= 3 ? last_my : (last_my == :cooperate ? :defect : :cooperate)
      end
    },

    # Tester: defects on round 1 to "probe" the opponent.
    # If the opponent retaliated (defected on round 1): cooperates on round 2
    #   as an apology, then plays Tit for Tat from round 3 onwards.
    # If the opponent did NOT retaliate (cooperated on round 1): keeps defecting
    #   for the rest of the match (exploiting a pushover).
    tester: lambda { |mine, theirs|
      if mine.empty?
        :defect                               # Round 1: probe
      elsif mine.length == 1
        # Round 2 decision depends on whether opponent retaliated in round 1
        if theirs[0] == :defect
          :cooperate                          # Opponent defended → apologize
        else
          :defect                             # Opponent didn't retaliate → keep exploiting
        end
      else
        # Round 3+: if opponent defended in round 1, play TfT; else keep defecting
        if theirs[0] == :defect
          theirs.last                         # TfT: copy opponent's last move
        else
          :defect                             # Opponent was a pushover → always defect
        end
      end
    },

    # Joss: plays like Tit for Tat but with a 10% chance of defecting
    # opportunistically on rounds where TfT would cooperate.
    # When TfT would defect, Joss always defects (no mercy).
    # NOTE: uses the global RNG; seed the RNG before calling run_match for
    # reproducibility.
    joss: lambda { |_mine, theirs|
      tft_move = theirs.empty? ? :cooperate : theirs.last
      if tft_move == :cooperate
        rand < 0.1 ? :defect : :cooperate    # 10% opportunistic defection
      else
        :defect
      end
    }
  }.freeze

  # --------------------------------------------------------------------------
  # run_match
  # Simulates a full match between two strategies for the given number of rounds.
  #
  # Parameters:
  #   strategy_a, strategy_b — callable (lambda or proc) or a strategy key (Symbol)
  #   rounds                 — number of rounds (integer >= 1)
  #   seed                   — optional Random seed for reproducibility with
  #                            stochastic strategies (:joss, etc.)
  #
  # Returns a Hash:
  #   {
  #     history: [ { a: :cooperate/:defect, b: :cooperate/:defect,
  #                  score_a: Integer, score_b: Integer }, ... ],
  #     score_a: Integer,   # cumulative score for player A
  #     score_b: Integer    # cumulative score for player B
  #   }
  # --------------------------------------------------------------------------
  def self.run_match(strategy_a, strategy_b, rounds, seed: nil)
    srand(seed) if seed

    fn_a = resolve_strategy(strategy_a)
    fn_b = resolve_strategy(strategy_b)

    history_a  = []
    history_b  = []
    score_a    = 0
    score_b    = 0
    rounds_log = []

    rounds.times do
      move_a = fn_a.call(history_a.dup, history_b.dup)
      move_b = fn_b.call(history_b.dup, history_a.dup)

      pts_a, pts_b = PAYOFFS[move_a][move_b]

      history_a << move_a
      history_b << move_b
      score_a   += pts_a
      score_b   += pts_b

      rounds_log << { a: move_a, b: move_b, score_a: pts_a, score_b: pts_b }
    end

    { history: rounds_log, score_a: score_a, score_b: score_b }
  end

  # --------------------------------------------------------------------------
  # deterministic_seed
  # Derives a reproducible integer seed from tournament + group IDs.
  # Same inputs → same seed → same match outcome for stochastic strategies.
  # --------------------------------------------------------------------------
  def self.deterministic_seed(tournament_id, group_a_id, group_b_id)
    # Sort group IDs so order doesn't matter
    id1, id2 = [group_a_id, group_b_id].minmax
    Digest::MD5.hexdigest("#{tournament_id}-#{id1}-#{id2}").to_i(16)
  end

  # --------------------------------------------------------------------------
  # Resolve strategy: accepts a Symbol key or any callable
  # --------------------------------------------------------------------------
  def self.resolve_strategy(strategy)
    case strategy
    when Symbol
      STRATEGIES.fetch(strategy) { raise ArgumentError, "Unknown strategy: #{strategy}" }
    else
      raise ArgumentError, "Strategy must be a Symbol" unless strategy.respond_to?(:call)
      strategy
    end
  end
  private_class_method :resolve_strategy
end

