# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

strategies = [
  {
    key: "tit_for_tat",
    name: "Tit for Tat",
    description: "Coopera en la primera ronda. A partir de ahí, copia exactamente el último movimiento del rival: si cooperó, coopera; si traicionó, traiciona.",
    pros: "Simple, justa y «perdonadora»: vuelve a cooperar en cuanto el rival lo hace. Castiga la traición de inmediato sin guardar rencor.",
    cons: "Sin ruido en el juego no es un problema, pero en variantes con errores puede quedar atrapada en ciclos de venganza mutua."
  },
  {
    key: "always_cooperate",
    name: "Always Cooperate",
    description: "Siempre coopera, sin importar lo que haga el rival ni el historial de la partida.",
    pros: "Maximiza el puntaje conjunto si el rival también coopera siempre (ambos obtienen 3 por ronda).",
    cons: "Completamente explotable: un rival que siempre traiciona obtiene 5 por ronda mientras esta estrategia acumula 0."
  },
  {
    key: "always_defect",
    name: "Always Defect",
    description: "Siempre traiciona, independientemente del historial o del movimiento del rival.",
    pros: "Nunca «regala» puntos al rival. Gana cualquier duelo individual contra estrategias cooperadoras.",
    cons: "Provoca represalia inmediata de estrategias reactivas. A largo plazo acumula castigos mutuos (1/1) en lugar de recompensas (3/3)."
  },
  {
    key: "grudger",
    name: "Grudger / Trigger",
    description: "Coopera en todas las rondas hasta que el rival traicione por primera vez. Desde ese momento, traiciona para siempre, sin excepción.",
    pros: "Disuade fuertemente la traición: el rival sabe que una sola defección arruina toda la partida.",
    cons: "No perdona nunca. Un solo «accidente» desencadena defección mutua el resto del juego."
  },
  {
    key: "tit_for_two_tats",
    name: "Tit for Two Tats",
    description: "Coopera siempre, excepto cuando el rival ha traicionado en las DOS rondas consecutivas inmediatamente anteriores. En ese caso traiciona una vez y vuelve a estar lista para cooperar.",
    pros: "Más «perdonadora» que Tit for Tat; evita ciclos de venganza por traiciones aisladas.",
    cons: "Puede ser explotada por rivales que alternan cooperación y traición, ya que nunca acumula dos traiciones seguidas frente a ellos."
  },
  {
    key: "suspicious_tit_for_tat",
    name: "Suspicious Tit for Tat",
    description: "Igual que Tit for Tat, pero comienza traicionando en la primera ronda. A partir de la segunda, copia el último movimiento del rival.",
    pros: "«Prueba» al rival desde el inicio; si el rival es cooperador, la estrategia se sincroniza rápidamente con él.",
    cons: "La traición inicial provoca represalia innecesaria contra estrategias cooperadoras, perdiendo puntos en las primeras rondas."
  },
  {
    key: "pavlov",
    name: "Pavlov (Win-Stay / Lose-Shift)",
    description: "Repite su jugada anterior si obtuvo un puntaje alto (3 ó 5 puntos). Cambia de jugada si obtuvo un puntaje bajo (0 ó 1 punto). Comienza cooperando.",
    pros: "Se adapta dinámicamente. Tiene buen desempeño general y puede «corregir» a un rival que coopera pero duda.",
    cons: "Su comportamiento es menos intuitivo de explicar y puede parecer errático frente a estrategias poco predecibles."
  },
  {
    key: "tester",
    name: "Tester",
    description: "Traiciona en la primera ronda para «probar» al rival. Si el rival se defendió (traicionó en ronda 1), coopera en ronda 2 como disculpa y luego juega como Tit for Tat. Si el rival no se defendió, sigue traicionando todas las rondas restantes.",
    pros: "Explota sin piedad a rivales demasiado cooperadores. Frente a rivales firmes se convierte en una variante de TfT.",
    cons: "Contra estrategias que sí se defienden termina perdiendo puntos en ronda 1 para luego comportarse como TfT, sin ventaja real."
  },
  {
    key: "joss",
    name: "Joss",
    description: "Juega como Tit for Tat pero con un 10% de probabilidad de traicionar oportunistamente en rondas donde TfT cooperaría. Cuando TfT diría «traiciona», Joss siempre traiciona.",
    pros: "Obtiene pequeñas ganancias extra con traiciones oportunistas. Mantiene el efecto disuasivo de TfT.",
    cons: "Sus traiciones aleatorias pueden desencadenar ciclos de represalia con estrategias reactivas, hundiéndose en mutua defección."
  }
]

strategies.each do |attrs|
  Strategy.find_or_create_by!(key: attrs[:key]) do |s|
    s.name        = attrs[:name]
    s.description = attrs[:description]
    s.pros        = attrs[:pros]
    s.cons        = attrs[:cons]
  end
  puts "Strategy seeded: #{attrs[:name]}"
end

# Remove the old "random" strategy if it exists (replaced by Tester + Joss)
if (old_random = Strategy.find_by(key: "random"))
  old_random.selections.destroy_all
  old_random.destroy!
  puts "Removed old 'random' strategy"
end

puts "\nTotal strategies: #{Strategy.count}"
