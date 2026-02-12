# Global Configuration

## Language & Communication
- 한국어로 응답한다
- 코드 주석은 한국어 또는 영어 (프로젝트 기존 컨벤션을 따른다)
- 기술 용어는 원어 그대로 사용한다 (예: "컨테이너"가 아닌 "container")

## Coding Style
- Indent: 2 spaces (모든 언어 공통, 단 Python은 4 spaces/PEP8, Go는 gofmt)
- 불필요한 주석, docstring, type annotation을 추가하지 않는다
- 변경하지 않은 코드에 손대지 않는다
- 간결하게: 3줄 반복이 섣부른 추상화보다 낫다

## New Project Initialization
새 프로젝트를 시작할 때 반드시 README.md를 생성한다:

```markdown
# 프로젝트명

## 개요
[프로젝트가 무엇이며 왜 필요한지 1-3문장]

## 목표
- [핵심 목표 1]
- [핵심 목표 2]

## 요구사항
- [기술적/비즈니스 요구사항]

## 기능 범위
### 포함
- [구현할 기능]

### 미포함 (Out of Scope)
- [명시적으로 제외하는 기능과 그 이유]

## 기술 스택
- [사용 언어, 프레임워크, 도구]

## 시작하기
[설치/실행 방법]
```

## Tech Stack Context
주로 다루는 기술 영역:
- **ML/AI**: vLLM, PyTorch, CUDA, Triton, 분산 추론, 모델 최적화
- **Cloud/Infra**: Kubernetes, OpenShift, Terraform, Docker, Go operators
- **Open Source**: PyTorch, vLLM, FlashAttention, RDMA, network-operator 내부 분석
- **Systems**: Linux kernel modules, C/C++, Python C extensions
- **기타**: 수학, 과학, 경제, 양자 컴퓨팅 등 다양한 분야 학습

## Git
- 커밋 메시지를 요청 없이 생성하지 않는다
- force push, reset --hard 등 파괴적 명령 실행 전 반드시 확인한다

## Reasoning Transparency (과정 표시)
모든 분석, 추론, 문제 풀이에서 사고 과정을 화면에 명시적으로 보여준다:

1. **방법론 선언**: 어떤 접근법/도구/프레임워크를 쓸 것인지, 왜 선택했는지
2. **단계별 과정**: 중간 결과를 생략하지 않고, 각 단계에서 무엇을 하는지 표시
3. **판단 근거**: "A이기 때문에 B라고 판단한다" 형태로 추론 과정을 명시
4. **불확실성 표시**: 확실하지 않은 부분은 `[불확실]` 또는 `[추정]`으로 표기
5. **분기점 설명**: 여러 경로가 가능할 때 왜 이 경로를 선택했는지

형식 예시:
```
[방법] Roofline Model로 memory-bound 여부를 판단한다
[단계 1/3] operational intensity 계산: FLOPS / Bytes = ...
[판단] OI < ridge point → memory bandwidth bound
[다음] 메모리 접근 패턴 최적화를 우선한다
```

## Work Logging
작업 기록은 `/logging-work` 스킬로 수행한다.
- 기록 시점은 사용자가 결정한다 — 자동으로 기록하지 않는다
- 한 프로젝트에 `WORKLOG.md` 하나만 유지한다 (파일 폭발 방지)
- 적절한 작업 단위 기준:
  - 기능 하나 구현 완료
  - 버그 하나 해결 완료
  - 설계/분석 세션 하나 완료
  - 학습 주제 하나 정리 완료
- 너무 작은 단위(변수명 변경)나 너무 큰 단위(1주일 작업)는 피한다

## General Rules
- 파일을 읽기 전에 수정을 제안하지 않는다
- 요청받은 범위만 수행한다. over-engineering 금지
- 확실하지 않으면 먼저 질문한다
