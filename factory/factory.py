#!/usr/bin/env python3
"""GramJeevan AI Development Factory: runs ONE development cycle.

Usage:
  python factory/factory.py                # full cycle (needs gh CLI + token)
  python factory/factory.py --checks-only  # just run Godot import + tests
"""
import difflib
import json
import os
import re
import subprocess
import sys
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CFG = json.loads((ROOT / "factory" / "config.json").read_text(encoding="utf-8"))
GAME = ROOT / "game"
GODOT = os.environ.get("GODOT_BIN", "godot")
ERR_MARKERS = ("SCRIPT ERROR", "Parse Error")

SYSTEM_PROMPT = """You are a careful Godot 4.3 GDScript developer working on GramJeevan, a portrait
touch-first 2D village farming game. Make ONE small change that completes the given task.
Rules:
- Reply with ONLY a JSON object: {"summary": "one sentence", "files": [{"path": "game/scripts/x.gd", "content": "FULL new file content"}]}
- Always return the COMPLETE content of every file you change (never fragments or diffs).
- Only edit files under game/scripts/ or game/scenes/. Never touch tests, workflows or project.godot.
- Use Godot 4.3 GDScript, tab indentation, no class_name, no external assets, no network or OS calls.
- Keep game logic in game_state.gd (testable) and UI in main.gd. Do not break existing behaviour.
- Keep the change small: at most a few files and a few hundred lines."""


def sh(cmd, timeout=120):
    return subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True, timeout=timeout)


# ---------------------------------------------------------------- checks
def run_checks():
    steps = [
        ("godot import", [GODOT, "--headless", "--path", str(GAME), "--import"], 240),
        ("godot tests", [GODOT, "--headless", "--path", str(GAME), "--script", "res://tests/run_tests.gd"], 120),
    ]
    ok, parts = True, []
    for name, cmd, limit in steps:
        try:
            p = subprocess.run(cmd, capture_output=True, text=True, timeout=limit)
            out = (p.stdout or "") + (p.stderr or "")
            bad = p.returncode != 0 or any(m in out for m in ERR_MARKERS)
        except subprocess.TimeoutExpired:
            out, bad = "TIMEOUT", True
        except FileNotFoundError:
            out, bad = "Godot binary not found (GODOT_BIN=%s)" % GODOT, True
        parts.append("### %s: %s\n```\n%s\n```" % (name, "FAIL" if bad else "PASS", out[-2500:]))
        if bad:
            ok = False
            break
    return ok, "\n".join(parts)


# ---------------------------------------------------------------- backlog
def next_task():
    lines = (ROOT / "BACKLOG.md").read_text(encoding="utf-8").splitlines()
    for i, line in enumerate(lines):
        m = re.match(r"^- \[ \] (.+)$", line)
        if m:
            return i, m.group(1)
    return None


def mark_done(index):
    p = ROOT / "BACKLOG.md"
    lines = p.read_text(encoding="utf-8").splitlines()
    lines[index] = lines[index].replace("- [ ]", "- [x]", 1)
    p.write_text("\n".join(lines) + "\n", encoding="utf-8")


# ---------------------------------------------------------------- AI
def read_context():
    files = [GAME / "project.godot"]
    files += sorted((GAME / "scripts").glob("*.gd"))
    files += sorted((GAME / "scenes").glob("*.tscn"))
    files += sorted((GAME / "tests").glob("*.gd"))
    out, total = [], 0
    for f in files:
        chunk = "=== %s ===\n%s\n" % (f.relative_to(ROOT).as_posix(), f.read_text(encoding="utf-8"))
        if total + len(chunk) > CFG["max_context_chars"]:
            break
        out.append(chunk)
        total += len(chunk)
    return "".join(out)


def http_json(url, payload, headers, timeout=300):
    req = urllib.request.Request(
        url, data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json", **headers})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.loads(r.read())


def call_model(messages):
    if os.environ.get("AI_PROVIDER", "github-models") == "ollama":
        d = http_json("http://localhost:11434/api/chat", {
            "model": CFG["ollama_model"], "messages": messages, "stream": False,
            "format": "json", "options": {"num_ctx": 8192, "temperature": 0.2}}, {})
        return d["message"]["content"]
    d = http_json("https://models.github.ai/inference/chat/completions", {
        "model": CFG["github_model"], "messages": messages, "temperature": 0.2,
        "response_format": {"type": "json_object"}},
        {"Authorization": "Bearer " + os.environ["GITHUB_TOKEN"],
         "Accept": "application/vnd.github+json"})
    return d["choices"][0]["message"]["content"]


def parse_proposal(raw):
    raw = raw.strip()
    raw = re.sub(r"^```(?:json)?\s*|\s*```$", "", raw)
    try:
        return json.loads(raw)
    except json.JSONDecodeError as e:
        raise ValueError("response was not valid JSON: %s" % e)


# ---------------------------------------------------------------- safety
def validate_and_apply(proposal, dry_run=False):
    files = proposal.get("files") if isinstance(proposal, dict) else None
    if not isinstance(files, list) or not files:
        raise ValueError("proposal has no files")
    if len(files) > CFG["max_files"]:
        raise ValueError("too many files (max %d)" % CFG["max_files"])
    writes, changed = [], 0
    for f in files:
        rel = str(f.get("path", "")).replace("\\", "/").lstrip("/")
        content = f.get("content")
        if not isinstance(content, str) or not content.strip():
            raise ValueError("empty content for %s" % rel)
        if ".." in rel.split("/"):
            raise ValueError("path traversal: %s" % rel)
        if not any(rel.startswith(a) for a in CFG["allowed_prefixes"]):
            raise ValueError("path not allowed: %s" % rel)
        if Path(rel).suffix not in CFG["allowed_ext"]:
            raise ValueError("file type not allowed: %s" % rel)
        if len(content) > CFG["max_file_chars"]:
            raise ValueError("file too large: %s" % rel)
        for bad in CFG["banned_substrings"]:
            if bad in content:
                raise ValueError("banned API '%s' in %s" % (bad, rel))
        target = ROOT / rel
        old = target.read_text(encoding="utf-8") if target.exists() else ""
        for line in difflib.unified_diff(old.splitlines(), content.splitlines(), lineterm="", n=0):
            if line and line[0] in "+-" and not line.startswith(("+++", "---")):
                changed += 1
        writes.append((target, content, rel))
    if changed > CFG["max_changed_lines"]:
        raise ValueError("change too large: %d lines (max %d)" % (changed, CFG["max_changed_lines"]))
    if not dry_run:
        for target, content, _ in writes:
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(content, encoding="utf-8", newline="\n")
    return [w[2] for w in writes], changed


def revert():
    sh(["git", "checkout", "--", "game", "BACKLOG.md"])
    sh(["git", "clean", "-fd", "game"])


# ---------------------------------------------------------------- reporting
def post_log(text):
    try:
        sh(["gh", "label", "create", "factory-log", "--force", "--color", "0E8A16"])
        p = sh(["gh", "issue", "list", "--label", "factory-log", "--state", "open", "--json", "number"])
        issues = json.loads(p.stdout or "[]")
        if issues:
            num = str(issues[0]["number"])
        else:
            q = sh(["gh", "issue", "create", "--title", "GramJeevan Factory Log",
                    "--label", "factory-log", "--body", "Every development cycle posts here."])
            num = q.stdout.strip().rsplit("/", 1)[-1]
        sh(["gh", "issue", "comment", num, "--body", text])
    except Exception as e:  # reporting must never break the cycle
        print("could not post log:", e)


def finish(status, task, details, pr_url=None, files=None, lines=0):
    now = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC")
    body = ["## Factory cycle: %s" % status, "", "- Time: %s" % now,
            "- Task: %s" % (task or "none")]
    if files:
        body.append("- Files changed: %s (%d lines)" % (", ".join(files), lines))
    if pr_url:
        body.append("- Pull request: %s" % pr_url)
    body += ["", details]
    text = "\n".join(body)
    (ROOT / "reports").mkdir(exist_ok=True)
    (ROOT / "reports" / ("cycle-%s.md" % datetime.now(timezone.utc).strftime("%Y%m%d-%H%M"))).write_text(text, encoding="utf-8")
    summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary:
        with open(summary, "a", encoding="utf-8") as fh:
            fh.write(text + "\n")
    print(text)
    post_log(text)


# ---------------------------------------------------------------- cycle
def cycle():
    p = sh(["gh", "pr", "list", "--label", "ai-factory", "--state", "open", "--json", "number"])
    open_prs = len(json.loads(p.stdout or "[]")) if p.returncode == 0 else 0
    if open_prs >= CFG["max_open_ai_prs"]:
        return finish("SKIPPED", None, "%d AI pull requests are waiting for your review. Merge or close some to continue." % open_prs)

    task = next_task()
    if not task:
        return finish("IDLE", None, "Backlog is empty. Add tasks to BACKLOG.md.")
    index, text = task

    ok, log = run_checks()
    if not ok:
        return finish("BASELINE FAILING", text, "Main branch fails its own checks. No AI changes attempted.\n\n" + log)

    messages = [
        {"role": "system", "content": SYSTEM_PROMPT},
        {"role": "user", "content": "TASK: %s\n\nCURRENT PROJECT FILES:\n%s" % (text, read_context())},
    ]
    notes, files, lines, summary = [], [], 0, ""
    for attempt in range(1, CFG["max_attempts"] + 1):
        try:
            raw = call_model(messages)
        except urllib.error.HTTPError as e:
            return finish("AI UNAVAILABLE", text, "Model request failed with HTTP %s (free rate limit?). Will retry next cycle." % e.code)
        except Exception as e:
            return finish("AI UNAVAILABLE", text, "Model request failed: %s" % e)
        try:
            proposal = parse_proposal(raw)
            files, lines = validate_and_apply(proposal)
            summary = str(proposal.get("summary", ""))
        except ValueError as e:
            notes.append("Attempt %d rejected: %s" % (attempt, e))
            messages += [{"role": "assistant", "content": raw},
                         {"role": "user", "content": "Rejected: %s. Return corrected JSON." % e}]
            revert()
            continue
        ok, log = run_checks()
        if ok:
            break
        notes.append("Attempt %d failed checks." % attempt)
        messages += [{"role": "assistant", "content": raw},
                     {"role": "user", "content": "Checks failed. Fix the errors and return the corrected full JSON.\n\n" + log[-2500:]}]
        revert()
    else:
        return finish("FAILED", text, "No valid change after %d attempts. Main untouched.\n\n%s" % (CFG["max_attempts"], "\n".join(notes)))

    mark_done(index)
    branch = "ai/cycle-" + datetime.now(timezone.utc).strftime("%Y%m%d-%H%M")
    base = os.environ.get("GITHUB_REF_NAME", "main")
    sh(["git", "checkout", "-b", branch])
    sh(["git", "add", "game", "BACKLOG.md"])
    sh(["git", "commit", "-m", "AI: " + text[:70]])
    push = sh(["git", "push", "-u", "origin", branch])
    if push.returncode != 0:
        return finish("PUSH FAILED", text, push.stderr[-1500:])
    sh(["gh", "label", "create", "ai-factory", "--force", "--color", "5319E7"])
    body = "**Task:** %s\n\n**AI summary:** %s\n\nGodot import and tests passed on this branch. Review before merging.\n\n%s" % (text, summary, "\n".join(notes))
    pr = sh(["gh", "pr", "create", "--base", base, "--head", branch, "--title", "AI: " + text[:70],
             "--body", body, "--label", "ai-factory"])
    url = pr.stdout.strip() if pr.returncode == 0 else None
    detail = "All checks passed.\n\n%s\n%s" % (summary, "\n".join(notes))
    if not url:
        detail += "\n\nPR creation failed: " + pr.stderr[-800:]
    return finish("SUCCESS", text, detail, url, files, lines)


def main():
    if "--checks-only" in sys.argv:
        ok, log = run_checks()
        print(log)
        sys.exit(0 if ok else 1)
    cycle()


if __name__ == "__main__":
    main()
