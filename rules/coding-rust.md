---
paths:
  - "**/*.rs"
  - "**/Cargo.toml"
  - "**/Cargo.lock"
---

# Rust 코딩 규칙

## 포맷·린트 (필수)
- `cargo fmt --all -- --check` (CI), 로컬은 저장 시 `cargo fmt`
- `cargo clippy --all-targets --all-features -- -D warnings`
- `rust-analyzer` LSP 활성 (이미 plugin 등록됨)

## 에러 처리
- `?` 연산자 우선, `unwrap()` / `expect()` 는 prototype/test 에서만
- **lib crate**: `thiserror` 로 enum 에러 정의 (각 variant 가 의미 단위)
- **bin crate**: `anyhow::Result` + `?` + `.context("...")` 로 보강
- `panic!` 은 invariant 위반(절대 일어나선 안 되는 상태)에서만

## 소유권·라이프타임
- 함수 시그니처에서 `&str` > `String`, `&[T]` > `Vec<T>` 우선 (호출자 부담 ↓)
- `Clone` 은 의식적으로 — 핫 패스에서는 비용 측정 후
- `Arc<Mutex<T>>` 남용 금지 — 채널 / `RwLock` / `Cell`/`RefCell` 분기

## 모듈 구조
- `src/lib.rs` (라이브러리) + `src/main.rs` (바이너리) 분리 권장
- `mod foo;` + `pub mod foo;` 명확히. `pub(crate)` 적극 활용
- `use` 는 std → 외부 crate → 내부 crate (그룹 사이 빈 줄)

## 비동기
- 단일 런타임 선택 (`tokio` 또는 `async-std`) — 혼용 금지
- `async fn` 은 호출 위치 명시 (`#[tokio::main]` / `block_on`)
- CPU bound 은 `spawn_blocking` 또는 별도 thread

## 테스트
- 단위 테스트는 같은 파일 `#[cfg(test)] mod tests`
- 통합 테스트는 `tests/` 디렉토리 (각 파일이 별도 crate)
- doc test 활용 — 공개 API 의 사용 예 검증
- property test (proptest/quickcheck) 는 invariant 검증에 권장
- seed-based RNG (e.g., `puzzle/diff-detective` 패턴) — 재현 가능

## 아키텍처 (선택)
- TUI / GUI / 단일 책임 도메인 → **Elm Architecture (TEA)** — `Model + Msg + update + view`. 상태 변이 명시적, 테스트 용이
- 어댑터 분리: `domain/` (순수 로직) ↔ `adapters/` (IO/네트워크/DB)

## 흔한 함정
- `String::from_utf8(...).unwrap()` → 외부 입력은 `?` 로 처리
- `Vec::with_capacity` 누락 — 크기 알면 prealloc
- `format!` 핫 패스 — `write!` 또는 `&str` concat 고려
- `println!` 디버그용 → 라이브러리는 `log`/`tracing` 사용
