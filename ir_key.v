module ir_key
#(
    parameter HOLD = 10000000
)
(
    output [7:0] o_sw,
    output reg [7:0] o_cmd,
    input [31:0] i_data,
    input i_valid,
    input i_clk,
    input i_rstn
);

localparam KEY_MENU  = 8'h40;
localparam KEY_LEFT  = 8'h10;
localparam KEY_RIGHT = 8'h50;
localparam KEY_UP    = 8'hA0;
localparam KEY_PLUS  = 8'h20;
localparam KEY_DOWN  = 8'hB0;
localparam KEY_MINUS = 8'h30;
localparam KEY_OK    = 8'h90;
localparam KEY_BACK  = 8'h60;
localparam KEY_NUM1  = 8'h08;
localparam KEY_NUM2  = 8'h88;
localparam KEY_NUM3  = 8'h48;
localparam KEY_NUM4  = 8'h28;
localparam KEY_NUM5  = 8'hA8;
localparam KEY_NUM6  = 8'h68;

wire [7:0] cmd = i_data[15:8];
wire [7:0] cmd_n = i_data[7:0];
wire cmd_ok = (cmd == ~cmd_n);

reg [7:0] key;

always @(*) begin
    case(cmd)
        KEY_MENU,  KEY_NUM1:           key = 8'b0000_0001;
        KEY_LEFT,  KEY_RIGHT, KEY_NUM2: key = 8'b0000_0010;
        KEY_UP,    KEY_PLUS,  KEY_NUM3: key = 8'b0000_0100;
        KEY_DOWN,  KEY_MINUS, KEY_NUM4: key = 8'b0000_1000;
        KEY_OK,    KEY_NUM5:           key = 8'b0001_0000;
        KEY_BACK,  KEY_NUM6:           key = 8'b0010_0000;
        default:                       key = 8'b0000_0000;
    endcase
end

reg [2:0] valid_s;
wire valid_rise = valid_s[1] & ~valid_s[2];

reg [7:0] press;
reg [$clog2(HOLD+1)-1:0] hold_cnt;

always @(posedge i_clk or negedge i_rstn) begin
    if(!i_rstn) begin
        valid_s <= 3'b000;
        press <= 8'd0;
        hold_cnt <= 0;
        o_cmd <= 8'd0;
    end else begin
        valid_s <= {valid_s[1:0], i_valid};
        if(valid_rise && cmd_ok) begin
            o_cmd <= cmd;
        end
        if(hold_cnt != 0) begin
            hold_cnt <= hold_cnt - 1;
            if(hold_cnt == 1) begin
                press <= 8'd0;
            end
        end else if(valid_rise && cmd_ok && key != 8'd0) begin
            press <= key;
            hold_cnt <= HOLD;
        end
    end
end

assign o_sw = ~press;

endmodule
