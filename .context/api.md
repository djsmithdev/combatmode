# API and documentation

## WoW API (preferred)

Use the **wow-api** MCP tools first (Mainline unless the task says otherwise):

- `lookup_api` / `search_api` for functions and namespaces
- `list_deprecated` for replacements
- `get_event`, `get_enum`, `get_namespace`, `get_widget_methods` as needed

See `.cursor/rules/wow-mcp-first.mdc` for the full reliability order.

## Fallback

Only use the web if MCP is unavailable, incomplete, or you need narrative/bug-context that isn’t captured by signatures/events.

Preferred web sources:

- [World of Warcraft API (wiki.gg)](https://warcraft.wiki.gg/wiki/World_of_Warcraft_API)
- [Widget API (wiki.gg)](https://warcraft.wiki.gg/wiki/Widget_API)

Secondary / last resort (only if wiki.gg lacks the detail you need):

- [World of Warcraft API (Wowpedia)](https://wowpedia.fandom.com/wiki/World_of_Warcraft_API)

## Lua

World of Warcraft uses **Lua 5.1** semantics for addon code. Reference: [Lua 5.1 manual](https://www.lua.org/manual/5.1/).

## In-repo truth

Prefer reading the owning **`CombatMode/Core/*.lua`**, **`Config/*.lua`**, or **`Constants/*.lua`** module over guessing how CombatMode wires an API.
