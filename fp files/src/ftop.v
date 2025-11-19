`timescale 1ns / 1ps
module ftop(
    input clk,
    input btnU, // reset
    input btnC, // start
    input btnR, // next sequence
    input [15:0] sw, // switches
    output reg [15:0] led // LEDs
);

    // estados
    localparam s0 = 3'd0, s1 = 3'd1, s2 = 3'd2, s3 = 3'd3, s4 = 3'd4, s5= 3'd5, s6= 3'd6;

    reg [2:0] state, next_state;

    reg [31:0] op_a_32, op_b_32;
    reg [1:0] op_code;
    reg mode_fp, round_mode;

    wire [31:0] result_32;
    wire [4:0] flags_out;
    wire valid_out_w;

    // Control de visualización
    reg [1:0] show_seq = 0; // 0: low16, 1: high16, 2: flags
    reg [15:0] led_next;

    // Instancia de ALU flotante
    falu aluuu (.clk(clk),.rst(btnU),.start(btnC),.op_a(op_a_32),.op_b(op_b_32),.op_code(op_code),.mode_fp(mode_fp),.round_mode(round_mode),
    .result(result_32),.valid_out(valid_out_w),.flags(flags_out));

    // Control de estado
    always @(posedge clk) begin
        if (btnU)
            state <= s0;
        else begin
            case (state)
                s0: if (btnC) state <= s1;
                s1: if (btnR) state <= s2;
                s2: if (btnR) state <= s3;
                s3: if (btnR) state <= s4;
                s4: if (btnR) state <= s5;
                s5: if (btnC) state <= s6;
                s6: state <= s6;
            endcase
        end
    end

    // cargar datos según el estado
    always @(posedge clk) begin
        if (btnU) begin
            op_a_32 <= 0;
            op_b_32 <= 0;
            op_code <= 0;
            mode_fp <= 0;
            round_mode <= 0;
        end else begin
            case (state)
                s1: begin
                    op_code <= sw[15:14];
                    mode_fp <= sw[13];
                    round_mode <= sw[12];
                end
                s2:  op_a_32[15:0]  <= sw;
                s3: op_a_32[31:16] <= sw;
                s4:  op_b_32[15:0]  <= sw;
                s5: op_b_32[31:16] <= sw;
            endcase
        end
    end

    // Control de secuencia de LEDs
    always @(posedge clk) begin
        if (btnU)
            show_seq <= 0;
        else if (state == s6 && btnR)
            show_seq <= (show_seq == 2) ? 0 : show_seq + 1;
    end

    // Selección de datos a mostrar
    always @(*) begin
        case (show_seq)
            0: led_next = result_32[15:0];
            1: led_next = result_32[31:16];
            2: led_next = {flags_out, valid_out_w, 10'b0};
            default: led_next = 16'b0;
        endcase
    end

    // Actualización de LEDs
    always @(posedge clk) begin
        if (btnU)
            led <= 0;
        else
            led <= led_next;
    end

endmodule
