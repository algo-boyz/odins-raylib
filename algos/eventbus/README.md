# 🎮 obus - Odin Event Bus
a **foundational tool for writing clean, modular, decoupled game logic**.

Game systems grow fast. Before long, UI needs to react to gameplay, audio reacts to combat, achievements react to everything, and suddenly **your code becomes a tangle of direct function calls**.

The *Event Bus* pattern solves this.

It allows different systems to communicate without tightly depending on each other:

* Gameplay systems dispatch events
* Other systems subscribe to them
* Nobody needs to know who talks to whom

# 🧱 When Should You Use an Event Bus?

Essentially: **any time a system should react to something it does not own.**

If you design your game systems around events early, you get:

* Cleaner architecture
* Easier debug
* Higher flexibility
* Better testing
* Fewer dependencies
* Avoids circular dependencies
* Faster iteration


Ideal for menus, enemy instances, UI panels, etc

# 📦 Creating an Event Bus

NOTE: This example is intentionally kept simple to teach the concepts. For a more robust multi-threaded implementtion check 'rlutil/events'

```odin
global_bus := events.new_bus("global", concurrent = true)
defer events.destroy_bus(global_bus)
```

Use `concurrent=true` if dispatching from multiple threads or nested dispatches.

---

# 👂 Subscribing to Events

### 1. A Generic Logger

```odin
on_log_event :: proc(e: ^events.EventData, user_data: rawptr) {
    fmt.printf("[LOG] Event received: %s\n", e.name)
}

sub_id_log := events.subscribe(global_bus, "level_up", on_log_event)
```

### 2. Type-Specific Subscriber

```odin
on_level_up :: proc(e: ^events.EventData, user_data: rawptr) {
    if payload, ok := e.data.(LevelUpPayload); ok {
        fmt.printf("[GAME] CONGRATS! Reached Level %d (%s)\n",
            payload.level, payload.new_rank)
    }
}
events.subscribe(global_bus, "level_up", on_level_up)
```

### 3. Subscriber With Context (`user_data`)

```odin
on_score_change :: proc(e: ^events.EventData, user_data: rawptr) {
    player_name := cast(^string) user_data
    if score, ok := e.data.(int); ok {
        fmt.printf("[UI] Updating Scoreboard for %s: %d\n", player_name^, score)
    }
}

p1_name := "Hero123"
events.subscribe(global_bus, "score_updated", on_score_change, &p1_name)
```

# 📢 Dispatching Events

Dispatch an event with any payload:

```odin
lvl_data := LevelUpPayload{ level = 5, new_rank = "Knight" }
events.dispatch(global_bus, "level_up", lvl_data)
```

Or simple types:

```odin
events.dispatch(global_bus, "score_updated", 100)
```

The bus takes a snapshot of listeners, so dispatch is safe even if listeners subscribe/unsubscribe during callbacks

# ❌ Unsubscribing

Every subscriber gets a UUID ID.

```odin
events.unsubscribe(global_bus, sub_id_log)
```