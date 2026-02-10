// Author: Ho Tin Hung

`include "axi/assign.svh"
`include "axi/typedef.svh"
`include "common_cells/assertions.svh"
`include "common_cells/registers.svh"
`include "mem_interface/assign.svh"
`include "mem_interface/typedef.svh"
`include "register_interface//assign.svh"
`include "register_interface/typedef.svh"
`include "reqrsp_interface/assign.svh"
`include "reqrsp_interface/typedef.svh"
`include "snitch_vm/typedef.svh"
`include "tcdm_interface/assign.svh"
`include "tcdm_interface/typedef.svh"
`include "hpdcache_typedef.svh"

module coherence_interco
  import coherence_pkg::*; 
  import hpdcache_pkg::*; 
#(
  parameter int unsigned NumL0CacheCtrl = 4,
  parameter int unsigned NumL1CacheCtrl = 4,
  parameter int unsigned AddrWidth      = 32,

  parameter type         cache_dir_fwd_t              = logic,
  parameter type         coherence_evict_t            = logic,
  parameter type         coherence_rsp_t             = logic,

  parameter type         coherence_down_payload_t      = logic,
  parameter type         coherence_up_payload_t        = logic,

  /// Port type of the data request ports.
  parameter type         tcdm_req_coherence_t           = logic,
  /// Port type of the data response ports.
  parameter type         tcdm_rsp_coherence_t           = logic,
  /// Payload type of the data request ports.
  parameter type         tcdm_req_chan_coherence_t      = logic,
  /// Payload type of the data response ports.
  parameter type         tcdm_rsp_chan_coherence_t      = logic

  // parameter snitch_pkg::topo_e Topology       = snitch_pkg::LogarithmicInterconnect
) (
  input logic         clk_i,
  input logic         rst_ni,

  // L1 to L2 forward channel (class 2)
  input   cache_dir_fwd_t [NumL0CacheCtrl-1:0] l1_l2_fwd_i,
  input   logic           [NumL0CacheCtrl-1:0] l1_l2_fwd_valid_i,
  output  logic           [NumL0CacheCtrl-1:0] l1_l2_fwd_ready_o,

  output  cache_dir_fwd_t [NumL1CacheCtrl-1:0] l1_l2_fwd_xbar_o,
  output  logic           [NumL1CacheCtrl-1:0] l1_l2_fwd_xbar_valid_o,
  input   logic           [NumL1CacheCtrl-1:0] l1_l2_fwd_xbar_ready_i,

  // L1 to L2 evict request (class 1)
  input   coherence_evict_t [NumL0CacheCtrl-1:0] l1_l2_evict_i,
  output  logic             [NumL0CacheCtrl-1:0] l1_l2_evict_ready_o,

  output  coherence_evict_t [NumL1CacheCtrl-1:0] l1_l2_evict_xbar_o,
  input   logic             [NumL1CacheCtrl-1:0] l1_l2_evict_xbar_ready_i,

  // L2 to L1 forward message (class 2)
  input  cache_dir_fwd_t [NumL1CacheCtrl-1:0] l2_l1_fwd_i,
  input  logic           [NumL1CacheCtrl-1:0] l2_l1_fwd_valid_i,
  output logic           [NumL1CacheCtrl-1:0] l2_l1_fwd_ready_o,

  output cache_dir_fwd_t [NumL0CacheCtrl-1:0] l2_l1_fwd_xbar_o,
  output logic           [NumL0CacheCtrl-1:0] l2_l1_fwd_xbar_valid_o,
  input  logic           [NumL0CacheCtrl-1:0] l2_l1_fwd_xbar_ready_i,

  // L2 to L1 coherence response (class 3, sink)
  input  coherence_rsp_t  [NumL1CacheCtrl-1:0] l2_l1_rsp_i,
  input  logic            [NumL1CacheCtrl-1:0] l2_l1_rsp_valid_i,
  output logic            [NumL1CacheCtrl-1:0] l2_l1_rsp_ready_o,

  output coherence_rsp_t  [NumL0CacheCtrl-1:0] l2_l1_rsp_xbar_o,
  output logic            [NumL0CacheCtrl-1:0] l2_l1_rsp_xbar_valid_o,
  input  logic            [NumL0CacheCtrl-1:0] l2_l1_rsp_xbar_ready_i,
  
  // XBAR signals
  input  logic            [$clog2(AddrWidth)-1:0] dynamic_offset_i
);

  cache_dir_fwd_t           [NumL0CacheCtrl-1:0] l1_l2_fwd_int;
  logic                     [NumL0CacheCtrl-1:0] l1_l2_fwd_valid_int;
  coherence_evict_t         [NumL0CacheCtrl-1:0] l1_l2_evict_int;
  coherence_down_payload_t  [NumL0CacheCtrl-1:0] l1_l2_fwd_payload, l1_l2_evict_payload;
  tcdm_req_coherence_t      [NumL0CacheCtrl-1:0] l1_l2_fwd_tcdm_int, l1_l2_evict_tcdm_int;
  tcdm_req_coherence_t      [NumL0CacheCtrl-1:0] l1_l2_coherence_tcdm;
  tcdm_req_coherence_t      [NumL1CacheCtrl-1:0] l1_l2_coherence_tcdm_xbar;

  logic                     [NumL0CacheCtrl-1:0] l1_l2_fwd_gnt, l1_l2_evict_gnt;
  logic                     [NumL0CacheCtrl-1:0] l1_l2_fwd_empty, l1_l2_evict_empty;
  logic                     [NumL1CacheCtrl-1:0] l1_l2_fwd_fifo_full, l1_l2_evict_fifo_full;

  cache_dir_fwd_t           [NumL0CacheCtrl-1:0] l2_l1_fwd_int;
  logic                     [NumL0CacheCtrl-1:0] l2_l1_fwd_valid_int;
  logic                     [NumL0CacheCtrl-1:0] l2_l1_fwd_ready_int;
  coherence_rsp_t           [NumL0CacheCtrl-1:0] l2_l1_rsp_int;
  logic                     [NumL0CacheCtrl-1:0] l2_l1_rsp_valid_int;
  logic                     [NumL0CacheCtrl-1:0] l2_l1_rsp_ready_int;
  coherence_up_payload_t    [NumL0CacheCtrl-1:0] l2_l1_fwd_payload, l2_l1_rsp_payload;
  tcdm_rsp_coherence_t      [NumL0CacheCtrl-1:0] l2_l1_fwd_tcdm_int, l2_l1_rsp_tcdm_int;
  tcdm_rsp_coherence_t      [NumL0CacheCtrl-1:0] l2_l1_coherence_tcdm;
  tcdm_rsp_coherence_t      [NumL1CacheCtrl-1:0] l2_l1_coherence_tcdm_xbar;
  logic                     [NumL1CacheCtrl-1:0] l2_l1_ready_tcdm, l2_l1_ready_tcdm_xbar;

  logic                     [NumL0CacheCtrl-1:0] l2_l1_fwd_gnt, l2_l1_rsp_gnt;
  logic                     [NumL0CacheCtrl-1:0] l2_l1_fwd_empty, l2_l1_rsp_empty;
  logic                     [NumL1CacheCtrl-1:0] l2_l1_fwd_fifo_full, l2_l1_rsp_fifo_full;

  
  for (genvar i = 0; i < NumL0CacheCtrl; i++) begin : doownward_pre_xbar
    /*****************************
    * pre_interconnect_processing
    *****************************/
    assign l1_l2_fwd_ready_o[i] = ~l1_l2_fwd_fifo_full[i];
    assign l1_l2_evict_ready_o[i] = ~l1_l2_evict_fifo_full[i];

    fifo_v3 #(
      .FALL_THROUGH(1'b0),
      .DATA_WIDTH($bits(cache_dir_fwd_t)+1),  // +1 for valid bit
      .DEPTH(8)
    ) i_l1_l2_fwd_fifo (
      .clk_i      (clk_i),
      .rst_ni     (rst_ni),
      .flush_i    (1'b0),
      .testmode_i (1'b0),
      .full_o     (l1_l2_fwd_fifo_full[i]),
      .empty_o    (l1_l2_fwd_empty[i]),
      .usage_o    (),
      .data_i     ({l1_l2_fwd_valid_i[i], l1_l2_fwd_i[i]}),
      .push_i     (l1_l2_fwd_valid_i[i]),
      .data_o     ({l1_l2_fwd_valid_int[i], l1_l2_fwd_int[i]}),
      .pop_i      (l1_l2_fwd_gnt[i] && !l1_l2_fwd_empty[i])
    );

    fifo_v3 #(
      .FALL_THROUGH(1'b0),
      .DATA_WIDTH($bits(coherence_evict_t)),
      .DEPTH(8)
    ) i_l1_l2_evict_fifo (
      .clk_i      (clk_i),
      .rst_ni     (rst_ni),
      .flush_i    (1'b0),
      .testmode_i (1'b0),
      .full_o     (l1_l2_evict_fifo_full[i]),
      .empty_o    (l1_l2_evict_empty[i]),
      .usage_o    (),
      .data_i     (l1_l2_evict_i[i]),
      .push_i     (l1_l2_evict_i[i].valid),
      .data_o     (l1_l2_evict_int[i]),
      .pop_i      (l1_l2_evict_gnt[i] && !l1_l2_evict_empty[i])
    );

    assign l1_l2_fwd_payload[i].fwd = l1_l2_fwd_int[i];
    assign l1_l2_fwd_payload[i].evict = '0;
    assign l1_l2_evict_payload[i].evict = l1_l2_evict_int[i];
    assign l1_l2_evict_payload[i].fwd = '0;

    assign l1_l2_fwd_tcdm_int[i].q.data = l1_l2_fwd_payload[i];
    assign l1_l2_fwd_tcdm_int[i].q.addr = l1_l2_fwd_int[i].addr;
    assign l1_l2_fwd_tcdm_int[i].q_valid = l1_l2_fwd_valid_int[i];
    assign l1_l2_fwd_tcdm_int[i].q.user.is_fwd = 1'b1;

    assign l1_l2_evict_tcdm_int[i].q.data = l1_l2_evict_payload[i];
    assign l1_l2_evict_tcdm_int[i].q.addr = l1_l2_evict_int[i].addr;
    assign l1_l2_evict_tcdm_int[i].q_valid = l1_l2_evict_int[i].valid;
    assign l1_l2_evict_tcdm_int[i].q.user.is_fwd = 1'b0;

    rr_arb_tree #(
      .NumIn     (2),
      .DataType  (tcdm_req_coherence_t),
      .AxiVldRdy (1'b1)
    ) i_pre_fwd_evict_arb (
      .clk_i   (clk_i),
      .rst_ni  (rst_ni),
      .flush_i (1'b0),
      .rr_i    (1'b1),
      .req_i   ({l1_l2_fwd_tcdm_int[i].q_valid, l1_l2_evict_tcdm_int[i].q_valid}),  // valid_i
      .gnt_o   ({l1_l2_fwd_gnt[i], l1_l2_evict_gnt[i]}),  // ready_o
      .data_i  ({l1_l2_fwd_tcdm_int[i], l1_l2_evict_tcdm_int[i]}),
      .req_o   (),                           // valid_o
      .gnt_i   (1'b1),                       // ready_i
      .data_o  (l1_l2_coherence_tcdm[i]),     // data_o,
      .idx_o   ()
    );
  end

  // coherence_down_payload_t  [NumL0CacheCtrl-1:0] l1_l2_fwd_payload, l1_l2_evict_payload;
  for (genvar i = 0; i < NumL1CacheCtrl; i++) begin : downward_post_xbar
    always_comb begin
      l1_l2_fwd_xbar_o[i] = '0;
      l1_l2_fwd_xbar_valid_o[i] = 1'b0;
      l1_l2_evict_xbar_o[i] = '0;
      if (l1_l2_coherence_tcdm_xbar[i].q_valid) begin
        if (l1_l2_coherence_tcdm_xbar[i].q.user.is_fwd) begin
          l1_l2_fwd_xbar_o[i] = l1_l2_coherence_tcdm_xbar[i].q.data.fwd;
          l1_l2_fwd_xbar_valid_o[i] = 1'b1;
          l1_l2_evict_xbar_o[i] = '0;

          // l1_l2_evict_xbar_valid_o[i] = 1'b0;
          l2_l1_fwd_tcdm_int[i].q_ready = l1_l2_fwd_xbar_ready_i[i];
          l2_l1_rsp_tcdm_int[i].q_ready = 1'b0;
        end else begin
          l1_l2_fwd_xbar_o[i] = '0;
          l1_l2_fwd_xbar_valid_o[i] = 1'b0;
          l1_l2_evict_xbar_o[i] = l1_l2_coherence_tcdm_xbar[i].q.data.evict;

          // l1_l2_evict_xbar_valid_o[i] = 1'b1;
          l2_l1_fwd_tcdm_int[i].q_ready = 1'b0;
          l2_l1_rsp_tcdm_int[i].q_ready = l1_l2_evict_xbar_ready_i[i];
        end
      end
    end
  end

  for (genvar i = 0; i < NumL1CacheCtrl; i++) begin : upward_pre_xbar
    assign l2_l1_fwd_ready_o[i] = ~l2_l1_fwd_fifo_full[i] && l2_l1_ready_tcdm_xbar[i];
    assign l2_l1_rsp_ready_o[i] = ~l2_l1_rsp_fifo_full[i] && l2_l1_ready_tcdm_xbar[i];

    fifo_v3 #(
      .FALL_THROUGH(1'b0),
      .DATA_WIDTH($bits(cache_dir_fwd_t)+1),  // +1 for valid bit
      .DEPTH(8)
    ) i_l2_l1_fwd_fifo (
      .clk_i      (clk_i),
      .rst_ni     (rst_ni),
      .flush_i    (1'b0),
      .testmode_i (1'b0),
      .full_o     (l2_l1_fwd_fifo_full[i]),
      .empty_o    (l2_l1_fwd_empty[i]),
      .usage_o    (),
      .data_i     ({l2_l1_fwd_valid_i[i], l2_l1_fwd_i[i]}),
      .push_i     (l2_l1_fwd_valid_i[i]),
      .data_o     ({l2_l1_fwd_valid_int[i], l2_l1_fwd_int[i]}),
      .pop_i      (l2_l1_fwd_gnt[i] && !l2_l1_fwd_empty[i])
    );

    fifo_v3 #(
      .FALL_THROUGH(1'b0),
      .DATA_WIDTH($bits(coherence_rsp_t)+1),  // +1 for valid bit
      .DEPTH(8)
    ) i_l2_l1_rsp_fifo (
      .clk_i      (clk_i),
      .rst_ni     (rst_ni),
      .flush_i    (1'b0),
      .testmode_i (1'b0),
      .full_o     (l2_l1_rsp_fifo_full[i]),
      .empty_o    (l2_l1_rsp_empty[i]),
      .usage_o    (),
      .data_i     ({l2_l1_rsp_valid_i[i], l2_l1_rsp_i[i]}),
      .push_i     (l2_l1_rsp_valid_i[i]),
      .data_o     ({l2_l1_rsp_valid_int[i], l2_l1_rsp_int[i]}),
      .pop_i      (l2_l1_rsp_gnt[i] && !l2_l1_rsp_empty[i])
    );

    assign l2_l1_fwd_payload[i].fwd = l2_l1_fwd_int[i];
    assign l2_l1_fwd_payload[i].rsp = '0;
    assign l2_l1_rsp_payload[i].rsp = l2_l1_rsp_int[i];
    assign l2_l1_rsp_payload[i].fwd = '0;

    assign l2_l1_fwd_tcdm_int[i].p.data = l2_l1_fwd_payload[i];
    // assign l2_l1_fwd_tcdm_int[i].p.addr = l2_l1_fwd_int[i].addr;
    // assign l2_l1_fwd_tcdm_int[i].p.user.addr = l2_l1_fwd_int[i].addr;
    assign l2_l1_fwd_tcdm_int[i].p_valid = l2_l1_fwd_valid_int[i];
    assign l2_l1_fwd_tcdm_int[i].p.user.is_fwd = 1'b1;

    assign l2_l1_rsp_tcdm_int[i].p.data = l2_l1_rsp_payload[i];
    // assign l2_l1_rsp_tcdm_int[i].p.addr = l2_l1_rsp_int[i].addr;
    // assign l2_l1_rsp_tcdm_int[i].p.user.addr = l2_l1_rsp_int[i].addr;
    assign l2_l1_rsp_tcdm_int[i].p_valid = l2_l1_rsp_valid_int[i];
    assign l2_l1_rsp_tcdm_int[i].p.user.is_fwd = 1'b0;
    assign l2_l1_rsp_tcdm_int[i].p.user.core_id = l2_l1_rsp_payload[i].rsp.core_id;
    assign l2_l1_rsp_tcdm_int[i].p.user.req_id = l2_l1_rsp_payload[i].rsp.req_id;

    rr_arb_tree #(
      .NumIn     (2),
      .DataType  (tcdm_rsp_coherence_t),
      .AxiVldRdy (1'b1)
    ) i_post_fwd_rsp_arb (
      .clk_i   (clk_i),
      .rst_ni  (rst_ni),
      .flush_i (1'b0),
      .rr_i    (1'b1),
      .req_i   ({l2_l1_rsp_tcdm_int[i].p_valid, l2_l1_fwd_tcdm_int[i].p_valid}),  // valid_i
      .gnt_o   ({l2_l1_rsp_gnt[i], l2_l1_fwd_gnt[i]}),  // ready_o
      .data_i  ({l2_l1_rsp_tcdm_int[i], l2_l1_fwd_tcdm_int[i]}),
      .req_o   (),                           // valid_o
      .gnt_i   (1'b1),                       // ready_i
      .data_o  (l2_l1_coherence_tcdm[i]),     // data_o,
      .idx_o   ()
    );
  end

  for (genvar i = 0; i < NumL1CacheCtrl; i++) begin : upward_post_xbar
    always_comb begin
      l2_l1_fwd_xbar_o[i] = '0;
      l2_l1_fwd_xbar_valid_o[i] = 1'b0;
      l2_l1_rsp_xbar_o[i] = '0;
      l2_l1_rsp_xbar_valid_o[i] = 1'b0;
      // if (l2_l1_coherence_tcdm_xbar[i].p_valid) begin
      //   if (l2_l1_coherence_tcdm_xbar[i].p.user.is_fwd) begin
      //     l2_l1_fwd_xbar_o[i] = l2_l1_coherence_tcdm_xbar[i].p.data.fwd;
      //     l2_l1_fwd_xbar_valid_o[i] = 1'b1;
      //     l2_l1_rsp_xbar_o[i] = '0;
      //     l2_l1_rsp_xbar_valid_o[i] = 1'b0;

      //     l2_l1_ready_tcdm[i] = l2_l1_fwd_xbar_ready_i[i];
      //   end else begin
      //     l2_l1_fwd_xbar_o[i] = '0;
      //     l2_l1_fwd_xbar_valid_o[i] = 1'b0;
      //     l2_l1_rsp_xbar_o[i] = l2_l1_coherence_tcdm_xbar[i].p.data.rsp;
      //     l2_l1_rsp_xbar_valid_o[i] = 1'b1;

      //     l2_l1_ready_tcdm[i] = l2_l1_rsp_xbar_ready_i[i];
      //   end
      // end
      if (l2_l1_coherence_tcdm_xbar[i].p.user.is_fwd) begin
        l2_l1_ready_tcdm[i] = l2_l1_fwd_xbar_ready_i[i];

        if (l2_l1_coherence_tcdm_xbar[i].p_valid) begin
          l2_l1_fwd_xbar_o[i] = l2_l1_coherence_tcdm_xbar[i].p.data.fwd;
          l2_l1_fwd_xbar_valid_o[i] = 1'b1;
          l2_l1_rsp_xbar_o[i] = '0;
          l2_l1_rsp_xbar_valid_o[i] = 1'b0;
        end
      end else begin
        l2_l1_ready_tcdm[i] = l2_l1_rsp_xbar_ready_i[i];

        if (l2_l1_coherence_tcdm_xbar[i].p_valid) begin
          l2_l1_fwd_xbar_o[i] = '0;
          l2_l1_fwd_xbar_valid_o[i] = 1'b0;
          l2_l1_rsp_xbar_o[i] = l2_l1_coherence_tcdm_xbar[i].p.data.rsp;
          l2_l1_rsp_xbar_valid_o[i] = 1'b1;
        end
      end
    end
  end

  // TODO: check
  // assign l2_l1_fwd_ready_o = l2_l1_ready_tcdm_xbar;
  // assign l2_l1_rsp_ready_o = l2_l1_ready_tcdm_xbar;

  // XBAR
  tcdm_cache_interco #(
    .NumCore          (NumL0CacheCtrl),
    .NumCache         (NumL1CacheCtrl),
    .AddrWidth        (AddrWidth),
    .tcdm_req_t       (tcdm_req_coherence_t),
    .tcdm_rsp_t       (tcdm_rsp_coherence_t),
    .tcdm_req_chan_t  (tcdm_req_chan_coherence_t),
    .tcdm_rsp_chan_t  (tcdm_rsp_chan_coherence_t)
  ) i_coherence_xbar (
    .clk_i            (clk_i),
    .rst_ni           (rst_ni),
    .dynamic_offset_i (dynamic_offset_i),
    .core_req_i       (l1_l2_coherence_tcdm),
    .core_rsp_ready_i (l2_l1_ready_tcdm),
    .core_rsp_o       (l2_l1_coherence_tcdm_xbar),
    .mem_req_o        (l1_l2_coherence_tcdm_xbar),
    .mem_rsp_ready_o  (l2_l1_ready_tcdm_xbar),
    .mem_rsp_i        (l2_l1_coherence_tcdm)
  );

endmodule