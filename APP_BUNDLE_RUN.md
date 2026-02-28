# App Bundle 실행 방법

`swift run` 대신 `.app` 번들로 실행하면 일반 macOS 앱처럼 실행할 수 있습니다.

## 1) 번들 생성

```bash
cd /Users/hyerim/dev/pomodoro-timer
./scripts/build_app_bundle.sh 1.0.4 4
```

## 2) 생성된 앱 실행

```bash
open /Users/hyerim/dev/pomodoro-timer/.app/PomodoroBuddy.app
```

또는 한 번에 실행:

```bash
cd /Users/hyerim/dev/pomodoro-timer
./scripts/run_app_bundle.sh 1.0.4 4
```
