# Compliance ZIP and Versioned Release Websites

## Problem

The compliance ZIP currently bundles a full Hugo/Hextra website that doesn't work when opened from `file://` (absolute URLs, JavaScript fetch CORS). The website and raw compliance data serve different audiences and should be separated.

## Design

### Compliance ZIP — raw artifacts only

The ZIP attached to each GitHub Release contains machine-readable evidence:

```
{tag}-compliance.zip
├── sboms/
│   ├── postgres.enriched.cdx.json
│   ├── redis.enriched.cdx.json
│   └── ...
├── scans/
│   ├── postgres.scan.json
│   ├── redis.scan.json
│   └── ...
├── vex/
│   ├── postgres.vex.yaml
│   ├── sbomify-app.vex.yaml
│   └── ...
├── docker-compose.yml
└── release.json
```

No website. Tools (Vanta, auditor scripts) ingest these directly.

### Release Website — versioned GitHub Pages

Each promoted release deploys to a versioned subdirectory:

```
https://wellmaintained.github.io/packages/releases/{tag}/
```

The root `/packages/` redirects to the latest promoted release.

#### Deploy flow

1. Download compliance ZIP from the GitHub Release
2. Run `extract-release-data` pointing at the ZIP contents
3. Build Hugo with `baseURL = /packages/releases/{tag}/`
4. Deploy to the `releases/{tag}/` subdirectory in GitHub Pages
5. Update root `/packages/index.html` to redirect to the latest

#### Past releases

Versioned URLs are never overwritten. Each deploy adds a new subdirectory. The gh-pages branch accumulates over time — acceptable since each site is ~5MB and releases are infrequent (weekly at most).

### Changes required

#### Pre-release workflow (`pre-release.yml`)

- `build-release-website` job: remove the website from the compliance bundle step (stop copying `public/` into the ZIP)
- Remove the `Upload built site` artifact step (site is no longer pre-built)

#### Deploy workflow (`deploy-release-website.yml`)

- Download compliance ZIP
- Extract raw data
- Run `extract-release-data` from the extracted data
- Build Hugo with dynamic `baseURL` set to `/packages/releases/{tag}/`
- Deploy to versioned subdirectory using `actions/deploy-pages` or direct gh-pages branch push
- Update root redirect

#### Hugo config

- `baseURL` in `hugo.toml` becomes a development default
- CI overrides it via `hugo --baseURL /packages/releases/{tag}/` flag

### Audience

- **Compliance ZIP**: auditors, procurement teams, evidence stores (Vanta). Machine-readable, archival.
- **Release website**: anyone reviewing a release's security posture. Human-readable, browsable, always available at a stable URL.
