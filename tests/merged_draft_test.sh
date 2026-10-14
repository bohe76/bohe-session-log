#!/bin/bash
# Implements the "merged draft" definition (the sentence shared by both SKILL.md files)
# command by command and checks it per scenario.
# Reproduces worktree commits, merges and branch deletion in a temp repo running this repo's hook.
# Usage: bash tests/merged_draft_test.sh [path to post-commit hook]  (default: the repo's hook)
HOOK_SRC="${1:-$(cd "$(dirname "$0")/.." && pwd)/skills/bohe-session-log/hooks/post-commit.sh}"
[ -f "$HOOK_SRC" ] || { echo "hook not found: $HOOK_SRC"; exit 2; }
S=$(mktemp -d); trap 'rm -rf "$S"' EXIT; cd "$S" || exit 1
PASS=0; FAIL=0
check() { if [ "$2" = "$3" ]; then echo "PASS $1 -> $2"; PASS=$((PASS+1)); else echo "FAIL $1 -> got $2, want $3"; FAIL=$((FAIL+1)); fi; }

git init -q --bare origin.git
git clone -q origin.git lead 2>/dev/null; cd lead
git checkout -q -b dev
mkdir -p hk docs/session-log; cp "$HOOK_SRC" hk/post-commit; chmod +x hk/post-commit
git config core.hooksPath "$PWD/hk"
echo "docs/session-log/" >> "$(git rev-parse --git-path info/exclude)"
echo "hk/" >> "$(git rev-parse --git-path info/exclude)"
git commit -q --allow-empty -m base; git push -q -u origin dev 2>/dev/null
rm -f docs/session-log/drafts/dev.draft.md
D=docs/session-log/drafts

# Classifier — definition ①②③ as written
classify() {
  local name; name=$(basename "$1" .draft.md)
  if { git for-each-ref --format='%(refname:lstrip=2)' refs/heads; git worktree list --porcelain | sed -n 's#^branch refs/heads/##p'; } | tr '/' '-' | grep -qxF "$name"; then echo "branch-alive"; return; fi
  if [ "$name" = detached ] && git worktree list --porcelain | grep -qx detached; then echo "detached-live"; return; fi
  grep -q '<!-- sha:' "$1" || { echo no-sha; return; }
  awk '/^## \[.*<!-- sha:.*-->$/{s=1;next} s==1&&/^- /{s=2;next} s==2&&/^---$/{s=0;next} /^$/&&s==0{next} {bad=1} END{exit !bad}' "$1" && { echo has-memo; return; }
  local r=merged
  for sha in $(grep -o '<!-- sha:[0-9a-f]*' "$1" | sed 's/.*sha://'); do
    git merge-base --is-ancestor "$sha" HEAD 2>/dev/null; c=$?
    if [ $c -eq 1 ]; then echo unmerged; return; elif [ $c -ne 0 ]; then r=unknown; fi
  done
  echo $r
}
worker() { # $1=branch: 2 commits in a worktree + push
  git worktree add -q "../wt-$1" -b "$1" dev
  local fn=$(echo "$1" | tr / -); echo a > "../wt-$1/$fn.txt"; git -C "../wt-$1" add .; git -C "../wt-$1" commit -q -m "feat: $1 one"
  echo b >> "../wt-$1/$fn.txt"; git -C "../wt-$1" commit -q -am "feat: $1 two"
  git -C "../wt-$1" push -q origin "$1" 2>/dev/null
}
cleanup() { git pull -q --ff-only 2>/dev/null; git worktree remove "../wt-$1"; git branch -D -q "$1"; }

# 1. Merge commit + branch deleted → merged draft
worker wk/merge
git clone -q ../origin.git ../gh 2>/dev/null; G=../gh
git -C $G checkout -q dev; git -C $G -c core.hooksPath=/dev/null merge -q --no-ff origin/wk/merge -m "Merge PR 1"; git -C $G push -q origin dev 2>/dev/null
cleanup wk/merge
check "1 merge-commit, deleted (wk-merge, $(grep -c 'sha:' $D/wk-merge.draft.md) stubs)" "$(classify $D/wk-merge.draft.md)" merged
check "1b no dev draft (pull does not fire post-commit)" "$([ -f $D/dev.draft.md ] && echo yes || echo no)" no

# 2. Squash merge + branch deleted → not merged
worker wk-squash
git -C $G pull -q 2>/dev/null; git -C $G -c core.hooksPath=/dev/null merge -q --squash origin/wk-squash; git -C $G -c core.hooksPath=/dev/null commit -q -m "Squash PR 2"; git -C $G push -q origin dev 2>/dev/null
cleanup wk-squash
check "2 squash, deleted" "$(classify $D/wk-squash.draft.md)" unmerged

# 3. Merged but the branch is alive → untouched
worker wk-alive
git -C $G pull -q 2>/dev/null; git -C $G -c core.hooksPath=/dev/null merge -q --no-ff origin/wk-alive -m "Merge PR 3"; git -C $G push -q origin dev 2>/dev/null
git pull -q --ff-only 2>/dev/null
check "3 merged, branch alive (worktree kept)" "$(classify $D/wk-alive.draft.md)" branch-alive
git worktree remove ../wt-wk-alive
check "3b merged, worktree removed, branch kept" "$(classify $D/wk-alive.draft.md)" branch-alive
git branch -D -q wk-alive

# 4. Stale remote-tracking ref (not pruned) → still treated as no branch
check "4 stale origin/wk/merge present=$(git branch -r | grep -c 'origin/wk/merge')" "$(classify $D/wk-merge.draft.md)" merged

# 5. Undecidable: missing SHA
printf '## [10:00] x <!-- sha:deadbee branch:gone -->\n- x\n---\n' > $D/gone.draft.md
check "5 sha missing" "$(classify $D/gone.draft.md)" unknown

# 5b. Draft with only a hand-written note → not a merged draft
printf 'note: clean up later\n' > $D/memo.draft.md
check "5b memo only" "$(classify $D/memo.draft.md)" no-sha

# 6. detached: excluded while a detached worktree exists, judged otherwise
git worktree add -q --detach ../wt-det dev
echo d > ../wt-det/d.txt; git -C ../wt-det add .; git -C ../wt-det commit -q -m "feat: detached work"
check "6 detached worktree live" "$(classify $D/detached.draft.md)" detached-live
git -C ../wt-det push -q origin HEAD:dev 2>/dev/null; git pull -q --ff-only 2>/dev/null
git worktree remove ../wt-det
check "6b detached worktree removed + merged" "$(classify $D/detached.draft.md)" merged

# 7. Step-0 mtime test: log vs merged draft
touch -d '2026-10-14 18:00' $D/../dev-00001-2026-10-14.md
touch -d '2026-10-14 17:50' $D/wk-merge.draft.md
newer() { [ "$1" -nt "$2" ] && echo flagged || echo quiet; }
check "7 merged after a normal end (stub 17:50 < log 18:00)" "$(newer $D/wk-merge.draft.md $D/../dev-00001-2026-10-14.md)" quiet
touch -d '2026-10-14 18:30' $D/wk-merge.draft.md
check "7b crash (stub 18:30 > log 18:00)" "$(newer $D/wk-merge.draft.md $D/../dev-00001-2026-10-14.md)" flagged

# 8. Live branch with a same-name tag (SHAs merged) → excluded (review MAJOR)
worker wk-tag
git -C $G pull -q 2>/dev/null; git -C $G -c core.hooksPath=/dev/null merge -q --no-ff origin/wk-tag -m "Merge PR 8"; git -C $G push -q origin dev 2>/dev/null
git pull -q --ff-only 2>/dev/null; git worktree remove ../wt-wk-tag; git tag wk-tag
check "8 same-name tag + branch alive (short=$(git for-each-ref --format='%(refname:short)' refs/heads/wk-tag))" "$(classify $D/wk-tag.draft.md)" branch-alive
git branch -D -q wk-tag
check "8b after branch deletion" "$(classify $D/wk-tag.draft.md)" merged

# 9. Stubs mixed with a hand-written note (SHAs merged) → excluded
{ echo "note: this branch is on hold because of X"; cat $D/wk-merge.draft.md; } > $D/mixed.draft.md
check "9 stub + memo" "$(classify $D/mixed.draft.md)" has-memo

# 9b. Bullet note (starting with -) appended → excluded (delta MINOR-1)
{ cat $D/wk-merge.draft.md; echo "- double-check this"; } > $D/bullet.draft.md
check "9b bullet memo" "$(classify $D/bullet.draft.md)" has-memo

# 10. Live branch named legacy → excluded
git branch legacy; cp $D/wk-merge.draft.md $D/legacy.draft.md
check "10 legacy branch alive" "$(classify $D/legacy.draft.md)" branch-alive
git branch -D -q legacy
check "10b no legacy branch" "$(classify $D/legacy.draft.md)" merged

# 11. Branch deleted after the PR merge but before the pull → not merged (merged after the pull)
worker wk-prepull
git -C $G pull -q 2>/dev/null; git -C $G -c core.hooksPath=/dev/null merge -q --no-ff origin/wk-prepull -m "Merge PR 11"; git -C $G push -q origin dev 2>/dev/null
git worktree remove ../wt-wk-prepull; git branch -D -q wk-prepull
check "11 before pull" "$(classify $D/wk-prepull.draft.md)" unmerged
git pull -q --ff-only 2>/dev/null
check "11b after pull" "$(classify $D/wk-prepull.draft.md)" merged

echo "== PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
