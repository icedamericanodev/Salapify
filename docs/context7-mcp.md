# Context7 MCP setup

Context7 is a Model Context Protocol (MCP) server that pulls up to date,
version correct documentation for libraries straight into a Claude session.
When you ask about Flutter, Expo, React Native, or any package, Claude can
fetch the current official docs instead of relying on training memory. That
matters for this repo because Expo SDK 54 and Flutter move fast.

## How it is wired here

The server is committed at the project root in `.mcp.json`, so it is shared
with every checkout of this repository and every Claude Code session that
opens the project. On the first session after this lands, Claude Code asks
you once to approve the project MCP server; approve it and it stays approved.

This project authenticates Context7 with an API key. Claude Code reads the
key from the `CONTEXT7_API_KEY` environment variable and expands it into the
request header at connect time, so no key is ever written to the file or to
git:

    {
      "mcpServers": {
        "context7": {
          "type": "http",
          "url": "https://mcp.context7.com/mcp",
          "headers": {
            "CONTEXT7_API_KEY": "${CONTEXT7_API_KEY}"
          }
        }
      }
    }

`CONTEXT7_API_KEY` is both the header name Context7 expects and the name of
the environment variable Claude Code expands into it. The key itself only
ever lives in your shell environment. Keyless use is not relied on here; in
this environment Context7 asks to be authorized before its tools are
available, so a key or OAuth is needed.

## Recommended setup: the Context7 CLI

Context7's own CLI wires everything up for you and is the current recommended
flow. In an interactive terminal:

    npx ctx7 setup --claude

That authenticates through OAuth in your browser, generates an API key, and
registers the server for Claude Code. For a remote or headless environment
where no browser is available, pass the key directly:

    npx ctx7 setup --claude --api-key YOUR_API_KEY

Get a key from your Context7 dashboard at context7.com.

## Setting the key by hand

If you would rather set the environment variable yourself so the committed
`.mcp.json` above picks it up, export it in your shell profile (`~/.zshrc`
or `~/.bashrc`) so it persists:

    export CONTEXT7_API_KEY="your-key-here"

Open a new terminal (or source the profile) and start Claude Code from it.
Check it loaded with `claude mcp list`; the context7 server should show no
missing-variable warning.

The equivalent manual command, if you prefer to register a user scope server
instead of relying on the project file, is:

    claude mcp add --scope user \
      --transport http \
      --header "CONTEXT7_API_KEY: YOUR_API_KEY" \
      context7 https://mcp.context7.com/mcp

A user scope server overrides the project one of the same name for you only.

## OAuth alternative

Clients that implement the MCP OAuth specification can authenticate without a
static key by pointing at the OAuth endpoint instead of the plain one:

    https://mcp.context7.com/mcp/oauth

With that URL, run `/mcp` inside an interactive Claude Code session to
complete the browser sign in. OAuth cannot be completed in a non interactive
or headless session, so use the API key method there.

## If the key is not set

Claude Code still loads the rest of your config. It shows a missing-variable
warning for the context7 server in `claude mcp list` and sends the header
unexpanded, so Context7 will not authenticate until the key is available.
This does not break other MCP servers or the session.

## Removing it

Delete the `context7` block from `.mcp.json`.
