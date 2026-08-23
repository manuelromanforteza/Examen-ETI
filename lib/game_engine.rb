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
        last_my   = mine.last
        last_their = theirs.last
        score, _  = PAYOFFS[last_my][last_their]
        score >= 3 ? last_my : (last_my == :cooperate ? :defect : :cooperate)
      end
    },

    # Cooperates or defects at random with equal probability
    random: ->(_mine, _theirs) { rand(2).zero? ? :cooperate : :defect }
  }.freeze

  # --------------------------------------------------------------------------
  # run_match
  # Simulates a full match between two strategies for the given number of rounds.
  #
  # Parameters:
  #   strategy_a, strategy_b — callable (lambda or proc) or a strategy key (Symbol)
  #   rounds                 — number of rounds (integer >= 1)
  #   seed                   — optional Random seed for reproducibility with :random
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

    history_a = []
    history_b = []
    score_a   = 0
    score_b   = 0
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
