# 통합 정리 (local/integration)

보드에서 7세그먼트 · LCD · 버저 · 버튼 동작 확인 완료. PSD는 추가 후 확인 예정.

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
| `alarm` | `i_clk`, `i_down`, `i_tick`, `i_stop` | 없음 |
| `alarm_cnt` | `i_en`, `i_down` | 없음 |
| `arbiter` | `i_timer_hour` | 없음 |
| `setting_top` | `o_buzzer`, `o_lcd_e`, `o_lcd_rs`, `o_lcd_rw`, `io_lcd_data`, `o_sclk`, `o_csn`, `o_din`, `i_dout` | `o_mode` 삭제 (아무 데도 안 쓰이는데 핀만 차지했음) |

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

보드 없이 전체 기능을 확인할 수 있음. 레포 폴더에서 실행할 것.

```bash
iverilog -g2012 -I lcd -o setting_top_tb.out setting_top_tb.v
vvp setting_top_tb.out
```

- `-g2012` 없으면 `syntax error` 가 남
- `-I lcd` 없으면 `lcd/lcd_top.v` 안의 `` `include "textlcd.v" `` 를 못 찾음

12단계로 확인하고 맨 아래 **`FAIL : 0`** 이면 전부 통과.

| 단계 | 확인 내용 |
|---|---|
| 1 | 리셋값 `00 00.00`, 버저 꺼짐 |
| 2 | 시계 1초 진행, 59초에서 분 자리올림 |
| 3 | 모드 전환 시 초가 튀지 않는지 |
| 4 | 시계 설정 증감, 설정 중 정지, 자리올림·자리내림 |
| 5 | 알람 설정 증감, 알람 ON |
| 6 | 알람을 현재 시각 +20초로 맞추고 실제로 5초 울리는지 |
| 7 | LCD 문구. 모드별 1행, 알람 2행, Clear 1회, 커서 OFF |
| 8 | 타이머 설정과 7세그 표시 (시·분·초) |
| 9 | sw5 초기화 |
| 10 | 카운트다운과 버저 5초 |
| 11 | 타이머 동작 중 다른 모드로 가도 제대로 감소하는지 |
| 12 | PSD 값을 강제로 올려 버저가 꺼지는지 |

LCD 파트 단독 검증은 `lcd/lcd_top_tb.v` 를 그대로 쓰면 됨.

```bash
cd lcd
iverilog -g2012 -o lcd_top_tb.out lcd_top_tb.v
vvp lcd_top_tb.out
```

---

## 다른 PC에서 받아서 실행하는 법

### 0. 필요한 것

| 항목 | 값 |
|---|---|
| Quartus | Prime 23.1std Lite Edition |
| 보드 | DE0-Nano 가 꽂힌 HBE-CapstoneMulti |
| Device | Cyclone IV E **EP4CE22F17C6** |
| Top-level entity | **`setting_top`** |
| 시뮬레이션 (선택) | Icarus Verilog |

### 1. 받기

```bash
git clone https://github.com/reasonis06/team-project.git
cd team-project
git checkout feat/integration
```

이미 받아뒀으면

```bash
git fetch origin
git checkout feat/integration
git pull
```

클론한 폴더가 곧 Quartus 프로젝트 폴더임. 폴더를 옮기거나 이름을 바꿔도 되고,
경로에 **한글이나 공백은 피하는 게 안전함.**

### 2. 프로젝트 열기

레포에 `setting_top.qpf` 와 `setting_top.qsf` 가 들어 있음.
Top-level entity, 디바이스, 핀 40개, 검색 경로가 전부 저장돼 있어서 **설정할 게 없음.**
`.qsf` 에 절대경로가 없어서 어느 PC에서 열어도 그대로 동작함.

1. Quartus 실행
2. **File - Open Project...**
3. 클론한 폴더의 **`setting_top.qpf`** 선택 - Open

> **New Project Wizard 로 새로 만들지 말 것.** 저장된 핀 40개와 검색 경로가 전부 날아감.
> 실수로 새로 만들었으면 아래 "프로젝트를 새로 만들어야 할 때" 를 볼 것.

### 3. 컴파일

**Processing - Start Compilation** (2~3분)

끝나면 `output_files/setting_top.pin` 을 열어 확인. 아래가 전부 맞아야 함.

| 신호 | 핀 |
|---|---|
| `i_clk` | R8 |
| `i_rstn` | J15 |
| `o_buzzer` | **C8** |
| `io_lcd_data[0]` | **L16** |
| `o_lcd_e` / `o_lcd_rs` / `o_lcd_rw` | B6 아님 - **L14 / N15 / P14** |
| `i_dout` / `o_csn` / `o_din` / `o_sclk` | **A9 / A10 / B10 / B14** |

Fitter 요약의 **Total pins 가 40** 이어야 함.

- 36이면 PSD 포트가 빠진 것
- `o_seg[5] : C8` 처럼 다른 신호가 C8 에 있으면 핀 할당이 안 들어간 것.
  그 상태로 보드에 올리면 **버저가 계속 울림**

### 4. 보드 케이블 연결

| 모듈 | 꽂는 헤더 (silkscreen 번호) |
|---|---|
| 7세그 데이터 | `FPGA GPIO-2` 의 `0 1 2 3 4 5 6 7` |
| 7세그 enable | `FPGA GPIO-2` 의 `8 9 10 11 12 13 14 15` |
| LCD 데이터 | `FPGA GPIO-2` 의 `16 17 18 19 20 21 22 23` |
| LCD 제어 | `FPGA GPIO-2` 의 `24 25 26 27 28 29 30 31` |
| 키패드 | `FPGA GPIO-1` 의 `24 25 26 27 28 29 30 31` |
| 버저 | `FPGA GPIO-1` 의 `16 17 18 19 20 21 22 23` |
| PSD 센서 | 센서 모듈 케이블만 연결 (DE0-Nano 내장 ADC 사용) |

보드 silkscreen 표기 기준임. `FPGA GPIO-2` = Altera `GPIO_1`(JP2), `FPGA GPIO-1` = Altera `GPIO_0`(JP1).

LCD 는 IDC 케이블 2개 외에 **전원 케이블과 밝기 조절 스위치(5V)** 도 연결해야 함.
모듈 구석의 **빨간 LED 가 켜지는지**로 전원이 들어갔는지 확인할 수 있음.
빨간 LED 가 꺼져 있으면 핀과 무관하게 화면이 깜깜함.

### 5. 보드에 올리기

1. **Tools - Programmer**
2. **Hardware Setup...** - Currently selected hardware 에서 **USB-Blaster** - Close
3. **Auto Detect** - 목록에 `EP4CE22` 가 뜨면 선택
4. 그 줄을 클릭해서 선택한 뒤 **Change File** - `output_files/setting_top.sof`
5. 그 줄의 **Program/Configure** 체크
6. **Start** - Progress 100%

두 번째부터는 파일이 기억되므로 **Start** 만 누르면 됨.

### 6. 올라갔는지 빠르게 확인

1. 리셋(J15) - 7세그에 `00 00.00`
2. 가만히 두면 초가 1초마다 증가
3. 아무 소리도 나지 않음
4. LCD 1행 `MODE: CLOCK`, 2행 `ALARM 00:00  OFF`
5. PSD 센서 앞에 손을 대면 7세그 **오른쪽 끝 자리 소수점**이 켜짐

이 다섯 개가 되면 핀과 케이블이 전부 맞은 것임. 이후 기능 확인은 아래 "버튼" 절 참고.

---

### 프로젝트를 새로 만들어야 할 때

`.qpf` 를 잃어버렸거나 실수로 Wizard 로 새로 만든 경우에만 해당함.

1. **File - New Project Wizard** - Next
2. Working directory : 클론한 폴더 / Project name : `setting_top` / Top-level entity : `setting_top`
3. Project Type : Empty project
4. **Add Files : `setting_top.v` 하나만.**
   나머지는 `setting_top.v` 안의 `` `include `` 로 들어감.
   여러 개 넣으면 모듈이 중복 정의돼서 에러남. `lcd/` 폴더 안의 파일도 넣지 말 것
5. Family `Cyclone IV E`, Device **`EP4CE22F17C6`**
   목록이 길면 Package `FBGA`, Pin count `256`, Speed grade `6` 으로 거르기
6. Finish
7. **View - Utility Windows - Tcl Console** 을 열고 아래를 그대로 붙여넣기

```tcl
cd [get_project_directory]
set_global_assignment -name SEARCH_PATH lcd
source pin.tcl
source pin_lcd.tcl
export_assignments
```

`cd [get_project_directory]` 가 핵심임. Tcl Console 의 현재 폴더가 프로젝트 폴더가
아닐 수 있어서 이 줄이 없으면 `couldn't read file "pin.tcl"` 에러가 남.
경로를 직접 쓰려면 **슬래시**와 중괄호를 쓸 것. 예: `source {D:/work/team-project/pin.tcl}`

`SEARCH_PATH` 는 `setting_top.v` 가 `` `include "lcd/lcd_top.v" `` 로 LCD 를 가져오는데
`lcd_top.v` 안에서는 다시 같은 폴더 기준으로 `` `include "textlcd.v" `` 를 부르기 때문에 필요함.

제대로 들어갔는지 확인

```tcl
get_location_assignment -to io_lcd_data[0]
get_location_assignment -to i_dout
```

→ 각각 **`PIN_L16`**, **`PIN_A9`** 가 나와야 함. 그다음 3번부터 이어서 진행.

### 자주 나는 문제

| 증상 | 원인 | 해결 |
|---|---|---|
| `Can't open include file "textlcd.v"` | SEARCH_PATH 누락 | Tcl Console 에서 `set_global_assignment -name SEARCH_PATH lcd` |
| `couldn't read file "pin.tcl"` | Tcl Console 의 현재 폴더가 다름 | `cd [get_project_directory]` 먼저 |
| 모듈 중복 정의 에러 | Add Files 에 여러 파일을 넣음 | `setting_top.v` 하나만 남기기 |
| `Node "i_dout" ... does not exist in design` | 소스가 옛 버전 | `git pull` 후 재컴파일 |
| Total pins 가 36 | PSD 포트 또는 핀 누락 | 위와 동일 |
| 보드에서 버저가 계속 울림 | `o_buzzer` 핀 미할당 | `.pin` 에서 C8 확인, 핀 스크립트 재실행 |
| 7세그가 안 뜸 | 7세그 케이블 2개 중 하나 누락 | GPIO-2 의 0~7, 8~15 둘 다 연결 |
| 버튼이 아무 반응 없음 | 키패드 케이블 미연결 | GPIO-1 의 24~31 헤더 |
| LCD 백라이트가 안 켜짐 | 모듈 전원 | 전원 케이블, 밝기 스위치 5V, 빨간 LED 확인 |
| LCD 글자가 깨짐 | 데이터·제어 케이블이 바뀜 | 두 케이블 서로 바꿔 꽂기 |
| PSD 소수점이 반응 없음 | 센서 미연결 또는 임계값 | `psd_stop` 의 `TH_ON` / `TH_OFF` 조정 |
| 시뮬에서 `syntax error` | `-g2012` 누락 | 명령에 `-g2012 -I lcd` 둘 다 넣기 |

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

## PSD : 손으로 버저 끄기

버저가 울리는 중에 PSD 센서에 손을 가까이 대면 알람이나 타이머가 멈춤.

### 동작

```
psd        ADC 값 12비트 읽기 (10주차 코드 그대로, ADC 채널 IN0)
psd_stop   임계값 판정 -> 손이 가까워지는 순간 1클럭 펄스
setting_top  psd_stop_pulse = psd_detect & (alarm_ring | timer_expire)
```

`alarm_ring` 이나 `timer_expire` 가 1일 때만 펄스를 내보냄.
그래서 지나가다 손이 닿아도 **시계나 동작 중인 타이머는 건드리지 않음.**

- 알람 → `alarm.i_stop` 으로 들어가 울림 즉시 정지.
  같은 초 안에서 다시 울리지 않도록 `armed` 잠금을 둠
- 타이머 → `timer.i_clear` 로 들어가 종료 상태에서 정지 상태로 복귀

### 판정 기준

10주차 측정값 기준 (손 없음 `0x136`, 손 가까이 `0x91A`).

| 파라미터 | 기본값 | 의미 |
|---|---|---|
| `TH_ON` | `12'h500` | 이 값 이상이면 손이 가까움 |
| `TH_OFF` | `12'h300` | 이 값 이하로 내려가야 멀어진 것으로 봄 |
| `HOLD` | `500000` | 같은 상태가 10ms 유지돼야 인정 (노이즈 제거) |

켜짐·꺼짐 기준을 다르게 둬서 경계에서 떨리지 않음.
센서나 조명 환경에 따라 값이 다르면 `setting_top.v` 의 `psd_stop` 인스턴스에서
파라미터만 바꾸면 됨.

### 핀

| 신호 | 핀 | 비고 |
|---|---|---|
| `o_sclk` | B14 | DE0-Nano 내장 ADC |
| `o_csn` | A10 | |
| `o_din` | B10 | |
| `i_dout` | A9 | |

확장 헤더가 아니라 DE0-Nano 내장 ADC 핀이라 다른 핀과 겹치지 않음.
PSD 센서 모듈 케이블만 연결하면 됨.

### 표시

7세그 **오른쪽 끝 자리 소수점**이 PSD가 손을 감지하는 동안 켜짐.
센서가 살아 있는지 눈으로 확인하는 용도.

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
