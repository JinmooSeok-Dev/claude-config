---
name: reviewing-pr
description: PR/변경 사항을 체계적으로 리뷰한다. bug → security → performance → convention → readability 순으로 검토. 도메인별 특화 점검(operator의 reconcile 멱등성/status race, python의 blocking IO/mutable default, go의 goroutine leak/context propagation). code-reviewer subagent 와 결합 가능. 사용자가 "PR 리뷰", "리뷰해줘", "이 변경 검토", "코드 리뷰"를 언급할 때 사용한다.
---

# Reviewing PR

체계적 코드 리뷰. 우선순위: **bug > security > performance > convention > readability**.

## 1. 입력
- 변경 내용: `git diff main...HEAD`, `git diff --staged`, GitHub PR 링크
- 컨텍스트: 변경 의도 (PR 본문 또는 사용자 설명)

## 2. 우선순위별 체크 (P0 → P4)

### P0 — Bug / Logic Error
- 잘못된 조건 (`==` vs `===`, `<=` vs `<`)
- off-by-one
- null / undefined / 빈 컬렉션 처리
- async race (Go: goroutine leak, Python: forgotten await)
- 자원 누출 (close/defer 누락)
- 의도와 다른 시그니처 사용 (예: `errors.Is` vs `==`)

### P1 — Security
- secret hard-coding
- injection (SQL, shell, YAML, K8s manifest)
- RBAC 과도 (cluster-admin 남발)
- 인증/인가 우회
- 외부 입력 → 직접 명령 실행
- 의존성 취약점 (deprecated package, unmaintained)

### P2 — Performance
- N+1 쿼리 / 불필요한 반복
- 메모리 누수 (Go: 무한 채널, Python: circular reference)
- 핫 패스에서 큰 객체 복사
- 불필요한 로깅 (debug log in hot path)
- cache 미사용 (반복 연산)
- DB connection pool 미사용

### P3 — Convention
- `~/.claude/rules/coding-*.md` (path-scoped 자동 로드) 위반
- 프로젝트 고유 컨벤션 (`<repo>/CLAUDE.md`)
- naming, indent, import order
- comment 가 코드와 sync 안 됨

### P4 — Readability / Maintainability
- 함수가 너무 길다 (50줄+)
- 중첩 너무 깊음 (4+ levels)
- 매직 넘버
- 의도 불명확한 변수명
- 테스트 누락 / coverage 회귀

## 3. 도메인별 특화 — 자주 놓치는 함정
### Go (operator)
- **Reconcile 멱등성**: 같은 input 으로 여러 번 호출해도 같은 결과
- **Status race**: `client.Status().Update` 시 `RetryOnConflict` 적용?
- **Owner reference**: 자식 리소스에 owner ref 설정?
- **Finalizer**: 삭제 시 cleanup 후 finalizer 제거?
- **Context propagation**: child goroutine 에 ctx 전달?
- **Goroutine leak**: 종료 조건 / select { case <-ctx.Done(): }

### Python (일반 + ML)
- **Mutable default arg**: `def f(x=[]):` (대안: `x=None` + 함수 내부에서 `if x is None: x = []`)
- **Blocking IO in async**: `requests.get` 대신 `httpx.AsyncClient`
- **Forgotten await**: `await` 누락 시 coroutine object 자체 반환
- **`==` vs `is`**: 객체 동일성 vs 값 동일성
- **`__init__.py` 의 무거운 import**: import 시간 폭증
- **GPU**: `torch.no_grad()` 누락 (inference 시), tensor device 불일치

### Rust
- **Cloning hot path**: `.clone()` 비용 측정
- **Lifetime**: 'static 강요 vs 명시
- **`Result` vs `Option`**: panic 시점

### Shell
- `set -euo pipefail` 누락
- 변수 미인용 (`$x` → `"${x}"`)
- `eval` / backtick 사용

### YAML / K8s
- `imagePullPolicy: Always` + `latest` 태그
- resource requests/limits 누락
- securityContext 부재

### CI (GitHub Actions)
- SHA pinning 누락
- secret echo
- `${{ }}` injection
- shell 미명시

## 4. 변경 의도와의 정합성
- PR 본문이 "Why / What / How-to-verify / Rollback" 4섹션 갖췄는가?
- 변경이 실제로 의도한 문제를 해결하는가?
- scope creep 없나? (다른 cleanup 묶이면 분리 권장)
- 테스트가 변경을 cover 하는가?

## 5. code-reviewer subagent 활용
복잡한 PR 은 `code-reviewer` agent 호출 (격리된 컨텍스트, 객관적 검토):
```
Task(subagent_type=code-reviewer, prompt="...")
```

## 6. 출력 형식
```markdown
## PR Review

**전반**: 의도 명확. 테스트 부족.

### CRITICAL — 즉시 수정 (3건)
1. `pkg/controller/foo.go:142` — Reconcile 에서 status update 후 return 누락 → 같은 spec 두 번 처리
2. `web/handler.py:78` — user input 직접 SQL 삽입
3. `.github/workflows/ci.yml:45` — `${{ github.event.issue.title }}` 직접 echo

### WARNING (5건)
4. ...

### INFO / nit (3건)
9. ...

### 테스트 제안
- `Reconcile` 의 멱등성 테스트
- ...
```

## 7. 흔한 함정 — 리뷰어 자신
- ❌ style nitpick 만 가득 — 진짜 버그 놓침
- ❌ "approve" 만 누름 (리뷰 의무 회피)
- ❌ 구두 의견 없음 — 왜 거부인지 모름
- ❌ 큰 PR 을 30분 만에 review — 깊이 부족

## 8. 리뷰 후 — 작성자 응답
- 모든 코멘트에 응답 (수정 / wontfix + 이유)
- 수정 commit 은 "Address review: ..." 메시지

## 관련 자산
- `code-reviewer` agent (격리 컨텍스트)
- `coding-*.md` rules (자동 로드, 컨벤션)
- `auditing-workflow` skill (CI 영역)
- `writing-pr-description` skill (작성자 측)
