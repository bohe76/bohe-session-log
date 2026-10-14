#!/bin/bash
# Implements the "handoff draft" definition (the sentence shared by both SKILL.md files) and the
# global-latest-log rule command by command, and checks them per scenario.
# Reproduces worktree commits, merges, branch switches and deletion in a temp repo running this repo's hook.
# Usage: bash tests/draft_handoff_test.sh [path to post-commit hook]  (default: the repo's hook)
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

# Writers: per worktree entry (path, branch, detached, prunable) → branch name (/→-), __DETACHED__ for detached
live_names() {
  git worktree list --porcelain | awk '
    /^worktree /{if(p!="")print p"|"b"|"d"|"x; p=substr($0,10); b=""; d=0; x=0}
    /^branch refs\/heads\//{b=substr($0,19)} /^detached$/{d=1} /^prunable/{x=1}
    END{if(p!="")print p"|"b"|"d"|"x}' |
  while IFS='|' read -r p b d x; do   # tab is IFS whitespace and collapses empty fields → use |
    [ "$x" = 1 ] && continue
    [ -n "$b" ] && echo "$b"
    if [ "$d" = 1 ]; then
      echo __DETACHED__
      for f in rebase-merge/head-name rebase-apply/head-name; do
        g=$(git -C "$p" rev-parse --path-format=absolute --git-path "$f"); [ -f "$g" ] && sed 's#^refs/heads/##' "$g"
      done
      g=$(git -C "$p" rev-parse --path-format=absolute --git-path BISECT_START); [ -f "$g" ] && cat "$g"
    fi
  done | tr '/' '-'
}
# Classifier — definition ①② as written; merge status is an annotation
classify() {
  local name; name=$(basename "$1" .draft.md)
  [ -s "$1" ] || { echo empty; return; }
  # ① writer: a branch line of any worktree (prunable excluded), or the rebase/bisect target of a detached entry → in progress
  local names; names=$(live_names)
  if printf '%s\n' "$names" | grep -qxF "$name"; then echo live; return; fi
  if [ "$name" = detached ] && printf '%s\n' "$names" | grep -qxF __DETACHED__; then echo live; return; fi
  # ② anything outside 3-line stubs and blank lines (notes)
  awk '/^## \[/{s=1;next} s==1&&/^- /{s=2;next} s==2&&/^---$/{s=0;next} /^$/&&s==0{next} {bad=1} END{exit !bad}' "$1" && { echo memo; return; }
  # annotation: merged if every sha is an ancestor of HEAD
  local r=handoff-merged
  for sha in $(grep -o '<!-- sha:[0-9a-f]*' "$1" | sed 's/.*sha://'); do
    git merge-base --is-ancestor "$sha" HEAD 2>/dev/null || r=handoff-unmerged
  done
  echo $r
}
worker() { # $1=branch: 2 commits in a worktree + push
  git worktree add -q "../wt-$1" -b "$1" dev
  local fn=$(echo "$1" | tr / -); echo a > "../wt-$1/$fn.txt"; git -C "../wt-$1" add .; git -C "../wt-$1" commit -q -m "feat: $1 one"
  echo b >> "../wt-$1/$fn.txt"; git -C "../wt-$1" commit -q -am "feat: $1 two"
  git -C "../wt-$1" push -q origin "$1" 2>/dev/null
}
ghmerge() { git -C $G pull -q 2>/dev/null; git -C $G -c core.hooksPath=/dev/null merge -q --no-ff "origin/$1" -m "Merge $1"; git -C $G push -q origin dev 2>/dev/null; }
git clone -q ../origin.git ../gh 2>/dev/null; G=../gh; git -C $G checkout -q dev

# 1. Lead flow: merge commit + worktree and branch deleted → handoff (merged)
worker wk/merge; ghmerge wk/merge
git pull -q --ff-only 2>/dev/null; git worktree remove ../wt-wk/merge; git branch -D -q wk/merge
check "1 merge + deleted (wk-merge, $(grep -c 'sha:' $D/wk-merge.draft.md) stubs)" "$(classify $D/wk-merge.draft.md)" handoff-merged
check "1b no dev draft (pull does not fire post-commit)" "$([ -f $D/dev.draft.md ] && echo yes || echo no)" no

# 2. Squash merge + deleted → handoff (not merged) — excluded under the old rule
worker wk-squash
git -C $G pull -q 2>/dev/null; git -C $G -c core.hooksPath=/dev/null merge -q --squash origin/wk-squash; git -C $G -c core.hooksPath=/dev/null commit -q -m "Squash wk-squash"; git -C $G push -q origin dev 2>/dev/null
git pull -q --ff-only 2>/dev/null; git worktree remove ../wt-wk-squash; git branch -D -q wk-squash
check "2 squash + deleted" "$(classify $D/wk-squash.draft.md)" handoff-unmerged

# 3. Merged and checked out in a worktree → in progress / only the worktree removed (branch alive) → handoff
worker wk-alive; ghmerge wk-alive; git pull -q --ff-only 2>/dev/null
check "3 checked out in a linked worktree" "$(classify $D/wk-alive.draft.md)" live
git worktree remove ../wt-wk-alive
check "3b worktree removed, branch alive" "$(classify $D/wk-alive.draft.md)" handoff-merged
git branch -D -q wk-alive

# 4. Stale remote-tracking refs do not matter
check "4 stale origin/wk/merge present=$(git branch -r | grep -c 'origin/wk/merge')" "$(classify $D/wk-merge.draft.md)" handoff-merged

# 5. Missing SHA → handoff (annotated not merged)
printf '## [10:00] x <!-- sha:deadbee branch:gone -->\n- x\n---\n' > $D/gone.draft.md
check "5 sha missing" "$(classify $D/gone.draft.md)" handoff-unmerged
# 5b. Draft with only a note → has notes
printf 'note: clean up later\n' > $D/memo.draft.md
check "5b memo only" "$(classify $D/memo.draft.md)" memo
# 5c. Empty file → not a candidate
: > $D/blank.draft.md
check "5c empty" "$(classify $D/blank.draft.md)" empty

# 6. detached: in progress while another worktree is detached, handoff after removal
git worktree add -q --detach ../wt-det dev
echo d > ../wt-det/d.txt; git -C ../wt-det add .; git -C ../wt-det commit -q -m "feat: detached work"
check "6 detached worktree live" "$(classify $D/detached.draft.md)" live
git -C ../wt-det push -q origin HEAD:dev 2>/dev/null; git pull -q --ff-only 2>/dev/null
git worktree remove ../wt-det
check "6b detached worktree removed + merged" "$(classify $D/detached.draft.md)" handoff-merged

# 7. Step 0: compare with the global latest log (any branch)
touch -d '2026-10-14 17:00' $D/../dev-00001-2026-10-14.md
touch -d '2026-10-14 18:00' $D/../side-00001-2026-10-14.md
latest() { ls -t $D/../*-[0-9][0-9][0-9][0-9][0-9]-[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9].md | head -1; }
newer() { [ "$1" -nt "$(latest)" ] && echo flagged || echo quiet; }
touch -d '2026-10-14 17:50' $D/wk-merge.draft.md
check "7 draft 17:50 < global latest 18:00 (newer than the dev log 17:00)" "$(newer $D/wk-merge.draft.md)" quiet
touch -d '2026-10-14 18:30' $D/wk-merge.draft.md
check "7b crash: draft 18:30 > global latest 18:00" "$(newer $D/wk-merge.draft.md)" flagged

# 8. Same-name tag + checked out in a worktree → in progress / handoff after removal
worker wk-tag; git tag wk-tag
check "8 same-name tag + checked out" "$(classify $D/wk-tag.draft.md)" live
git worktree remove ../wt-wk-tag
check "8b worktree removed (tag kept)" "$(classify $D/wk-tag.draft.md)" handoff-unmerged

# 9. Stubs mixed with a note → has notes
{ echo "note: on hold because of X"; cat $D/wk-merge.draft.md; } > $D/mixed.draft.md
check "9 stub + memo" "$(classify $D/mixed.draft.md)" memo
{ cat $D/wk-merge.draft.md; echo "- double-check this"; } > $D/bullet.draft.md
check "9b bullet memo appended" "$(classify $D/bullet.draft.md)" memo

# 10. Branch named legacy checked out in a worktree → in progress / otherwise handoff
git worktree add -q ../wt-legacy -b legacy dev; cp $D/wk-merge.draft.md $D/legacy.draft.md
check "10 legacy branch checked out" "$(classify $D/legacy.draft.md)" live
git worktree remove ../wt-legacy
check "10b legacy branch not checked out" "$(classify $D/legacy.draft.md)" handoff-merged

# 11. Deleted after the PR merge but before the pull → handoff (not merged), merged after the pull
worker wk-prepull; ghmerge wk-prepull
git worktree remove ../wt-wk-prepull; git branch -D -q wk-prepull
check "11 before pull" "$(classify $D/wk-prepull.draft.md)" handoff-unmerged
git pull -q --ff-only 2>/dev/null
check "11b after pull" "$(classify $D/wk-prepull.draft.md)" handoff-merged

# 12. Switched to another branch in the same worktree (branch alive) → handoff
git checkout -q -b side; echo s > side.txt; git add side.txt; git commit -q -m "feat: side work"; git checkout -q dev
check "12 switched away in same worktree" "$(classify $D/side.draft.md)" handoff-unmerged
# 12b. Session in a linked worktree: the main worktree's current branch (dev) draft is in progress
git worktree add -q ../wt-sess side; printf '## [11:00] y <!-- sha:%s branch:dev -->\n- y\n---\n' "$(git rev-parse --short HEAD)" > $D/dev.draft.md
check "12b branch checked out in the main worktree (from a linked session)" "$(cd ../wt-sess && classify "$OLDPWD/$D/dev.draft.md")" live
git worktree remove ../wt-sess; rm -f $D/dev.draft.md

# 13. Worktree whose directory was deleted by hand (prunable) → no writer → handoff (review MEDIUM)
worker wk-gone; rm -rf ../wt-wk-gone
check "13 prunable entry present=$(git worktree list --porcelain | grep -c '^prunable')" "$(classify $D/wk-gone.draft.md)" handoff-unmerged
git worktree prune; git branch -D -q wk-gone

# 14. Another worktree stopped mid-rebase (detached) → its branch is in progress (review MEDIUM)
echo base > conf.txt; git add conf.txt; git commit -q -m "chore: conf base"
git worktree add -q ../wt-rb -b rb dev
echo rb > ../wt-rb/conf.txt; git -C ../wt-rb commit -q -am "feat: rb side"
echo dev > conf.txt; git commit -q -am "chore: conf dev"
git -C ../wt-rb rebase dev >/dev/null 2>&1
check "14 rebase stopped (detached=$(git worktree list --porcelain | grep -c '^detached'))" "$(classify $D/rb.draft.md)" live
git -C ../wt-rb rebase --abort
# 14b. The same worktree mid-bisect (detached, BISECT_START = branch name) → in progress
git -C ../wt-rb bisect start -q 2>/dev/null || git -C ../wt-rb bisect start >/dev/null; git -C ../wt-rb checkout -q --detach HEAD~1
check "14b bisect in progress (detached=$(git worktree list --porcelain | grep -c '^detached'))" "$(classify $D/rb.draft.md)" live
git -C ../wt-rb bisect reset -q 2>/dev/null || git -C ../wt-rb bisect reset >/dev/null; git worktree remove --force ../wt-rb

# 15. Step-0 function: my draft + handoff drafts newer than the global latest log (existence alone when there is no log)
step0() { local L; L=$(latest 2>/dev/null); for f in $D/*.draft.md; do
  local n; n=$(basename "$f" .draft.md); [ -s "$f" ] || continue
  if [ "$n" != "$(git branch --show-current | tr / -)" ]; then case "$(classify "$f")" in handoff-*) ;; *) continue;; esac; fi
  { [ -z "$L" ] || [ "$f" -nt "$L" ]; } && { echo flagged; return; }
done; echo quiet; }
for f in $D/*.draft.md; do touch -d '2026-10-14 17:30' "$f"; done
worker wk-live; touch -d '2026-10-14 19:00' $D/wk-live.draft.md
check "15 only an in-progress draft is newest → step 0 quiet" "$(step0)" quiet
touch -d '2026-10-14 19:00' $D/side.draft.md
check "15b handoff draft is newest → flagged" "$(step0)" flagged
mkdir -p ../logs-off; mv $D/../*-0000[0-9]-*.md ../logs-off/; touch -d '2026-10-14 17:30' $D/side.draft.md
check "15c no log + a handoff draft exists → flagged" "$(step0)" flagged
mv ../logs-off/*.md $D/../

echo "== PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
