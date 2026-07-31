# Release procedure

After the release pull request is reviewed, CI is green, and it is merged:

```bash
git switch main
git pull --ff-only origin main
test "$(cat VERSION)" = "0.3.0"
git tag -a v0.3.0 -m "simple-nextflow-salmon v0.3.0"
git push origin v0.3.0
```

The tag workflow rechecks version declarations, runs unit/validation/stub/real/strict tests, builds the source archive and versioned container, and creates the GitHub Release from the changelog. Verify the workflow, release assets, and GHCR package before announcing the release. Do not create the tag from a feature branch.
