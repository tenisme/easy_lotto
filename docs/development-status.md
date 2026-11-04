# 구현 상태

2026-11-04 기준.

- 순수 Dart 추천 모델과 엔진: 고정수, 제외수, 홀짝, 고저, 총합, 연속 묶음, 직전 회차 제외, 미출현 개수 검사 구현.
- 일반 조건에서는 균등 무작위 후보를 선택하고, 1,000회 후보 생성으로 충분한 게임을 얻지 못하면 전체 탐색과 reservoir sampling으로 전환한다. 반복 한도 도달만으로 불가능하다고 판단하지 않는다.
- Flutter 기본 화면: 추천 홈의 1~5게임 선택 → 완전 랜덤 생성 → 추천 결과 → 재생성 확인·취소 연결. 생성은 `compute`를 통해 호출한다.
- 상세 설정 UI: 임시 설정으로 고정수·제외수·홀짝·고저·총합·연속 묶음을 입력하고 결과를 생성한다. 결과에서 설정을 수정하거나 같은 설정으로 다시 생성할 수 있다. 연속 묶음 하위 값은 화면 안에서 옵션을 전환해도 유지한다.
- 저장 설정, 보관함·복권 용지, 실제 회차 데이터 동기화는 아직 연결하지 않았다. 회차 기반 옵션은 화면에서 비활성 표시한다. 상세 설정의 영구 저장과 이탈 확인은 후속 단계이며 현재 결과·설정은 세션에만 존재한다.
- `flutter test`: 엔진 및 위젯 테스트 11개 통과.
- `dart tool/check_engine.dart`: 기본 검증과 100회 생성 시간 측정. 개발 환경 측정치는 기기 성능 보장이 아니다.

이 작업 환경의 기본 사용자 디렉터리는 읽기 전용이므로 Flutter 실행 시 `PUB_CACHE=/workspace/.pub-cache`, `XDG_CONFIG_HOME=/workspace/.flutter-config`, `CI=true`와 `--suppress-analytics`를 사용한다. 분석 시에는 `ANALYZER_STATE_LOCATION_OVERRIDE=/workspace/.analyzer-state`도 지정한다. 일반 개발 PC에서는 기본 `flutter test`, `flutter analyze` 명령을 사용한다.
