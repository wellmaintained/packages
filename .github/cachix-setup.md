# Cachix Binary Cache Setup

This document describes how to set up and configure the Cachix binary cache for this project.

## Prerequisites

- A Cachix account (sign up at https://cachix.org)
- Access to the `wellmaintained-nixpkgs` cache (request from maintainers)

## Setup Steps

### 1. Create or Access the Cache

**If creating a new cache:**
```bash
# Install cachix CLI
nix profile install nixpkgs#cachix

# Create cache (requires Cachix account)
cachix cache create wellmaintained-nixpkgs

# Generate signing key
cachix signing-key-gen wellmaintained-nixpkgs
```

**If using existing cache:**
Request access from the maintainers and they will provide the signing key.

### 2. Configure GitHub Secrets

Add the following secrets to your GitHub repository:

| Secret Name | Value | Description |
|------------|-------|-------------|
| `CACHIX_SIGNING_KEY` | Private signing key | Required for pushing to cache |
| `CACHIX_AUTH_TOKEN` | Cachix API token | Alternative auth method |
| `CACHIX_PUBLIC_KEY` | Public key (optional) | For documentation purposes |

**To get the signing key:**
```bash
# View signing key (run this on a secure machine)
cachix signing-key-info wellmaintained-nixpkgs
```

**To create API token:**
1. Go to https://app.cachix.org/tokens
2. Create a new token with "push" permission
3. Add to GitHub Secrets as `CACHIX_AUTH_TOKEN`

### 3. Verify Configuration

```bash
# Test cache access
cachix use wellmaintained-nixpkgs

# Verify signing key is configured
nix store sign --key-file ~/.config/cachix/signing-key.sec --help > /dev/null && echo "Signing key configured"

# Test pushing a small derivation
echo "test" | cachix push wellmaintained-nixpkgs
```

## Consumer Configuration

### Using the Cache

Add to your `nix.conf` or `~/.config/nix/nix.conf`:

```ini
substituters = https://wellmaintained-nixpkgs.cachix.org
trusted-public-keys = wellmaintained-nixpkgs-1:AbCdEfGhIjKlMnOpQrStUvWxYz1234567890AbCdEfGhIjKlMnOpQrStUvWxYz1234567890=
```

### Verifying Cache Access

```bash
# Check cache info
curl -s https://wellmaintained-nixpkgs.cachix.org/nix-cache-info

# Test building with cache
nix build .#go --option substituters https://wellmaintained-nixpkgs.cachix.org
```

## Troubleshooting

### "Cache not found" Error

Ensure the cache name is correct: `wellmaintained-nixpkgs`

### "Unauthorized" Error

1. Verify `CACHIX_SIGNING_KEY` is correctly set in GitHub Secrets
2. Check the key hasn't expired
3. Ensure the cache has push permissions for your account

### Slow Downloads

The cache may be warming up. First-time builds will be slower as binaries are uploaded.

## Security Considerations

- **Never commit the signing key to the repository**
- Use GitHub Secrets for all credentials
- Rotate signing keys periodically
- Monitor cache access logs in Cachix dashboard

## Maintenance

### Rotating Signing Key

```bash
# Generate new key
cachix signing-key-gen wellmaintained-nixpkgs

# Update GitHub Secret with new key
gh secret set CACHIX_SIGNING_KEY --body="$(cat new-signing-key.sec)"

# Push existing cache with new key
cachix sign --signing-key new-signing-key.sec wellmaintained-nixpkgs
```

### Monitoring Cache Usage

1. Go to https://app.cachix.org/cache/wellmaintained-nixpkgs
2. Monitor storage usage and download statistics
3. Set up alerts for storage limits