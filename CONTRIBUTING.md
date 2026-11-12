# Contributing

Anyone can contribute through forks and pull requests. Samuel-Fx-1 is the maintainer.

## What isn't accepted

- MyDockFinder binaries, repacks, cracked copies, or copyrighted assets such as wallpapers, icons, fonts, or music.
- Personal paths, usernames, tokens, or machine names.
- changes-log.md, state files, or backups.

## How to contribute

1. Fork the repository.
2. Create a branch for your change.
3. Make the change.
4. Parse every `.ps1` file with the PowerShell parser.
5. Open a pull request that describes the change and how you tested it.

## AI assistance

- Contributors may use AI tools, such as Claude, opencode, or Freebuff, to help write changes.
- The person who submits the pull request is responsible for every line and must have tested it on Windows 11.
- If an AI tool wrote a significant part of a commit, end the commit message with a line in this form: `Assisted-by: <tool name>`
- AI tools must not be used as Git author names, author emails, or co-authors.

## Testing

Run scripts with `-WhatIf` first. In the pull request, state the Windows version you tested on.

## Review

The maintainer must review every change before merging. If the change touches the registry, services, or scheduled tasks, say so in the pull request.

## License

Contributions are under the MIT license in [LICENSE](LICENSE).

## Security

Do not report vulnerabilities in a public issue. See [SECURITY.md](SECURITY.md).
