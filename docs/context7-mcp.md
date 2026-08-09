# Context7 MCP setup

Context7 is a Model Context Protocol (MCP) server that pulls up to date,
version correct documentation for libraries straight into a Claude session.
When you ask about Flutter, Expo, React Native, or any package, Claude can
fetch the current official docs instead of relying on training memory. That
matters for this repo because Expo SDK 54 and Flutter move fast.

## How it is wired here

The server is committed at the project root in `.mcp.json`, so it is shared
with every checkout of this repository and every Claude Code session that
opens the project. There is nothing to install per machine. On the first
session after this lands, Claude Code asks you once to approve the project
MCP server; approve it and it stays approved.

The committed config is the keyless remote server:

```json
{
  "mcpServers": {
    "context7": {
      "type": "http",
      "url": "https://mcp.context7.com/mcp"
    }
  }
}
```

Keyless works out of the box for everyone. It has a lower rate limit, which
is fine for the occasional doc lookup a single developer does.

## Adding a free API key for higher limits (optional)

A free API key raises the rate limit. Get one at context7.com/dashboard.

Do NOT paste the key into `.mcp.json`, because that file is committed and the
key would leak into git history. Keep the key on your own machine instead.
Two safe ways:

1. User scope, per machine, never committed. Run this once in your terminal.
   This writes to your personal Claude config, not to the repo:

   ```
   claude mcp add --scope user \
     --transport http \
     --header "Authorization: Bearer YOUR_API_KEY" \
     context7 https://mcp.context7.com/mcp
   ```

   A user scope server takes priority over the project one of the same name,
   so your keyed server is what actually runs for you, while everyone else
   keeps the committed keyless server.

2. Environment variable, if you prefer to keep the header in `.mcp.json`.
   Claude Code expands `${VAR}` in `.mcp.json`. You could change the project
   file to send `"Authorization": "Bearer ${CONTEXT7_API_KEY}"` and export
   `CONTEXT7_API_KEY` in your shell. We do NOT ship it this way, because a
   checkout with the variable unset would fail to start that one server. The
   keyless default avoids that, so option 1 is the recommended path for a key.

## Removing it

Delete the `context7` block from `.mcp.json`, or run
`claude mcp remove context7` for a user scope copy.
