# Contributing

Keep changes within SnS's paired-end bulk RNA-seq quantification scope and preserve its scientific defaults unless a change is justified and documented.

1. Branch from `main` and make a focused change.
2. Update tests and user-facing documentation with behavior changes.
3. Run:

   ```bash
   python3 -m unittest discover -s tests -p 'test_*.py'
   bash tests/test_validation.sh
   bash tests/test_stub_workflow.sh
   NXF_SYNTAX_PARSER=v2 nextflow lint .
   git diff --check
   ```

4. Let CI run the real miniature Conda workflow if the pinned environment is unavailable locally.
5. Open a pull request and describe compatibility and scientific effects.

Do not commit biological data, credentials, absolute local paths, work directories, or generated results.
