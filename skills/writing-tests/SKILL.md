---
name: writing-tests
description: 변경된 코드에 적합한 테스트를 작성한다. 도메인별 프레임워크(Go ginkgo/envtest, Python pytest, Shell bats, Ansible molecule, K8s kind/envtest)와 패턴(table-driven, given-when-then, AAA)을 적용하고, integration > mock 원칙(fransible 사례)으로 실제 동작을 검증한다. 사용자가 "테스트 작성", "test 추가", "이 코드 테스트 어떻게", "test plan", "유닛 테스트", "통합 테스트"를 언급할 때 사용한다.
---

# Writing Tests

도메인 자동 감지 후 적절한 프레임워크/패턴으로 테스트 작성.

## 1. 도메인 감지 (파일/디렉토리 단서)
| 단서 | 프레임워크 |
|---|---|
| `*.go`, `go.mod` | go test (단순) / **ginkgo + gomega** (operator/복잡) |
| `controller-runtime`, `kubebuilder` | **envtest** (가짜 etcd+apiserver) + ginkgo |
| `pyproject.toml`, `*.py` | **pytest** + parametrize + fixture |
| `playbooks/`, `roles/` | **molecule** (Ansible) |
| `*.sh` | **bats-core** + `set -euo pipefail` |
| `*.rs`, `Cargo.toml` | `#[test]` + `tests/` 디렉토리 + `proptest` |
| K8s manifest | **kuttl** 또는 envtest |

## 2. 테스트 피라미드
```
        E2E (kind, real cluster)        — 적게, 핵심 시나리오만
       /                          \
      Integration (envtest, db)        — 비즈니스 로직 + 외부 어댑터
     /                                \
    Unit (mock 최소)                       — 빠르게, 다수
```

**원칙: integration > mock** (사용자의 fransible 사례). mock 으로 통과해도 prod 에서 실패하면 의미 없음. 가능하면 실제 외부 시스템(또는 envtest 같은 가짜 환경) 사용.

## 3. 작성 패턴 (모든 도메인 공통)
### Given-When-Then / AAA
```go
func TestReconcile(t *testing.T) {
  // Arrange (Given): 초기 상태
  ctx := context.Background()
  obj := &myv1.Foo{...}
  client := fake.NewClientBuilder().WithObjects(obj).Build()

  // Act (When): 대상 동작
  reconciler := &FooReconciler{Client: client}
  result, err := reconciler.Reconcile(ctx, ctrl.Request{NamespacedName: ...})

  // Assert (Then): 결과 검증
  require.NoError(t, err)
  assert.True(t, result.Requeue)
  // status 변화 확인
}
```

### Table-driven
```go
tests := []struct {
  name    string
  input   FooSpec
  want    FooStatus
  wantErr bool
}{
  {"empty spec", FooSpec{}, FooStatus{Phase: "Pending"}, false},
  {"invalid replicas", FooSpec{Replicas: -1}, FooStatus{}, true},
  ...
}
for _, tt := range tests {
  t.Run(tt.name, func(t *testing.T) { ... })
}
```

### Pytest parametrize
```python
@pytest.mark.parametrize("input_x,expected", [
    (0, "empty"),
    (1, "single"),
    (10, "many"),
])
def test_classify(input_x, expected):
    assert classify(input_x) == expected
```

## 4. Go (operator) — Ginkgo + envtest 패턴
```go
var _ = Describe("Foo Controller", func() {
  Context("When creating a Foo resource", func() {
    It("Should create the dependent Deployment", func() {
      ctx := context.Background()
      foo := &myv1.Foo{...}
      Expect(k8sClient.Create(ctx, foo)).To(Succeed())

      Eventually(func() error {
        deploy := &appsv1.Deployment{}
        return k8sClient.Get(ctx, types.NamespacedName{...}, deploy)
      }, timeout, interval).Should(Succeed())
    })
  })
})
```

핵심:
- `Eventually` (수렴 대기) vs `Consistently` (조건 유지)
- timeout/interval 명시 (각 환경 안정성 고려)
- `BeforeEach` 에 isolation 셋업

## 5. Python — pytest fixture scope
```python
import pytest

@pytest.fixture(scope="session")
def expensive_resource():
    """전체 세션 1회 셋업."""
    r = setup()
    yield r
    teardown(r)

@pytest.fixture
def fresh_object():
    """각 테스트마다 새로."""
    return Foo()

def test_uses_both(expensive_resource, fresh_object):
    ...
```

scope 분기:
- `function` (default) — 가장 안전, 가장 느림
- `module` — 모듈 내 공유
- `session` — 셋업 비싼 것 (DB, container)

## 6. Shell — bats
```bash
#!/usr/bin/env bats

setup() {
  export NAMESPACE="test-$$"
  kubectl create ns "$NAMESPACE"
}

teardown() {
  kubectl delete ns "$NAMESPACE" --ignore-not-found
}

@test "deploy script creates pod" {
  run ./scripts/deploy.sh
  [ "$status" -eq 0 ]
  [[ "$output" =~ "pod/foo created" ]]
  kubectl get pod foo -n "$NAMESPACE"
}
```

## 7. Flaky test 처리 — **격리, retry 금지**
- flaky 발견 즉시 별도 격리 (skip + 이슈 등록)
- retry 로 숨기지 않음 (가시성 손실)
- 근본 원인: race condition, timeout, 외부 의존, network

## 8. 커버리지·검증
- Go: `go test -cover -race ./...`
- Python: `pytest --cov=mypackage --cov-report=term-missing`
- 커버리지 100% 강박 X — **핵심 로직 (controller, business rule)** 우선

## 9. 흔한 함정
- ❌ mock 만으로 통과 → prod 에서 다른 동작 (예: K8s API mock)
- ❌ 한 테스트에 여러 assertion (실패 시 어디 깨졌는지 불명)
- ❌ test 간 의존 (순서 바뀌면 깨짐)
- ❌ `time.Sleep(5)` 로 타이밍 맞추기 (flaky 원인) — `Eventually`/`tick` 사용
- ❌ test 가 hard-coded 환경 의존 (`localhost:8080`) — fixture / config 로

## 관련 자산
- `coding-go.md`, `coding-python-ml.md`, `coding-shell.md` rules (자동 로드)
- `code-reviewer` agent (테스트 리뷰 시)
- `reviewing-pr` skill
