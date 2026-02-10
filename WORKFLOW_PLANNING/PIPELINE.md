# 개발 파이프라인 정의

> 기능 개발의 전체 프로세스를 7단계로 정의합니다.

---

## 🔄 전체 프로세스

### 7단계 개발 파이프라인
```
1. Plan (계획): 기능 요청 분석, 작업 단위 분해, 파일 식별
2. Design (설계): 아키텍처 설계, 기술적 검증 (순환 참조, 성능, 스레드 안전성 등)
3. Code (코딩): 코드 구현, 코드 스타일 준수
4. Test (테스트): 단위 테스트 자동 생성, 기능 테스트, 빌드 테스트
5. Docs (문서화): 각 단계별 문서 업데이트, API 문서 생성
6. QA (품질검사): 코드 품질, 스타일, 아키텍처 준수 검토
7. Review (최종검토): 전체 결과물 종합 검토
```

### 개발 워크플로우

#### 방식 1: 자동화 모드 (코디네이터 주도)
```
사용자: "coordinator CSV 기능 추가"
  ↓
coordinator: 작업 시작 → WorkID 생성
  ↓
1. Plan: analyst (기획서 분석 → 유형 판단 → 계획 수립)
  ↓
2. Design: architect (아키텍처 설계 → 기술적 검증)
  ↓
3. Code: developer (구현 → 빌드 확인)
  ↓
4. Test: tester (단위 테스트 자동 생성 → 기능 테스트 → 빌드 테스트)
  ↓
5. Docs: doc-manager (각 단계별 문서 업데이트 → API 문서 생성)
  ↓
6. QA: reviewer (코드 품질, 스타일, 아키텍처 준수 검토)
  ↓
7. Review: coordinator (전체 결과물 종합 검토 → 최종 승인)
```

#### 방식 2: 수동 모드 (사용자 직접 호출)
```
사용자: "analyst 이 기획서 분석해줘"
  ↓
1. Plan: analyst만 실행 → 보고
  ↓
사용자: "developer 이 계획으로 구현해줘"
  ↓
2. Code: developer만 실행 → 보고
  ↓
사용자: "tester 단위 테스트 자동 생성하고 테스트해줘"
  ↓
3. Test: tester만 실행 → 보고
  ↓
사용자: "doc-manager 각 단계별 문서 업데이트해줘"
  ↓
4. Docs: doc-manager만 실행 → 보고
  ↓
사용자: "reviewer 코드 품질 검토해줘"
  ↓
5. QA: reviewer만 실행 → 보고
  ↓
사용자: "coordinator 전체 결과물 종합 검토해줘"
  ↓
6. Review: coordinator만 실행 → 보고
```

#### 방식 3: 혼합 모드 (부분 자동화)
```
사용자: "coordinator Plan부터 Code까지만 자동화해줘"
  ↓
coordinator: analyst → developer까지만 조율
  ↓
사용자: "tester 단위 테스트 자동 생성하고 테스트해줘"
  ↓
3. Test: tester만 실행 → 보고
  ↓
사용자: "doc-manager 각 단계별 문서 업데이트해줘"
  ↓
4. Docs: doc-manager만 실행 → 보고
  ↓
사용자: "reviewer 코드 품질 검토해줘"
  ↓
5. QA: reviewer만 실행 → 보고
  ↓
사용자: "coordinator 최종 검토해줘"
  ↓
6. Review: coordinator만 실행 → 보고
```

---

## 📚 관련 모듈

- [GATES.md](GATES.md) - Gate 검증 시스템 및 통과 조건
- [AUTO_UPDATE.md](AUTO_UPDATE.md) - WorkID 및 자동 업데이트 시스템
- [ERROR_HANDLING.md](ERROR_HANDLING.md) - 에러 처리 및 롤백 프로토콜
- [REPORTS.md](REPORTS.md) - 작업 완료 보고서 생성
