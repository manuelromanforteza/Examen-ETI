namespace :demo do
  desc "Crea 8 grupos de prueba con estrategias ya asignadas para probar el torneo completo"
  task setup: :environment do
    # Ensure strategies are seeded
    if Strategy.count < 8
      puts "Sembrando estrategias primero..."
      Rake::Task["db:seed"].invoke
    end

    # Find or create an active collecting session
    tournament = TournamentSession
                   .where(status: %w[setup collecting])
                   .order(created_at: :desc)
                   .first_or_create!(rounds_per_match: 50, status: "collecting")

    puts "Usando TournamentSession ##{tournament.id} (status: #{tournament.status})"
    puts ""

    demo_groups = [
      { name: "Los Tigres",    pin: "1111", strategy_key: "tit_for_tat" },
      { name: "Los Dragones",  pin: "2222", strategy_key: "always_defect" },
      { name: "Los Águilas",   pin: "3333", strategy_key: "always_cooperate" },
      { name: "Los Lobos",     pin: "4444", strategy_key: "grudger" },
      { name: "Los Zorros",    pin: "5555", strategy_key: "pavlov" },
      { name: "Los Cóndores",  pin: "6666", strategy_key: "tit_for_two_tats" },
      { name: "Los Pumas",     pin: "7777", strategy_key: "tester" },
      { name: "Los Halcones",  pin: "8888", strategy_key: "joss" },
    ]

    demo_groups.each do |attrs|
      strategy = Strategy.find_by!(key: attrs[:strategy_key])

      group = tournament.groups.find_or_initialize_by(name: attrs[:name])
      if group.new_record?
        group.pin = attrs[:pin]
        group.save!
        puts "  Creado:    #{group.name} (PIN: #{attrs[:pin]})"
      else
        puts "  Ya existe: #{group.name}"
      end

      unless group.selection
        group.create_selection!(strategy: strategy)
        puts "             → #{strategy.name}"
      else
        puts "             → ya tiene #{group.strategy.name}"
      end
    end

    ready = tournament.groups.joins(:selection).count
    puts ""
    puts "Listo. #{ready} grupos con estrategia en sesión ##{tournament.id}."
    puts "Ahora ve a http://localhost:3000/admin (admin / admin123) y ejecuta el torneo."
  end

  desc "Elimina todos los grupos y resultados de la sesión activa (para empezar de cero)"
  task reset: :environment do
    tournament = TournamentSession.order(created_at: :desc).first
    unless tournament
      puts "No hay sesiones de torneo."
      next
    end

    MatchResult.where("group_a_id IN (?) OR group_b_id IN (?)",
                      tournament.groups.ids, tournament.groups.ids).destroy_all
    tournament.groups.destroy_all
    tournament.update!(status: "collecting")

    puts "Sesión ##{tournament.id} reiniciada. Grupos y resultados eliminados."
  end
end
