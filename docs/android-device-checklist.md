# Android 테스트 설치와 확인

대상: ARM64 Android 7.0(API 24) 이상 기기. 테스트 APK는 디버그 서명이며 정식 스토어 배포용이 아니다.

## 최신 업데이트 APK (0.1.5-preview)

사용자 요청으로 [2026-11-08 UI 수정](ui-revision-2026-11-08.md)을 포함한 APK를 생성·다운로드 검증했다. 통합 보관함, 조합 카드 선택/작업 아이콘 분리, 정렬, 컬러 번호 칸, 디자인 하위 옵션, 확대·가로 배치와 추천·더보기 변경이 포함된다.

- 소스 커밋: `67e71cf`
- 버전: `0.1.5-preview` (versionCode 6)
- 앱 이름/패키지 유지: `Easy Lotto 2차 테스트`, `com.example.easy_lotto.preview2`
- [빌드 실행](https://github.com/tenisme/easy_lotto/actions/runs/42488302347)
- [최신 APK ZIP 다운로드](https://github.com/tenisme/easy_lotto/actions/runs/42488302347/artifacts/13620229277): 압축 해제 후 `app-debug.apk` 설치. GitHub 로그인이 필요할 수 있다.
- CI 정적 분석·95개 테스트·APK 빌드 성공. 실제 다운로드의 ZIP 무결성·SHA-256, APK 패키지·버전·최소 SDK 24·v2 서명·16KiB 정렬을 검증했다. Flutter 실행 라이브러리는 ARM64용이다.
- 인증서 SHA-256: `a2143aaee266c2ac6321ca977827ab4bf1640dc92d7bb487c14926f76e294f23`. 이전 2차 APK와 동일하다.
- APK SHA-256: `fbfb8ff4c2557c3bb6d5c4e896411a962a1b36f235751ccedff29d38a5216f36`.
- ZIP SHA-256: `f92c864345cb3d2f2f49e5e2e55a8a6885e5f4d9fbd2c5d58195a65573956bc2`. GitHub artifact digest와 일치한다.
- APK 86,473,115바이트(약 82.5MiB), ZIP 51,285,103바이트(약 48.9MiB).
- ZIP 보관 만료: 2026-11-22 23:13 한국 시간.
- 기존 2차 앱을 삭제하지 않고 업데이트 설치한다. 설치 화면에서 다시 실패하면, 이전에 성공했던 Windows ADB 방식으로 `adb install -r "APK의 전체 경로"`를 사용하고 실제 오류를 확인한다. 서명 검증만으로 휴대폰 설치·실행 성공을 단정하지 않는다.
- 다음 확인 항목은 [수정 문서의 실기기 체크리스트](ui-revision-2026-11-08.md#다음-실기기-확인)를 따른다. 특히 데이터 보존, 통합 탭 접힘 상태, 카드 선택/편집 분리, 화살표 위치, 최대 확대의 1열 전환을 확인한다.

## 이전 업데이트 APK (0.1.4-preview)

사용자 요청에 따라 [번호 배치·테마 페이지·보관함 및 버튼 중앙 정렬 개선](layout-review.md)을 포함한 APK를 생성·검증했다.

- 소스 커밋: `f591ba8`
- 버전: `0.1.4-preview` (versionCode 5)
- 앱 이름/패키지 유지: `Easy Lotto 2차 테스트`, `com.example.easy_lotto.preview2`
- [빌드 실행](https://github.com/tenisme/easy_lotto/actions/runs/42282012347)
- [최신 APK ZIP 다운로드](https://github.com/tenisme/easy_lotto/actions/runs/42282012347/artifacts/13536965471): 압축 해제 후 `app-debug.apk` 설치. GitHub 로그인이 필요할 수 있다.
- CI 분석·86개 테스트·빌드 성공. 다운로드한 APK의 패키지·버전·v2 서명·16KiB 정렬을 검증했다.
- 인증서 SHA-256: `a2143aaee266c2ac6321ca977827ab4bf1640dc92d7bb487c14926f76e294f23`. 기존 2차 앱과 동일하다.
- APK SHA-256: `8c0874cbffd68fba51893bb79ab7dbff1671ee3e0966a820753d2787d05be0cf`.
- ZIP 보관 만료: 2026-11-21 04:48 한국 시간.
- 기존 2차 앱을 삭제하지 않고 업데이트 설치한다.
- 설치 후 기존 데이터, 테마 저장/취소, 네 디자인, 확대 배치, 보관함, 버튼 문구 중앙 정렬을 확인한다.

## 이전 업데이트 APK (0.1.3-preview)

2026-11-07 요청으로 테마·스타일·임시 광고·안내 개선을 포함한 APK를 생성·검증했다. 이번 확인 항목은 [theme-style-review.md](theme-style-review.md)를 따른다.

- 소스 커밋: `54a3011`
- 버전: `0.1.3-preview` (versionCode 4)
- 앱 이름과 패키지 유지: `Easy Lotto 2차 테스트`, `com.example.easy_lotto.preview2`
- [빌드 실행](https://github.com/tenisme/easy_lotto/actions/runs/42242219651)
- [최신 APK ZIP 다운로드](https://github.com/tenisme/easy_lotto/actions/runs/42242219651/artifacts/13516202331): 압축 해제 후 `app-debug.apk` 설치. GitHub 로그인이 필요할 수 있다.
- CI 분석·72개 테스트·빌드 성공. 다운로드한 APK의 버전·패키지·v2 서명·16KiB 정렬을 검증했다.
- 인증서 SHA-256: `a2143aaee266c2ac6321ca977827ab4bf1640dc92d7bb487c14926f76e294f23`. 이전 `0.1.2-preview`와 동일하다. 키 캐시 복원과 고정 지문 검증도 통과했다.
- APK SHA-256: `a5ee6f0872ea1321b53b9a12a4461641d9dc425497e3838e76869d93ee657a22`.
- ZIP 보관 만료: 2026-11-21 00:25 한국 시간.
- 기존 2차 앱은 삭제하지 않고 같은 앱 위에 업데이트 설치한다.
- 설치 후 기존 설정·번호·용지 보존 여부를 먼저 확인한다.

## 2차 테스트 빌드

기존 앱과 병행 설치하는 새 빌드 생성·다운로드 검증을 완료했다. 실기기 병행 설치와 기능 검증은 아래 항목을 따른다.

- 앱 이름: `Easy Lotto 2차 테스트`
- 패키지: `com.example.easy_lotto.preview2` (1차의 `.preview`와 다름)
- 버전: `0.1.2-preview` (versionCode 3)
- [빌드 실행](https://github.com/tenisme/easy_lotto/actions/runs/41975595034)
- [2차 APK ZIP 다운로드](https://github.com/tenisme/easy_lotto/actions/runs/41975595034/artifacts/13391706994): 압축 해제 후 `app-debug.apk` 설치. GitHub 로그인이 필요할 수 있다.
- 소스 커밋: `01e3619`. 정적 분석·56개 테스트·APK 빌드 성공. v2 서명·16KiB 정렬과 별도 식별자·이름을 검증했다.
- APK 약 79MiB, ZIP 약 46MiB. 보관 만료: 2026-11-19 14:46 한국 시간.
- APK SHA-256: `0caed970275f5029be32d086d913861e42efa2915a72fff44f076a8a6bca7f8f`.
- 서명 인증서 SHA-256: `a2143aaee266c2ac6321ca977827ab4bf1640dc92d7bb487c14926f76e294f23`. 빌드 키의 공개 지문과 APK 지문이 같고, 서명 키 캐시 저장을 확인했다. 이후 빌드는 이 지문으로 고정한다. 보존 한계와 복구 정책은 [preview-signing.md](preview-signing.md)를 따른다.
- 기존 앱을 삭제하지 않고 새 앱을 설치한다. 두 앱의 데이터는 분리되며 이전 데이터는 자동 이전되지 않는다.
- 이번 확인 항목: [first-device-review.md](first-device-review.md). 새 앱에서 테스트용 설정·조합·용지를 만든 뒤 앱 재실행으로 보존을 확인한다.

## 이전 2차 빌드 보류 기록

**배포 보류: 아래 APK는 1차 APK와 서명이 달라 기존 앱 위에 업데이트 설치할 수 없다. 기존 앱을 삭제하지 않는다. 별도 패키지 병행 설치 또는 데이터 보존 대책을 사용자와 결정한 뒤 배포한다.**

- 소스 커밋: `5a2181c`
- 버전: `0.1.1-preview` (versionCode 2)
- [GitHub 빌드·다운로드](https://github.com/tenisme/easy_lotto/actions/runs/41974397038)
- 1차 수정 사항 및 이번 확인 범위: [first-device-review.md](first-device-review.md).
- 정적 분석·56개 테스트·APK 빌드·v2 서명 및 16KiB 정렬 검증은 통과했다. APK SHA-256: `ca24406c302f224d09a8cad058add2f21b8676306ae20194f11e14cae612f1a9`.
- 1차 서명 인증서 SHA-256: `9a89baeeca3f08ee914ce02a1fef90afce147d9d94e949b7a00fae1e5e966a41`.
- 이번 인증서 SHA-256: `10721f082e39eb6946435f81604283f4136d61c4a3c0959f43440bd2af054bad`.
- 빌드 캐시에는 현재 이전 서명 키가 없다. 이번 빌드도 `~/.android/debug.keystore` 경로가 존재하지 않아 캐시 저장이 생략되었다. 다음 배포 전 명시적인 서명 경로와 키 보존·검증을 구성해야 한다.

## 1차 테스트 빌드 기록

아래 빌드는 **1차 테스트 APK**이며 1차 피드백의 수정 사항은 포함되어 있지 않다.

- 소스 커밋: `feb42de`
- 버전: `0.1.0-preview` (versionCode 1)
- [GitHub 빌드·다운로드](https://github.com/tenisme/easy_lotto/actions/runs/41895462064)
- [ZIP 산출물](https://github.com/tenisme/easy_lotto/actions/runs/41895462064/artifacts/13355169684): 압축 해제 후 `app-debug.apk` 설치. GitHub 로그인이 필요할 수 있다.
- 산출물 보관 만료: 2026-11-19 04:23 한국 시간. 만료 후에는 새 빌드가 필요하다.
- APK 약 80MiB, ZIP 약 46MiB.
- APK SHA-256: `5cc4592aa1299dfb602c4e6d61aa64e882769f349611f3b86325f78e55668302`
- GitHub 분석·테스트 44건·Android 빌드 성공. 내려받은 APK의 v2 서명·16KiB 페이지 정렬·ARM64 라이브러리·패키지·최소 SDK 확인 완료.
- 로컬 실행 환경은 JRE만 있어 Java 컴파일러 단계에서 실패했으며, JDK 21을 설정한 GitHub 빌드의 산출물을 검증했다. 실행 환경 안내에 맞춰 SDK 캐시·프록시를 구성했지만 로컬 JDK 추가 설치는 이번 결과에 필요하지 않았다.

서명 검증과 빌드 성공은 실제 휴대폰에서의 기능 검증을 대신하지 않는다. 아래 항목은 사용자 기기에서 확인해야 한다.

## 설치

- APK를 휴대폰으로 내려받아 실행한다. Android가 요구하면 파일을 연 브라우저 또는 파일 앱에 대해 앱 설치 권한을 허용한다.
- 앱 목록에서 `Easy Lotto 2차 테스트`를 실행한다. `com.example.easy_lotto.preview2` 패키지로 1차 앱과 구분한다.
- 기존 `Easy Lotto 테스트`는 삭제하지 않는다. 새 앱은 독립 데이터로 실행되므로 1차 앱의 저장 데이터가 새 앱에서 보이지 않는 것은 정상이다.
- 앞으로 같은 `.preview2` 패키지의 업데이트는 동일 서명일 때만 가능하다. 서명 키가 없거나 다르면 빌드를 중단한다.

## 확인할 흐름

1. 비행기 모드에서 첫 실행: 1~1248회 초기 기록으로 추천이 가능해야 한다.
2. 완전 랜덤: 1게임과 5게임을 생성하고, 각 게임이 1~45의 중복 없는 6개인지 확인한다.
3. 상세 설정: 고정수·제외수·홀짝·연속수와 직전 회차·미출현 옵션을 적용한다. 충돌 시 안내를 확인한다.
4. 설정 저장: 이름 없이 저장, 이름 변경, 앱 종료 후 재실행과 마지막 선택 복원을 확인한다.
5. 보관함: 번호 하트와 조합을 저장하고, 앱 재실행 후 복원·수정·삭제를 확인한다.
6. 복권 용지: 선택 게임으로 용지를 만들고 게임 교체·순서 변경을 저장한다. 원본 조합을 삭제해도 용지 번호가 유지돼야 한다.
7. 번호 크게 보기: 최초 안내가 보기 화면 위에 한 번만 표시되는지 확인한다. 기본·용지별·랜덤을 바꾼 뒤 이전 디자인 값이 유지되는지 확인한다.
8. 화면 계속 켜기: 해당 화면에서 켠 뒤 화면이 유지되는지, 뒤로가기·편집 진입·앱 백그라운드에서는 해제되는지 확인한다.
9. 미저장 결과·설정에서 뒤로가기와 재생성 확인을 취소해 기존 내용이 유지되는지 확인한다.
10. 동행복권 출처 링크가 브라우저를 열고, 글자를 크게 설정하거나 화면을 가로로 돌려도 주요 버튼·번호를 볼 수 있는지 확인한다.

현재 날짜에 새 회차가 없으면 네트워크 갱신이 발생하지 않을 수 있다. 이 경우 저장된 데이터 기준 회차가 표시되면 정상이다.

## 결과 전달

기기 모델, Android 버전, 테스트 항목 번호, 누른 버튼과 기대한 결과·실제 결과를 알려주면 재현에 도움이 된다. 오류 화면 캡처는 가능할 때만 첨부한다.

## 아직 출시 전에 필요한 일

실기기 결과 반영, 최종 앱 ID·이름·아이콘 결정, 정식 서명 키 준비, 개인정보처리방침·스토어 소개와 출처 표시 검토, 릴리스 빌드 검증이 필요하다. 이번 APK는 스토어에 게시하지 않는다.
