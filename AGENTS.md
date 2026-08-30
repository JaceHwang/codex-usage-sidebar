<!-- repo-governance:start -->
## Repository governance

- Run `./governance doctor` before the first code-changing action in a task. If hooks are inactive, run `./governance bootstrap` and repeat doctor.
- Never develop or commit directly on `main`; use `codex/<type>/<kebab-case>`.
- Use English Conventional Commit headers and Conventional Commit PR titles. PR background and verification may be written in Chinese.
- Never use `--no-verify`, weaken checks, overwrite a published release asset, or edit product versions in ordinary commits.
- Run `./governance check all` before pushing. Release product versions only through the generated Release Please PR.
<!-- repo-governance:end -->


