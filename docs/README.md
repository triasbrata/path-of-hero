# Path of Hero — knowledge base

Everything learned while building this game lives in this folder. **Read this index first**, then only the documents
your task needs. Each document has ONE purpose, stated in its first line. Building and running: the repository's
README.md, then [dev-workflow.md](dev-workflow.md).

| Document | Its one purpose |
|---|---|
| [game-overview.md](game-overview.md) | What the game is and how a round plays, for someone who has never seen it |
| [architecture.md](architecture.md) | How the code is split (logic vs. drawing) and where each system lives |
| [dev-workflow.md](dev-workflow.md) | How to build and run the game, its identity on each platform, and the traps that break it |
| [process.md](process.md) | How a change gets in: the branches, the checks before main, the decisions log, the art's vault and its hooks, and what never goes into this public repository |
| [units-and-combat.md](units-and-combat.md) | Troop and monster stats, attacks, waves, the boss, the Dungeon's fights |
| [loot-items-relics.md](loot-items-relics.md) | Drops, per-type item upgrades and their awakening caps, per-troop relics, the store |
| [formation-and-navigation.md](formation-and-navigation.md) | How troops line up, walk in, make way and settle |
| [camera-and-field.md](camera-and-field.md) | The camera, the back line, the deploy zone and the field's size |
| [scoreboard.md](scoreboard.md) | The score's rules, the score storage adapters (local file / HTTP server) and the server's contract |
| [telemetry.md](telemetry.md) | The balancing log: what is recorded, the sinks (local file / HTTP stub), privacy, and how to read it |
| [ui-hud.md](ui-hud.md) | The book HUD, the landscape layout and its letterbox, buttons, bars, cursor — and which sprite rects they use |
| [assets.md](assets.md) | Which asset packs are used, how their files were made, naming, the licence rule, the asset vault (the licensed art encrypted, its hooks) and the placeholder art |
| [testing.md](testing.md) | How tests are written and run, and how to check visuals |
| [dungeon-design.md](dungeon-design.md) | The Dungeon's design, built milestone by milestone (M1 built): its rules, numbers, screens, code plan and milestones |
| [decisions-log.md](decisions-log.md) | What the owner asked for and why things are the way they are |

## Rules for keeping it useful

- One purpose per document. A new topic gets a new file and a row in the table above.
- When you change behaviour a document describes, update that document in the same commit.
- Write facts you can act on (names, numbers, file paths), not narration.
- The owner speaks Indonesian; the owner's requests are quoted as given. Code, comments, these docs and the game's text
  are in English.
- References like "decisions-log 232" point at that entry of [decisions-log.md](decisions-log.md); "#79" is an issue in
  the private archive's tracker. A few docs name sdlc.md or itch-page.md, which are in the maintainers' private notes.
- Nothing private here ([process.md](process.md), "What never goes in").
