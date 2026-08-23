# PROGRESS — Torneo del Dilema del Prisionero Iterado

> Actualiza este archivo al terminar cada fase.  
> Última actualización: **Fase 2 completa / Fase 3 pendiente**

---

## 1. Objetivo del proyecto

Recrear el torneo de Robert Axelrod como actividad de clase para el ramo de
**Estrategias TI**. Los grupos de alumnos **eligen** una estrategia predefinida
(no programan nada). El sistema corre un torneo round-robin automático y revela
el resultado de forma animada para todos en tiempo real.

**Flujo del juego:**
1. El profesor crea una sesión de torneo (define rondas por duelo).
2. Cada grupo entra con nombre + PIN de 4 dígitos (sin cuentas/registro).
3. Ven el catálogo de 8 estrategias (tarjetas con pros/contras) y eligen una.
4. Cuando todos confirman, el profesor pulsa **"Ejecutar torneo"**.
5. El servidor calcula el round-robin instantáneamente y transmite los resultados
   a todos los navegadores vía Action Cable.
6. La pantalla de resultados se anima ronda a ronda con Stimulus (client-side).

---

## 2. Stack

| Componente | Versión |
|---|---|
| Ruby | 4.0.1 |
| Rails | 8.1.3.1 |
| PostgreSQL | 16.14 |
| Tailwind CSS | vía tailwindcss-rails 4.6.0 |
| Turbo / Stimulus | turbo-rails 2.0.23 / stimulus-rails 1.3.4 |
| RSpec | rspec-rails 7.x |
| Deploy target | Render.com (free tier) |

---

## 3. Lo que ya está construido y funciona

### 3.1 Proyecto Rails (`rails new . --database=postgresql --css=tailwind`)
- Importmap, Turbo, Stimulus, Tailwind instalados.
- Solid Cache / Solid Queue / Solid Cable configurados.

### 3.2 Base de datos — migraciones y modelos (Fase 0)

| Modelo | Tabla | Notas |
|---|---|---|
| `TournamentSession` | `tournament_sessions` | `rounds_per_match` (default 10), `status` (default "setup") |
| `Strategy` | `strategies` | `key`, `name`, `description`, `pros`, `cons` |
| `Group` | `groups` | `session_id → tournament_sessions`, `name`, `pin_digest` |
| `Selection` | `selections` | `group_id`, `strategy_id`; unicidad por grupo |
| `MatchResult` | `match_results` | `group_a_id`, `group_b_id` → groups; `rounds_json`, `score_a`, `score_b` |

`Group` usa `has_secure_password :pin` para el PIN de 4 dígitos (BCrypt, nunca
se guarda en claro).

`MatchResult#rounds` / `MatchResult#rounds=` serializan/deserializan el JSON
del historial de rondas.

### 3.3 Seeds

`db/seeds.rb` siembra las **8 estrategias** con `find_or_create_by!(key:)` —
idempotente, se puede correr múltiples veces. Confirmado: `Strategy.count == 8`.

### 3.4 GameEngine (Fase 1)

`lib/game_engine.rb` — módulo Ruby puro, sin dependencia de base de datos.

**8 estrategias** como lambdas puras `(my_history, opponent_history) → :cooperate/:defect`:

| Key | Nombre |
|---|---|
| `tit_for_tat` | Tit for Tat |
| `always_cooperate` | Always Cooperate |
| `always_defect` | Always Defect |
| `grudger` | Grudger / Trigger |
| `tit_for_two_tats` | Tit for Two Tats |
| `suspicious_tit_for_tat` | Suspicious Tit for Tat |
| `pavlov` | Pavlov (Win-Stay / Lose-Shift) |
| `random` | Random |

**`GameEngine.run_match(strategy_a, strategy_b, rounds, seed: nil)`**
- Acepta símbolos (`:tit_for_tat`) o callables.
- Devuelve `{ history: [...], score_a: Integer, score_b: Integer }`.
- Cada entrada del historial: `{ a: :cooperate/:defect, b: ..., score_a: pts, score_b: pts }`.
- `seed:` hace reproducibles los partidos con `:random`.

**Matriz de pagos clásica (T>R>P>S):**
```
Yo \ Rival   | Coopera | Traiciona
Coopero      |  3 / 3  |  0 / 5
Traiciono    |  5 / 0  |  1 / 1
```

### 3.6 Fase 2 — Flujo de grupos

**Rutas** (`config/routes.rb`):
```
GET  /         → groups#new      (root, formulario de entrada)
GET  /join     → groups#new
POST /join     → groups#create   (crea o autentica grupo)
DELETE /leave  → groups#destroy  (cierra sesión)
GET  /strategies      → strategies#index   (catálogo)
POST /strategies/:id/pick → strategies#pick (elige estrategia)
GET  /waiting  → groups#waiting  (sala de espera)
```

**Lógica de entrada (`GroupsController#create`)**:
- Si el nombre no existe en la sesión activa → crea grupo nuevo con PIN hasheado.
- Si existe → valida PIN con `has_secure_password :pin` (`authenticate_pin`).
- PIN debe ser exactamente 4 dígitos numéricos (validado en controller).
- `session[:group_id]` guarda el grupo autenticado.

**`ApplicationController`** expone `current_group` y `active_session` como helpers.  
`active_session` busca la sesión de torneo con status `setup` o `collecting`; crea una por defecto si no existe.

**Catálogo de estrategias (`StrategiesController#index`)**:
- Muestra las 8 estrategias del seed como tarjetas Tailwind.
- Marca la estrategia ya elegida con badge "✓ Elegida".
- `@can_change`: solo permite elegir/cambiar si el torneo está en `setup/collecting`.

**Selección (`StrategiesController#pick`)**:
- Crea o actualiza `Selection` (upsert vía `current_group.selection || build_selection`).
- Bloquea cambio si el torneo ya está en `running/done`.

**Sala de espera (`groups#waiting`)**:
- Muestra estrategia elegida, contador de grupos listos vs. total.
- Enlace "Cambiar estrategia" visible mientras el torneo no haya iniciado.
- Maneja graciosamente el caso en que el grupo aún no tiene selección (sin crash).

**Tests de request** (`spec/requests/groups_spec.rb`) — **22 ejemplos, 0 fallos**:
- Formulario de entrada: GET muestra form, redirección si ya logueado
- Nuevo grupo: crea, guarda session, hashea PIN
- Validaciones: nombre vacío, PIN no numérico, PIN de longitud incorrecta
- Grupo existente: PIN correcto autentica, PIN incorrecto rechaza
- Logout (DELETE /leave)
- Catálogo: requiere login, muestra estrategias
- Selección: crea, permite cambio, bloquea si torneo activo
- Sala de espera: requiere login, muestra estrategia elegida

**Total del suite: 68 ejemplos, 0 fallos** (46 GameEngine + 22 request).

`spec/lib/game_engine_spec.rb` — **46 ejemplos, 0 fallos**.

Cubre:
- Payoff matrix
- Cada estrategia de forma aislada (simple + casos borde)
- `run_match`: claves, cantidad de rondas, cálculo de puntajes, errores
- Enfrentamientos cruzados: TfT vs AD, TfT vs AC, Grudger vs AD, Pavlov vs AD,
  TfTT vs AD, STfT vs AC
- Reproducibilidad con semilla

---

## 4. Decisiones de diseño

| Decisión | Razón |
|---|---|
| PIN con `has_secure_password` | Seguridad sin necesidad de Devise; BCrypt ya viene con Rails |
| Estrategias como lambdas en `GameEngine::STRATEGIES` | Código fijo del profesor, los grupos solo eligen; no se guarda código de usuario |
| Torneo calculado instantáneamente (no en vivo) | La animación es client-side (Stimulus con setTimeout); el backend solo hace aritmética y brodacast el resultado ya completo |
| `rounds_json` como TEXT | Flexibilidad; se parsea con `JSON.parse` via helpers en el modelo |
| 10 rondas por defecto | Simple y conocido para clase; discusión sobre fin incierto queda para el cierre conceptual |
| `find_or_create_by!(key:)` en seeds | Idempotencia: se puede re-seedear sin duplicar |
| `app/lib` → `lib/` | Rails 8 autoloads `lib/` con `config.autoload_lib`; más estándar |

---

## 5. Problemas resueltos

- **DB development no existía al empezar**: resuelto con `rails db:create db:migrate`.
- **Foreign key en `groups.session_id`**: migration generada apuntaba a `sessions` (tabla inexistente); corregido a `{ to_table: :tournament_sessions }`.
- **Foreign keys en `match_results`**: `group_a` y `group_b` necesitan `{ to_table: :groups }` explícito.
- **`app/lib` no autoloaded**: movido a `lib/` que sí está en `autoload_lib`.
- **`rails new .` preguntó por README.md**: confirmado con `Y` para sobreescribir.

---

## 6. Cómo correr el proyecto en local

```bash
# 1. Instalar dependencias
bundle install

# 2. Crear y migrar base de datos
bin/rails db:create db:migrate

# 3. Sembrar estrategias
bin/rails db:seed

# 4. Servidor de desarrollo (Rails + Tailwind en paralelo)
bin/dev

# 5. Correr todos los tests
bundle exec rspec

# 6. Correr solo el GameEngine
bundle exec rspec spec/lib/game_engine_spec.rb --format documentation
```

---

## 7. Estado de fases

| Fase | Descripción | Estado |
|---|---|---|
| Fase 0 | Setup Rails, migraciones, modelos | ✅ Completa |
| Fase 1 | GameEngine + 8 estrategias + tests | ✅ Completa |
| Fase 2 | Flujo de grupos: entrada, catálogo, selección, espera | ✅ Completa |
| Fase 3 | Panel admin + ejecución del torneo | ⬜ Pendiente |
| Fase 4 | Action Cable + animación reveal en vivo | ⬜ Pendiente |
| Fase 5 | Pulido visual, leaderboard final | ⬜ Pendiente |
| Fase 6 | Deploy a Render.com | ⬜ Pendiente |

---

## 8. Qué falta (Fase 2 en adelante)

### Fase 2 — Flujo de grupos
- Página de entrada: nombre + PIN → crea grupo nuevo o autentica existente
- Catálogo de estrategias: tarjetas Tailwind con descripción, pros y contras
- Selección de estrategia: guarda `Selection`; permite cambio mientras `status = "collecting"`
- Pantalla de espera: confirma elección, mensaje estático "esperando al profesor"
- Tests de request para el flujo completo

### Fase 3 — Panel admin
- Vista admin simple (sin autenticación compleja, básica con sesión)
- Lista de grupos y cuántos han elegido estrategia
- Botón "Ejecutar torneo" → corre `GameEngine` round-robin → guarda `MatchResult`s

### Fase 4 — Action Cable + animación
- Canal `TournamentChannel`
- Suscripción desde pantalla de espera
- Broadcast al ejecutar el torneo → todos redirigen a pantalla de resultados
- Animación ronda a ronda con Stimulus (setTimeout, datos ya en el HTML)

### Fase 5 — Pulido
- Página de instrucciones/reglas
- Leaderboard con animación de contadores
- Distinción "más duelos ganados" vs "más puntos totales" (gancho pedagógico)

### Fase 6 — Deploy
- Cuenta en Render.com, conectar repo GitHub, configurar Postgres en Render
- Probar con datos reales 1-2 días antes de la clase
