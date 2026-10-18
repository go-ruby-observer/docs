<p align="center"><img src="https://raw.githubusercontent.com/go-ruby-observer/brand/main/social/go-ruby-observer.png" alt="go-ruby-observer/docs" width="720"></p>

# go-ruby-observer/docs

Versioned documentation for [go-ruby-observer](https://github.com/go-ruby-observer),
built with [Hugo](https://gohugo.io/) and this fleet's [Hextra fork](https://github.com/tannevaled/hextra) — upstream Hextra plus the opt-in features the fleet's sites use. Published to the
`gh-pages` branch and served at <https://go-ruby-observer.github.io/docs/>.

The organization landing page ([go-ruby-observer.github.io](https://go-ruby-observer.github.io))
links here.

## Local preview

```bash
git submodule update --init --recursive   # themes/hextra, pinned at a release tag
hugo server                               # http://localhost:1313
```

## Releasing a new docs version

Each documented version is its own build under `/docs/<version>/`, and
`/docs/latest/` follows the newest — which is what `mike` did before. The version
comes from `params.docs.version` in `hugo.yaml`: set it to the release the pages
describe (`v0.16.0` → `/docs/0.16/`), or leave it at `main` while no release is
tagged. The `docs` workflow reads it, builds with that `--baseURL`, and replaces
**only** that version's path.

⛔ The build runs with `--panicOnWarning`, so a link to a page that is not there
fails the lane instead of 404ing for a reader.
