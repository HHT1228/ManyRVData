// Author: Ho Tin Hung

`include "common_cells/registers.svh"
module cache_dir_tag_arb #(
  parameter int unsigned NumTagBankPerCtrl = 2,

  parameter type tcdm_bank_addr_t = logic,
  parameter type tag_data_t       = logic
)(
  input logic clk_i,
  input logic rst_ni,

  input logic             [NumTagBankPerCtrl-1:0] cache_tag_bank_req_i,
  input logic             [NumTagBankPerCtrl-1:0] cache_tag_bank_we_i,
  input tcdm_bank_addr_t  [NumTagBankPerCtrl-1:0] cache_tag_bank_addr_i,
  input tag_data_t        [NumTagBankPerCtrl-1:0] cache_tag_bank_wdata_i,
  input logic             [NumTagBankPerCtrl-1:0] cache_tag_bank_be_i,
  
  input logic             [NumTagBankPerCtrl-1:0] dir_tag_bank_req_i,
  input logic             [NumTagBankPerCtrl-1:0] dir_tag_bank_we_i,
  input tcdm_bank_addr_t  [NumTagBankPerCtrl-1:0] dir_tag_bank_addr_i,
  input tag_data_t        [NumTagBankPerCtrl-1:0] dir_tag_bank_wdata_i,
  input logic             [NumTagBankPerCtrl-1:0] dir_tag_bank_be_i,

  // input  logic            dir_req_valid_i,
  // input  addr_t           dir_req_addr_i,
  // input  core_meta_t      dir_req_meta_i,
  // input  logic            dir_req_write_i,
  // // input  word_data_t      dir_req_wdata_i,
  // input  logic            dir_req_is_evict_i,

  // Tag bank end-signals
  output logic            [NumTagBankPerCtrl-1:0] tag_bank_req_o,
  output logic            [NumTagBankPerCtrl-1:0] tag_bank_we_o,
  output tcdm_bank_addr_t [NumTagBankPerCtrl-1:0] tag_bank_addr_o,
  output tag_data_t       [NumTagBankPerCtrl-1:0] tag_bank_wdata_o,
  output logic            [NumTagBankPerCtrl-1:0] tag_bank_be_o,

  // Response from tag bank
  // input  tag_data_t       [NumTagBankPerCtrl-1:0] tag_bank_rdata_i,
  // Response to upstream (cache or dir)
  // output tag_data_t       [NumTagBankPerCtrl-1:0] tag_bank_rdata_o,

  output logic            [NumTagBankPerCtrl-1:0] is_cache_meta_o,
  output logic            [NumTagBankPerCtrl-1:0] cache_tag_bank_gnt_o,
  output logic            [NumTagBankPerCtrl-1:0] dir_tag_bank_gnt_o
);

  typedef struct packed {
    logic             req;
    logic             we;
    tcdm_bank_addr_t  addr;
    tag_data_t        wdata;
    logic             be;
  } tag_bank_req_pack_t;

  tag_bank_req_pack_t [NumTagBankPerCtrl-1:0] cache_req_pack, dir_req_pack, final_req_pack;
  tag_bank_req_pack_t [NumTagBankPerCtrl-1:0] req_pack_combined;
  // logic               [NumTagBankPerCtrl-1:0] req_valid;
  logic               [NumTagBankPerCtrl-1:0] cache_req_gnt, dir_req_gnt;
  // logic               [NumTagBankPerCtrl/2-1:0] cache_req_gnt, dir_req_gnt;
  logic               [NumTagBankPerCtrl-1:0] cache_tag_bank_gnt_q;

  for(genvar i = 0; i < NumTagBankPerCtrl; i++) begin
    assign cache_req_pack[i].req    = cache_tag_bank_req_i[i];
    assign cache_req_pack[i].we     = cache_tag_bank_we_i[i];
    assign cache_req_pack[i].addr   = cache_tag_bank_addr_i[i];
    assign cache_req_pack[i].wdata  = cache_tag_bank_wdata_i[i];
    assign cache_req_pack[i].be     = cache_tag_bank_be_i[i];

    assign dir_req_pack[i].req      = dir_tag_bank_req_i[i];
    assign dir_req_pack[i].we       = dir_tag_bank_we_i[i];
    assign dir_req_pack[i].addr     = dir_tag_bank_addr_i[i];
    assign dir_req_pack[i].wdata    = dir_tag_bank_wdata_i[i];
    assign dir_req_pack[i].be       = dir_tag_bank_be_i[i];

    assign tag_bank_req_o[i]    = final_req_pack[i].req;
    assign tag_bank_we_o[i]     = final_req_pack[i].we;
    assign tag_bank_addr_o[i]   = final_req_pack[i].addr;
    assign tag_bank_wdata_o[i]  = final_req_pack[i].wdata;
    assign tag_bank_be_o[i]     = final_req_pack[i].be;

    // assign req_valid[i] = dir_tag_bank_req_i[i] || [i];

    rr_arb_tree #(
      .NumIn     (2),
      .DataType  (tag_bank_req_pack_t),
      .AxiVldRdy (1'b1)
    ) i_l2_meta_bank_arb (
      .clk_i   (clk_i),
      .rst_ni  (rst_ni),
      .flush_i (1'b0),
      .rr_i    (1'b1),
      .req_i   ({cache_tag_bank_req_i[i], dir_tag_bank_req_i[i]}),  // valid_i
      .gnt_o   ({cache_req_gnt[i], dir_req_gnt[i]}),  // ready_o
      .data_i  ({cache_req_pack[i], dir_req_pack[i]}),
      .req_o   (),            // valid_o
      .gnt_i   (1'b1),                           // ready_i
      .data_o  (final_req_pack[i]),
      .idx_o   ()
    );
    assign is_cache_meta_o[i] = !dir_tag_bank_req_i[i];
    assign cache_tag_bank_gnt_o[i] = cache_req_gnt[i];
    // assign cache_tag_bank_gnt_o[i] = 1'b1;
    assign dir_tag_bank_gnt_o[i]   = dir_req_gnt[i];
    // assign dir_tag_bank_gnt_o[i]   = 1'b1;
  end

  // `FF(cache_tag_bank_gnt_q, cache_req_gnt, '0, clk_i, rst_ni)
  // assign cache_tag_bank_gnt_o = cache_tag_bank_gnt_q;

  // assign dir_tag_bank_gnt_o = |(req_gnt[1]);

//   tag_bank_req_pack_t [NumTagBankPerCtrl-1:0] cache_req_pack_push, cache_req_pack_pop;
//   logic [NumTagBankPerCtrl-1:0] latch_cache_req, serve_pend_cache_req;
//   logic [NumTagBankPerCtrl-1:0] fifo_full, fifo_empty;

//   for (genvar i = 0; i < NumTagBankPerCtrl; i++) begin
//     assign cache_req_pack_push[i].req   = cache_tag_bank_req_i[i];
//     assign cache_req_pack_push[i].we    = cache_tag_bank_we_i[i];
//     assign cache_req_pack_push[i].addr  = cache_tag_bank_addr_i[i];
//     assign cache_req_pack_push[i].wdata = cache_tag_bank_wdata_i[i];
//     assign cache_req_pack_push[i].be    = cache_tag_bank_be_i[i];

//     assign serve_pend_cache_req[i] = !dir_tag_bank_req_i[i] && !fifo_empty[i];

//     always_comb begin
//       if(dir_tag_bank_req_i[i]) begin
//         if(cache_tag_bank_req_i[i]) begin
//           latch_cache_req[i] = 1'b1;      // push cache req to fifo when both coming in on same cycle
//         end else begin
//           latch_cache_req[i] = 1'b0;
//         end
//         // Prioritize directory request to output
//         tag_bank_req_o[i]   = dir_tag_bank_req_i[i];
//         tag_bank_we_o[i]    = dir_tag_bank_we_i[i];
//         tag_bank_addr_o[i]  = dir_tag_bank_addr_i[i];
//         tag_bank_wdata_o[i] = dir_tag_bank_wdata_i[i];
//         tag_bank_be_o[i]    = dir_tag_bank_be_i[i];
//         is_cache_meta_o[i]  = 1'b0;
//       end else if (cache_tag_bank_req_i[i]) begin
//         if(fifo_empty[i]) begin
//           // cache request coming in with empty fifo, fall through
//           tag_bank_req_o[i]   = cache_tag_bank_req_i[i];
//           tag_bank_we_o[i]    = cache_tag_bank_we_i[i];
//           tag_bank_addr_o[i]  = cache_tag_bank_addr_i[i];
//           tag_bank_wdata_o[i] = cache_tag_bank_wdata_i[i];
//           tag_bank_be_o[i]    = cache_tag_bank_be_i[i];
//           is_cache_meta_o[i]  = 1'b1;
//           latch_cache_req[i]  = 1'b0;
//         end else begin
//           // otherwise serve buffered req first and buffer current req
//           tag_bank_req_o[i]   = cache_req_pack_pop[i].req;
//           tag_bank_we_o[i]    = cache_req_pack_pop[i].we;
//           tag_bank_addr_o[i]  = cache_req_pack_pop[i].addr;
//           tag_bank_wdata_o[i] = cache_req_pack_pop[i].wdata;
//           tag_bank_be_o[i]    = cache_req_pack_pop[i].be;
//           is_cache_meta_o[i]  = 1'b1;
//           latch_cache_req[i]  = 1'b1;
//         end
//       end else begin
//         // No incoming requests, serve buffered req if any
//         tag_bank_req_o[i]   = cache_req_pack_pop[i].req;
//         tag_bank_we_o[i]    = cache_req_pack_pop[i].we;
//         tag_bank_addr_o[i]  = cache_req_pack_pop[i].addr;
//         tag_bank_wdata_o[i] = cache_req_pack_pop[i].wdata;
//         tag_bank_be_o[i]    = cache_req_pack_pop[i].be;
//         is_cache_meta_o[i]  = 1'b1;
//         latch_cache_req[i]  = 1'b0; 
//       end
//     end

//     fifo_v3 #(
//       .FALL_THROUGH      (1'b0),
//       .DATA_WIDTH        ( $bits(tag_bank_req_pack_t)),
//       .DEPTH             (4),
//       .dtype             (tag_bank_req_pack_t)
//     ) i_cache_req_buf (
//       .clk_i        (clk_i),
//       .rst_ni       (rst_ni),
//       .flush_i      (1'b0),
//       .testmode_i   (1'b0),
//       .full_o       (fifo_full[i]),
//       .empty_o      (fifo_empty[i]),
//       .usage_o      (),
//       .data_i       (cache_req_pack_push[i]),
//       .push_i       (latch_cache_req[i]),
//       .data_o       (cache_req_pack_pop[i]),
//       .pop_i        (serve_pend_cache_req[i])
//     );
//   end
endmodule