---
name: herdr-agent-orchestration
description: "Run coding agents (pi, claude, codex…) in herdr panes as implementors or reviewers: start them, get past trust prompts, send prompts, watch panes for permission prompts and completion, answer or deny prompts, and clean up. Use whenever an orchestrator drives other agents through herdr."
---

# Skill: herdr agent orchestration — start, prompt, watch and answer agents in panes

Use this when one agent (the orchestrator) runs other agents in herdr panes, for example the implementor and reviewer roles in [delegated-implementation-review](../delegated-implementation-review/SKILL.md). It covers the mechanics; the workflow and review rules live in that skill.

Tools: `herdr_layout` (tabs and panes), `herdr_agent` (agent lifecycle: start, prompt, read, send_keys), `herdr_pane` (raw pane: read, send_text, send_keys, close), and the `herdr` CLI for shell scripts.

## 1. One tab per agent

Create a tab per agent so the operator can find it, then start the agent in that tab's root pane:

```js
const tab = await tools.herdr_layout({action: "tab_create", cwd: WORKTREE, label: "abc123-impl"});
const pane = tab.match(/root pane (\S+)/)[1];
await tools.herdr_agent({action: "start", kind: "pi", pane, name: "abc123-impl",
  agentArgs: ["--model", "<provider/model>", "--thinking", "high"]});
```

- Name agents `<ticket>-<role>` (`-impl`, `-review`, `-repro`, `-mock`). Names must match `^[a-z][a-z0-9_-]{0,31}$`.
- Pass the model and thinking level explicitly in `agentArgs`; never rely on the agent's default.
- Set `cwd` to the agent's own worktree. The implementor and reviewer get separate worktrees (see the delegated workflow).

## 2. Get to the ready state before prompting

A new folder shows a **trust prompt**; a trusted one shows the model banner. Loop until the banner appears, answering the trust prompt when it shows:

```js
let screen = "";
for (let i = 0; i < 20; i++) {
  screen = await tools.herdr_pane({action: "read", pane, lines: 30});
  if (/Trust project folder/.test(screen)) {
    await tools.herdr_pane({action: "send_keys", pane, keys: ["down", "down", "enter"]}); // "trust"
    continue;
  }
  if (/<model-name-fragment>/.test(screen)) break;          // a fragment of the model id shown in the banner
  await tools.herdr_pane({action: "wait_output", pane, match: "Trust project folder|<model-name-fragment>",
    regex: true, timeout: 5000}).catch(() => {});
}
```

- Some agents take longer than one `wait_output` to load. If a launcher times out, **read the pane** before assuming failure; it is often just ready and idle. Then send the prompt.
- Store a reusable launcher (e.g. with codemode `store("launchSrc", …)`) instead of rewriting this each time.

## 3. Prompting: briefs on disk, short prompts

- Write the full brief to a file (`<scratch>/<ticket>/brief.md`) and prompt with one line: *"Read <brief> and carry it out exactly. When done, write <report.md> and stop."* Long prompts typed into a pane are fragile, and a file can be re-read after compaction.
- Use `herdr_agent prompt` with `wait: false`, then end your turn and let a watcher (§4) wake you.
- Follow-up rounds go to the **same** agent session (`prompt` on the same target) so it keeps its context. Say which commit it is now on and what changed.
- A pane-hosted agent is not a subagent: `steer_subagent` does not reach it. Send a new prompt instead (it queues after the current tool call).
- If `prompt` fails with "agent … is blocked and requires interactive input", the agent is sitting on a permission prompt (§5).

## 4. Watch panes, not just output files

Waiting only for the report file misses the most common stall: **the agent is blocked on a permission prompt** and will never write the report. Use a watcher that checks both. The script is [scripts/pane-watch.sh](scripts/pane-watch.sh):

```sh
sh pane-watch.sh <pane-id> <done-file> [done-pattern]
# prints "BLOCKED <pane>" plus the tool/input lines, or "READY <done-file>"
```

Run it as a background task that notifies you on exit (`bg_run`, with a generous `timeoutSeconds`). Use a pattern for follow-up rounds so an old report doesn't count as done, e.g. `'^#* *Round 2'`. For reviews, require the expected commit on line 1 (`head -1 review.md | grep -q <sha>`).

When it fires:

- **READY:** read the report or review, then check the diff yourself.
- **BLOCKED:** read the pane (`herdr_agent read`) and answer (§5), then restart the watcher.

Also read the pane whenever an agent seems slow. And when you kill a watcher on purpose, expect its "killed" notification and ignore it.

## 5. Answering permission prompts

pi's prompt looks like:

```
Permission Required
tool  : fetch_content
input : with input {...}
▶ (y) Yes  (s) Yes, allow for this session  (n) No  (r) No, provide reason
press a letter, then again to confirm
```

- **Approve once:** send `y`, then `y` again (letters must be pressed twice). Prefer once over "allow for session".
- **Deny with a reason**, which is the best way to redirect an agent: select the option with arrow keys (`down` ×3, `enter`). Then type the reason with `herdr_pane send_text`, and submit it with **`ctrl+m`**. In this prompt, `enter` sent through `send_keys` did not submit, but `ctrl+m` did.
- Judge each prompt as you would your own tool call. Deny anything outside the agent's brief (network fetches it doesn't need, writes outside its worktree, git writes for an implementor, real-cloud writes). Give the agent the alternative in the reason, e.g. "no internet fetches; use an asset already on disk".
- Ask the operator when the request is a hard-to-reverse or outward-facing action you have no authority for.

## 6. Reading and judging output

- `herdr_agent get` gives the lifecycle state (working, done, idle, blocked). `read` with `lines: 30–40` shows the tail.
- Never accept a report as proof. Read the diff, rerun the decisive checks, and open the images it claims to have checked.

## 7. Clean up

When a ticket's PR has merged (or its work has been dropped):

1. Check every worktree is clean (`git status --porcelain`) and that each branch's head is contained in the merged commit (`git merge-base --is-ancestor <head> <merged-head>`).
2. Close the panes (`herdr_pane close`), remove the worktrees (`git worktree remove`) and delete the local branches.
3. Keep anything the operator still needs, such as evidence branches linked from PR descriptions, and say what you kept.

Leave panes from other workspaces or sessions alone.
