#!/usr/bin/env bash
# StormRaven daily health check. Exit 42 = wake agent with findings. Exit 0 = nothing to do.
set -uo pipefail
export GH_TOKEN=sentinel
OUT=""; flag(){ OUT="$OUT$1"$'\n'; }
WS=~/workspace
mkdir -p "$WS"
for repo in StormRaven-OS-Core- StormRaven-Alfheim-UI-; do
  dir="$WS/$repo"
  if [ ! -d "$dir/.git" ]; then
    git clone -q "https://github.com/faithjennings055-cmyk/$repo.git" "$dir" 2>/dev/null || { flag "[$repo] clone failed"; continue; }
  fi
  cd "$dir" || continue
  git fetch -q origin 2>/dev/null
  git checkout -q main 2>/dev/null || git checkout -q master 2>/dev/null
  git reset -q --hard "origin/$(git rev-parse --abbrev-ref HEAD)" 2>/dev/null
  prs=$(gh pr list --state open --json number,isDraft,mergeable,statusCheckRollup 2>/dev/null)
  echo "$prs" | jq -e '.[]|select(.isDraft==false and .mergeable=="MERGEABLE" and ([.statusCheckRollup[]?|select(.conclusion!=null and .conclusion!="SUCCESS" and .conclusion!="NEUTRAL")]|length==0))' >/dev/null 2>&1 \
    && flag "[$repo] green mergeable open PR(s) ready to auto-merge"
  echo "$prs" | jq -e '.[]|select([.statusCheckRollup[]?|select(.conclusion=="FAILURE")]|length>0)' >/dev/null 2>&1 \
    && flag "[$repo] open PR with FAILING CI"
done
cd "$WS/StormRaven-OS-Core-" 2>/dev/null && {
  python3 -m pytest tests/ -q >/tmp/sr-pytest.log 2>&1 || { flag "[Core] pytest FAILING on main:"; OUT="$OUT$(tail -15 /tmp/sr-pytest.log)"$'\n'; }
  flake8 . --count --select=E9,F63,F7,F82 >/tmp/sr-flake.log 2>&1 || { flag "[Core] flake8 critical errors:"; OUT="$OUT$(tail -15 /tmp/sr-flake.log)"$'\n'; }
}
[ -n "$OUT" ] && { echo "$OUT"; exit 42; }; exit 0
