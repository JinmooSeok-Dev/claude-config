$ARGUMENTS 현재 디렉토리(또는 인자 경로)의 정적 검사를 일괄 실행한다.

## 절차
1. **언어/프레임워크 자동 감지** (파일 확장자 / 매니페스트 기반):
   - `*.go`, `go.mod` → Go
   - `*.py`, `pyproject.toml` → Python
   - `*.rs`, `Cargo.toml` → Rust
   - `*.sh` → Shell
   - `*.tf` → Terraform
   - `*.yaml/yml` (K8s) → YAML
   - `Dockerfile*` → Dockerfile
   - `.github/workflows/*` → GitHub Actions

2. **언어별 검사 명령** (있는 도구만 실행):
   - **Go**: `gofmt -l ./...` (출력 있으면 fail), `go vet ./...`, `golangci-lint run` (있으면)
   - **Python**: `ruff check .`, `ruff format --check .`, `mypy .` (config 있으면)
   - **Rust**: `cargo fmt -- --check`, `cargo clippy --all-targets -- -D warnings`
   - **Shell**: `shellcheck **/*.sh`
   - **Terraform**: `terraform fmt -check -recursive`, `terraform validate`
   - **YAML**: `yamllint .`, `kubeconform <files>` (K8s)
   - **Dockerfile**: `hadolint Dockerfile`
   - **GitHub Actions**: `actionlint`

3. **결과 요약 표** 출력:
   | 도구 | 결과 | 위치 |
   | gofmt | ✅ 통과 | — |
   | golangci-lint | ❌ 5건 | pkg/x.go:42, ... |
   | shellcheck | ⚠️ 2 warning | scripts/foo.sh:10 |

4. **자동 수정 제안** (사용자 동의 후):
   - `gofmt -w`, `cargo fmt`, `ruff format`, `terraform fmt` — 자동 적용 가능
   - lint 위반 — 사용자에게 수정 위임

## 옵션
- `--fix`: 자동 수정 가능한 것 즉시 적용
- `--strict`: warning 도 fail 처리

## 관련
- `coding-*.md` rules (path-scoped, 자동 로드)
- `auditing-workflow` skill (CI 영역 별도)
