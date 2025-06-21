// File : distorter_pipelined_368.v
// Author : Omar Fahmy
// Date : 9/3/2023
// Version : 1
// Abstract : this file contains a fixed-point pipelined implementation of the memory polynomial equation of a distorter
//            operating at clock frequency = 368.64 MHz. This will be used as a pre-distorter.

//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////// Module ports list, declaration, and data type ///////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////

module distorter_pipelined_368 #(parameter INT_WIDTH = 4,
                                 FRACT_WIDTH = 12,
                                 DATA_WIDTH = INT_WIDTH + FRACT_WIDTH)
                                (input wire clk_368,
                                 input wire rst_n,
                                 input wire signed [DATA_WIDTH-1 : 0] in_r,
                                 input wire signed [DATA_WIDTH-1 : 0] in_i,
                                 input wire signed [DATA_WIDTH-1 : 0] a10_r,
                                 input wire signed [DATA_WIDTH-1 : 0] a10_i,
                                 input wire signed [DATA_WIDTH-1 : 0] a30_r,
                                 input wire signed [DATA_WIDTH-1 : 0] a30_i,
                                 input wire signed [DATA_WIDTH-1 : 0] a50_r,
                                 input wire signed [DATA_WIDTH-1 : 0] a50_i,
                                 output reg signed [DATA_WIDTH-1 : 0] out_r,
                                 output reg signed [DATA_WIDTH-1 : 0] out_i);
    
    //////////////////////////////////////////////////////////////////////////////////////////////////////
    ///////////////////////////////// Signals and Internal Connections ///////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////////////////////////
    
    wire signed [2*DATA_WIDTH-1 : 0] xin_r, xin_i;
    wire signed [DATA_WIDTH-1 : 0] xin_trunc_r, xin_trunc_i;
    
    wire signed [DATA_WIDTH-1 : 0] abs_squared;
    
    wire signed [2*DATA_WIDTH-1 : 0] abs_pwr_four;
    wire signed [DATA_WIDTH-1 : 0] abs_pwr_four_trunc;
    
    wire signed [2*DATA_WIDTH-1 : 0] half_mul1_r;
    wire signed [DATA_WIDTH-1 : 0] half_mul1_trunc_r;
    wire signed [2*DATA_WIDTH-1 : 0] half_mul1_i;
    wire signed [DATA_WIDTH-1 : 0] half_mul1_trunc_i;
    
    wire signed [DATA_WIDTH-1 : 0] add1_r;
    wire signed [DATA_WIDTH-1 : 0] add1_i;
    
    wire signed [2*DATA_WIDTH-1 : 0] half_mul2_r;
    wire signed [DATA_WIDTH-1 : 0] half_mul2_trunc_r;
    wire signed [2*DATA_WIDTH-1 : 0] half_mul2_i;
    wire signed [DATA_WIDTH-1 : 0] half_mul2_trunc_i;
    
    wire signed [DATA_WIDTH-1 : 0] add2_r;
    wire signed [DATA_WIDTH-1 : 0] add2_i;
    
    wire signed [2*DATA_WIDTH-1 : 0] mul1;
    wire signed [DATA_WIDTH-1 : 0] mul1_trunc;
    wire signed [2*DATA_WIDTH-1 : 0] mul2;
    wire signed [DATA_WIDTH-1 : 0] mul2_trunc;
    wire signed [2*DATA_WIDTH-1 : 0] mul3;
    wire signed [DATA_WIDTH-1 : 0] mul3_trunc;
    wire signed [2*DATA_WIDTH-1 : 0] mul4;
    wire signed [DATA_WIDTH-1 : 0] mul4_trunc;
    
    reg signed [DATA_WIDTH-1 : 0] in_r_reg1, in_i_reg1, in_r_reg2, in_i_reg2, in_r_reg3, in_i_reg3, in_r_reg4, in_i_reg4;
    
    wire signed [DATA_WIDTH-1 : 0] out_r_comb, out_i_comb;
    
    reg signed [DATA_WIDTH-1 : 0] a10_r_reg1, a10_i_reg1, a10_r_reg2, a10_i_reg2, a10_r_reg3, a10_i_reg3;
    reg signed [DATA_WIDTH-1 : 0] a30_r_reg1, a30_i_reg1, a30_r_reg2, a30_i_reg2;
    reg signed [DATA_WIDTH-1 : 0] a50_r_reg1, a50_i_reg1, a50_r_reg2, a50_i_reg2, a50_r_reg3, a50_i_reg3;
    
    reg signed [DATA_WIDTH-1 : 0] abs_squared_reg;
    
    reg signed [DATA_WIDTH-1 : 0] half_mul1_trunc_r_reg, half_mul1_trunc_i_reg;
    
    reg signed [DATA_WIDTH-1 : 0] abs_pwr_four_trunc_reg;
    
    reg signed [DATA_WIDTH-1 : 0] add1_r_reg, add1_i_reg;
    
    reg signed [DATA_WIDTH-1 : 0] half_mul2_trunc_r_reg, half_mul2_trunc_i_reg;
    
    reg signed [DATA_WIDTH-1 : 0] add2_r_reg;
    reg signed [DATA_WIDTH-1 : 0] add2_i_reg;
    
    reg signed [DATA_WIDTH-1 : 0] in_r_reg5, in_i_reg5;
    
    //////////////////////////////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////////////// Sequential Logic //////////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////////////////////////
    
    always@(posedge clk_368 or negedge rst_n)
    begin
        if (!rst_n)
        begin
            in_r_reg1              <= 'd0;
            in_i_reg1              <= 'd0;
            in_r_reg2              <= 'd0;
            in_i_reg2              <= 'd0;
            in_r_reg3              <= 'd0;
            in_i_reg3              <= 'd0;
            in_r_reg4              <= 'd0;
            in_i_reg4              <= 'd0;
            out_r                  <= 'd0;
            out_i                  <= 'd0;
            a10_r_reg1             <= 'd0;
            a10_i_reg1             <= 'd0;
            a10_r_reg2             <= 'd0;
            a10_i_reg2             <= 'd0;
            a10_r_reg3             <= 'd0;
            a10_i_reg3             <= 'd0;
            a30_r_reg1             <= 'd0;
            a30_i_reg1             <= 'd0;
            a30_r_reg2             <= 'd0;
            a30_i_reg2             <= 'd0;
            a50_r_reg1             <= 'd0;
            a50_i_reg1             <= 'd0;
            a50_r_reg2             <= 'd0;
            a50_i_reg2             <= 'd0;
            a50_r_reg3             <= 'd0;
            a50_i_reg3             <= 'd0;
            abs_squared_reg        <= 'd0;
            half_mul1_trunc_r_reg  <= 'd0;
            half_mul1_trunc_i_reg  <= 'd0;
            abs_pwr_four_trunc_reg <= 'd0;
            add1_r_reg             <= 'd0;
            add1_i_reg             <= 'd0;
            half_mul2_trunc_r_reg  <= 'd0;
            half_mul2_trunc_i_reg  <= 'd0;
            add2_r_reg             <= 'd0;
            add2_i_reg             <= 'd0;
            in_r_reg5              <= 'd0;
            in_i_reg5              <= 'd0;
        end
        else
        begin
            in_r_reg1              <= in_r;
            in_i_reg1              <= in_i;
            in_r_reg2              <= in_r_reg1;
            in_i_reg2              <= in_i_reg1;
            in_r_reg3              <= in_r_reg2;
            in_i_reg3              <= in_i_reg2;
            in_r_reg4              <= in_r_reg3;
            in_i_reg4              <= in_i_reg3;
            out_r                  <= out_r_comb;
            out_i                  <= out_i_comb;
            a10_r_reg1             <= a10_r;
            a10_i_reg1             <= a10_i;
            a10_r_reg2             <= a10_r_reg1;
            a10_i_reg2             <= a10_i_reg1;
            a10_r_reg3             <= a10_r_reg2;
            a10_i_reg3             <= a10_i_reg2;
            a30_r_reg1             <= a30_r;
            a30_i_reg1             <= a30_i;
            a30_r_reg2             <= a30_r_reg1;
            a30_i_reg2             <= a30_i_reg1;
            a50_r_reg1             <= a50_r;
            a50_i_reg1             <= a50_i;
            a50_r_reg2             <= a50_r_reg1;
            a50_i_reg2             <= a50_i_reg1;
            a50_r_reg3             <= a50_r_reg2;
            a50_i_reg3             <= a50_i_reg2;
            abs_squared_reg        <= abs_squared;
            half_mul1_trunc_r_reg  <= half_mul1_trunc_r;
            half_mul1_trunc_i_reg  <= half_mul1_trunc_i;
            abs_pwr_four_trunc_reg <= abs_pwr_four_trunc;
            add1_r_reg             <= add1_r;
            add1_i_reg             <= add1_i;
            half_mul2_trunc_r_reg  <= half_mul2_trunc_r;
            half_mul2_trunc_i_reg  <= half_mul2_trunc_i;
            add2_r_reg             <= add2_r;
            add2_i_reg             <= add2_i;
            in_r_reg5              <= in_r_reg4;
            in_i_reg5              <= in_i_reg4;
        end
    end
    
    //////////////////////////////////////////////////////////////////////////////////////////////////////
    ///////////////////////////////////////// Combinational Logic ////////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////////////////////////
    
    assign xin_r       = in_r_reg1 * in_r_reg1;
    assign xin_trunc_r = xin_r >> (FRACT_WIDTH);
    assign xin_i       = in_i_reg1 * in_i_reg1;
    assign xin_trunc_i = xin_i >> (FRACT_WIDTH);
    
    assign abs_squared = xin_trunc_r + xin_trunc_i;
    
    assign abs_pwr_four       = abs_squared_reg * abs_squared_reg;
    assign abs_pwr_four_trunc = abs_pwr_four >> (FRACT_WIDTH);
    
    assign half_mul1_r       = abs_squared_reg * a30_r_reg2;
    assign half_mul1_trunc_r = half_mul1_r >> (FRACT_WIDTH);
    assign half_mul1_i       = abs_squared_reg * a30_i_reg2;
    assign half_mul1_trunc_i = half_mul1_i >> (FRACT_WIDTH);
    
    assign add1_r = half_mul1_trunc_r_reg + a10_r_reg3;
    assign add1_i = half_mul1_trunc_i_reg + a10_i_reg3;
    
    assign half_mul2_r       = abs_pwr_four_trunc_reg * a50_r_reg3;
    assign half_mul2_trunc_r = half_mul2_r >> (FRACT_WIDTH);
    assign half_mul2_i       = abs_pwr_four_trunc_reg * a50_i_reg3;
    assign half_mul2_trunc_i = half_mul2_i >> (FRACT_WIDTH);
    
    assign add2_r = half_mul2_trunc_r_reg + add1_r_reg;
    assign add2_i = half_mul2_trunc_i_reg + add1_i_reg;
    
    assign mul1       = add2_r_reg * in_r_reg5;
    assign mul1_trunc = mul1 >> (FRACT_WIDTH);
    assign mul2       = add2_i_reg * in_i_reg5;
    assign mul2_trunc = mul2 >> (FRACT_WIDTH);
    assign mul3       = add2_r_reg * in_i_reg5;
    assign mul3_trunc = mul3 >> (FRACT_WIDTH);
    assign mul4       = add2_i_reg * in_r_reg5;
    assign mul4_trunc = mul4 >> (FRACT_WIDTH);
    
    assign out_r_comb = mul1_trunc - mul2_trunc;
    assign out_i_comb = mul3_trunc + mul4_trunc;
    
endmodule
