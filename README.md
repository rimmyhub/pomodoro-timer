# PomodoroBuddy

메뉴바에서 바로 쓰는, 가볍고 꾸준한 집중 타이머

## 이 앱은 어떤 앱인가요?
PomodoroBuddy는 macOS 메뉴바에서 바로 실행해서 쓰는 포모도로 타이머입니다.  
앱 창을 크게 열어두지 않아도, 필요한 순간에 빠르게 집중을 시작하고 기록까지 남길 수 있습니다.

## 왜 써야 하나요?
- 집중 시작이 빠릅니다: 메뉴바 클릭 후 바로 시작
- 흐름이 끊기지 않습니다: 카테고리/휴식 사이클로 루틴 유지
- 기록이 남습니다: 집중 통계를 기간별로 확인
- 복잡하지 않습니다: 꼭 필요한 기능만 간단하게 제공

## 핵심 기능
- 원형 다이얼로 1~60분 타이머 설정
- 재생/일시정지/초기화
- 카테고리 관리(추가/수정/삭제/선택)
- 휴식 사이클 자동 전환(업무 종료 후 휴식 자동 진입)
- 설정
  - 테마
  - 알림음
  - BGM(비 소리/장작 소리)
  - 휴식 주기 및 휴식 분
- 통계
  - 기간: 1일/1주/1개월/6개월/1년
  - 카테고리 필터(삭제된 카테고리 포함)

## 빠르게 시작하기 (일반 사용자)
### 1) 릴리즈 파일 다운로드
GitHub Releases에서 `PomodoroBuddy-macOS-v*.zip` 파일을 받습니다.

### 2) 실행
1. 압축을 풉니다.
2. `PomodoroBuddy.app`을 `Applications`로 옮깁니다.
3. 앱을 실행합니다.

처음 실행 시 macOS 보안 경고가 나오면, 시스템 설정에서 실행 허용 후 다시 실행하세요.
PomodoroBuddy는 메뉴바 앱이라 실행 직후 큰 메인 창이 자동으로 뜨지 않을 수 있습니다. 이 경우 메뉴바 아이콘을 클릭해 타이머 창을 열어 사용하면 됩니다.

## 사용 방법
### 1) 집중 시작
1. 메뉴바의 PomodoroBuddy 아이콘 클릭
2. 원형 다이얼로 시간 설정
3. 카테고리 선택
4. 재생 버튼 클릭

### 2) 휴식 사이클
- 설정에서 `휴식 시간 주기`를 켜면 업무 세션 완료 후 자동으로 휴식으로 넘어갑니다.
- 휴식 종료 후에는 이전 업무 카테고리로 돌아옵니다.

### 3) 통계 보기
1. 메인 화면 우측 상단 `통계` 버튼 클릭
2. 기간과 카테고리 필터 선택
3. 집중 횟수/합계 시간/차트 확인

## 데이터는 어디에 저장되나요?
- 모든 데이터는 로컬(UserDefaults)에만 저장됩니다.
- 저장 항목:
  - 설정(테마/사운드/휴식 설정)
  - 카테고리
  - 세션 기록
  - 마지막 선택 카테고리

## 라이선스/사용 정책
- 이 저장소는 `Proprietary (All Rights Reserved)` 정책입니다.
- 소스 열람 외 사용(복제, 수정, 재배포, 상업적 사용, 앱 재출시)은 허용되지 않습니다.
- 사용 또는 배포가 필요하면 저작권자에게 사전 서면 허가를 받아야 합니다.
- 자세한 내용은 `LICENSE` 파일을 확인하세요.

## 개발 환경에서 실행하기
### 요구사항
- macOS 13+
- Swift 5.10+

### 빌드/실행
```bash
git clone https://github.com/rimmyhub/pomodoro-timer.git
cd pomodoro-timer
swift run PomodoroBuddy
```

### 앱 번들로 실행
```bash
./scripts/run_app_bundle.sh
```
필요하면 버전/빌드 번호를 직접 지정할 수 있습니다.
```bash
./scripts/run_app_bundle.sh <version> <build>
```

## 릴리즈 빌드
```bash
./scripts/build_release_zip.sh
```
필요하면 버전/빌드 번호를 직접 지정할 수 있습니다.
```bash
./scripts/build_release_zip.sh <version> <build>
```

생성 결과:
- `.app`: `.app/PomodoroBuddy.app`
- zip: `PomodoroBuddy-macOS-v<version>.zip`

## 문서
- 제품 요구사항: `PRD.md`
- 구현/운영 계획: `IMPLEMENTATION_PLAN.md`
- 릴리즈 노트 인덱스: `RELEASE_NOTES.md`
