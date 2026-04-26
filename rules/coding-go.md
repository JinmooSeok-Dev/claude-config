---
paths:
  - "**/*.go"
  - "**/go.mod"
  - "**/go.sum"
---

# Go 코딩 규칙

Operator 개발(controller-runtime, kubebuilder, operator-sdk) + 일반 Go 서비스에 적용.

## 포맷 / 린터
- `gofmt` 필수, 추가로 `goimports`로 import 그룹화 (stdlib / third-party / local 3그룹)
- `golangci-lint` 권장 set: `errcheck, govet, ineffassign, staticcheck, unused, gocritic, revive`
- `go vet ./...`은 CI에서 게이트
- Module 경로는 도메인 포함: `github.com/<org>/<repo>` (단순 이름 금지)

## 에러 처리
- 에러 wrapping: `fmt.Errorf("describe context: %w", err)` — `%v` 금지
- 라이브러리 코드는 `errors.Is`/`errors.As`로 식별 가능하도록 sentinel 또는 typed error 노출
- `_ = someCall()`로 에러를 무시하지 않는다 — 무시 의도면 주석으로 이유 명시
- `panic`은 라이브러리 진입점에서만, 평소는 에러 반환

## Context propagation
- 모든 외부 호출(HTTP, DB, k8s API) 함수는 첫 인자가 `ctx context.Context`
- `context.Background()`는 `main()`/테스트/init에서만 사용 — 일반 함수는 호출자 ctx를 받는다
- 장기 작업은 `ctx.Done()` 체크 또는 deadline 설정

## Concurrency
- goroutine 시작은 항상 종료 책임자가 명확해야 함 (`errgroup`, `sync.WaitGroup`, channel 종료 신호)
- channel은 송신자가 close, 수신자가 close 금지
- 공유 state는 mutex 또는 channel — atomic은 단일 변수에만
- `time.After`를 select에 단독 사용 시 GC 누수 — `time.NewTimer` + `Stop()` 사용

## Operator (controller-runtime) 패턴
- Reconcile은 **idempotent** — 같은 상태 재진입에서 부작용 없어야 함
- Reconcile 반환:
  - 성공 + 더 할 일 없음 → `ctrl.Result{}, nil`
  - 일정 시간 후 재확인 → `ctrl.Result{RequeueAfter: time.Minute}, nil`
  - 즉시 재시도 → `ctrl.Result{Requeue: true}, nil` 또는 `ctrl.Result{}, err` (에러 반환이 표준)
- `client.Patch` > `client.Update` — Update는 conflict가 잦음. SSA(Server-Side Apply)는 `client.Apply` 사용
- Status 업데이트는 `Status().Update()` 또는 `Status().Patch()` — spec과 분리된 path
- Finalizer:
  - `controllerutil.AddFinalizer` / `RemoveFinalizer` 헬퍼 사용
  - DeletionTimestamp 설정 시에만 정리 → 끝나면 finalizer 제거
- OwnerReference: 자식 리소스 생성 시 `controllerutil.SetControllerReference`로 GC 보장
- Watch 최소화: 같은 GVK는 한 번만 `For()` / `Owns()`, 외부 리소스는 `Watches()` + custom EventHandler

## kubebuilder marker
- `+kubebuilder:rbac:groups=...,resources=...,verbs=...` — 정확한 verb만 (`*` 금지)
- `+kubebuilder:object:root=true` 누락 시 DeepCopy 미생성
- `+kubebuilder:validation:Required` / `Optional` 명시
- `+kubebuilder:printcolumn`으로 `kubectl get` 출력 컬럼 추가

## 테스트
- 표준 라이브러리 `testing` + table-driven 권장
- Operator는 `envtest` (etcd + apiserver) — Ginkgo/Gomega는 operator-sdk 기본이지만 의무는 아님
- testify(`assert`/`require`) 또는 cmp(`cmp.Diff`) 사용 가능
- `t.Parallel()` 적극 활용 — 단 글로벌 state 의존 시 금지
- HTTP는 `httptest`, k8s client는 fake client 또는 envtest

## 의존성
- `go mod tidy`는 CI에서 게이트 (`-diff`로 변경 감지)
- 직접 의존성만 `go.mod`의 `require` 블록에 — indirect는 자동 관리
- replace는 일시적으로만 사용, 장기적으로는 fork 또는 upstream 기여
- vendoring은 보안/재현성 강제 시에만 (대부분 불필요)

## 로깅
- `logr.Logger` (controller-runtime), `slog` (1.21+), 또는 `zap` 중 프로젝트 컨벤션 따름
- 구조화 로깅: `log.Info("reconciling", "namespace", ns, "name", name)` (key-value 쌍)
- `fmt.Println`/`log.Printf`는 main이나 디버깅 외 금지

## API 디자인
- 함수는 동사로, struct는 명사로
- Receiver 이름은 1~2자 짧게, struct 이름 prefix 일관성
- Interface는 사용처에 정의 (consumer-side), 작게 유지 (1~3 메서드 권장)
- Exported field에 `json` 태그 명시 (특히 CRD spec/status)
