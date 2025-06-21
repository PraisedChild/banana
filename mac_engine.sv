/*
 * mac_engine.sv
 * Francesco Conti <f.conti@unibo.it>
 *
 * Copyright (C) 2018-2022 ETH Zurich, University of Bologna
 * Copyright and related rights are licensed under the Solderpad Hardware
 * License, Version 0.51 (the "License"); you may not use this file except in
 * compliance with the License.  You may obtain a copy of the License at
 * http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
 * or agreed to in writing, software, hardware and materials distributed under
 * this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
 * CONDITIONS OF ANY KIND, either express or implied. See the License for the
 * specific language governing permissions and limitations under the License.
 *
 * The architecture that follows is relatively straightforward; it supports two modes:
 *  - in 'simple_mult' mode, the a_i and b_i streams feed the 32b x 32b multiplier (mult).
 *    The output of the multiplier (64b) is registered in a pipeline stage
 *    (r_mult), which is then shifted by ctrl_i.shift to the right and streamed out as d_o.
 *    There is no control local to the module except for handshakes.
 *  - in 'scalar_prod' mode, the c_i stream is first shifted left by ctrl_i.shift, extended
 *    to 64b and saved in r_acc. Then, the a_i and b_i streams feed the 32b x 32b multiplier
 *    (mult) for ctrl_i.len cycles, controlled by a local counter. The output of mult is 
 *    registered in a pipeline stage (r_mult), whose value is used as input to an accumulator
 *    (r_acc) -- the one which was inited by the shifted value of c_i. At the end of the
 *    ctrl_i.len cycles, the output of r_acc is shifted back to the right by ctrl_i.shift
 *    bits and streamed out as d_o.
 */

import mac_package::*;

module mac_engine
(
  // global signals
  input  logic                   clk_i,
  input  logic                   rst_ni,
  input  logic                   test_mode_i,
  // input a stream
  hwpe_stream_intf_stream.sink   a_i,
  // input b stream
  hwpe_stream_intf_stream.sink   b_i,
  // input c stream
  hwpe_stream_intf_stream.source c_o,
  // output d stream
  hwpe_stream_intf_stream.source d_o,
  // control channel
  input  ctrl_engine_t           ctrl_i,
  output flags_engine_t          flags_o

  input logic [15:0]             a10_r,
  input logic [15:0]             a10_i,
  input logic [15:0]             a30_r,
  input logic [15:0]             a30_i,
  input logic [15:0]             a50_r,
  input logic [15:0]             a50_i
);

  logic unsigned [$clog2(MAC_CNT_LEN):0] cnt;
  logic unsigned [$clog2(MAC_CNT_LEN):0] r_cnt;
  logic signed [63:0] c_shifted;
  logic signed [63:0] mult;
  logic signed [63:0] r_mult;
  logic               r_mult_valid;
  logic               r_mult_ready;
  logic signed [64+$clog2(MAC_CNT_LEN)-1:0] r_acc;
  logic                                     r_acc_valid;
  logic                                     r_acc_ready;
  logic signed [64+$clog2(MAC_CNT_LEN)-1:0] d_nonshifted;
  logic                                     d_nonshifted_valid;
  logic [5:0]                               output_valid;
  logic [15:0]                              in_r;
  logic [15:0]                              in_i;
  logic [15:0]                              out_r;
  logic [15:0]                              out_i;




  always_ff @(posedge clk_i or negedge rst_ni)
  begin : mult_pipe_data
    if(~rst_ni) begin
      in_r <= '0;
      in_i <= '0;
    end
    else if (ctrl_i.clear) begin
      in_r <= '0;
      in_i <= '0;
    end
    else if (ctrl_i.enable) begin
      // `r_mult` value is updated if there is a valid handshake at both its inputs;
      // in all other cases it is kept constant.
      if (a_i.valid & b_i.valid & a_i.ready & b_i.ready) begin
        in_r <= a_i.data;
        in_i <= b_i.data;
      end
    end
  end

  distorter_pipelined_368 i_actuator (
    .clk_368(clk_i),
    .rst_n(rst_ni),
    .in_r(in_r),
    .in_i(in_i),
    .a10_r(a10_r),
    .a10_i(a10_i),
    .a30_r(a30_r),
    .a30_i(a30_i),
    .a50_r(a50_r),
    .a50_i(a50_i),
    .out_r(out_r),
    .out_i(out_i)   
  );
  // This calculates the `valid` signal associated with `r_mult`. In this case, we
  // chose to propagate this signal explicitly through all pipeline registers in the
  // datapath to showcase explicitly how this can be done (in other accelerators,
  // one could manage validity in a less sophisticated way, e.g., with a counter).
  // In detail, `r_mult` is valid when both `a_i` and `b_i` are valid, with one
  // cycle of delay. The validity is evaluated only in two conditions:
  //  1) when a valid handshake happens at the output (`r_mult` valid & ready)
  //  2) when the inputs are known to be valid
  // Of course, by construction `r_mult_valid` can transition from 1 to 0 only in
  // condition 1), that is, following a valid handshake at the output.


  always_ff @(posedge clk_i or negedge rst_ni)
  begin : mult_pipe_valid
    if(~rst_ni) begin
      r_mult_valid <= '0;
    end
    else if (ctrl_i.clear) begin
      r_mult_valid <= '0;
    end
    else if (ctrl_i.enable) begin
      // r_mult_valid is re-evaluated after a valid handshake or in transition to 1
      if ((a_i.valid & b_i.valid) | (r_mult_valid & r_mult_ready)) begin
        r_mult_valid <= a_i.valid & b_i.valid;
      end
    end
  end



  // Differently to `r_mult`, the validity of `r_acc` depends on a full dot-product having
  // happened, controlled by comparing the `r_cnt` counter with the size `ctrl_i.len`.
  // The validity is evaluated when the length reaches this threshold and the `r_mult` has 
  // a valid handshake (as `r_mult` is the input from `r_acc`'s viewpoint). It is also
  // re-evaluated after a correct output transition.
  always_ff @(posedge clk_i or negedge rst_ni)
  begin : accumulator_valid
    if(~rst_ni) begin
      r_acc_valid <= '0;
    end
    else if (ctrl_i.clear) begin
      r_acc_valid <= '0;
    end
    else if (ctrl_i.enable) begin
      // r_acc_valid is re-evaluated after a valid handshake or in transition to 1
      if(((r_cnt == ctrl_i.len) & r_mult_valid & r_mult_ready) | (r_acc_valid)) begin
        r_acc_valid <= (r_cnt == ctrl_i.len);
      end
    end
  end

//input takes 6 cycles to reach output, we need to have a validity check for each point of the pipeline
  always_ff
  begin
    if(~rst_ni) begin
      output_valid <= '0;
    end
    else if(ctrl_i.clear) begin
      output_valid <= '0;
    end
    else if(ctrl_i.enable) begin
      output_valid[5] <= output_valid[4];
      output_valid[4] <= output_valid[3];
      output_valid[3] <= output_valid[2];
      output_valid[2] <= output_valid[1];
      output_valid[1] <= output_valid[0];
      output_valid[0] <= r_mult_valid;
    end
  end

  always_comb
  begin
    d_o.data  = out_i; 
    d_o.valid = ctrl_i.enable & output_valid[5];
    d_o.strb  = '1; 
    c_o.data  = out_r; 
    c_o.valid = ctrl_i.enable & output_valid[5];
    c_o.strb  = '1; 
  end


  always_comb
  begin
    cnt = r_cnt + 1;
  end

  always_ff @(posedge clk_i or negedge rst_ni)
  begin
    if(~rst_ni) begin
      r_cnt <= '0;
    end
    else if(ctrl_i.clear) begin
      r_cnt <= '0;
    end
    else if(ctrl_i.enable) begin
      // The counter is updated
      //  1) at the start of operations
      //  2) when the count value is between 0 and `len` (excluded), and there is a valid `r_mult` handshake.
      if ((ctrl_i.start == 1'b1) || ((r_cnt > 0) && (r_cnt < ctrl_i.len) && (r_mult_valid & r_mult_ready == 1'b1))) begin
        r_cnt <= cnt;
      end
    end
  end

  // Export counter and valid accumulator to main HWPE control FSM.
  assign flags_o.cnt = r_cnt;
  assign flags_o.acc_valid = r_acc_valid;

  // Ready signals have to be propagated backwards through pipeline stages (combinationally).
  // To avoid deadlocks, the following rules have to be followed:
  //  1) transition of ready CAN depend on the current state of valid
  //  2) transition of valid CANNOT depend on the current state of ready
  //  3) transition 1->0 of valid MUST depend on (previous) ready (i.e., once the valid goes
  //     to 1 it cannot go back to 0 until there is a valid handshake)
  // In the following:
  // R_valid & R_ready denominate the handshake at the *output* (Q port) of pipe register R


  // Accumulator accepts new value from multiplier when
  //  1) output is ready or `r_mult` is invalid (if in simple multiplication mode)
  //  2) `r_acc` is ready or `r_mult` is invalid (if in scalar product mode)
  assign r_mult_ready = (d_o.ready & c_o.ready)  | ~r_mult_valid;
  // Multiplier accepts new value from `a_i` and `b_i` when `r_mult` is ready and both
  // `a_i` & `b_i` are valid, or when both `a_i` & `b_i` are invalid
  assign a_i.ready = (r_mult_ready & a_i.valid & b_i.valid) | (~a_i.valid & ~b_i.valid);
  assign b_i.ready = (r_mult_ready & a_i.valid & b_i.valid) | (~a_i.valid & ~b_i.valid);
  // Multiplier accepts new value from `c_i` when `r_acc` is ready or `c_i` is invalid

  

endmodule // mac_engine
