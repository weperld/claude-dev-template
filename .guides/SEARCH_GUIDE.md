# 검색 가이드

## 검색 규칙 (필수 준수)
- 코드 검색 시 반드시 AI-grep을 먼저 사용할 것
- 전체 파일을 읽지 말고 `--lines N-M` 옵션으로 필요한 부분만 읽을 것
- 직접 파일 탐색은 AI-grep으로 찾을 수 없을 때만 최후의 수단으로 사용
- 기본 출력은 compact 모드 (토큰 절약). 상세 정보가 필요하면 `--verbose` 추가
- Windows 환경: 반드시 `PYTHONIOENCODING=utf-8 python .search/ai-grep` 형식으로 실행

## 검색 도구 사용법
```
# 접두어: PYTHONIOENCODING=utf-8 python .search/ai-grep (Windows)

ai-grep stats                              # 코드베이스 개요
ai-grep relevant "query" --top 5           # 관련 파일 랭킹 (--top은 relevant 전용)
ai-grep search "keyword" --limit 10        # 전문 검색 (compact 출력)
ai-grep search "keyword" --verbose          # 상세 메타데이터 포함 출력
ai-grep refs "ClassName" --context 3       # 심볼 참조 검색 (--context: 전후 줄 수)
ai-grep get "file.cs" --lines 10-50       # 특정 줄만 읽기 (--raw: JSON 없이 원본만)
ai-grep outline "file.cs"                  # 파일 구조 확인
```
**주의**: 각 명령어의 옵션을 혼용하지 말 것 (예: `refs --top` 불가)

## 검색 전략: ai-grep + LSP 병행

| 상황 | 도구 | 이유 |
|------|------|------|
| "이 기능 어디에 있지?" (탐색) | `ai-grep relevant` | 파일 위치 파악에 최적 |
| 심볼 정의/참조 추적 | LSP (goto definition, find references) | 정확한 코드 탐색 |
| 전체 텍스트 검색 (로그, 문자열 등) | `ai-grep search` | LSP가 못 찾는 비코드 매칭 |
| 파일 구조 파악 | `ai-grep outline` 또는 LSP (document symbols) | 둘 다 가능, 상황에 따라 |
| 리팩토링 영향 분석 | LSP (find references) → `ai-grep refs` 보조 | LSP가 정확, ai-grep은 주석/문자열도 포함 |

## 검색 동작 참고 (에이전트용)
- 소스코드(.ps1/.sh/.py 등)가 문서(.md/.txt)보다 높은 점수를 받음
- 클래스/함수 선언부가 일반 코드보다 높은 점수를 받음
- 복합 식별자(ExportService)는 서브워드(Export, Service)도 매칭됨
- 인덱스가 오래되면 ripgrep(실시간) 비중이 자동으로 올라감
