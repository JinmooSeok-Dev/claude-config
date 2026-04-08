프로젝트 현재 상태를 종합 보고해줘:

!`git status --short 2>/dev/null`

!`git log --oneline -5 2>/dev/null`

!`cat STATUS.md 2>/dev/null || echo "STATUS.md 없음"`

보고 형식:
1. Git 상태 요약 (미커밋 변경, 최근 커밋)
2. STATUS.md 핵심 내용 (있으면)
3. 다음 작업 제안
