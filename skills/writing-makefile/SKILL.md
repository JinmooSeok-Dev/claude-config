---
name: writing-makefile
description: Makefile을 작성·리뷰한다. SHELL := bash + .SHELLFLAGS pipefail, .PHONY 강제, help 자동 생성, kubebuilder 관습(manifests/generate/test), 도구 자동 설치 패턴, 탭/스페이스/시그널 함정을 가이드한다. 사용자가 "Makefile", "make target", "make help", "kubebuilder make"를 언급할 때 사용한다.
---

# Writing Makefile

Makefile 작성 표준 + kubebuilder/operator 관습.

## 1. 헤더·기본
```make
SHELL := bash
.SHELLFLAGS := -euo pipefail -c
.DEFAULT_GOAL := help
.ONESHELL:                # recipe 한 블록을 한 shell 에서 실행 (선택)
MAKEFLAGS += --warn-undefined-variables --no-builtin-rules

# 절대경로 / 도구 경로
ROOT_DIR := $(abspath $(dir $(firstword $(MAKEFILE_LIST))))
BIN_DIR  := $(ROOT_DIR)/bin
```

`SHELL := bash` + `.SHELLFLAGS` 가 핵심 — 기본 sh 로 실행되면 `pipefail` 등 사용 불가.

## 2. .PHONY 강제
파일을 만들지 않는 모든 target 에 `.PHONY` 명시:
```make
.PHONY: build test lint clean help
```
누락 시 동명 파일/디렉토리 존재 → target 실행 안 됨.

## 3. Help 자동 생성 (강력 권장)
```make
help:  ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?##' $(MAKEFILE_LIST) | \
	  awk 'BEGIN{FS=":.*?##"} {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

build:  ## Build the binary
	go build ./cmd/app
```
→ `make` (인자 없이) → 도움말 출력

## 4. 변수
- 즉시 평가 (`:=`) vs 지연 평가 (`=`) — 일반적으로 `:=` 안전
- 문자열 비교: `ifeq ($(VAR),value)` (빈 값 주의 — `ifeq ($(strip $(VAR)),)`)
- 외부 명령 캡처: `VERSION := $(shell git describe --tags --always)` (한 번만 평가됨)

## 5. 도구 자동 설치 (kubebuilder 관습)
```make
GOLANGCI_LINT := $(BIN_DIR)/golangci-lint
$(GOLANGCI_LINT):
	GOBIN=$(BIN_DIR) go install github.com/golangci/golangci-lint/cmd/golangci-lint@v1.59.0

lint: $(GOLANGCI_LINT)  ## Run linter
	$(GOLANGCI_LINT) run --timeout 5m
```

## 6. kubebuilder Operator 관습
```make
.PHONY: manifests generate fmt vet test build

manifests: $(CONTROLLER_GEN)  ## Generate CRD/RBAC
	$(CONTROLLER_GEN) rbac:roleName=manager-role crd webhook \
	  paths="./..." output:crd:artifacts:config=config/crd/bases

generate: $(CONTROLLER_GEN)  ## Generate deepcopy
	$(CONTROLLER_GEN) object:headerFile="hack/boilerplate.go.txt" paths="./..."

fmt:  ## Run go fmt
	go fmt ./...

vet:  ## Run go vet
	go vet ./...

test: manifests generate fmt vet  ## Run tests
	KUBEBUILDER_ASSETS="$(shell setup-envtest use $(ENVTEST_K8S_VERSION) -p path)" \
	  go test ./... -coverprofile cover.out

build: manifests generate fmt vet  ## Build manager binary
	go build -o bin/manager cmd/main.go
```

## 7. 흔한 함정
- recipe 안 `cd dir; make ...` → exit code 손실. `cd dir && make ...` 사용
- 탭 vs 스페이스 — recipe 들여쓰기는 **반드시 탭 1개**
- `$(...)` vs `$$(...)` — 전자는 make 변수, 후자는 shell 명령 치환
- `@` prefix (echo 안 함) 와 `-` prefix (실패 무시) 남용 금지 — 디버깅 어려워짐
- `.PHONY` 누락 — 동명 파일/디렉토리 존재 시 target 실행 안 됨
- `MAKEFLAGS += --warn-undefined-variables` 안 쓰면 typo 방치

## 8. 디버깅
- `make -n <target>` (dry-run, 실행될 명령 출력)
- `make --debug=basic` (target 평가 순서)
- `make -p | less` (모든 변수/규칙)

## 9. CI 와의 관계
- CI 는 Makefile target 을 호출 — 로컬과 CI 가 같은 진입점
- target 추가 시 `.github/workflows/*.yml` 의 `make <target>` 호출과 동기화 (drift 방지)
- 사용자 정책: scripts 와 Makefile 모두 **로컬 단독 실행 가능** 해야 함 (`organizing-workflow-scripts` skill)

## 10. 작성 체크리스트
- [ ] `SHELL := bash` + `.SHELLFLAGS := -euo pipefail -c`
- [ ] `.DEFAULT_GOAL := help` + `help:` target
- [ ] 모든 phony target 에 `.PHONY:`
- [ ] target 마다 `## 설명` 주석 (help 자동 생성용)
- [ ] 도구는 `BIN_DIR` 에 자동 설치
- [ ] CI 가 호출하는 target 과 sync

## 관련
- `coding-shell.md` rule (recipe 안 shell 코드)
- `designing-workflow` skill (CI 가 make 호출)
- `bootstrapping-project` skill (새 프로젝트 Makefile 스켈레톤)
