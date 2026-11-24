# 통합 정리 (local/integration)

보드에서 7세그먼트 · LCD · 버저 · 버튼 전부 동작 확인 완료.

`setting_top.v`를 전체 통합 Top으로 만들고, 네 파트를 실제로 연결했음.
모듈명은 전부 그대로고 기존 포트는 지우거나 이름을 바꾸지 않았음. 필요한 포트만 추가했음.

## 파일별 변경

| 파일 | 담당 | 변경 |
|---|---|---|
| `setting_top.v` | 설정 | 전체 통합. 버저·LCD 인스턴스 추가, `i_clk` 연결, timer 시·분·초 연결, `i_tick`을 `o_tick`에, `i_clear`를 sw5에 |
| `ctrl.v` | 설정 | 동기 설계로 재작성. 포트 3개 추가 (`o_timer_set_hour`, `o_timer_clear`, `o_tick`) |
| `clock.v` | 설정 | `i_clk` 추가. 자리올림·자리내림을 이 모듈 안에서 처리 |
| `clock_cnt.v` | 설정 | `i_en` 추가. `i_clk` 동기. `o_max` 조합. 리셋값 0 |
| `arbiter.v` | 설정 | 타이머 모드의 분·시 연결 수정, `i_timer_hour` 추가 |
| `alarm.v` | 알람 | 울림 5초 유지 추가. `i_clk`, `i_down`, `i_tick` 추가 |
| `alarm_cnt.v` | 알람 | `i_en`, `i_down` 추가. 감소 동작 |
| `timer.v` | 타이머 | **변경 없음** |
| `lcd/` | LCD | **변경 없음** |
| `ssegdisp*.v`, `buzzer*.v`, `ctrl_nco.v`, `ctrl_debouncer.v` | — | 변경 없음 |
| `setting_top_tb.v` | — | 신규. 통합 전체 기능 자동 점검 |
| `pin.tcl`, `pin_lcd.tcl` | — | 신규 |

### 포트 변화 요약

| 모듈 | 추가 | 삭제·개명 |
|---|---|---|
| `ctrl` | `o_timer_set_hour`, `o_timer_clear`, `o_tick` | 없음 |
| `clock` | `i_clk` | 없음 |
| `clock_cnt` | `i_en` | 없음 |
| `alarm` | `i_clk`, `i_down`, `i_tick` | 없음 |
| `alarm_cnt` | `i_en`, `i_down` | 없음 |
| `arbiter` | `i_timer_hour` | 없음 |
| `setting_top` | `o_buzzer`, `o_lcd_e`, `o_lcd_rs`, `o_lcd_rw`, `io_lcd_data` | `o_mode` 삭제 (아무 데도 안 쓰이는데 핀만 차지했음) |

---

## 고친 문제

| 문제 | 고친 방법 |
|---|---|
| 통합 Top이 컴파일된 적 없음 | `setting_top.v`가 `alarm.v`, `timer.v`를 include하는데 다른 브랜치에 있었음. 이제 한 브랜치에 다 있고 포트도 맞춰짐 |
| 타이머 모드에서 분이 알람 분으로 표시됨 | `arbiter.v`의 `min = i_alarm_min` → `i_timer_min`. 시도 `i_timer_hour` 연결 |
| 알람이 1초만 울림 | `alarm.v`에 울림 유지 카운터 추가 (`RING_SEC = 5`). 울리는 중 OFF하면 즉시 정지 |
| 알람 감소 버튼이 증가로 동작 | `alarm_cnt.v`에 `i_down` 추가. `ctrl`의 `o_alarm_down`을 실제로 연결 |
| 보드에서 버저가 계속 울림 | `o_buzzer` 포트와 `buzzer` 인스턴스 추가. 핀 미할당 시 약한 풀업 때문이었음 |
| 타이머 초기화 버튼 없음 | sw5 → `o_timer_clear` → `timer.i_clear` |
| 모드를 바꾸면 타이머가 멈추거나 튐 | `timer.i_tick`을 `ctrl.o_tick`(모드 무관 1Hz 펄스)에 연결 |
| 알람 ON/OFF를 7세그에서 알 수 없음 | 왼쪽 끝 자리 소수점으로 표시 |
| 모드를 바꾸는 순간 초가 한 칸 뜀 | 게이티드 클럭 제거 (아래) |
| 설정에서 59 다음 윗자리가 안 올라감 | 자리올림을 `clock.v` 안으로 옮김 (아래) |
| LCD가 통합 안 됨 | `setting_top`에 `lcd_top` 인스턴스 추가 |

---

## 설계가 바뀐 부분 두 가지

### 1. 게이티드 클럭 제거

원본은 `ctrl`이 만든 신호를 카운터의 **클럭 입력**으로 썼음.

```
o_sec_clk  ->  clock_cnt 의 i_clk
sw[0]      ->  모드 레지스터의 클럭
```

모드가 바뀌면 `o_sec_clk`의 연결 대상이 `clk_1hz`와 설정 펄스 사이에서 갈아끼워지는데,
그 순간 `clk_1hz`가 1이면 그대로 상승엣지가 되어 초가 한 칸 뜀.
`always @(*)`에서 기본값 0을 넣고 case에서 다시 대입하는 구조라 같은 시각에 `1 -> 0 -> 1`도 생김.

수정 후에는 모든 레지스터가 `i_clk`(50MHz) 하나로 돌고,
`o_sec_clk` 같은 신호는 **1클럭 폭 enable 펄스**가 됨. 이름은 그대로지만 의미가 달라졌음.

| 신호 | 원본 | 수정 후 |
|---|---|---|
| `ctrl.o_sec_clk` 등 | 50% 듀티 클럭 | 1클럭 폭 enable 펄스 |
| `clock_cnt.i_clk` | 카운트 트리거 | 50MHz 시스템 클럭 |
| `clock_cnt.o_max` | 레지스터, 1초간 유지 | 조합, 지금 값이 MAX면 1 |

### 2. 자리올림을 clock.v 안으로

증상: 설정 모드에서 초를 59에서 올리면 00이 되는데 분이 그대로였음.
원인: 자리올림 경로가 일반 동작에만 있었음.

```
sec_carry = i_sec_clk && (i_down ? (o_sec == 0) : (o_sec == 59))
min_en    = i_min_clk | sec_carry
min_carry = min_en    && (i_down ? (o_min == 0) : (o_min == 59))
hour_en   = i_hour_clk | min_carry
```

일반 동작과 설정 모드가 같은 규칙으로 동작함.
자리별 독립 설정이 낫다고 판단하면 `clock.v`에서 `sec_carry`, `min_carry`를 `1'b0`으로 두면 됨.

---

## 시뮬레이션

```
cd C:\Users\seeun\lab\team-project
iverilog -g2012 -I lcd -o setting_top_tb.out setting_top_tb.v
vvp setting_top_tb.out
```

`-I lcd` 가 필요함. `lcd/lcd_top.v` 안의 `include "textlcd.v"` 를 찾기 위해서임.

11단계로 확인하고 맨 아래 `FAIL : 0` 이면 전부 통과.

1. 리셋값
2. 시계 1초 진행과 59초 자리올림
3. 모드 전환 시 초가 튀지 않는지
4. 시계 설정 증감, 설정 중 정지, 자리올림·자리내림
5. 알람 설정 증감, 알람 ON
6. 알람을 현재 시각 +20초로 맞추고 실제로 5초 울리는지
7. LCD 문구 (모드별 1행, 알람 2행, Clear 1회, 커서 OFF)
8. 타이머 설정과 7세그 표시 (시·분·초)
9. sw5 초기화
10. 카운트다운과 버저 5초
11. 타이머 동작 중 다른 모드로 가도 제대로 감소하는지

LCD 파트 단독 검증은 기존 `lcd/lcd_top_tb.v` 를 그대로 쓰면 됨.

---

## Quartus

1. File → Open Project → setting_top.qpf
2. Processing → Start Compilation
3. Tools → Programmer → Start

### LCD 핀 배치

LCD 신호 11개가 11주차 핀 그대로면 7세그먼트 핀과 완전히 겹침.
그래서 LCD를 같은 GPIO_1 의 뒤쪽 헤더 두 개로 옮겼음. `pin_lcd.tcl` 에 들어 있음.

보드 silkscreen 의 `FPGA GPIO-2` 는 Altera DE0-Nano 기준 **GPIO_1 (JP2)** 임.
번호에서 핀 이름은 DE0-Nano User Manual Table 3-7 기준.

| 헤더 (silkscreen 번호) | 핀 이름 | 용도 |
|---|---|---|
| GPIO_1 0~7 | `F13 T15 T14 T13 R13 T12 R12 T11` | 7세그 데이터 |
| GPIO_1 8~13 | `T10 R11 P11 R10 N12 P9` | 7세그 enable |
| GPIO_1 16~23 | `L16 K16 R16 L15 P15 P16 R14 N16` | **LCD 데이터** |
| GPIO_1 24~26 | `N15 P14 L14` | **LCD rs / rw / e** |
| GPIO_0 16 | `C8` | 버저 |
| GPIO_0 24~31 | `C9 D9 E11 E10 C11 B11 A12 D11` | 키패드 |

케이블 연결

```
7세그 케이블      -> GPIO_1  0~7  헤더, 8~15 헤더
LCD 데이터 케이블 -> GPIO_1 16~23 헤더
LCD 제어 케이블   -> GPIO_1 24~31 헤더
키패드 케이블     -> GPIO_0 24~31 헤더
버저 케이블       -> GPIO_0 16~23 헤더
```

7세그와 LCD가 같은 GPIO_1 안의 서로 다른 구간을 쓰므로 **동시 사용 가능함.**

---

## 버튼

| 버튼 | 핀 | 기능 |
|---|---|---|
| `i_rstn` | J15 | 리셋 |
| `i_sw[0]` | C9 | 모드 전환. 일반 → 시계설정 → 알람설정 → 타이머 → 일반 |
| `i_sw[1]` | D9 | 자리 전환. 초 → 분 → 시 → 초 |
| `i_sw[2]` | E11 | 값 증가 |
| `i_sw[3]` | E10 | 값 감소 |
| `i_sw[4]` | C11 | 알람설정: 알람 ON/OFF · 타이머: 시작 / 일시정지 |
| `i_sw[5]` | B11 | 타이머: 00:00:00 으로 초기화 |

7세그는 `시시 분분.초초`. 왼쪽 끝 자리 소수점이 켜져 있으면 알람 ON.
설정 모드에서는 선택한 자리가 1초 주기로 깜빡임. 리셋값은 `00 00.00`.
LCD는 1행에 현재 모드, 2행에 `ALARM HH:MM  ON/OFF`.
