#!/usr/bin/env bash

set -uo pipefail

framework_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
failure_count=0
personas=(orchestrator architect-planner implementer reviewer verifier releaser goal-setter marketer)

pass() {
  printf 'PASS  %s\n' "$1"
}

fail() {
  printf 'FAIL  %s\n' "$1" >&2
  failure_count=$((failure_count + 1))
}

require_file() {
  local relative_path="$1"
  if [[ -f "$framework_root/$relative_path" ]]; then
    pass "required file: $relative_path"
  else
    fail "missing required file: $relative_path"
  fi
}

compare_manifest() {
  local label="$1"
  local expected="$2"
  local actual="$3"
  if [[ "$actual" == "$expected" ]]; then
    pass "$label manifest"
  else
    fail "$label manifest drift"
    diff -u <(printf '%s\n' "$expected") <(printf '%s\n' "$actual") || true
  fi
}

required_files=(
  AGENTS.md
  MEMORY.md
  PERCEPTION.md
  .agents/skills/the-perfect-agent/SKILL.md
  .agents/skills/the-perfect-agent/LICENSE
  .agents/skills/the-perfect-agent/agents/openai.yaml
  .agents/skills/the-perfect-agent/references/commission-and-gates.md
  .agents/skills/the-perfect-agent/references/persona-routing.md
  .agents/skills/the-perfect-agent/references/review-and-learning.md
  memory/personas/README.md
  scripts/validate-agent-framework.sh
)

for persona in "${personas[@]}"; do
  required_files+=("PERSONA-$persona.md" "memory/personas/$persona.md")
done

for relative_path in "${required_files[@]}"; do
  require_file "$relative_path"
done

expected_personas="$(printf 'PERSONA-%s.md\n' "${personas[@]}" | LC_ALL=C sort)"
actual_personas="$(find "$framework_root" -maxdepth 1 -name 'PERSONA-*.md' -type f -exec basename {} \; | LC_ALL=C sort)"
compare_manifest "persona contract" "$expected_personas" "$actual_personas"

expected_memories="$(printf '%s\n' README.md "${personas[@]/%/.md}" | LC_ALL=C sort)"
actual_memories="$(find "$framework_root/memory/personas" -maxdepth 1 -name '*.md' -type f -exec basename {} \; | LC_ALL=C sort)"
compare_manifest "persona memory" "$expected_memories" "$actual_memories"

expected_skill_files="$(printf '%s\n' \
  SKILL.md \
  LICENSE \
  agents/openai.yaml \
  references/commission-and-gates.md \
  references/persona-routing.md \
  references/review-and-learning.md | LC_ALL=C sort)"
actual_skill_files="$(find "$framework_root/.agents/skills/the-perfect-agent" -type f -print | sed "s#^$framework_root/.agents/skills/the-perfect-agent/##" | LC_ALL=C sort)"
compare_manifest "the-perfect-agent skill" "$expected_skill_files" "$actual_skill_files"

if [[ ! -e "$framework_root/.agents/skills/full-workforce" ]]; then
  pass "legacy full-workforce skill path absent"
else
  fail "legacy repository skill path remains: .agents/skills/full-workforce"
fi

agents_file="$framework_root/AGENTS.md"
agents_terms=(
  'PERCEPTION.md'
  'MEMORY.md'
  'PERSONA-*.md'
  'memory/personas/*.md'
  '.agents/skills/the-perfect-agent/'
)
agents_routing_ok=1
for term in "${agents_terms[@]}"; do
  if ! grep -Fq "$term" "$agents_file"; then
    fail "AGENTS.md missing framework route: $term"
    agents_routing_ok=0
  fi
done
if ! grep -Eqi 'work solo by default' "$agents_file" \
  || ! grep -Eqi 'explicit workforce' "$agents_file" \
  || ! grep -Eqi 'cross-system' "$agents_file" \
  || ! grep -Eqi 'release-critical' "$agents_file" \
  || ! grep -Eqi 'high-consequence' "$agents_file" \
  || ! grep -Eqi 'independent acceptance' "$agents_file"; then
  fail "AGENTS.md workforce escalation route is incomplete"
  agents_routing_ok=0
fi
if ! grep -Eqi 'fresh reviewer' "$agents_file" \
  || ! grep -Eqi 'builder rationale' "$agents_file" \
  || ! grep -Eqi 'case-specific memory' "$agents_file"; then
  fail "AGENTS.md fresh-reviewer isolation is incomplete"
  agents_routing_ok=0
fi
if ! grep -Eqi 'global.*full-workforce.*requirement above remains controlling' "$agents_file" \
  || ! grep -Eqi 'never widen authority' "$agents_file" \
  || ! grep -Eqi 'phone delivery' "$agents_file" \
  || ! grep -Eqi 'distinct repository-governed states' "$agents_file"; then
  fail "AGENTS.md precedence or delivery boundary is incomplete"
  agents_routing_ok=0
fi
if [[ "$agents_routing_ok" == "1" ]]; then
  pass "AGENTS.md framework routing, precedence, and authority"
fi

goal_count="$(grep -c '^- Goal:' "$framework_root/PERCEPTION.md" || true)"
status_count="$(grep -c '^- Status:' "$framework_root/PERCEPTION.md" || true)"
refreshed_count="$(grep -c '^- Refreshed:' "$framework_root/PERCEPTION.md" || true)"
if [[ "$goal_count" == "1" && "$status_count" == "1" && "$refreshed_count" == "1" ]]; then
  pass "single perception goal, status, and refresh marker"
else
  fail "PERCEPTION.md must contain exactly one Goal, Status, and Refreshed field"
fi
if grep -Fq 'repository rules remain controlling' "$framework_root/PERCEPTION.md" \
  && grep -Fq 'external effects require separate authority' "$framework_root/PERCEPTION.md"; then
  pass "perception authority boundary"
else
  fail "PERCEPTION.md authority boundary is incomplete"
fi

durable_count="$(awk '/^## Durable memory/{inside=1; next} /^## Working memory/{inside=0} inside && /^\|/ && !/^\|---/ && !/^\| ID /{count++} END{print count+0}' "$framework_root/MEMORY.md")"
working_count="$(awk '/^## Working memory/{inside=1; next} /^## Maintenance/{inside=0} inside && /^\|/ && !/^\|---/ && !/^\| ID /{count++} END{print count+0}' "$framework_root/MEMORY.md")"
if (( durable_count <= 25 )); then
  pass "durable memory cap ($durable_count/25)"
else
  fail "durable memory exceeds 25 entries"
fi
if (( working_count <= 10 )); then
  pass "working memory cap ($working_count/10)"
else
  fail "working memory exceeds 10 entries"
fi
if (( durable_count == 0 )) && ! grep -Fq 'No active durable-memory entries.' "$framework_root/MEMORY.md"; then
  fail "empty durable memory is not declared"
elif (( durable_count > 0 )) && grep -Fq 'No active durable-memory entries.' "$framework_root/MEMORY.md"; then
  fail "durable memory declares empty state while entries exist"
else
  pass "durable memory state declaration"
fi
if (( working_count == 0 )) && ! grep -Fq 'No active working-memory entries.' "$framework_root/MEMORY.md"; then
  fail "empty working memory is not declared"
elif (( working_count > 0 )) && grep -Fq 'No active working-memory entries.' "$framework_root/MEMORY.md"; then
  fail "working memory declares empty state while entries exist"
else
  pass "working memory state declaration"
fi
memory_terms=('25 active' 'quarter' '10 active' '30 days' 'evidence-backed' 'confidence' 'Last verified' 'delete' 'Secrets' 'raw transcripts' 'hidden reasoning')
memory_contract_ok=1
for term in "${memory_terms[@]}"; do
  if ! grep -Fqi "$term" "$framework_root/MEMORY.md"; then
    fail "MEMORY.md missing contract term: $term"
    memory_contract_ok=0
  fi
done
if [[ "$memory_contract_ok" == "1" ]]; then
  pass "shared-memory evidence, retention, deletion, and privacy contract"
fi

persona_ok=1
for persona in "${personas[@]}"; do
  persona_file="$framework_root/PERSONA-$persona.md"
  memory_file="$framework_root/memory/personas/$persona.md"
  expected_link="Role memory: [memory/personas/$persona.md](memory/personas/$persona.md)"
  if ! grep -Fqx "$expected_link" "$persona_file"; then
    fail "$persona persona-to-memory link"
    persona_ok=0
  fi
  persona_count="$(awk '/^\|/ && !/^\|---/ && !/^\| ID /{count++} END{print count+0}' "$memory_file")"
  if (( persona_count > 10 )); then
    fail "$persona memory exceeds 10 entries"
    persona_ok=0
  elif (( persona_count == 0 )) && ! grep -Fq 'No active lessons.' "$memory_file"; then
    fail "$persona empty memory is not declared"
    persona_ok=0
  elif (( persona_count > 0 )) && grep -Fq 'No active lessons.' "$memory_file"; then
    fail "$persona memory declares empty state while entries exist"
    persona_ok=0
  fi
  if ! grep -Fq 'Limit: 10.' "$memory_file" || ! grep -Fq '90 days' "$memory_file"; then
    fail "$persona memory cap or inactivity review"
    persona_ok=0
  fi
done
if [[ "$persona_ok" == "1" ]]; then
  pass "persona links and lifecycle-aware memory bounds"
fi

memory_readme="$framework_root/memory/personas/README.md"
if grep -Fq 'task transcripts' "$memory_readme" \
  && grep -Fq 'case-specific private reasoning' "$memory_readme" \
  && grep -Fq 'Fresh reviewers' "$memory_readme" \
  && grep -Fq 'implementer memory' "$memory_readme"; then
  pass "persona-memory privacy and critic isolation"
else
  fail "persona-memory privacy or critic isolation is incomplete"
fi

skill_file="$framework_root/.agents/skills/the-perfect-agent/SKILL.md"
skill_frontmatter_name="$(sed -n '2p' "$skill_file")"
skill_frontmatter_description="$(sed -n '3p' "$skill_file")"
if [[ "$(sed -n '1p' "$skill_file")" == "---" \
  && "$skill_frontmatter_name" == "name: the-perfect-agent" \
  && "$skill_frontmatter_description" == description:\ * ]]; then
  pass "skill frontmatter"
else
  fail "invalid the-perfect-agent frontmatter"
fi
if grep -Fq 'allow_implicit_invocation: true' "$framework_root/.agents/skills/the-perfect-agent/agents/openai.yaml"; then
  pass "skill invocation policy"
else
  fail "skill invocation policy is missing or unexpected"
fi
skill_terms=('Stay solo' 'explicit' 'cross-system' 'release-critical' 'high-consequence' 'independent acceptance' 'fresh reviewer' 'Phone delivery' 'Recurring automations')
skill_contract_ok=1
for term in "${skill_terms[@]}"; do
  if ! grep -Fqi "$term" "$skill_file"; then
    fail "the-perfect-agent skill missing invariant: $term"
    skill_contract_ok=0
  fi
done
if [[ "$skill_contract_ok" == "1" ]]; then
  pass "skill activation, isolation, delivery, and automation boundaries"
fi

framework_paths=(
  "$framework_root/MEMORY.md"
  "$framework_root/PERCEPTION.md"
  "$framework_root"/PERSONA-*.md
  "$framework_root/memory/personas"
  "$framework_root/.agents/skills/the-perfect-agent"
)
if grep -REn --exclude='validate-agent-framework.sh' \
  '(/Users/|file://|BEGIN[[:space:]].*PRIVATE KEY|sk-[A-Za-z0-9]{16,}|AKIA[A-Z0-9]{16})' \
  "${framework_paths[@]}" >/dev/null; then
  fail "framework state contains a private-path or credential-shaped pattern"
else
  pass "framework privacy scan"
fi
if grep -REn --exclude='validate-agent-framework.sh' '(TODO|TBD|REPLACE_ME)' "${framework_paths[@]}" >/dev/null; then
  fail "framework contains an unfinished placeholder"
else
  pass "framework placeholder scan"
fi
if grep -REn '[[:blank:]]+$' "${framework_paths[@]}" >/dev/null; then
  fail "framework contains trailing whitespace"
else
  pass "framework whitespace hygiene"
fi

while IFS= read -r markdown_file; do
  markdown_dir="$(dirname "$markdown_file")"
  while IFS= read -r raw_target; do
    target="${raw_target#*(}"
    target="${target%)}"
    target="${target%%#*}"
    case "$target" in
      ''|http://*|https://*|mailto:*|\#*) continue ;;
    esac
    if [[ ! -e "$markdown_dir/$target" ]]; then
      fail "broken Markdown link: ${markdown_file#"$framework_root/"} -> $target"
    fi
  done < <(grep -Eo '\]\([^)]*\)' "$markdown_file" || true)
done < <(find "${framework_paths[@]}" -type f -name '*.md' -print)

if bash -n "$framework_root/scripts/validate-agent-framework.sh"; then
  pass "validator Bash syntax"
else
  fail "validator Bash syntax"
fi

if (( failure_count > 0 )); then
  printf '\n%d validation failure(s).\n' "$failure_count" >&2
  exit 1
fi

printf '\nRepository agent framework validation passed.\n'
