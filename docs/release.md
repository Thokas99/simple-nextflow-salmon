# Release procedure

After `main` is green and the version declarations have been reviewed:

```bash
git switch main
git pull --ff-only origin main
test "$(cat VERSION)" = "0.5.0"
git tag -a v0.5.0 -m "v0.5.0: preflight, provenance and reference setup"
git push origin v0.5.0
```

The tag workflow rechecks version declarations, runs unit/validation/stub/real/strict tests, builds the source archive and versioned container, and creates the GitHub Release from the changelog. Verify the workflow, release assets, and GHCR package before announcing the release. Do not create the tag from a feature branch.
