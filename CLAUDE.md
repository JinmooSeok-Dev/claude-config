# Global Configuration

## Language & Communication
- 한국어로 응답한다
- 반말을 사용하지 않는다 (존댓말 사용: "~합니다", "~습니다")
- 코드 주석은 한국어 또는 영어 (프로젝트 기존 컨벤션을 따른다)
- 기술 용어는 원어 그대로 사용한다 (예: "컨테이너"가 아닌 "container")

## Coding Style
- Indent: 2 spaces (모든 언어 공통, 단 Python은 4 spaces/PEP8, Go는 gofmt)
- 불필요한 주석, docstring, type annotation을 추가하지 않는다
- 변경하지 않은 코드에 손대지 않는다
- 간결하게: 3줄 반복이 섣부른 추상화보다 낫다
- 언어별 상세 규칙은 `~/.claude/rules/coding-*.md` 참조 (path-scoped 자동 로드)

## Tech Stack Context
주로 다루는 기술 영역:
- **ML/AI**: vLLM, PyTorch, CUDA, Triton, 분산 추론, 모델 최적화
- **Cloud/Infra**: Kubernetes, OpenShift, Terraform, Docker, Go operators, Ansible
- **Open Source**: PyTorch, vLLM, FlashAttention, RDMA, network-operator 내부 분석
- **Systems**: Linux kernel modules, C/C++, Python C extensions
- **CI/CD**: GitHub Actions, Shell scripting, 자동화 파이프라인
- **기타**: 수학, 과학, 경제, 양자 컴퓨팅 등 다양한 분야 학습

## Tech Baseline & Workflow (프로젝트별 override 가능)
- Tech: Go ≥ 1.21, Python 3.10–3.13, Rust stable, Node 18+ (프로젝트 `CLAUDE.md` 의 "Override" 섹션에 예외 명시)
- Test: 도메인별 표준(go test/ginkgo, pytest, shellcheck+bats, ansible-lint+molecule), **통합 > mock**
- Branch: `feat/`/`fix/`/`chore/`/`docs/<topic>` + Conventional Commits, llm-d 계열은 DCO signoff
- PR 본문: Why / What changed / How to verify / Rollback (상세는 `/user:pr` command)
- 문서: Reference(Top-down: Problem→Scenario→Design→Architecture) vs Operational(Task-first) vs Archive (상세는 `rules/documentation.md`)

## Git
- 커밋 메시지를 요청 없이 생성하지 않는다
- force push, reset --hard 등 파괴적 명령 실행 전 반드시 확인한다

## Reasoning Transparency (과정 표시)
모든 분석, 추론, 문제 풀이에서 사고 과정을 명시적으로 보여준다:
1. **방법론 선언**: 어떤 접근법을 쓸 것인지, 왜 선택했는지
2. **단계별 과정**: 중간 결과를 생략하지 않는다
3. **판단 근거**: "A이기 때문에 B라고 판단한다" 형태
4. **불확실성 표시**: `[불확실]` 또는 `[추정]`으로 표기
5. **분기점 설명**: 여러 경로가 가능할 때 왜 이 경로를 선택했는지

## 작업 과정 공유 (Working Transparency)
사용자와 함께 작업하는 것이므로, 수행하는 과정을 **생략하지 않고** 보여준다:
- 실행하는 **명령어와 그 목적**을 사전에 설명한다: "X를 확인하기 위해 Y 명령을 실행한다"
- 명령어 실행 결과를 **요약하지 않고 핵심 출력을 그대로** 보여준다
- 디버깅/분석 시 **탐색 경로를 모두 노출**한다 — 어떤 파일을 읽었고, 어떤 검색을 했고, 무엇을 발견했는지
- 여러 명령을 연속 실행할 때 각 명령의 **결과와 그로부터 얻은 판단**을 매번 표시한다
- "확인했습니다", "분석했습니다" 같은 **요약 한 줄로 뭉뚱그리지 않는다** — 무엇을 확인했고 어떤 결과였는지 보여준다
- 긴 출력이라도 핵심 부분은 생략 없이 인용하고, 비핵심 부분만 `(... N줄 생략)` 처리한다

## Accuracy (수치 및 근거 정확성)
- 성능 수치, 벤치마크 결과에는 반드시 **출처 링크** 첨부
- 수치는 가능하면 **2개 이상 출처로 교차 검증**
- 측정 조건(HW/SW 버전, 설정값, 시점) 명시
- "X배 빠르다" 주장에는 baseline 명시
- 확실하지 않은 수치는 `[불확실]` `[추정]` 표기

## Documentation (문서 작성)
- 상세 규칙은 `~/.claude/rules/documentation.md` 참조
- 핵심: Top-down 구조, 정량적 Problem Statement, User Scenario 기반, 출처 필수

### Doc-PR fact verification 컨벤션 (round-N+1 핑퐁 방지)

문서 PR 작성 시 다음 4가지를 **doc 단어를 코드와 1:1 매칭** 하는 식으로 검증한다. 검증 안 거치면 같은 류 코멘트가 round-2 / round-3 으로 반복된다 (실측: rebel-jinmoo/network-operator PR #38·#39·#40 의 round-1 코멘트 17개 중 11개가 이 컨벤션 위반).

1. **컴포넌트 / 함수 / 변수 이름은 코드 의 정의 형 (definition form)**:
   - reconciler 등 등록명 (`Name() string` 반환값 또는 spec field name) — 파일명 대신 등록명 사용. 예: `secondaryNetwork`/`moduleConfig` (✓) vs `secondary_network.go` 의 file path 를 prose 에서 인용 (✗).
   - spec / CR field 경로는 **루트부터 경로 전체** 인용. 예: `spec.nodeFeatureDiscovery.deploy: Never` (✓) vs `nfd.deploy: Never` (shorthand, ✗).
   - field 가 string 인지 struct 인지 명시 — `spec.X.image` 가 `ImageSpec` 객체면 어떤 inner field 를 채워야 하는지까지.

2. **에러 메시지 / 동작 묘사는 코드 verbatim**:
   - 에러 문구를 doc 에 인용할 때 `fmt.Errorf` / `errors.New` / `panic` 의 실제 인자를 그대로. 추측 금지. 예: `"NAD probe failed: <err>"` (✓) vs `"Multus required"` (잘못된 추측, ✗).
   - 컴포넌트가 "X 를 한다" / "Y 를 자동으로 한다" 류 묘사는 해당 코드 path 를 직접 본 후만 작성.

3. **cross-PR forward reference 금지 (또는 명시적 마커)**:
   - 같은 시리즈의 다른 PR 의 helper / file / 함수를 main 의 현재 상태처럼 묘사하지 않는다.
   - 부득이하면 `(planned, see PR #N)` 또는 `(landing in a parallel PR)` 명시. main HEAD 기준 사실만 단정.

4. **단정 (assertion) 은 즉시 검증 가능한 형태**:
   - "X 라서 Y 가 동작한다" 의 X 부분은 `grep` / `cat` / `dnf info` 로 1분 안에 확인 가능한 사실만. 추정은 `[불확실]` 또는 `[추정]` 표기.
   - Dockerfile 에 패키지 인용 시 entitlement-free base image 에서 실제로 install 되는지 `docker run --rm <base> dnf info <pkg>` 로 사전 확인.

위반 의심이면 `verifying-document-facts` skill 호출. 이미 PR open 후 round-1 review 받았다면 `/copilot-fix` 의 5.5 self-review pass 가 자동으로 catch 한다.

## Work Logging
- `/logging-work` 스킬로 수행, 기록 시점은 사용자가 결정
- 프로젝트당 `WORKLOG.md` 하나만 유지

## Infrastructure & Configuration Changes
- `STATUS.md` 있으면 작업 시작/완료 시 반드시 읽고 반영
- 설정 변경은 설정 파일을 통해 수행 (런타임 임시 패치 금지)
- 디버깅 목적 임시 수정 성공 시, 설정 파일 반영 여부를 사용자에게 확인
- 변경 이력(이전 값, 실패 원인, 새 값)을 커밋 메시지에 기록

## General Rules
- 파일을 읽기 전에 수정을 제안하지 않는다
- 요청받은 범위만 수행한다. over-engineering 금지
- 확실하지 않으면 먼저 질문한다
