// Author: Ho Tin Hung
// Handles 16-to-4 forwarding network from L2 to L1

module coherence_fwd_interco
  import coherence_pkg::*; 
  import hpdcache_pkg::*;  
#(
  parameter int unsigned NumL0CacheCtrl = 4,
  parameter int unsigned NumL1CacheCtrl = 4,
  parameter int unsigned AddrWidth      = 32,

  parameter type         cache_dir_fwd_t              = logic,
  parameter type         dir_ctrl_fwd_t               = logic,
  parameter type         fwd_sel_t                    = logic
) (
  input logic         clk_i,
  input logic         rst_ni,
  
  // L2 to L1 forward channel (class 2)
  input   dir_ctrl_fwd_t  [NumL1CacheCtrl-1:0] l2_l1_fwd_i,
  input   logic           [NumL1CacheCtrl-1:0] l2_l1_fwd_valid_i,
  output  logic           [NumL1CacheCtrl-1:0] l2_l1_fwd_ready_o,
  
  // L1 to L2 forward channel (class 2)
  output  cache_dir_fwd_t [NumL0CacheCtrl-1:0] l2_l1_fwd_o,
  output  logic           [NumL0CacheCtrl-1:0] l2_l1_fwd_valid_o,
  input   logic           [NumL0CacheCtrl-1:0] l2_l1_fwd_ready_i
);

  logic           [NumL1CacheCtrl-1:0] l2_l1_fwd_fifo_full, l2_l1_fwd_fifo_empty;
  dir_ctrl_fwd_t  [NumL1CacheCtrl-1:0] l2_l1_fwd_int;
  logic           [NumL1CacheCtrl-1:0] l2_l1_fwd_valid_int, l2_l1_fwd_ready_int;
  // logic           [NumL1CacheCtrl-1:0] l2_l1_fwd_valid_int_q, l2_l1_fwd_valid_int_d;

  dir_ctrl_fwd_t  l2_l1_fwd_served;
  logic           l2_l1_fwd_served_valid, l2_l1_fwd_served_ready;

  cache_dir_fwd_t [NumL0CacheCtrl-1:0] l2_l1_fwd_unmerged;
  logic           [NumL0CacheCtrl-1:0] l2_l1_fwd_unmerged_valid, l2_l1_fwd_unmerged_ready;
  fwd_sel_t       [NumL0CacheCtrl-1:0] l2_l1_fwd_sel;

  // assign l2_l1_fwd_ready_o = l2_l1_fwd_valid_i & ~l2_l1_fwd_fifo_full;

  for (genvar i = 0; i < NumL1CacheCtrl; i++) begin : gem_fwd_buffer
  //   fifo_v3 #(
  //     .FALL_THROUGH(1'b0),
  //     .DATA_WIDTH($bits(dir_ctrl_fwd_t)+1),  // +1 for valid bit
  //     .DEPTH(4)
  //   ) i_l2_l1_fwd_fifo (
  //     .clk_i      (clk_i),
  //     .rst_ni     (rst_ni),
  //     .flush_i    (1'b0),
  //     .testmode_i (1'b0),
  //     .full_o     (l2_l1_fwd_fifo_full[i]),
  //     .empty_o    (l2_l1_fwd_fifo_empty[i]),
  //     .usage_o    (),
  //     .data_i     ({l2_l1_fwd_valid_i[i], l2_l1_fwd_i[i]}),
  //     .push_i     (l2_l1_fwd_valid_i[i] && !l2_l1_fwd_fifo_full[i]),
  //     .data_o     ({l2_l1_fwd_valid_int[i], l2_l1_fwd_int[i]}),
  //     .pop_i      (l2_l1_fwd_ready_int[i] && !l2_l1_fwd_fifo_empty[i])
  //   );
    stream_fifo #(
      .FALL_THROUGH(1'b0),
      .DATA_WIDTH($bits(dir_ctrl_fwd_t)),
      .DEPTH(4)
    ) i_l2_l1_fwd_fifo (
      .clk_i      (clk_i),
      .rst_ni     (rst_ni),
      .flush_i    (1'b0),
      .testmode_i (1'b0),
      // .full_o     (l2_l1_fwd_fifo_full),
      // .empty_o    (l2_l1_fwd_fifo_empty),
      .usage_o    (),
      .data_i     (l2_l1_fwd_i[i]),
      .valid_i    (l2_l1_fwd_valid_i[i]),
      .ready_o    (l2_l1_fwd_ready_o[i]),
      .data_o     (l2_l1_fwd_int[i]),
      .valid_o    (l2_l1_fwd_valid_int[i]),
      .ready_i    (l2_l1_fwd_ready_int[i])
    );
  end

  rr_arb_tree #(
    .NumIn     (NumL1CacheCtrl),
    .DataType  (dir_ctrl_fwd_t),
    .AxiVldRdy (1'b1)
  ) i_l2_l1_fwd_arb (
    .clk_i   (clk_i),
    .rst_ni  (rst_ni),
    .flush_i (1'b0),
    .rr_i    ('0),
    .req_i   (l2_l1_fwd_valid_int),     // valid_i
    // .req_i   (l2_l1_fwd_valid_int_d),  // registered valid for better timing
    .gnt_o   (l2_l1_fwd_ready_int),     // ready_o
    .data_i  (l2_l1_fwd_int),           // data_i
    .req_o   (l2_l1_fwd_served_valid),  // valid_o
    .gnt_i   (l2_l1_fwd_served_ready),  // ready_i
    .data_o  (l2_l1_fwd_served),        // data_o
    .idx_o   ()
  );

  assign l2_l1_fwd_served_ready = |(l2_l1_fwd_unmerged_ready);

  for (genvar i = 0; i < NumL0CacheCtrl; i++) begin : fwd_unmerge
    always_comb begin
      l2_l1_fwd_unmerged_valid[i] = 1'b0;
      l2_l1_fwd_unmerged[i]       = '0;
      l2_l1_fwd_sel[i]            = '0;
      if (l2_l1_fwd_served_valid) begin
        if (l2_l1_fwd_served.receivers[i] && (l2_l1_fwd_served.fwd_msg_type == INV)) begin
          l2_l1_fwd_unmerged_valid[i]         = 1'b1;
          l2_l1_fwd_unmerged[i].addr          = l2_l1_fwd_served.addr;
          l2_l1_fwd_unmerged[i].fwd_msg_type  = l2_l1_fwd_served.fwd_msg_type;
          l2_l1_fwd_unmerged[i].line_state    = l2_l1_fwd_served.line_state;
          l2_l1_fwd_unmerged[i].core_id       = i;
          l2_l1_fwd_unmerged[i].new_owner     = l2_l1_fwd_served.new_owner;
          l2_l1_fwd_sel[i]                    = i;
        end else if (l2_l1_fwd_served.receivers[i] && (l2_l1_fwd_served.fwd_msg_type == GET)) begin
          l2_l1_fwd_unmerged_valid[i]         = 1'b1;
          l2_l1_fwd_unmerged[i].addr          = l2_l1_fwd_served.addr;
          l2_l1_fwd_unmerged[i].fwd_msg_type  = l2_l1_fwd_served.fwd_msg_type;
          // l2_l1_fwd_unmerged[i].line_state    = l2_l1_fwd_served.line_state;
          l2_l1_fwd_unmerged[i].core_id       = i;
          // l2_l1_fwd_unmerged[i].new_owner     = '0; // not used for GET
          l2_l1_fwd_sel[i]                    = i;
        end
      end
    end
  end

  // TODO: might be redundant as unmerge already does the routing
  stream_xbar #(
    .NumInp       (NumL0CacheCtrl),
    .NumOut       (NumL0CacheCtrl),
    // LockIn cannot be set when using external priority
    .ExtPrio      (1'b0             ),
    .AxiVldRdy    (1'b1             ),
    .LockIn       (1'b1             ),
    .payload_t    (cache_dir_fwd_t  )
  ) i_l2_l1_fwd_xbar (
    .clk_i  (clk_i            ),
    .rst_ni (rst_ni           ),
    .flush_i(1'b0             ),
    // External priority flag
    .rr_i   ('0             ),
    // Master
    .data_i (l2_l1_fwd_unmerged),
    .valid_i(l2_l1_fwd_unmerged_valid),
    .ready_o(l2_l1_fwd_unmerged_ready),
    .sel_i  (l2_l1_fwd_sel),
    // Slave
    .data_o (l2_l1_fwd_o),
    .valid_o(l2_l1_fwd_valid_o),
    .ready_i(l2_l1_fwd_ready_i),
    .idx_o  (/* Unused */)
  );

endmodule