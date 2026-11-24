# Text LCD Module (Text LCD 기능)

논리회로실험 팀 프로젝트 - Text LCD 기능 담당 파트

담당: 2313247 변은서

## 요구사항

- 모드 (일반/설정/알람설정/타이머) 표시
- 알람 시각 및 On/Off 표시
- 모드나 알람 값이 바뀌면 화면에 바로 반영
- **PSD 활용 : 센서에 손을 갖다 댈 때마다 2행이 현재 시각 → 알람 → 타이머 순으로 전환**

## 화면

```
MODE: CLOCK          MODE: CLOCK          MODE: CLOCK
TIME    12:34:56  →  ALM 07:30:00 ON   →  TMR 00:02:59 RUN  → (처음으로)
        (손 대기)              (손 대기)              (손 대기)
```

| `i_mode` | 1행 |
|---|---|
| 0 | `MODE: CLOCK` |
| 1 | `MODE: CLOCK SET` |
| 2 | `MODE: ALARM SET` |
| 3 | `MODE: TIMER` |

2행은 페이지(`o_page`)에 따라 바뀜

| 페이지 | 2행 | 내용 |
|---|---|---|
| 0 | `TIME    HH:MM:SS` | 현재 시각 |
| 1 | `ALM HH:MM:SS ON ` / `ALM HH:MM:SS OFF` | 알람 시각(시:분:초) + On/Off |
| 2 | `TMR HH:MM:SS RUN` / `TMR HH:MM:SS STP` | 타이머 남은 시간 + 동작/정지 |

### PSD 페이지 전환 규칙 (`lcd_psd_page.v`)

- PSD가 **멀다 → 가깝다**로 바뀌는 순간 1번 전환. 손을 계속 대고 있어도 1번만 넘어감
- 20ms(`PSD_STABLE`)보다 짧은 흔들림은 무시 (센서 출력이 경계값에서 떨려도 여러 번 안 넘어가게)
- 모드가 바뀌면 그 모드에 맞는 페이지로 자동 이동 : 일반/설정 → 시각, 알람설정 → 알람, 타이머 → 타이머
  (설정 중인 값을 LCD에서 바로 볼 수 있게. 이동 후에도 PSD로 다른 페이지 확인 가능)

## 파일

모듈(`.v`)은 `timer.v`와 같이 레포 루트에 있고, `lcd/`에는 테스트벤치, 데모 Top, README만 있음. `top.v`에서 `` `include "lcd_top.v" ``로 사용

| 파일 | 설명 |
|---|---|
| `lcd_top.v` | LCD 파트 Top. 팀 통합 시 이 모듈만 인스턴스하면 됨 |
| `lcd_textgen.v` | 모드/알람 입력으로 2행 문구 생성, 10Hz로 화면 갱신 요청 |
| `textlcd.v` | LCD(KS0066) 구동 FSM. 11주차 실습 코드 재사용 |
| `textlcd_nco.v` | 50MHz → 1MHz 분주기 (11주차 그대로) |
| `textgen_nco.v` | 50MHz → 10Hz 분주기 (11주차 그대로, 분주비만 변경해서 사용) |
| `lcd_psd_page.v` | PSD 손 감지(동기화 + 디바운스 + 상승 엣지) → 2행 페이지 전환 |
| `lcd_top_tb.v` | LCD 파트 단독 테스트벤치 |

```
lcd_top.v ──include──> textlcd.v ─────include──> textlcd_nco.v
          ├─include──> lcd_textgen.v ─include──> textgen_nco.v
          └─include──> lcd_psd_page.v
```

## lcd_top.v 인터페이스

### Output

| 신호 | 폭 | 설명 |
|---|---|---|
| `o_lcd_e` | 1 | LCD Enable |
| `o_lcd_rs` | 1 | 0: 명령, 1: 문자 |
| `o_lcd_rw` | 1 | 0: 쓰기, 1: 읽기 (Busy Flag 확인용) |
| `io_lcd_data` | 8 | LCD 데이터, **inout** (Busy Flag 읽기 때문에 양방향) |
| `o_page` | 2 | 현재 2행 페이지 0:시각 1:알람 2:타이머 (LED 표시 등 디버그용, 안 써도 됨) |

### Input

| 신호 | 폭 | 설명 |
|---|---|---|
| `i_mode` | 2 | 0: 일반, 1: 설정, 2: 알람설정, 3: 타이머 |
| `i_psd` | 1 | PSD 근접 신호. 손을 대면 1 (반대면 `PSD_ACTIVE_LOW=1`) |
| `i_clock_hour` / `i_clock_min` / `i_clock_sec` | 5 / 6 / 6 | 현재 시각 (`clock` 출력) |
| `i_alarm_hour` | 5 | 알람 시 (0~23) |
| `i_alarm_min` | 6 | 알람 분 (0~59) |
| `i_alarm_sec` | 6 | 알람 초 (0~59) |
| `i_alarm_en` | 1 | 알람 On(1) / Off(0) |
| `i_timer_hour` / `i_timer_min` / `i_timer_sec` | 5 / 6 / 6 | 타이머 남은 시간 (`timer` 출력) |
| `i_timer_run` | 1 | 타이머 카운트다운 중 (`timer.o_run`) |

### Parameter

| 이름 | 기본값 | 설명 |
|---|---|---|
| `TEXT_FREQDIV` | 5000000 | 화면 갱신 주기 분주비. 50MHz / 5,000,000 = 10Hz (0.1초) |
| `PSD_ACTIVE_LOW` | 0 | 1이면 `i_psd`가 0일 때를 '손 댐'으로 인식 |
| `PSD_STABLE` | 1000000 | PSD 디바운스 클럭 수. 50MHz 기준 20ms |

## 11주차 실습 코드 대비 수정

| 파일 | 수정 | 이유 |
|---|---|---|
| `textlcd.v` | Display ON/OFF `0x0F` → `0x0C` | 커서/커서 깜빡임 OFF. 계속 갱신하는 화면에 커서가 보이지 않게 |
| `textlcd.v` | `init_done` 추가: Clear~Entry Set 초기화는 리셋 후 1번만 | 0.1초마다 Clear하면 화면이 깜빡임. 이후 갱신은 Return Home → 1행 → 2행만 반복 |
| `textgen.v` → `lcd_textgen.v` | 고정 문구 4세트 + 5초 카운터 삭제, 입력으로 문구 생성 | 모드/알람 표시 |
| `lcd_textgen.v` | 2행을 페이지(시각/알람/타이머)별 문구로 선택 | PSD 화면 전환 |

## 통합 시 참고

- 현재 설정 파트 `ctrl`의 모드가 1비트(일반/설정)라서, 알람설정/타이머 모드를 포함한 **2비트 모드 신호**가 필요함
- 알람 시각 저장, On/Off 신호(`i_alarm_hour`, `i_alarm_min`, `i_alarm_sec`, `i_alarm_en`)를 알람 쪽에서 받아야 함
- PSD : 10주차 PSD 회로에서 나오는 '가깝다' 1비트 신호를 `i_psd`에 연결. 거리값(ADC)으로 나오면 Top에서 `psd_value > 기준값` 비교 결과를 연결
- 시각/타이머 값은 `top`의 `clock_hour/min/sec`, `timer_hour/min/sec`, `timer_run`을 그대로 연결 (아래 예시)
- `io_lcd_data`는 inout이므로 팀 Top에서도 `inout [7:0]`으로 선언해서 그대로 연결
- 공용 모듈 없음. `textlcd_nco`, `textgen_nco`는 LCD 파트 전용 이름이라 다른 파트와 겹치지 않음

### top 연결 (통합 완료)

```verilog
lcd_top
u_lcd_top(
    .o_lcd_e        (o_lcd_e        ),
    .o_lcd_rs       (o_lcd_rs       ),
    .o_lcd_rw       (o_lcd_rw       ),
    .io_lcd_data    (io_lcd_data    ),
    .o_page         (               ),
    .i_mode         (mode           ),
    .i_psd          (i_psd          ),
    .i_clock_hour   (clock_hour     ),
    .i_clock_min    (clock_min      ),
    .i_clock_sec    (clock_sec      ),
    .i_alarm_hour   (alarm_hour     ),
    .i_alarm_min    (alarm_min      ),
    .i_alarm_sec    (alarm_sec      ),
    .i_alarm_en     (alarm_en       ),
    .i_timer_hour   (timer_hour     ),
    .i_timer_min    (timer_min      ),
    .i_timer_sec    (timer_sec      ),
    .i_timer_run    (timer_run      ),
    .i_clk          (i_clk          ),
    .i_rstn         (i_rstn         )
);
```

## 단독 검증 방법

### 시뮬레이션

```
iverilog -o lcd_top_tb.vvp lcd/lcd_top_tb.v   # 레포 루트에서 실행
vvp lcd_top_tb.vvp
```

- 테스트벤치는 `TEXT_FREQDIV = 50000` (갱신 주기 1ms)으로 단축
- LCD 간이 모델(BF/AC/DDRAM)로 실제 화면에 찍히는 2행을 복원해서 기대 문구와 비교
- 테스트벤치는 `PSD_STABLE = 100` (디바운스 100클럭)으로 단축
- 화면 14세트 + Clear 명령 1회 + Display ON/OFF `0x0C` 확인
  - PSD로 시각 → 알람 → 타이머 → 시각 전환
  - 디바운스보다 짧은 PSD 흔들림은 무시
  - 손을 계속 대고 있어도 1번만 전환
  - 모드 변경 시 해당 페이지로 자동 이동
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

## 보드 단독 검증 (PSD 화면 전환)

`lcd/lcd_psd_demo_top.v`를 Top으로 설정하고 컴파일 (Quartus 프로젝트 폴더는 레포 루트). 팀 통합 시에는 쓰지 않음.

- 시각은 12:00:00부터 증가, 알람은 07:30 ON 고정, 타이머는 00:03:00부터 감소 (가짜 값)
- `i_btn_mode` 버튼 : 모드 0 → 1 → 2 → 3 순환 (1행 모드 변경 + 2행 자동 이동 확인)
- `i_psd` : PSD 신호 연결. 손을 댈 때마다 2행이 시각 → 알람 → 타이머로 바뀌면 정상
  - 거꾸로 동작(손 떼면 바뀜)하면 `PSD_ACTIVE_LOW = 1`
- `i_btn_psd` 버튼 : PSD 대신 눌러서 페이지 전환 확인용 (PSD 연결 전 테스트)
- 버튼은 눌렀을 때 0인 기준. LCD 핀은 위 표와 동일, `i_psd`/버튼 핀은 보드에 맞게 지정
