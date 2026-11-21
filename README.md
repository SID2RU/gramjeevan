# GramJeevan AI Development Factory (cloud, zero cost)

Everything runs on GitHub's servers. Nothing is installed on your laptop.

## One-time setup (about 10 minutes, browser only)
1. Create a free GitHub account and a NEW repository named `gramjeevan`. Choose Public (unlimited free Actions minutes).
2. Click "uploading an existing file" and drag in ALL files and folders from this package, then Commit.
   If the `.github` folder did not upload: Add file > Create new file, type `.github/workflows/factory.yml`,
   paste the contents, commit. Repeat for `ci.yml` and `daily-report.yml`.
3. Settings > Actions > General > Workflow permissions: choose "Read and write permissions" and tick
   "Allow GitHub Actions to create and approve pull requests". Save.
4. Settings > Branches (or Rules > Rulesets): protect `main` and require a pull request before merging.
5. Actions tab > "Game checks" > Run workflow. It should go green. This proves Godot and tests work.
6. Actions tab > "Factory cycle" > Run workflow. After a few minutes a pull request appears.
7. From then on it runs every 4 hours by itself. Review pull requests and merge the good ones.

## Go live
Settings > Pages > Source: GitHub Actions. Then Actions > 'Deploy game (go live)' > Run workflow.
Your game appears at https://YOUR-USERNAME.github.io/gramjeevan/ . Every merged change redeploys automatically.

## Where to look
- Issue "GramJeevan Factory Log": one comment per cycle.
- Issues "Daily report YYYY-MM-DD": created each midnight IST.
- Pull requests labelled `ai-factory`: the actual changes.

## Controls
- Add or reorder tasks in BACKLOG.md (first unchecked task is taken).
- Pause: Actions tab > Factory cycle > ... > Disable workflow.
- Use Ollama instead: Settings > Secrets and variables > Actions > Variables > AI_PROVIDER = ollama.
- Limits live in factory/config.json.
