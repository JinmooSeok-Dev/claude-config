#!/usr/bin/env bash
# SessionStart hook: 프로젝트 루트의 STATUS.md를 자동으로 context에 주입
#
# Fail-safe: STATUS.md가 없으면 즉시 exit 0 — 사용자 작업에 영향 없음
# CLAUDE.md "STATUS.md 있으면 작업 시작 시 반드시 읽고 반영" 규칙을 자동화

set -euo pipefail

[ -f "STATUS.md" ] || exit 0

echo "## Project STATUS (auto-loaded from STATUS.md)"
head -200 STATUS.md
