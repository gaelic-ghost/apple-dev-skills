# Apple Dev Skills

Apple Dev Skills has moved into the [Socket marketplace](https://github.com/gaelic-ghost/socket).

This repository stays online as a compatibility marketplace for people who installed `gaelic-ghost/apple-dev-skills` directly. The plugin payload is served from Socket at `plugins/apple-dev-skills`, so existing standalone users can keep using the same marketplace name while receiving the Socket-owned Apple Dev Skills payload.

## Recommended Install

Use Socket when you want Apple Dev Skills and Gale's companion plugins from one Codex marketplace:

```bash
codex plugin marketplace add gaelic-ghost/socket
codex plugin marketplace upgrade socket
```

After adding Socket, open the Codex plugin directory, choose `Socket`, and install or enable `apple-dev-skills`.

## Compatibility Install

Existing Apple-only users can keep this marketplace:

```bash
codex plugin marketplace add gaelic-ghost/apple-dev-skills
codex plugin marketplace upgrade apple-dev-skills
```

That compatibility marketplace points at the Socket-hosted plugin payload through `.agents/plugins/marketplace.json`. New feature work, issue tracking, release notes, and maintainer documentation live in [gaelic-ghost/socket](https://github.com/gaelic-ghost/socket).

## Duplicate Installs

If both Socket and this compatibility marketplace are configured, prefer the Socket entry: `apple-dev-skills@socket`.

## License

Apple Dev Skills is licensed under the PolyForm Noncommercial License 1.0.0 for future public versions. See [LICENSE](./LICENSE), [NOTICE](./NOTICE), and [COMMERCIAL-USE.md](./COMMERCIAL-USE.md).

Commercial use requires a separate written commercial license from Gale. For commercial licensing, contact Gale W at <mail@galewilliams.com>.

Apple Dev Skills versions published before the PolyForm Noncommercial change remain available under the license terms that applied to those versions. The historical Apache License 2.0 text is preserved in [LICENSE-APACHE-2.0](./LICENSE-APACHE-2.0).
