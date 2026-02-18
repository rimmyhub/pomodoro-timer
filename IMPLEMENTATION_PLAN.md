# Implementation Plan: PomodoroBuddy (Current State v1.0.2)

## 0. 변경 이력
- 2026-02-18 v1.0.2: 문서를 “계획” 중심에서 “현행 구현 + 후속 계획” 중심으로 재작성.
- 2026-02-18 v1.0.2: 설정 사운드 변경 크래시 대응(리소스 번들 탐색 로직 개선) 반영.

## 1. 문서 목적
현재 저장소 구현 상태를 기준으로:
- 어떤 기능이 완료되었는지
- 어떤 항목이 아직 미구현인지
- 다음 릴리즈에서 무엇을 우선할지
를 명확히 관리한다.

## 2. 현재 아키텍처
- UI: SwiftUI
- 앱 진입: `MenuBarExtra` + 다중 `Window` 씬
- 상태 관리: `PomodoroViewModel` 단일 `ObservableObject`
- 저장소: `UserDefaults` (`PersistenceService`)
- 사운드: `NSSound` (`SoundService`)
- 통계 렌더링: `Swift Charts`

## 3. 코드 기준 모듈 맵
- 앱 진입/창 구성: `Sources/PomodoroBuddyApp.swift`
- 메인 타이머 UI: `Sources/MainTimerView.swift`
- 원형 다이얼 인터랙션: `Sources/CircularDialView.swift`
- 카테고리 관리 UI: `Sources/CategoryManagerView.swift`
- 설정 UI: `Sources/SettingsView.swift`
- 통계 UI: `Sources/StatsView.swift`
- 상태/도메인 로직: `Sources/PomodoroViewModel.swift`
- 모델 타입: `Sources/Models.swift`
- 저장/사운드 서비스: `Sources/Services.swift`
- 배포 스크립트:
  - `scripts/build_app_bundle.sh`
  - `scripts/run_app_bundle.sh`
  - `scripts/build_release_zip.sh`

## 4. 기능 상태

### 4.1 완료
- 메뉴바 타이머 및 재생/일시정지/초기화
- 다이얼 기반 1~60분 설정
- 카테고리 CRUD + 고정 카테고리 보호(`휴식`, `공부하기`)
- 세션 활성 시 카테고리/설정 수정 잠금
- 휴식 사이클 전환 로직
- 설정(테마/알림음/BGM/휴식시간)
- 통계(기간/카테고리 필터, 요약, 차트)
- 삭제 카테고리 `(삭제됨)` 필터 노출
- 로컬 저장(설정/카테고리/세션/선택 카테고리)
- 릴리즈 zip 자동화 스크립트
- v1.0.2 크래시 수정:
  - 설정에서 사운드 변경 시 `Bundle.module` 의존으로 종료되던 문제 해결
  - 런타임 리소스 번들 탐색 방식으로 교체

### 4.2 미구현(백로그)
- Apple Calendar(EventKit) 연동
- 시작 전 질문형 빠른 선택 UX(`공부하기/독서하기/직접정하기`)
- 타이머 실행 상태(`isRunning`, `remainingSeconds`) 영속화
- 자동화된 테스트(단위/UI) 구축

## 5. 데이터/상태 설계 현행

### 5.1 저장 키
- `app.settings`
- `app.categories`
- `app.sessions`
- `app.selectedCategoryID`

### 5.2 핵심 모델
- `AppSettings`
  - `defaultMinutes`, `breakMinutes`, `breakCycleEnabled`
  - `theme`, `notificationSound`
  - `whiteNoiseEnabled`, `whiteNoiseTrack`
- `Category`
  - `id`, `name`, `createdAt`, `updatedAt`
- `FocusSession`
  - `id`, `startedAt`, `endedAt`, `durationSec`
  - `categoryId`, `categoryNameSnapshot`, `segments`

## 6. 통계 집계 규칙 현행
- 집계 기준 시간대: 로컬 시간대
- `1일`: 당일 24시간(시간대별) 막대
  - `segments`와 시간 슬롯의 겹침으로 초 단위 계산
- `1주`: 최근 7일 일자 막대
- `1개월`: 당월 일자 막대
- `6개월/1년`: 월별 막대
- 카테고리 필터:
  - `전체` 또는 특정 `categoryId`
  - 삭제된 카테고리는 세션 스냅샷 기반으로 필터 옵션 유지

## 7. 릴리즈 운영 절차 현행
1. 릴리즈 zip 생성
```bash
cd /Users/hyerim/dev/pomodoro-timer
./scripts/build_release_zip.sh 1.0.2 2
```
2. 산출물 확인
- `.app` 버전/빌드 번호
- zip SHA256 체크섬
3. Git 태그/푸시
```bash
git tag -a v1.0.2 -m "v1.0.2"
git push origin main
git push origin v1.0.2
```
4. GitHub Release에 zip 첨부 + 릴리즈 노트 등록

## 8. 다음 릴리즈 우선순위 제안
1. Calendar 연동 1차(EventKit 권한 + 기본 캘린더 기록)
2. 타이머 상태 영속화(앱 재시작 복구)
3. 자동화 테스트 최소 세트 구축
4. 시작 전 질문형 카테고리 선택 UX 도입 여부 재결정

## 9. 회귀 테스트 체크리스트
- 타이머:
  - 시작/일시정지/재개/초기화 정상 동작
  - 실행 중 다이얼 변경 불가
- 카테고리:
  - 고정 카테고리 보호
  - 세션 활성 중 편집 잠금
  - 삭제 후 통계 스냅샷 유지
- 설정:
  - 휴식 사이클 전환
  - 알림음/BGM 프리뷰 시 크래시 없음
  - 저장 후 재실행 유지
- 통계:
  - 기간/카테고리 필터 동기화
  - 합계 시간/집중 횟수 정확성
- 배포:
  - `.app` 실행 확인
  - zip 압축 해제 후 설정 변경 안정성 재검증

