#!/usr/bin/env bash
# UserPromptSubmit hook — enforces the 100-word bullet-only response cap.
#
# Reads the hook JSON on stdin (Claude Code passes the user's prompt in
# `.prompt`). If the prompt does NOT contain an elaborate-trigger, we emit
# a <system-reminder> onto stdout. Claude Code forwards this as additional
# context to the next model turn. If the prompt DOES contain a trigger,
# we emit a reminder granting permission to elaborate this turn only.
#
# Cap: 100 words. Bullet-point format mandatory.
# Elaborate triggers: elaborate, long version, detailed plan, deep dive,
#   draft the full thing, write the doc, full answer, expand.

set -euo pipefail

PROMPT="$(jq -r '.prompt // .user_prompt // ""' 2>/dev/null || true)"
PROMPT_LOWER="$(echo "$PROMPT" | tr '[:upper:]' '[:lower:]')"

# Regex of elaborate-triggers. Adjust this single source of truth if the
# vocabulary changes; CLAUDE.md + memory reference this same list.
TRIGGERS='elaborate|long version|detailed plan|deep dive|draft the full thing|write the doc|full answer|expand|give me the long|write the file|long form'

if echo "$PROMPT_LOWER" | grep -Eq "$TRIGGERS"; then
  cat <<'EOF'
<system-reminder>
RESPONSE LENGTH: user used an elaborate-trigger — long-form is allowed for THIS turn only. Still prefer structure (headings, bullets). Next turn reverts to the 100-word bullet cap.
</system-reminder>
EOF
else
  cat <<'EOF'
<system-reminder>
RESPONSE LENGTH RULE (HARD CAP): your next reply MUST be:
  1. ≤ 100 words total (exceptions: file writes, code diffs, persona synthesis — length driven by the work, not chat).
  2. Bullet-point format only. No prose paragraphs.
  3. End with the literal line: "Want an elaborative answer?"
If the answer cannot fit in 100 words, collapse to top-3 bullets + the offer. Do NOT elaborate unless the user uses a trigger (elaborate, long version, detailed plan, deep dive, draft the full thing, write the doc, full answer, expand).
</system-reminder>
EOF
fi

exit 0
