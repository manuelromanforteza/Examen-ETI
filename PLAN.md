# Plan: Torneo del Dilema del Prisionero Iterado (estilo Axelrod)

## 0. Objetivo
Recrear la idea del torneo de Robert Axelrod (Tit for Tat vs. otras estrategias) como
actividad de clase para el ramo de Estrategias TI. Grupos de alumnos **eligen** una
estrategia predefinida (no programan en vivo), el sistema corre un torneo round-robin
automático, y se revela el resultado de forma animada y simultánea para todos.

Stack: **Ruby on Rails 7** (lo que ya conoces) + **Action Cable** (para el "reveal" en vivo)
+ **Turbo/Stimulus** (JS liviano, viene con Rails, sin necesidad de React).
Hosting: **Render.com** (free tier, Postgres incluido, deploy vía git).

---

## 1. Mecánica del juego

1. Tú (profe/admin) creas una "Sesión de torneo" con: cantidad de rondas por duelo (sugerido:
   **10 rondas fijas y conocidas** — simple para clase; opcional avanzado: fin probabilístico
   tipo Axelrod original, para discutir en clase por qué importa que el fin sea incierto).
2. Cada grupo entra con un **nombre + PIN de 4 dígitos** (sin necesidad de cuentas/registro).
3. Ven el **catálogo de estrategias** (tarjetas con explicación + pros/contras).
4. Cada grupo elige **una** estrategia y confirma. Pantalla de espera muestra "X/N grupos listos"
   (vía Action Cable, así todos ven el contador subir en tiempo real).
5. Cuando todos confirmaron (o tú fuerzas el cierre), aprietas **"Ejecutar torneo"**.
6. El servidor calcula TODO instantáneamente (round-robin: cada grupo vs. cada grupo, N rondas,
   matriz de pagos clásica).
7. Todos los navegadores reciben el broadcast y la pantalla de resultados se anima sola:
   duelo por duelo, ronda por ronda (íconos de Coopera/Traiciona apareciendo), y al final un
   leaderboard que se ordena con contador de puntaje subiendo.
8. Cierre en clase: discusión de por qué ganó quien ganó (gancho para la parte de "Estrategias TI").

### Matriz de pagos (clásica, sugerida)
| | Rival coopera | Rival traiciona |
|---|---|---|
| **Yo coopero** | 3 / 3 | 0 / 5 |
| **Yo traiciono** | 5 / 0 | 1 / 1 |

(T=5 tentación, R=3 recompensa mutua, P=1 castigo mutuo, S=0 pagado del tonto — cumple T>R>P>S).

---

## 2. Catálogo de estrategias sugerido (8, ajustable)

| Estrategia | Cómo funciona | Pro | Contra |
|---|---|---|---|
| **Tit for Tat** | Coopera primero, luego copia lo último que hizo el rival | Simple, "perdona", castiga traición | Vulnerable a ruido/errores (no aplica acá, no hay ruido) |
| **Always Cooperate** | Siempre coopera | Maximiza puntaje conjunto si el otro también coopera | Explotable: pierde feo contra Always Defect |
| **Always Defect** | Siempre traiciona | Nunca "regala" puntos | Provoca represalia, mal resultado a largo plazo contra estrategias vengativas |
| **Grudger / Trigger** | Coopera hasta la primera traición del rival; después nunca más coopera | Castiga fuerte, disuade traición | No perdona nunca, encadena mal resultado si hay un solo error |
| **Tit for Two Tats** | Solo traiciona si el rival traicionó 2 veces seguidas | Más "perdonador", evita ciclos de venganza | Puede ser explotada por rivales que alternan |
| **Suspicious Tit for Tat** | Igual que TfT pero empieza traicionando | Prueba al rival desde el inicio | Genera represalia innecesaria contra cooperadores |
| **Pavlov (Win-Stay/Lose-Shift)** | Repite su jugada si le fue bien (3 o 5 pts), cambia si le fue mal (0 o 1 pt) | Se adapta, buen desempeño general | Comportamiento menos intuitivo de explicar |
| **Random** | Coopera o traiciona 50/50 | Impredecible | No tiene "estrategia" real, generalmente rinde mal |

Cada una se implementa como una función pura en Ruby: `(historial_propio, historial_rival) -> :coopera / :traiciona`.
No hay que guardar "código" de usuario, es código tuyo fijo — los grupos solo *eligen*.

---

## 3. Modelo de datos (simplificado)

- `TournamentSession` (id, rounds_per_match, status: setup/collecting/running/done)
- `Group` (id, session_id, name, pin_digest)
- `Strategy` (id, key, name, description, pros, cons) — semilla fija (seed), no editable por usuarios
- `Selection` (group_id, strategy_id)
- `MatchResult` (group_a_id, group_b_id, rounds_json, score_a, score_b) — se genera al ejecutar, no antes

No hace falta autenticación compleja (Devise, etc.) — con PIN + sesión de Rails basta.

---

## 4. Flujo técnico de la animación "en vivo"

1. Admin aprieta "Ejecutar torneo" → controller calcula el round-robin completo en memoria
   (rápido, es solo aritmética) → guarda resultados → hace `broadcast_append_to` /
   `ActionCable.server.broadcast` a un canal `tournament_#{session.id}`.
2. Todos los navegadores (proyector + grupos) están suscritos a ese canal desde la pantalla
   de espera → al recibir el evento, Turbo Stream reemplaza la vista por la de resultados
   ya calculados.
3. La "animación" de revelado ronda-por-ronda es **puramente client-side** con Stimulus:
   un loop de `setTimeout` que va mostrando cada ícono/resultado con un pequeño delay
   (200-400ms), sobre datos que YA están completos en el HTML. Cero complejidad de backend.

---

## 5. Fases sugeridas (y cómo pedírselo a Claude Code en VSCode, en orden)

**Fase 0 — Setup**
- `rails new torneo_dilema --database=postgresql --css=tailwind`
- Prompt: *"Crea el modelo TournamentSession, Group, Strategy, Selection y MatchResult con
  las migraciones según [pega el esquema de la sección 3]"*

**Fase 1 — Motor del juego (lo más importante, pruébalo con tests)**
- Prompt: *"Implementa un módulo Ruby `GameEngine` con las 8 estrategias de este listado
  [pega tabla sección 2] como clases/lambdas, más un método `run_match(strategy_a, strategy_b, rounds)`
  que devuelve el historial y puntaje usando esta matriz de pagos [pega sección 1]. Agrega tests con RSpec."*
- Esto lo puedes probar 100% en consola/tests antes de tocar ninguna vista — es la parte
  que más importa que funcione bien.

**Fase 2 — Flujo de grupos**
- Prompt: *"Crea las vistas y controller para que un grupo entre con nombre+PIN, vea el
  catálogo de estrategias como tarjetas (usa esta info [pega sección 2]) y elija una"*

**Fase 3 — Panel admin + ejecución del torneo**
- Prompt: *"Crea un panel admin simple donde vea cuántos grupos han elegido, y un botón
  'Ejecutar torneo' que corra el round-robin usando GameEngine y guarde MatchResult"*

**Fase 4 — Reveal en vivo (Action Cable + animación)**
- Prompt: *"Agrega un canal Action Cable `TournamentChannel`, suscribe la pantalla de espera
  de cada grupo, y al ejecutar el torneo haz broadcast para redirigir/actualizar a todos a la
  pantalla de resultados. En esa pantalla, anima el revelado ronda a ronda con Stimulus."*

**Fase 5 — Pulido**
- Página de instrucciones/reglas claras (para antes de jugar)
- Leaderboard final con estilos
- Deploy a Render (Fase 6)

**Fase 6 — Deploy**
- Crear cuenta en Render, conectar el repo de GitHub, Render detecta Rails + Postgres,
  deploy automático. Probar el link 1-2 días antes de la clase con datos de prueba.

---

## 6. Cosas que puedes dejar fuera (para no atrasarte)
- Autenticación real de usuarios (PIN basta)
- Editor de estrategias custom (das el catálogo fijo, ya es suficientemente rico para discutir)
- Persistencia entre sesiones de torneo distintas (una sesión por clase alcanza)
- Diseño perfecto — Tailwind básico + las tarjetas de estrategia bien explicadas es suficiente

---

## 7. Sugerencia de "extra" barato si te sobra tiempo
Después de mostrar el leaderboard, mostrar un mini-resumen tipo "¿Qué estrategia ganó más
duelos individuales?" vs "¿Qué estrategia sumó más puntos totales?" — a veces no coinciden,
y es un excelente gancho de discusión para el ramo (igual que en el torneo real de Axelrod,
donde Tit for Tat nunca ganó un duelo individual, pero ganó el torneo completo).