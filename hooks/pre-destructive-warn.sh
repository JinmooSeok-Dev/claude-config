#!/usr/bin/env bash
# PreToolUse hook (matcher: Bash): 파괴적 명령 패턴을 stderr로 경고
#
# Fail-safe: 항상 exit 0 — block 하지 않고 정보만 추가. 오작동해도 워크플로우 영향 없음
# CLAUDE.md "파괴적 명령 실행 전 확인" 규칙 보강

set -uo pipefail

# jq가 없으면 silent skip (휴대용성)
command -v jq >/dev/null 2>&1 || exit 0

input=$(cat)
cmd=$(echo "$input" | jq -r '.tool_input.command // empty' 2>/dev/null || true)

[ -z "$cmd" ] && exit 0

# 시스템 디렉토리 / 홈 / wildcard root 만 잡고 일반 path는 통과
if [[ "$cmd" =~ rm[[:space:]]+-[rRfd]+[[:space:]]+(/|~|\$HOME)([[:space:]]|$) ]] \
   || [[ "$cmd" =~ rm[[:space:]]+-[rRfd]+[[:space:]]+(/usr|/etc|/var|/bin|/sbin|/lib|/boot|/root|/home)([[:space:]/]|$) ]] \
   || [[ "$cmd" =~ rm[[:space:]]+-[rRfd]+[[:space:]]+/\* ]]; then
  echo "DANGER: rm against system / home / root wildcard" >&2
fi

if [[ "$cmd" =~ (kubectl|oc)[[:space:]]+delete ]] \
   && [[ "$cmd" =~ (--all|namespace[[:space:]]|-n[[:space:]]+kube-system) ]]; then
  echo "WARN: cluster-wide or system namespace delete" >&2
fi

if [[ "$cmd" =~ git[[:space:]]+push.*(--force|[[:space:]]-f([[:space:]]|$)) ]]; then
  echo "WARN: force push detected" >&2
fi

case "$cmd" in
  *"git reset --hard"*|*"git clean -fd"*|*"git clean -ffd"*|*"git checkout -- ."*)
    echo "WARN: destructive git command (irreversible)" >&2 ;;
  *"terraform destroy"*|*"terraform apply -auto-approve"*)
    echo "WARN: terraform destructive command" >&2 ;;
  *"DROP TABLE"*|*"DROP DATABASE"*|*"TRUNCATE TABLE"*)
    echo "WARN: destructive SQL detected" >&2 ;;
esac

# dd to block device
if [[ "$cmd" =~ dd[[:space:]].*of=/dev/(sd|nvme|vd|xvd|hd) ]]; then
  echo "DANGER: dd to block device — irreversible" >&2
fi

exit 0
