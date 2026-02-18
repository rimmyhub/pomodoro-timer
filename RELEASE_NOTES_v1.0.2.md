# PomodoroBuddy v1.0.2

출시일: 2026-02-18

## 핵심 수정
- 설정 화면에서 알림음/BGM 변경 시 앱이 종료되던 크래시를 수정했습니다.
- 사운드 리소스 탐색에서 `Bundle.module` 고정 접근을 제거하고, 실행 환경별 번들 탐색으로 교체했습니다.
- 리소스 탐색 실패 시 앱 종료 대신 안전한 fallback(`NSSound.beep`) 경로를 유지합니다.

## 빌드/배포 개선
- `scripts/build_app_bundle.sh`
  - 버전/빌드번호 인자 지원
  - 기본 빌드 구성을 `release`로 정리
  - 모듈 캐시 경로 설정 추가
- `scripts/run_app_bundle.sh`
  - 버전/빌드번호 인자 전달 지원
- `scripts/build_release_zip.sh`
  - 릴리즈 zip 생성/체크섬 확인 스크립트 신규 추가

## 릴리즈 에셋
- `PomodoroBuddy-macOS-v1.0.2.zip`
- SHA256: `ee7c5260fc6a5f59e5bcba43f5361206ec3bf2be7f54f981d5cf7ef09cdb3e68`
