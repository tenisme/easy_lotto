# 테스트 APK 서명

## 2차부터의 격리

- 1차 패키지는 `com.example.easy_lotto.preview`, 2차부터는 `.preview2`이다. 기존 앱을 삭제하거나 데이터를 옮기지 않고 병행 설치한다.
- 디버그 라벨은 `Easy Lotto 2차 테스트`이며, 정식 스토어 앱 ID·서명과 무관하다.

## 명시적인 키 경로

CI는 `$RUNNER_TEMP/easy-lotto-preview2/debug.keystore`를 캐시에서 복원한다. `EASY_LOTTO_PREVIEW_KEYSTORE`로 Gradle의 debug signingConfig에 같은 경로를 전달한다. AGP의 기본 경로에 의존하지 않는다.

캐시 키는 `easy-lotto-preview2-signing-v2`이다. 첫 키 생성 직후 APK 빌드 전에 저장하므로 이후 단계 실패로 키 보존이 생략되지 않는다. 개인 키를 저장소·로그·APK 산출물에 포함하지 않는다. 별칭과 표준 디버그 비밀번호는 테스트 전용이며 릴리스에 사용하지 않는다.

`.github/preview2-signing.sha256`에는 공개 인증서의 SHA-256을 기록한다. 최초 생성 중에만 `INITIALIZE`를 사용하고, 생성한 APK 인증서를 확인한 직후 실제 지문으로 고정한다. 이후 캐시가 없거나 지문이 다르면 빌드를 실패시켜 서명을 조용히 교체하지 않는다.

## 보존 한계

Actions 캐시는 영구 백업이 아니며 만료·용량 제한으로 제거될 수 있다. 현재 연동 권한으로 Actions Secrets API를 사용할 수 없어 암호화 Secret 보관을 자동 설정하지 못했다. 장기 배포 전에는 저장소 소유자가 암호화된 서명 키 백업과 복원 경로를 준비해야 한다. 캐시 유실 때 기존 키 복구 없이 새 키를 생성하거나 지문을 초기화하면 안 된다. 서명 문제를 해결하려고 사용자에게 앱 삭제를 요구하지 않는다.
