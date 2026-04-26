---
paths:
  - "**/Makefile"
  - "**/*.mk"
---

# Makefile 코딩 규칙

## 헤더·기본
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

## .PHONY
- 파일을 만들지 않는 모든 target 에 `.PHONY` 명시:
  ```make
  .PHONY: build test lint clean help
  ```
- 그렇지 않으면 동명 파일 존재 시 target 이 실행되지 않음

## help 자동 생성
```make
help:  ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?##' $(MAKEFILE_LIST) | \
	  awk 'BEGIN{FS=":.*?##"} {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

build:  ## Build the binary
	go build ./cmd/app
```
→ `make` (인자 없이) → 도움말 출력

## 변수
- 즉시 평가 (`:=`) vs 지연 평가 (`=`) 구분 — 일반적으로 `:=` 안전
- 문자열 비교: `ifeq ($(VAR),value)` (빈 값 주의 — `ifeq ($(strip $(VAR)),)`)
- 외부 명령 캡처: `VERSION := $(shell git describe --tags --always)` (한 번만 평가됨)

## 자주 쓰는 패턴
```make
# 도구 자동 설치 (kubebuilder 관습)
GOLANGCI_LINT := $(BIN_DIR)/golangci-lint
$(GOLANGCI_LINT):
	GOBIN=$(BIN_DIR) go install github.com/golangci/golangci-lint/cmd/golangci-lint@v1.59.0

lint: $(GOLANGCI_LINT)  ## Run linter
	$(GOLANGCI_LINT) run --timeout 5m
```

## kubebuilder Makefile 관습
- `manifests`: CRD/RBAC 재생성 (`controller-gen`)
- `generate`: deepcopy 등 boilerplate
- `manifests generate fmt vet` 를 `build` 의 prerequisite 로
- `test`: `envtest` setup 후 `go test`

## 흔한 함정
- recipe 안에서 `cd dir; make ...` → exit code 손실. `cd dir && make ...` 사용
- 탭 vs 스페이스 — recipe 들여쓰기는 **반드시 탭 1개**
- `$(...)` vs `$$(...)` — 전자는 make 변수, 후자는 shell 명령 치환
- `@` prefix (echo 안 함) 와 `-` prefix (실패 무시) 남용 금지 — 디버깅 어려워짐
- `.PHONY` 누락 — 동명 디렉토리/파일 존재 시 실행 안 됨

## 디버깅
- `make -n <target>` (dry-run, 실행될 명령 출력)
- `make --debug=basic` (target 평가 순서)
- `make -p | less` (모든 변수/규칙)

## CI 와의 관계
- CI 는 Makefile target 을 호출 — 로컬과 CI 가 같은 진입점
- target 추가 시 `.github/workflows/*.yml` 의 `make <target>` 호출과 동기화
