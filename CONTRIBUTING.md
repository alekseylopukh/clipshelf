# Contributing to Clipshelf

Thanks for helping. This file covers how work moves from an idea to a release.

## Before you start

- Bugs and feature ideas start as an [issue](../../issues/new/choose). For anything bigger than a small fix, wait for a maintainer to agree on the approach before writing code.
- Clipshelf is an independent project. Do not contribute code, images, sounds or text copied from Paste or any other proprietary app. See the IP rules in [AGENTS.md](AGENTS.md#ip-rules).
- Contributions are licensed under [GPL-3.0](LICENSE). Code taken from other projects must come from GPL-3.0-compatible licenses (MIT, BSD, Apache-2.0, GPL-3.0) and keep its copyright notice.

## AI-assisted contributions

AI tools are welcome. You stay responsible for what you submit.

- Say in the pull request description which AI tools you used and for what, for example "Claude Code wrote the first draft of the search parser". Pull requests that hide AI use may be closed.
- You must understand every line you submit and be able to explain it in review. You must have built and tested it yourself.
- Do not submit large generated changes nobody asked for. Open an issue first.
- Instructions for AI coding agents live in [AGENTS.md](AGENTS.md).

## Workflow: GitHub Flow

`main` is always releasable. All work happens on short-lived branches and lands through a pull request.

1. Branch off `main` and name the branch `<type>/<short-description>`, for example `feat/search-filters` or `fix/paste-into-terminal`.
2. Keep each pull request focused on one change.
3. Title the pull request as a [Conventional Commit](https://www.conventionalcommits.org/en/v1.0.0/), for example `feat: add type filters to search`. Pull requests are squash-merged and the title becomes the commit message on `main`.
4. Once the pull request is merged, its branch is deleted automatically.

Commit types: `feat`, `fix`, `perf`, `refactor`, `docs`, `test`, `build`, `ci`, `chore`. Mark breaking changes with `!`, for example `feat!: ...`.

## Releases

- Versions follow [Semantic Versioning](https://semver.org). Releases are tagged `vMAJOR.MINOR.PATCH` on `main`, for example `v0.1.0`.
- Only maintainers create tags. Each tag gets a GitHub Release with a signed and notarized build attached.
- Release notes are generated from merged pull requests and grouped by label (see [.github/release.yml](.github/release.yml)). Label your pull request so it lands in the right section.
- A hotfix for an old version gets a `release/vX.Y` branch cut from that tag. This is needed only when `main` has moved on.
