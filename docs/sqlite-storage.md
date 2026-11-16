# SQLite 저장과 이관

2026-11-05 구현 기준. Android/iOS/macOS는 sqflite를 사용하며 데이터베이스 파일은 플랫폼의 앱 전용 DB 경로에 `easy_lotto.db`로 생성한다.

## 저장 구조

- 설정: `presets`에 ID·이름·옵션 JSON·정렬 위치, 마지막 선택 ID는 `metadata`.
- 내 번호: `favorite_numbers`에 숫자당 한 행.
- 저장한 조합: `number_sets`와 `number_set_items`. 조합 중복은 정렬된 번호에서 만든 키로 방지한다.
- 복권 용지: `lottery_papers`, `lottery_paper_games`, `lottery_paper_game_items`. 게임은 용지별 번호 사본이며 원본 조합의 삭제와 독립적이다.
- 회차: `draw_results`와 `draw_main_numbers`. 이미 같은 값인 회차는 다시 쓰지 않는다.
- 보기 디자인, 최초 안내 확인, 마지막 조회 주기: 작은 설정 값으로 `metadata`에 저장한다.

숫자 범위·중복·용지 내 위치 제약, 외래키와 연쇄 삭제를 적용한다. 6개 번호·보너스 중복·1~5게임은 저장 계층에서 검증한다. 현재 화면 저장소의 문서 단위 계약을 유지하기 위해 `LocalStorage`가 테이블과 기존 JSON 모델 사이를 변환한다. 화면 저장 모델을 직접 SQL에 종속시키지 않는다. 기존 모델에 없던 생성·수정 시각과 XLSX에 없는 추첨일은 이번 이관에서 임의로 생성하지 않았다.

## 자동 이관

`migration.v1` 표시가 없을 때 이전 설정·보관함·용지·회차·보기 옵션을 SharedPreferences에서 읽는다. 모든 변환과 완료 표시는 한 트랜잭션으로 저장한다. 한 항목이라도 잘못되면 전체를 롤백하고 DB 연결을 닫아 다음 시도에서 다시 이관한다. 원본 SharedPreferences는 삭제하거나 새 데이터로 덮어쓰지 않는다.

완료 표시가 있으면 SQLite만 사용하므로 오래된 원본이 새 데이터를 덮어쓰지 않는다. 개별 저장도 트랜잭션이며 실패하면 이전 내용과 메모리 표시를 유지한다. 지원하지 않는 손상된 원본은 조용히 버리지 않고 이관 오류로 처리한다. 사용자용 복원·내보내기 UI는 아직 없다.

## 검증

`migration_test.dart`는 실제 파일 DB에서 전체 종류 이관, 재연결 후 재이관 방지, 원본 보존, 실패 후 재시도와 부분 쓰기 롤백을 검사한다. 일부 저장소 단위 테스트도 실제 SQLite를 사용한다. 위젯 테스트에서는 외부 IO와 가상 시간이 충돌하지 않도록 테스트용 메모리 저장을 주입한다.

데스크톱 테스트는 sqflite_common_ffi와 OS SQLite를 사용한다. Linux는 `libsqlite3.so`, macOS는 `libsqlite3.dylib`, Windows는 `winsqlite3.dll`이 필요하다. 이 원격 환경에는 버전 이름인 `libsqlite3.so.0`만 있어 `/workspace/.sqlite-test/libsqlite3.so` 링크를 만들고 `LD_LIBRARY_PATH=/workspace/.sqlite-test`를 테스트 명령에 지정했다. Android 앱은 sqflite 플랫폼 구현을 사용하므로 이 데스크톱 테스트 설정에 의존하지 않는다. 실기기 앱 업데이트 이관 검증은 아직 남아 있다.
