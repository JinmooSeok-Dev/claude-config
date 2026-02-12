---
name: solving-calculus
description: >
  미적분 문제를 풀고 개념을 설명한다. 극한, 미분, 적분, 편미분,
  다변수 미적분, 벡터 미적분, 미분방정식, 최적화(경사하강법),
  테일러 급수, 푸리에 변환 등을 다룬다.
  사용자가 "미분", "적분", "극한", "편미분", "gradient",
  "수렴", "발산", "미분방정식", "미적분"을 언급할 때 사용한다.
argument-hint: "[문제 또는 개념]"
---

ultrathink

## 미적분 분석 프레임워크

$ARGUMENTS에 대해:

### 1. 문제 유형 파악

| 유형 | 핵심 | 활용 예시 |
|------|------|----------|
| **극한/연속** | lim, ε-δ | 수렴 조건, 안정성 분석 |
| **미분** | df/dx, 변화율 | sensitivity, 역전파 |
| **편미분** | ∂f/∂xᵢ | gradient, Jacobian, Hessian |
| **적분** | ∫f dx, 누적량 | 확률밀도 → CDF, 넓이/부피 |
| **다변수 최적화** | ∇f = 0, ∇²f | 경사하강법, Newton's method |
| **미분방정식** | ODE, PDE | 물리 시뮬레이션, 동적 시스템 |
| **급수/변환** | Taylor, Fourier | 근사, 주파수 분석, 신호처리 |
| **벡터 미적분** | grad, div, curl | 물리장, 유체, 전자기 |

### 2. 직관 먼저

모든 미적분 개념을 직관적으로 먼저 설명한다:

- **미분** = 순간 변화율 = 접선의 기울기
- **적분** = 누적된 양 = 곡선 아래 넓이
- **편미분** = 다른 변수를 고정하고 하나만 움직일 때의 변화
- **gradient** = "가장 가파른 오르막 방향" 벡터
- **Hessian** = 곡면의 곡률 (볼록? 안장점?)

```
f(x)          f'(x) > 0: 증가 중
  /\           f'(x) = 0: 극값
 /  \          f'(x) < 0: 감소 중
/    \___     f''(x) > 0: 아래로 볼록 (극소)
              f''(x) < 0: 위로 볼록 (극대)
```

### 3. 풀이

**해석적 풀이:**
- 단계별 전개 (치환, 부분적분, 연쇄법칙 등)
- 각 단계의 동기: "왜 이 방법을 쓰는가"

**수치적 풀이:**
```python
import numpy as np
from scipy import integrate, optimize

# 수치 미분
def numerical_grad(f, x, h=1e-7):
  return (f(x + h) - f(x - h)) / (2 * h)

# 수치 적분
result, error = integrate.quad(f, a, b)

# 최적화 (gradient descent)
def gradient_descent(f, grad_f, x0, lr=0.01, steps=1000):
  x = x0
  for _ in range(steps):
    x = x - lr * grad_f(x)
  return x

# ODE 풀이
from scipy.integrate import solve_ivp
sol = solve_ivp(f, [t0, tf], y0, method='RK45')
```

### 4. ML/시스템 연결

- **역전파** = 연쇄법칙(chain rule)의 계산그래프 적용
  ∂L/∂w = ∂L/∂y · ∂y/∂w
- **경사하강법** = -∇f 방향으로 이동, lr = 보폭
  - SGD, Adam, AdaGrad의 수학적 차이
- **학습률 스케줄링** = f(t)의 감쇠 함수 설계
- **정규화** = 손실함수에 페널티 항 ∫|w|² 추가
- **Attention softmax** = exp 함수의 미분 특성 활용
- **Neural ODE** = 연속 시간 모델로서의 신경망
- **Fourier 특성** = positional encoding, 주파수 도메인 분석

### 5. 시각화

가능하면 함수/벡터장을 시각화한다:
- 1D: 함수 그래프 + 접선/넓이 표시
- 2D: 등고선(contour) + gradient 벡터장
- 3D: 곡면 + 극값 위치

## 과정 표시
매 단계마다 아래 형식으로 과정을 보여준다:
```
[문제] ∫₀^∞ x²e^(-x) dx
[방법] 부분적분 선택 — x²이 미분하면 단순해지고, e^(-x)는 적분해도 동일
[단계 1/3] u=x², dv=e^(-x)dx → [x²·(-e^(-x))]₀^∞ + ∫2x·e^(-x)dx
[단계 2/3] 경계: x²e^(-x)→0 (x→∞), 나머지 ∫2xe^(-x)dx에 부분적분 반복
[단계 3/3] = 2·1 = 2 → 이것은 Γ(3) = 2!
[해석] Gamma 함수 Γ(n) = (n-1)!의 특수한 경우
[검증] scipy.integrate.quad(lambda x: x**2*np.exp(-x), 0, np.inf) → 2.0
```
- 왜 이 풀이법을 선택했는지 동기를 밝힌다
- 각 변환 단계마다 "무엇을 하는 건지"를 자연어로 병기
- 최종 결과의 의미를 해석한다
- 가능하면 수치적으로 교차 검증한다

## 규칙
- 직관 → 수식 → 코드 → ML 연결 순서
- 작은 예제(1-2차원)로 먼저 보여준다
- 수치적 방법 사용 시 오차와 수렴 조건을 언급한다
- 물리적/기하학적 의미를 반드시 함께 설명한다
