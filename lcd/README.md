# Text LCD Module (Text LCD 기능)

논리회로실험 팀 프로젝트 - Text LCD 기능 담당 파트

담당: 2313247 변은서

## 요구사항

- 모드 (일반/설정/알람설정/타이머) 표시
- 알람 시각 및 On/Off 표시
- 모드나 알람 값이 바뀌면 화면에 바로 반영

## 화면

```
MODE: ALARM SET
ALARM 07:30  ON
```

| `i_mode` | 1행 |
|---|---|
| 0 | `MODE: CLOCK` |
| 1 | `MODE: CLOCK SET` |
| 2 | `MODE: ALARM SET` |
| 3 | `MODE: TIMER` |

2행은 항상 `ALARM HH:MM  ON` 또는 `ALARM HH:MM  OFF`

## 파일

| 파일 | 설명 |
|---|---|
| `lcd_top.v` | LCD 파트 Top. 팀 통합 시 이 모듈만 인스턴스하면 됨 |
| `lcd_textgen.v` | 모드/알람 입력으로 2행 문구 생성, 10Hz로 화면 갱신 요청 |
| `textlcd.v` | LCD(KS0066) 구동 FSM. 11주차 실습 코드 재사용 |
| `textlcd_nco.v` | 50MHz → 1MHz 분주기 (11주차 그대로) |
| `textgen_nco.v` | 50MHz → 10Hz 분주기 (11주차 그대로, 분주비만 변경해서 사용) |
| `lcd_top_tb.v` | LCD 파트 단독 테스트벤치 |

```
lcd_top.v ──include──> textlcd.v ─────include──> textlcd_nco.v
          └─include──> lcd_textgen.v ─include──> textgen_nco.v
```

## lcd_top.v 인터페이스

### Output

| 신호 | 폭 | 설명 |
|---|---|---|
| `o_lcd_e` | 1 | LCD Enable |
| `o_lcd_rs` | 1 | 0: 명령, 1: 문자 |
| `o_lcd_rw` | 1 | 0: 쓰기, 1: 읽기 (Busy Flag 확인용) |
| `io_lcd_data` | 8 | LCD 데이터, **inout** (Busy Flag 읽기 때문에 양방향) |

### Input

| 신호 | 폭 | 설명 |
|---|---|---|
| `i_mode` | 2 | 0: 일반, 1: 설정, 2: 알람설정, 3: 타이머 |
| `i_alarm_hour` | 5 | 알람 시 (0~23) |
| `i_alarm_min` | 6 | 알람 분 (0~59) |
| `i_alarm_en` | 1 | 알람 On(1) / Off(0) |

### Parameter

| 이름 | 기본값 | 설명 |
|---|---|---|
| `TEXT_FREQDIV` | 5000000 | 화면 갱신 주기 분주비. 50MHz / 5,000,000 = 10Hz (0.1초) |

## 11주차 실습 코드 대비 수정

| 파일 | 수정 | 이유 |
|---|---|---|
| `textlcd.v` | Display ON/OFF `0x0F` → `0x0C` | 커서/커서 깜빡임 OFF. 계속 갱신하는 화면에 커서가 보이지 않게 |
| `textlcd.v` | `init_done` 추가: Clear~Entry Set 초기화는 리셋 후 1번만 | 0.1초마다 Clear하면 화면이 깜빡임. 이후 갱신은 Return Home → 1행 → 2행만 반복 |
| `textgen.v` → `lcd_textgen.v` | 고정 문구 4세트 + 5초 카운터 삭제, 입력으로 문구 생성 | 모드/알람 표시 |

## 통합 시 참고

- 현재 설정 파트 `ctrl`의 모드가 1비트(일반/설정)라서, 알람설정/타이머 모드를 포함한 **2비트 모드 신호**가 필요함
- 알람 시각 저장, On/Off 신호(`i_alarm_hour`, `i_alarm_min`, `i_alarm_en`)를 알람 쪽에서 받아야 함
- `io_lcd_data`는 inout이므로 팀 Top에서도 `inout [7:0]`으로 선언해서 그대로 연결
- 공용 모듈 없음. `textlcd_nco`, `textgen_nco`는 LCD 파트 전용 이름이라 다른 파트와 겹치지 않음

## 단독 검증 방법

### 시뮬레이션

```
iverilog -o lcd_top_tb.vvp lcd_top_tb.v
vvp lcd_top_tb.vvp
```

- 테스트벤치는 `TEXT_FREQDIV = 50000` (갱신 주기 1ms)으로 단축
- LCD 간이 모델(BF/AC/DDRAM)로 실제 화면에 찍히는 2행을 복원해서 기대 문구와 비교
- 모드/알람 입력 5세트 + Clear 명령 1회 + Display ON/OFF `0x0C` 확인
- 마지막에 `RESULT : ALL PASS` 나오면 정상

### 보드 핀 (11주차와 동일)

| 신호 | 방향 | 핀 |
|---|---|---|
| `io_lcd_data[7]` | Bidir | PIN_T11 |
| `io_lcd_data[6]` | Bidir | PIN_R12 |
| `io_lcd_data[5]` | Bidir | PIN_T12 |
| `io_lcd_data[4]` | Bidir | PIN_R13 |
| `io_lcd_data[3]` | Bidir | PIN_T13 |
| `io_lcd_data[2]` | Bidir | PIN_T14 |
| `io_lcd_data[1]` | Bidir | PIN_T15 |
| `io_lcd_data[0]` | Bidir | PIN_F13 |
| `o_lcd_e` | Output | PIN_P11 |
| `o_lcd_rs` | Output | PIN_T10 |
| `o_lcd_rw` | Output | PIN_R11 |

- IDC 케이블 2개 연결, LCD 밝기용 스위치 5V + 전원 케이블 연결
