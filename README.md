# Claude Code Global Configuration

Claude Code CLI의 전역 설정 저장소. `~/.claude/`에 배치하여 모든 프로젝트에 공통 적용한다.

## 설치

```bash
# 기존 ~/.claude/ 백업 (있으면)
mv ~/.claude ~/.claude.bak

# clone
git clone https://github.com/JinmooSeok-Dev/claude-config.git ~/.claude

# 개인 설정 복원 (필요 시)
cp ~/.claude.bak/settings.local.json ~/.claude/
cp ~/.claude.bak/.credentials.json ~/.claude/
```

> `settings.local.json`, `.credentials.json` 등 개인 파일은 `.gitignore`로 제외되어 있다.

## 디렉토리 구조

```
~/.claude/
├── CLAUDE.md                  # 전역 지침 (모든 세션에 로드)
├── settings.json              # 전역 permission (allow/deny)
├── rules/                     # path-scoped 코딩/문서 규칙 (자동 로드)
├── commands/                  # 사용자 수동 호출 (/user:command-name)
├── skills/                    # Claude 자동 호출 (키워드 트리거)
├── agents/                    # 전문 subagent 정의
├── settings.local.json        # 개인 설정 (gitignored)
└── .credentials.json          # 인증 정보 (gitignored)
```

## 구성 요소

### CLAUDE.md — 전역 지침 (~70줄)

모든 세션 시작 시 로드되는 핵심 규칙:
- 언어/커뮤니케이션 (한국어 응답, 기술 용어 원어 유지)
- 코딩 스타일 (indent, 간결함 원칙)
- Reasoning Transparency (사고 과정 명시)
- Working Transparency (작업 과정 생략 금지)
- Accuracy (수치/근거 정확성, 출처 필수)
- Git, Infra, 문서 작성 원칙

### rules/ — Path-scoped 코딩 규칙

해당 파일을 다룰 때만 자동 로드되어 context를 절약한다:

| 파일 | 적용 대상 | 핵심 내용 |
|------|----------|----------|
| `coding-yaml-k8s.md` | `*.yaml`, `*.yml` | K8s label, resource, probe, KServe, Kustomize |
| `coding-shell.md` | `*.sh`, `*.bash` | `set -euo pipefail`, sudo 금지, ShellCheck |
| `coding-github-actions.md` | `.github/workflows/**` | `shell: bash` 필수, SHA pinning, sh vs bash 문제 |
| `coding-terraform.md` | `*.tf`, `*.tfvars` | snake_case, remote state, `for_each > count` |
| `coding-ansible.md` | `playbooks/**`, `roles/**` | FQCN 필수, vault_ prefix, 멱등성 |
| `documentation.md` | 항상 로드 | Top-down 구조, 시나리오 기반, 출처 필수 |

### commands/ — 사용자 수동 호출

`/user:command-name`으로 호출한다:

| Command | 호출 | 용도 |
|---------|------|------|
| `review.md` | `/user:review` | git diff 기반 코드 리뷰 |
| `status.md` | `/user:status` | git + STATUS.md 종합 보고 |
| `analyze-oss.md` | `/user:analyze-oss` | 오픈소스 코드베이스 분석 |
| `debug.md` | `/user:debug` | 체계적 디버깅 프로세스 |
| `implement.md` | `/user:implement` | TDD 기반 기능 구현 |
| `logging-work.md` | `/user:logging-work` | WORKLOG.md에 작업 완료 보고서 기록 |
| `til.md` | `/user:til` | TIL.md에 발견/조사 내용 간결히 기록 |
| `sync-docs.md` | `/user:sync-docs` | 코드 변경 시 관련 문서 업데이트 확인/제안 |

### skills/ — Claude 자동 호출 (13개)

사용자가 관련 키워드를 언급하면 Claude가 자동으로 적절한 프레임워크를 로드한다:

| Skill | 트리거 키워드 |
|-------|-------------|
| `analyzing-probability` | 확률, 통계, 분포, 베이즈 |
| `deep-analyzing` | 분석해줘, 깊이 파봐, 트레이드오프 |
| `designing-architecture` | 설계, 아키텍처, 시스템 디자인 |
| `explaining-concept` | 설명해줘, 이게 뭐야, 차이가 뭐야 |
| `exploring-new-field` | 배우고 싶어, 공부, 입문 |
| `ideating-project` | 아이디어, 뭘 만들면, 가능할까 |
| `optimizing-system` | 최적화, 튜닝, 빠르게 |
| `profiling-performance` | 프로파일링, 병목, latency |
| `researching-topic` | 조사해줘, 비교해줘, 서베이 |
| `solving-calculus` | 미분, 적분, gradient |
| `solving-linear-algebra` | 행렬, SVD, 고유값 |
| `verifying-document-facts` | 팩트체크, 문서 검증 |
| `verifying-simulator-numerics` | 수치 검증, 소스코드 확인 |

### agents/ — 전문 Subagent (2개)

독립된 context window에서 실행되는 전문 agent:

| Agent | 모델 | 도구 | 용도 |
|-------|------|------|------|
| `code-reviewer.md` | Sonnet | Read, Grep, Glob | 읽기 전용 코드 리뷰 |
| `source-analyst.md` | Opus | Read, Grep, Glob, Bash, WebSearch | 오픈소스 코드베이스 분석 |

### settings.json — Permission

```
allow: 읽기 도구, git/kubectl/oc 조회, lint 도구 (자동 승인)
deny:  .env*, vault.yml, *secret* (읽기 차단)
```

## 설계 원칙

이 설정은 다음 best practices를 기반으로 구성했다:

1. **CLAUDE.md는 100줄 이하** (Boris Cherny 원칙) — 핵심만 유지
2. **Path-scoped rules** (Eduardo Ordax 원칙) — 해당 파일 작업 시에만 로드
3. **Skills vs Commands 분리** — 자동 호출 vs 수동 호출 명확히 구분
4. **Subagent context 격리** — 복잡한 분석/리뷰를 독립 context에서 수행
5. **Permission deny 우선** — 민감 파일 차단, 안전한 도구만 자동 승인
