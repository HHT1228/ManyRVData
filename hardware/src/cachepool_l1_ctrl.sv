// Author: Ho Tin Hung

module cachepool_l1_ctrl
  import cachepool_pkg::*; 
  import hpdcache_pkg::*;
  import reqrsp_pkg::*;
  #(
  parameter int unsigned CachePoolReqIdWidth = 8,
  parameter int unsigned TCDMAddrWidth = 32,

  parameter type tcdm_addr_t = logic,
  parameter type coherence_rsp_t = logic,
  parameter type l2_cache_req_t = logic,
  parameter type l2_cache_rsp_t = logic,

  parameter hpdcache_cfg_t HPDcacheCfg = '0,

  parameter type wbuf_timecnt_t = logic,

  //  Request Interface Definitions
  //  {{{
  parameter type hpdcache_tag_t = logic,
  parameter type hpdcache_data_word_t = logic,
  parameter type hpdcache_data_be_t = logic,
  parameter type hpdcache_req_offset_t = logic,
  parameter type hpdcache_req_data_t = logic,
  parameter type hpdcache_req_be_t = logic,
  parameter type hpdcache_req_sid_t = logic,
  parameter type hpdcache_req_tid_t = logic,
  parameter type hpdcache_req_t = logic,
  parameter type hpdcache_rsp_t = logic,
  //  }}}

  //  Memory Interface Definitions
  //  {{{
  parameter type hpdcache_mem_addr_t = logic,
  parameter type hpdcache_mem_id_t = logic,
  parameter type hpdcache_mem_data_t = logic,
  parameter type hpdcache_mem_be_t = logic,
  parameter type hpdcache_mem_req_t = logic,
  parameter type hpdcache_mem_req_w_t = logic,
  parameter type hpdcache_mem_resp_r_t = logic,
  parameter type hpdcache_mem_resp_w_t = logic,
  //  }}}

  // Coherence type parameters
  parameter type cache_dir_fwd_t = logic,
  parameter type sharer_list_t = logic,
  parameter type inv_ack_cnt_t = logic,
  parameter type hpdcache_coherence_rsp_t = logic,
  // parameter type hpdcache_coherence_req_t = logic,
  parameter type coherence_evict_t = logic,
  
  localparam type hpdcache_nline_t = logic [HPDcacheCfg.nlineWidth-1:0]

  ) (
  input  logic                          clk_i,
  input  logic                          rst_ni,
  input  logic                          wbuf_flush_i,

  //      Core request interface
  //         1st cycle
  input  logic                          core_req_valid_i [HPDcacheCfg.u.nRequesters],
  output logic                          core_req_ready_o [HPDcacheCfg.u.nRequesters],
  input  hpdcache_req_t                 core_req_i       [HPDcacheCfg.u.nRequesters],
  //         2nd cycle
  input  logic                          core_req_abort_i [HPDcacheCfg.u.nRequesters],
  input  hpdcache_tag_t                 core_req_tag_i   [HPDcacheCfg.u.nRequesters],
  // input  hpdcache_pma_t                 core_req_pma_i   [HPDcacheCfg.u.nRequesters],

  //      Core response interface
  output logic                          core_rsp_valid_o [HPDcacheCfg.u.nRequesters],
  output hpdcache_rsp_t                 core_rsp_o       [HPDcacheCfg.u.nRequesters],

  // Coherence extension interface
  input   cache_dir_fwd_t               fwd_rx_i,
  input   logic                         fwd_rx_valid_i,
  output  logic                         fwd_rx_ready_o,
  
  output  cache_dir_fwd_t               fwd_tx_o,
  output  logic                         fwd_tx_valid_o,
  input   logic                         fwd_tx_ready_i,
  
  // input   hpdcache_coherence_rsp_t      coherence_rsp_i,
  input   coherence_rsp_t               coherence_rsp_i,
  input   logic                         coherence_rsp_valid_i,
  output  logic                         coherence_rsp_ready_o,
  // output  hpdcache_coherence_req_t      coherence_req_o,
  // output  logic                         coherence_req_valid_o,
  output  coherence_evict_t             coherence_evict_o,
  input   logic                         coherence_evict_ready_i,

  //      Read / Invalidation memory interface
  // input  logic                          mem_req_read_ready_i,
  // output logic                          mem_req_read_valid_o,
  // output hpdcache_mem_req_t             mem_req_read_o,

//   output logic                          mem_resp_read_ready_o,
//   input  logic                          mem_resp_read_valid_i,
//   input  hpdcache_mem_resp_r_t          mem_resp_read_i,
// `ifdef HPDCACHE_OPENPITON
//   input  logic                          mem_resp_read_inval_i,
//   input  hpdcache_nline_t               mem_resp_read_inval_nline_i,
// `endif

  //      Write memory interface
  // input  logic                          mem_req_write_ready_i,
  // output logic                          mem_req_write_valid_o,
  // output hpdcache_mem_req_t             mem_req_write_o,

  // input  logic                          mem_req_write_data_ready_i,
  // output logic                          mem_req_write_data_valid_o,
  // output hpdcache_mem_req_w_t           mem_req_write_data_o,

  // output logic                          mem_resp_write_ready_o,
  // input  logic                          mem_resp_write_valid_i,
  // input  hpdcache_mem_resp_w_t          mem_resp_write_i,

  output l2_cache_req_t                 l2_req_o,
  input  l2_cache_rsp_t                 l2_rsp_i,
  // input  logic                          l2_rsp_valid_i,
  output logic                          l2_rsp_ready_o,

  input logic [$clog2(TCDMAddrWidth)-1:0] dynamic_offset_i,

  //      Performance events
  output logic                          evt_cache_write_miss_o,
  output logic                          evt_cache_read_miss_o,
  output logic                          evt_uncached_req_o,
  output logic                          evt_cmo_req_o,
  output logic                          evt_write_req_o,
  output logic                          evt_read_req_o,
  output logic                          evt_prefetch_req_o,
  output logic                          evt_req_on_hold_o,
  output logic                          evt_rtab_rollback_o,
  output logic                          evt_stall_refill_o,
  output logic                          evt_stall_o,

  //      Status interface
  output logic                          wbuf_empty_o,

  //      Configuration interface
  input  logic                          cfg_enable_i,
  input  wbuf_timecnt_t                 cfg_wbuf_threshold_i,
  input  logic                          cfg_wbuf_reset_timecnt_on_write_i,
  input  logic                          cfg_wbuf_sequential_waw_i,
  input  logic                          cfg_wbuf_inhibit_write_coalescing_i,
  input  logic                          cfg_prefetch_updt_plru_i,
  input  logic                          cfg_error_on_cacheable_amo_i,
  input  logic                          cfg_rtab_single_entry_i,
  input  logic                          cfg_default_wb_i
  
);

  ////////////////
  // PARAMETERS //
  ////////////////
  localparam int unsigned HPDCACHE_NREQUESTERS = 2;   // Snitch + Spatz


  ///////////////////
  // LOCAL SIGNALS //
  ///////////////////
  hpdcache_mem_resp_w_t l1_mem_resp_write;
  logic                 l1_mem_resp_write_valid, l1_mem_resp_write_ready;
  hpdcache_mem_resp_r_t l1_mem_resp_read;
  logic                 l1_mem_resp_read_valid, l1_mem_resp_read_ready;

  // Coalesced requests
  // logic hpd_l1_cache_req_valid_coal [HPDCACHE_NREQUESTERS];
  // logic hpd_l1_cache_req_ready_coal [HPDCACHE_NREQUESTERS];
  logic l1_cache_req_ready_coal;
  // logic hpd_l1_cache_rsp_valid_coal [HPDCACHE_NREQUESTERS];
  // logic hpd_l1_cache_rsp_ready_coal [HPDCACHE_NREQUESTERS];
  // hpdcache_req_t l1_cache_req_coal  [HPDCACHE_NREQUESTERS];
  hpdcache_req_t l1_cache_req_inv   [HPDCACHE_NREQUESTERS];
  logic l1_cache_req_inv_valid      [HPDCACHE_NREQUESTERS];
  // logic l1_cache_req_inv_valid_q    [HPDCACHE_NREQUESTERS];
  logic l1_cache_req_ready_final    [HPDCACHE_NREQUESTERS];
  logic l1_cache_req_valid_final    [HPDCACHE_NREQUESTERS];
  logic l1_cache_req_inv_ready      [HPDCACHE_NREQUESTERS];
  hpdcache_req_t l1_cache_req_final [HPDCACHE_NREQUESTERS];
  // hpdcache_rsp_t l1_cache_rsp_coal  [HPDCACHE_NREQUESTERS];
  // hpdcache_tag_t l1_cache_tag_coal  [HPDCACHE_NREQUESTERS];
  // tcdm_addr_t l1_cache_req_coal_addr     [HPDCACHE_NREQUESTERS];
  // logic [DataWidth*NrL0CoaleserInputs-1:0] l1_cache_req_coal_wdata[HPDCACHE_NREQUESTERS];

  hpdcache_req_t  l1_cache_req_inv_buf;
  logic           l1_cache_req_inv_valid_buf;
  logic           l1_cache_req_inv_ready_buf;
  hpdcache_req_t  l1_cache_req_coal_buf;
  logic           l1_cache_req_coal_valid_buf;
  logic           l1_cache_req_coal_ready_buf;

  hpdcache_coherence_rsp_t l1_coherence_rsp;

  hpdcache_mem_req_t    l1_mem_req_read, l1_mem_req_write, l1_l2_req;
  hpdcache_mem_req_w_t  l1_mem_req_write_data;
  logic                 l1_mem_req_read_valid, l1_mem_req_read_ready;
  logic                 l1_mem_req_write_valid, l1_mem_req_write_data_valid, l1_mem_req_write_both_valid;
  logic                 l1_mem_req_write_ready, l1_mem_req_write_data_ready, __l1_mem_req_write_ready;
  logic                 l1_l2_req_valid, l1_l2_req_ready;
  tcdm_user_t           l1_l2_req_meta;

  ////////////////////////
  // L1 Rsp translation //
  ////////////////////////

  always_comb begin : rsp_translation
    l1_mem_resp_read_valid  = 1'b0;
    l1_mem_resp_write_valid = 1'b0;
    l1_mem_resp_write       = '0;
    l1_mem_resp_read        = '0;

    if (l2_rsp_i.p.write) begin
      l1_mem_resp_write_valid = l2_rsp_i.p_valid;
      l2_rsp_ready_o          = l1_mem_resp_write_ready;

      l1_mem_resp_write.mem_resp_w_is_atomic  = l2_rsp_i.p.user.is_amo;
      l1_mem_resp_write.mem_resp_w_error      = HPDCACHE_MEM_RESP_OK; // grounded for now
      l1_mem_resp_write.mem_resp_w_id         = l2_rsp_i.p.user.req_id - l2_rsp_i.p.user.core_id;
    end else begin
      l1_mem_resp_read_valid = l2_rsp_i.p_valid;
      l2_rsp_ready_o         = l1_mem_resp_read_ready;

      l1_mem_resp_read.data_exclusive = l2_rsp_i.p.user.data_exclusive;
      l1_mem_resp_read.mem_resp_r_id    = l2_rsp_i.p.user.req_id - l2_rsp_i.p.user.core_id;
      l1_mem_resp_read.mem_resp_r_error = HPDCACHE_MEM_RESP_OK; // grounded for now
      l1_mem_resp_read.mem_resp_r_data  = l2_rsp_i.p.data;
      l1_mem_resp_read.mem_resp_r_last  = 1'b1;
    end
  end

  ///////////////////////////
  // L1-L2 Req translation //
  ///////////////////////////

  assign l1_mem_req_write_both_valid = l1_mem_req_write_valid && l1_mem_req_write_data_valid;

  rr_arb_tree #(
    .NumIn     (2),
    .DataType  (hpdcache_mem_req_t),
    .AxiVldRdy (1'b1)  // treat req/gnt as valid/ready
  ) i_l1_l2_req_rr_arb (
    .clk_i   (clk_i),
    .rst_ni  (rst_ni),
    .flush_i (1'b0),
    .rr_i    (1'b1),
    .req_i   ({l1_mem_req_read_valid, l1_mem_req_write_both_valid}),  // valid_i
    .gnt_o   ({l1_mem_req_read_ready, __l1_mem_req_write_ready}),  // ready_o
    .data_i  ({l1_mem_req_read, l1_mem_req_write} ),
    .req_o   (l1_l2_req_valid),            // valid_o
    // .gnt_i   (l2_rsp_i.q_ready),  // TODO: test
    .gnt_i   (1'b1),
    .data_o  (l1_l2_req),
    .idx_o   ()
  );

  // Request meta
  assign l1_l2_req_meta.is_amo          = (l1_l2_req.mem_req_command == HPDCACHE_MEM_ATOMIC);
  assign l1_l2_req_meta.is_fpu          = l1_l2_req.mem_req_id[HPDcacheCfg.u.memIdWidth-1];
  assign l1_l2_req_meta.data_exclusive  = '0;      // req does not carry this info, groudned
  assign l1_l2_req_meta.lost_bits       = l1_l2_req.mem_req_addr[dynamic_offset_i+$clog2(NumL0CacheCtrl)-1-:$clog2(NumL0CacheCtrl)];

  // TODO: handle these at tile-level, HPD does not carry core_id
  // assign l1_l2_req_meta.req_id          = l1_l2_req.mem_req_id[ReqIdWidth-1:0] + cb; // make req_id unique across cores
  assign l1_l2_req_meta.req_id          = l1_l2_req.mem_req_id[CachePoolReqIdWidth-1:0];
  // // assign l1_l2_req_meta.core_id = l1_l2_req.mem_req_id[tidWidth-2:ReqIdWidth+1];
  assign l1_l2_req_meta.core_id         = '0;  // manually tag core_id

  assign l2_req_o.q.addr  = l1_l2_req.mem_req_addr;
  assign l2_req_o.q.write = (l1_l2_req.mem_req_command == HPDCACHE_MEM_WRITE);
  assign l2_req_o.q.amo   = AMONone;

  // Data channel
  assign l2_req_o.q.strb  = l1_mem_req_write_data.mem_req_w_be;
  assign l2_req_o.q.data  = l1_mem_req_write_data.mem_req_w_data;

  // User and handshake
  assign l2_req_o.q.user  = l1_l2_req_meta;
  assign l2_req_o.q_valid = l1_l2_req_valid;

  // Write ready
  assign l1_mem_req_write_ready = __l1_mem_req_write_ready & (l1_mem_req_write_valid & l1_mem_req_write_data_valid);
  assign l1_mem_req_write_data_ready = __l1_mem_req_write_ready;

  ///////////////////////////////
  // Coherence Rsp translation //
  ///////////////////////////////
  assign l1_coherence_rsp.addr_tag        = coherence_rsp_i.addr[L0AddrWidth-1:HPDcacheCfg.reqOffsetWidth];
  assign l1_coherence_rsp.addr_offset     = coherence_rsp_i.addr[HPDcacheCfg.reqOffsetWidth-1:0];
  assign l1_coherence_rsp.tid             = coherence_rsp_i.req_id;
  assign l1_coherence_rsp.is_inv_ack_cnt  = coherence_rsp_i.is_inv_ack_cnt;
  assign l1_coherence_rsp.inv_ack_cnt     = coherence_rsp_i.inv_ack_cnt;

  ///////////////////////
  // Coherence INV CMO //
  ///////////////////////
  // assign l1_cache_req_valid_final[0] = hpd_l1_cache_req_valid_coal[0];
  // assign l1_cache_req_final[0]    = l1_cache_req_coal[0];
  assign l1_cache_req_valid_final[0]  = core_req_valid_i[0];
  assign l1_cache_req_final[0]        = core_req_i[0];

  // assign hpd_l1_cache_req_ready_coal[1] = l1_cache_req_coal_ready_buf;
  // assign hpd_l1_cache_req_ready_coal[0] = l1_cache_req_ready_final[0];
  assign core_req_ready_o[0] = l1_cache_req_ready_final[0];
  assign core_req_ready_o[1] = l1_cache_req_ready_coal;

  always_comb begin
    l1_cache_req_inv_valid[1] = '0;
    // l1_cache_req_inv_valid[1] = l1_cache_req_inv_valid_q[1];
    l1_cache_req_inv[1] = '0;
    if (fwd_rx_valid_i && fwd_rx_i.fwd_msg_type == INV) begin
      // l1_cache_req_inv[1].addr_offset = l1_l1_fwd_xbar.addr[HPDcacheCfg.reqOffsetWidth-1:0];
      l1_cache_req_inv[1].addr_offset   = fwd_rx_i.addr[HPDcacheCfg.reqOffsetWidth-1:0];
      l1_cache_req_inv[1].op            = HPDCACHE_REQ_CMO_INVAL_NLINE;
      l1_cache_req_inv[1].sid           = '0;
      l1_cache_req_inv[1].tid           = '0;
      l1_cache_req_inv[1].need_rsp      = 1'b0;
      l1_cache_req_inv[1].phys_indexed  = 1'b1;
      // l1_cache_req_inv[1].addr_tag = l1_l1_fwd_xbar.addr[L0AddrWidth-1:HPDcacheCfg.reqOffsetWidth];
      l1_cache_req_inv[1].addr_tag      = fwd_rx_i.addr[L0AddrWidth-1:HPDcacheCfg.reqOffsetWidth];

      l1_cache_req_inv_valid[1] = 1'b1;
    end
  end

  spill_register #(
    .T      (hpdcache_req_t ),
    .Bypass (1'b0)
  ) i_l1_inv_spill (
    .clk_i   (clk_i),
    .rst_ni  (rst_ni),
    .valid_i (l1_cache_req_inv_valid[1]),
    .ready_o (l1_cache_req_inv_ready[1]),
    .data_i  (l1_cache_req_inv[1]),
    .valid_o (l1_cache_req_inv_valid_buf),
    .ready_i (l1_cache_req_inv_ready_buf),
    .data_o  (l1_cache_req_inv_buf)
  );

  stream_fifo #(
    .FALL_THROUGH(1'b1),
    .DATA_WIDTH($bits(hpdcache_req_t)),
    .DEPTH(8)
  ) i_l1_coal_fifo (
    .clk_i      (clk_i),
    .rst_ni     (rst_ni),
    .flush_i    (1'b0),
    .testmode_i (1'b0),
    .usage_o    (),
    .data_i     (core_req_i[1]),
    .valid_i    (core_req_valid_i[1]),
    .ready_o    (l1_cache_req_ready_coal),
    .data_o     (l1_cache_req_coal_buf),
    .valid_o    (l1_cache_req_coal_valid_buf),
    .ready_i    (l1_cache_req_coal_ready_buf)
  );

  rr_arb_tree #(
    .NumIn     (2),
    .DataType  (hpdcache_req_t),
    .AxiVldRdy (1'b1)  // treat req/gnt as valid/ready
  ) i_l1_req_inv_arb (
    .clk_i   (clk_i),
    .rst_ni  (rst_ni),
    .flush_i (1'b0),
    .rr_i    (1'b1),
    .req_i   ({l1_cache_req_inv_valid_buf, l1_cache_req_coal_valid_buf}),  // valid_i
    .gnt_o   ({l1_cache_req_inv_ready_buf, l1_cache_req_coal_ready_buf}),  // ready_o
    .data_i  ({l1_cache_req_inv_buf, l1_cache_req_coal_buf}),
    .req_o   (l1_cache_req_valid_final[1]),                 // valid_o
    .gnt_i   (l1_cache_req_ready_final[1]),     // ready_i; old: cache_req_ready
    .data_o  (l1_cache_req_final[1]),
    .idx_o   ()
  );


  hpdcache_pma_t dummy_pma [HPDcacheCfg.u.nRequesters]; // Don't care for non-VIPT, to bypass lint check
  for (genvar i = 0; i < HPDcacheCfg.u.nRequesters; i++) begin : genn_dummy_pma
    assign dummy_pma[i].uncacheable = 1'b0;
    assign dummy_pma[i].io = 1'b0;
    assign dummy_pma[i].wr_policy_hint = HPDCACHE_WR_POLICY_WT;
  end


  //////////////
  // L1 CACHE //
  //////////////
  hpdcache  #(
    .HPDcacheCfg          (HPDcacheCfg),
    .wbuf_timecnt_t       (wbuf_timecnt_t),
    .hpdcache_tag_t       (hpdcache_tag_t),
    .hpdcache_data_word_t (hpdcache_data_word_t),
    .hpdcache_data_be_t   (hpdcache_data_be_t),
    .hpdcache_req_offset_t(hpdcache_req_offset_t),
    .hpdcache_req_data_t  (hpdcache_req_data_t),
    .hpdcache_req_be_t    (hpdcache_req_be_t),
    .hpdcache_req_sid_t   (hpdcache_req_sid_t),
    .hpdcache_req_tid_t   (hpdcache_req_tid_t),
    .hpdcache_req_t       (hpdcache_req_t),
    .hpdcache_rsp_t       (hpdcache_rsp_t),
    .hpdcache_mem_addr_t  (hpdcache_mem_addr_t),
    .hpdcache_mem_id_t    (hpdcache_mem_id_t),
    .hpdcache_mem_data_t  (hpdcache_mem_data_t),
    .hpdcache_mem_be_t    (hpdcache_mem_be_t),
    .hpdcache_mem_req_t   (hpdcache_mem_req_t),
    .hpdcache_mem_req_w_t (hpdcache_mem_req_w_t),
    .hpdcache_mem_resp_r_t(hpdcache_mem_resp_r_t),
    .hpdcache_mem_resp_w_t(hpdcache_mem_resp_w_t),
    .cache_dir_fwd_t      (cache_dir_fwd_t),
    .sharer_list_t        (sharer_list_t),
    .inv_ack_cnt_t        (inv_ack_cnt_t),
    .hpdcache_coherence_rsp_t (hpdcache_coherence_rsp_t),
    // .hpdcache_coherence_req_t (hpdcache_coherence_req_t),
    // .hpdcache_coherence_evict_t (hpdcache_coherence_evict_t)
    .coherence_evict_t    (coherence_evict_t)
  ) i_l1_hpdcache (
    .clk_i                              (clk_i),
    .rst_ni                             (rst_ni),
    .wbuf_flush_i                       (wbuf_flush_i),
    
    // .core_req_valid_i                   (core_req_valid_i),
    // .core_req_ready_o                   (core_req_ready_o),
    // .core_req_i                         (core_req_i),
    .core_req_valid_i                   (l1_cache_req_valid_final),
    .core_req_ready_o                   (l1_cache_req_ready_final),
    .core_req_i                         (l1_cache_req_final),
    .core_req_abort_i                   (core_req_abort_i),
    .core_req_tag_i                     (core_req_tag_i),
    .core_req_pma_i                     (dummy_pma),
    .core_rsp_valid_o                   (core_rsp_valid_o),
    .core_rsp_o                         (core_rsp_o),

    .fwd_rx_i                           (fwd_rx_i),
    .fwd_rx_valid_i                     (fwd_rx_valid_i),
    .fwd_rx_ready_o                     (fwd_rx_ready_o),
    .fwd_tx_o                           (fwd_tx_o),
    .fwd_tx_valid_o                     (fwd_tx_valid_o),
    .fwd_tx_ready_i                     (fwd_tx_ready_i),

    // .coherence_rsp_i                    (coherence_rsp_i),
    .coherence_rsp_i                    (l1_coherence_rsp),
    .coherence_rsp_valid_i              (coherence_rsp_valid_i),
    .coherence_rsp_ready_o              (coherence_rsp_ready_o),

    .coherence_evict_o                  (coherence_evict_o),
    .coherence_evict_ready_i            (coherence_evict_ready_i),

    // .mem_req_read_ready_i               (mem_req_read_ready_i),
    // .mem_req_read_valid_o               (mem_req_read_valid_o),
    // .mem_req_read_o                     (mem_req_read_o),
    .mem_req_read_ready_i               (l1_mem_req_read_ready),
    .mem_req_read_valid_o               (l1_mem_req_read_valid),
    .mem_req_read_o                     (l1_mem_req_read),
    // .mem_resp_read_ready_o              (mem_resp_read_ready_o),
    // .mem_resp_read_valid_i              (mem_resp_read_valid_i),
    // .mem_resp_read_i                    (mem_resp_read_i),
    .mem_resp_read_ready_o              (l1_mem_resp_read_ready),
    .mem_resp_read_valid_i              (l1_mem_resp_read_valid),
    .mem_resp_read_i                    (l1_mem_resp_read),

    // .mem_req_write_ready_i              (mem_req_write_ready_i),
    // .mem_req_write_valid_o              (mem_req_write_valid_o),
    // .mem_req_write_o                    (mem_req_write_o),
    .mem_req_write_ready_i              (l1_mem_req_write_ready),
    .mem_req_write_valid_o              (l1_mem_req_write_valid),
    .mem_req_write_o                    (l1_mem_req_write),
    // .mem_req_write_data_ready_i         (mem_req_write_data_ready_i),
    // .mem_req_write_data_valid_o         (mem_req_write_data_valid_o),
    // .mem_req_write_data_o               (mem_req_write_data_o),
    .mem_req_write_data_ready_i         (l1_mem_req_write_data_ready),
    .mem_req_write_data_valid_o         (l1_mem_req_write_data_valid),
    .mem_req_write_data_o               (l1_mem_req_write_data),
    // .mem_resp_write_ready_o             (mem_resp_write_ready_o),
    // .mem_resp_write_valid_i             (mem_resp_write_valid_i),
    // .mem_resp_write_i                   (mem_resp_write_i),
    .mem_resp_write_ready_o             (l1_mem_resp_write_ready),
    .mem_resp_write_valid_i             (l1_mem_resp_write_valid),
    .mem_resp_write_i                   (l1_mem_resp_write),

    .evt_cache_write_miss_o             (),
    .evt_cache_read_miss_o              (),
    .evt_uncached_req_o                 (/* unused */),
    .evt_cmo_req_o                      (/* unused */),
    .evt_write_req_o                    (),
    .evt_read_req_o                     (),
    .evt_prefetch_req_o                 (/* unused */),
    .evt_req_on_hold_o                  (/* unused */),
    .evt_rtab_rollback_o                (/* unused */),
    .evt_stall_refill_o                 (/* unused */),
    .evt_stall_o                        (),

    .wbuf_empty_o                       (/* unused */),

    .cfg_enable_i                       (1'b1),
    .cfg_wbuf_threshold_i               (3'd2), // copied from hpdcache_lint.sv
    .cfg_wbuf_reset_timecnt_on_write_i  (1'b1),
    .cfg_wbuf_sequential_waw_i          (1'b0),
    .cfg_wbuf_inhibit_write_coalescing_i(1'b0),
    .cfg_prefetch_updt_plru_i           (1'b0),
    .cfg_error_on_cacheable_amo_i       (1'b0),
    .cfg_rtab_single_entry_i            (1'b0),
    .cfg_default_wb_i                   (1'b0)
  );

endmodule