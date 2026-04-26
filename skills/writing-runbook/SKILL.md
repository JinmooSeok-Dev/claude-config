---
name: writing-runbook
description: 운영 절차서(runbook)를 작성한다. 정상 동작 / 자주 발생하는 실패와 대응 / 수동 트리거 / 에스컬레이션. CI 워크플로우 도메인은 자동 분기(.github/runbooks/<name>.md). K8s/배포/장애 대응 모두 동일 구조. 사용자가 "runbook", "운영 절차", "장애 대응 문서", "오퍼레이션 문서"를 언급할 때 사용한다.
---

# Writing Runbook

운영 절차서. 도메인 자동 분기:
- **CI 워크플로우** → `.github/runbooks/<workflow-name>.md`
- **K8s 워크로드** → `docs/runbooks/<service>.md`
- **인프라** → `docs/runbooks/<infra>.md`

## 1. 메타데이터 + 헤더
```markdown
# Runbook: <대상>

> **검토일**: YYYY-MM-DD · **소유자**: @<handle> / <team>
> **에스컬레이션**: 1차 @<handle>, 2차 #<channel>
> **관련 워크로드/워크플로우**: [<link>](<path>)
```

## 2. 표준 구조
```markdown
## 정상 동작
- 트리거 / 빈도 / 소요 시간
- 산출물 / 보존 기간
- 알림 채널

## 자주 발생하는 실패와 대응
### 1. <증상 한 줄>
**증상**: 관찰되는 현상 (에러 메시지, status, log 패턴)
**확인**:
\`\`\`bash
gh run view <id> --log-failed | grep ERROR
kubectl describe pod <name>
\`\`\`
**대응**:
1. ...
2. ...
**예방** (선택): ...

### 2. ...

## 수동 트리거 (재실행/긴급 실행)
\`\`\`bash
gh workflow run <name>.yml --ref main
# or
kubectl rollout restart deploy/<name>
\`\`\`

## 에스컬레이션
- 1차: @<handle>
- 2차: #<channel> 또는 @<team>
- 외부 (vendor): ...

## 관련 문서
- 설계: [docs/<name>-design.md](../<name>-design.md)
- 워크플로우: [.github/workflows/<name>.yml](../workflows/<name>.yml)
- 모니터링: [grafana url]
```

## 3. 정상 동작 섹션
- **트리거**: cron / on push / 수동 / scale event
- **빈도**: 매일 18:00 UTC / 매 push / 임의
- **소요 시간**: 평균 N분 (정상 범위)
- **산출물**: artifact 이름, 보존 기간, 위치
- **알림**: 성공 (조용히) / 실패 (Slack #ci-alerts 자동)

## 4. 실패 대응 — 형식 일관성
각 증상마다 동일 4-필드:
1. **증상** (관찰자가 보는 것)
2. **확인** (진단 명령)
3. **대응** (단계적 조치)
4. **예방** (선택, 향후 발생 방지)

## 5. CI 워크플로우 runbook 특화
```markdown
## 자주 발생하는 실패와 대응

### 1. self-hosted runner offline
**증상**: workflow queue 에 "Waiting for a runner" + 30분 무진행
**확인**:
\`\`\`bash
gh api repos/<owner>/<repo>/actions/runners | jq '.runners[] | {name, status, busy}'
ssh runner-host 'systemctl status actions.runner.<name>'
\`\`\`
**대응**:
- 단순 재시작: \`ssh runner-host 'systemctl restart actions.runner.<name>'\`
- 노드 자체 down: 인프라팀 호출 (#infra-oncall)
- 임시: 다른 runner 라벨로 매뉴얼 dispatch

### 2. HuggingFace 401 / rate limit
...
```

## 6. K8s 워크로드 runbook 특화
```markdown
## 자주 발생하는 실패와 대응

### 1. Pod CrashLoopBackOff
**증상**: \`kubectl get pod\` 가 \`CrashLoopBackOff\`
**확인**:
\`\`\`bash
kubectl describe pod <name>
kubectl logs <name> --previous
kubectl get events --sort-by='.lastTimestamp' | tail -20
\`\`\`
**대응**:
- exit code 137 (OOMKilled) → memory request/limit 증가
- ImagePullBackOff → image pull secret / registry 권한
- LivenessProbe 실패 → probe 설정 조정
```

## 7. 명령 안전 — runbook 내 명령
- placeholder 표시 명확 (`<namespace>`, `<pod-name>`)
- destructive 명령은 "확인 후 실행" 명시 (`kubectl delete pod ... --grace-period=0` 등)
- 긴급 stop 절차는 별도 강조 박스
- rollback 절차 항상 포함

## 8. 검증
- runbook 의 명령이 실제로 동작하는가? (drill 권장)
- 에스컬레이션 연락처가 최신인가?
- 관련 문서 링크 살아있는가?
- 새 실패 패턴 발견 시 즉시 추가 (incident 회고 후)

## 9. drill (정기 점검)
- 분기마다: runbook 의 첫 3개 시나리오를 drill (의도적 실패 + 복구)
- 개월마다: 에스컬레이션 채널 응답 시간 검증
- 새 팀원 onboarding 시: 함께 walkthrough

## 10. 흔한 함정
- ❌ 한 번 작성 후 방치 (현실과 괴리)
- ❌ 너무 일반적 ("어떻게든 고치세요") — 구체 명령 없음
- ❌ 에스컬레이션 없음 (혼자 해결 못 하면 갇힘)
- ❌ rollback 절차 부재 (사고 키움)

## 관련 자산
- `documentation.md` rule (자동 로드)
- `writing-operational-doc` skill (가이드/트러블슈팅)
- `documenting-workflow` skill (CI 도메인 — `.github/runbooks/`)
- `triaging-incident` skill (실시간 장애 대응)
