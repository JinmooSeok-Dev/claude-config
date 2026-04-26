---
paths:
  - "**/*.py"
  - "**/pyproject.toml"
  - "**/requirements*.txt"
---

# Python (ML / 벤치마크 / 일반 서비스) 코딩 규칙

PEP8/PEP484 같은 일반 규칙은 Python 기본 지식으로 처리. 본 파일은 ML/벤치마크 컨벤션과 자주 실수하는 패턴에 집중.

## 포맷 / 린터
- `ruff` 권장 (format + lint 통합) — 최소 rule set: `E, F, I, B, UP, SIM`
- `isort` 또는 `ruff --fix` 로 import 정렬 (stdlib / third-party / local 3그룹)
- vLLM contributing은 `YAPF + isort + ruff` — 해당 repo 내에서는 그 컨벤션을 따른다
- `pyproject.toml`에 도구 설정 일원화 — `setup.cfg` 신규 사용 금지

## 타입 힌트
- public API와 모듈 경계에는 type hint 필수
- private 함수는 자유 — 과한 type hint는 가독성 해침
- `from __future__ import annotations` 적극 활용 (forward reference 단순화)
- `Optional[X]` 보다 `X | None` (Python 3.10+)
- 구조화된 dict는 `TypedDict` 또는 `@dataclass` — 익명 dict의 `Any`로 떠다니지 않게

## 데이터 구조
- config / 결과 객체는 `@dataclass(frozen=True)` 또는 `pydantic.BaseModel`
- 익명 dict 남발 금지 — schema가 코드에 명시되어야 디버깅 가능
- 불변이 의미 있으면 `frozen=True` 또는 `tuple`
- 큰 collection iteration은 generator로

## 경로 / IO
- `pathlib.Path` 우선, `os.path` 금지
- 파일 open은 `with open(...) as f` (자원 누수 방지)
- 임시 파일은 `tempfile.NamedTemporaryFile` 또는 `tempfile.mkdtemp`

## async / await
- async 함수 안에서 blocking 호출 금지 (`time.sleep`, `requests.get` 등) — `asyncio.sleep`, `aiohttp` 사용
- vLLM `AsyncLLMEngine` 사용 시 모든 호출 경로가 async여야 함 — sync wrapper는 `asyncio.run` 명시
- `asyncio.gather` 사용 시 부분 실패 처리 명시 — 한 task 실패 시 다른 task가 cancel될지 결정

## PyTorch / CUDA
- device 명시: `tensor.to(device)` — 하드코딩 `"cuda"` 금지, `device = "cuda" if torch.cuda.is_available() else "cpu"` 패턴
- `torch.no_grad()` 또는 `inference_mode()` — inference 경로에서 그래디언트 추적 차단
- DDP/FSDP 환경: rank 0만 로깅/저장 (`if dist.get_rank() == 0:`)
- `torch.compile`은 첫 호출 컴파일 시간 발생 — 벤치마크에서 warmup 필수
- VRAM 누수 방지: 큰 텐서는 명시적 `del` + `torch.cuda.empty_cache()` (디버깅 시)
- mixed precision: `torch.autocast(device_type='cuda', dtype=torch.bfloat16)`
- seed는 `torch.manual_seed`, `torch.cuda.manual_seed_all`, `random.seed`, `numpy.random.seed` 모두 설정

## 벤치마크 / 측정
- 측정값은 **3회 이상 실행 후 median** (단일 run은 noise)
- warmup run 별도 실행, 측정 run에 포함 금지
- 결과 보고에 `[측정]` / `[추정]` 태그 — CLAUDE.md Accuracy 규칙 연계
- HW/SW 버전, 배치 크기, sequence length 등 측정 조건 명시
- p50 / p95 / p99 모두 보고 — mean만 보고 금지 (long tail 정보 손실)

## 테스트 (pytest)
- fixture scope: `function`(기본) / `module` / `session` 의도적으로 선택
  - GPU 모델 로드 같은 무거운 setup은 `session` scope
  - mutable state는 `function` scope (테스트 간 독립성)
- `parametrize`로 table-driven test
- `pytest.mark.gpu` 등 마커로 GPU 테스트 분리, CI에서 selective 실행
- assertion은 `pytest`의 plain assert (testify 같은 helper 불필요)

## 의존성 / 환경
- 프로덕션은 lock file (`uv lock`, `pip-tools requirements.txt`, `poetry.lock`)로 재현성 확보
- `requirements.txt`에 git+https 직접 참조는 보안/재현성 위험 — 피하거나 commit hash pin
- CUDA 버전과 PyTorch wheel 매칭 명시 (`+cu121`, `+cu124` 등)
- vLLM 같이 빠르게 변하는 패키지는 commit hash 또는 정확 버전 pin

## 로깅
- 표준 `logging` 모듈 — `print()`는 main 진입점이나 일회성 스크립트에서만
- `logger = logging.getLogger(__name__)` 모듈별 logger
- 구조화 로깅이 필요하면 `structlog`
- 민감 정보(token, API key) 로깅 금지

## 주의 패턴
- `*args, **kwargs`를 무지성 forwarding하지 않는다 — type 정보 손실
- mutable default argument 금지: `def f(x, items=[])` → `def f(x, items=None)`
- `lambda`는 1줄 표현식만, 복잡한 로직은 named function
- `eval` / `exec` 금지 (RCE 위험)
