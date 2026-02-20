// Author: Ho Tin Hung

`include "common_cells/registers.svh"

module cahcepool_dir_ctrl 
  import coherence_pkg::*; 
  import hpdcache_pkg::*;
  #(
  
  parameter int unsigned AddrWidth  = 32,
  parameter int unsigned WordWidth  = 64,
  parameter int unsigned TagWidth   = 64,
  parameter int unsigned NumTagBankPerCtrl = 2,
  parameter int unsigned NumCacheEntry = 512,
  parameter int unsigned SetAssociativity = 4,
  parameter int unsigned CacheLineWidth = 512,
  parameter int unsigned NumDataBankPerCtrl = 2,
  parameter int unsigned NumMetaBankPerWay = 2,
  parameter int unsigned BankFactor = 2,

  // Coherence tag extension related parameters
  parameter int unsigned NumCores = 4,
  parameter int unsigned NumCoherenceStates = 4,

  // Type parameters
  parameter type addr_t             = logic [AddrWidth-1:0],
  parameter type word_data_t        = logic [WordWidth-1:0],
  parameter type core_meta_t        = logic,
  parameter type tag_data_t         = logic [TagWidth-1:0],   // 64-bit representation, not actual tag-tag
  // parameter type cache_tag_t      = logic,
  parameter type tcdm_bank_addr_t   = logic,
  parameter type reqid_t            = logic,
  // parameter type fwd_msg_type_t   = logic,
  parameter type cache_dir_fwd_t    = logic,
  parameter type dir_ctrl_fwd_t     = logic,
  parameter type sharer_list_t      = logic,
  // parameter type dir_cache_fwd_t  = logic,
  // parameter type l0_line_state_t  = logic
  parameter type coherence_rsp_t    = logic,
  parameter type coherence_evict_t  = logic,
  parameter type inv_ack_cnt_t      = logic [$clog2(NumCores)-1:0]

) (
  input logic clk_i,
  input logic rst_ni,

  // Request from L1
  input  logic                                              upstream_req_valid_i,
  output logic                                              upstream_req_ready_o,
  input  addr_t                                             upstream_req_addr_i,
  input  core_meta_t                                        upstream_req_meta_i,
  input  logic                                              upstream_req_write_i,
  input  word_data_t                                        upstream_req_wdata_i,
  input  logic                                              upstream_req_is_evict_i,  // TODO: replace with signal below
  input  logic                                              upstream_req_fake_read_i,
  input  coherence_evict_t                                  upstream_req_evict_i,
  output logic                                              upstream_req_evict_ready_o,

  // Cache response to L1
  output logic                                              upstream_resp_valid_o,
  input  logic                                              upstream_resp_ready_i,
  output logic                                              upstream_resp_write_o,
  output word_data_t                                        upstream_resp_data_o,
  output core_meta_t                                        upstream_resp_meta_o,

  // Request to L2
  output logic                                              downstream_req_valid_o,
  input  logic                                              downstream_req_ready_i,
  output addr_t                                             downstream_req_addr_o,
  output core_meta_t                                        downstream_req_meta_o,
  output logic                                              downstream_req_write_o,
  output word_data_t                                        downstream_req_wdata_o,

  // Response from L2
  input  logic                                              downstream_resp_valid_i,
  output logic                                              downstream_resp_ready_o,
  input  logic                                              downstream_resp_write_i,
  input  word_data_t                                        downstream_resp_data_i,
  input  core_meta_t                                        downstream_resp_meta_i,

  // FWD message interface
  input   cache_dir_fwd_t                                   fwd_rx_i,
  input   logic                                             fwd_rx_valid_i,
  output  logic                                             fwd_rx_ready_o,

  output  dir_ctrl_fwd_t                                    fwd_tx_o,
  output  logic                                             fwd_tx_valid_o,
  input   logic                                             fwd_tx_ready_i,

  // Coherence response to L1
  output coherence_rsp_t                                    coherence_rsp_o,
  output logic                                              coherence_rsp_valid_o,
  input  logic                                              coherence_rsp_ready_i,

  // Meta bank (tag) access
  // output logic            [NumTagBankPerCtrl-1:0]           tag_bank_req_o,
  // output logic            [NumTagBankPerCtrl-1:0]           tag_bank_we_o,
  // output tcdm_bank_addr_t [NumTagBankPerCtrl-1:0]           tag_bank_addr_o,
  // output tag_data_t       [NumTagBankPerCtrl-1:0]           tag_bank_wdata_o,
  // output logic            [NumTagBankPerCtrl-1:0]           tag_bank_be_o,
  // input  tag_data_t       [NumTagBankPerCtrl-1:0]           tag_bank_rdata_i,

  // input  logic            [NumDataBankPerCtrl-1:0]          l1_data_bank_gnt_i

  output logic            [SetAssociativity-1:0][NumMetaBankPerWay-1:0]           tag_bank_req_o,
  output logic            [SetAssociativity-1:0][NumMetaBankPerWay-1:0]           tag_bank_we_o,
  output tcdm_bank_addr_t [SetAssociativity-1:0][NumMetaBankPerWay-1:0]           tag_bank_addr_o,
  output tag_data_t       [SetAssociativity-1:0][NumMetaBankPerWay-1:0]           tag_bank_wdata_o,
  output logic            [SetAssociativity-1:0][NumMetaBankPerWay-1:0]           tag_bank_be_o,
  input  tag_data_t       [SetAssociativity-1:0][NumMetaBankPerWay-1:0]           tag_bank_rdata_i,

  input  logic            [SetAssociativity-1:0][NumMetaBankPerWay-1:0]           l1_data_bank_gnt_i,
  // input  logic            [SetAssociativity-1:0][NumMetaBankPerWay-1:0]           cache_tag_bank_gnt_i,  
  input  logic            [SetAssociativity-1:0][NumMetaBankPerWay-1:0]           dir_tag_bank_gnt_i
);

  /**
  * Local parameters
  */
  localparam int unsigned CacheBankDepth    = NumCacheEntry/SetAssociativity;
  localparam int unsigned NumLRUBits        = $clog2(SetAssociativity);
  localparam int unsigned NumActualTagBits  = AddrWidth - $clog2(CacheLineWidth/8) - $clog2(CacheBankDepth);

  /**
  * Type definitions
  */
  // Coherence metadata as exntension to L2 tags
  // typedef logic [$clog2(NumCoherenceStates)-1:0] dir_line_state_t;
  // typedef logic [NumCores-1:0]                   sharer_list_t;
  typedef logic [NumActualTagBits-1:0]           cache_tag_t;
  
  typedef enum logic [1:0] {
    EVEN = 2'b00,
    ODD  = 2'b01,
    BOTH = 2'b10
  } pseudo_port_t;

  typedef enum logic [2:0] {
    DIR_LINE_INVALID      = 3'b000,
    DIR_LINE_SHARED       = 3'b001,
    DIR_LINE_EXCLUSIVE    = 3'b010,
    DIR_LINE_MODIFIED     = 3'b011,
    DIR_LINE_ESA          = 3'b100    // substate
  } dir_line_state_t;

  typedef struct packed {
    dir_line_state_t      line_state;
    sharer_list_t         sharers;
  } coherence_meta_t;
  /**
  * Internal signals
  */
  // logic            tag_bank_req_r, tag_bank_req_w;
  // tcdm_bank_addr_t tag_bank_addr_r, tag_bank_addr_w;
  // tag_data_t       tag_bank_rdata, tag_bank_wdata;
  logic                               busy, busy_q, busy_d; // Does not accept new req when busy

  tcdm_bank_addr_t                    tag_bank_addr, tag_bank_addr_q, tag_bank_addr_d;
  // tcdm_bank_addr_t                    tag_bank_waddr;
  // tag_data_t [NumTagBankPerCtrl-1:0]  tag_bank_rdata;
  tag_data_t [SetAssociativity-1:0]   tag_bank_rdata, tag_bank_wdata;
  logic                               tag_bank_write_req;

  tag_data_t                          curr_line_meta, curr_line_meta_q;
  // logic      [SetAssociativity-1:0]   way_hit;
  // logic                               curr_line_meta_valid;
  coherence_meta_t                    line_coherence_meta, next_coherence_meta, next_coherence_meta_q;
  dir_line_state_t                    curr_line_state;
  // l0_line_state_t                     next_line_state;
  hpd_coherence_state_t               next_line_state, next_line_state_q;
  sharer_list_t                       curr_sharer_list;
  pseudo_port_t                       tag_bank_port_accessed_q, tag_bank_port_accessed_d;

  fwd_msg_type_t                      fwd_msg_type;

  core_meta_t                         upstream_req_meta_q;
  logic                               upstream_req_valid_q, upstream_req_is_evict_q, upstream_req_write_q;
  coherence_evict_t                   upstream_req_evict_q, upstream_req_evict_d;
  core_meta_t                         upstream_req_meta_d;
  logic                               upstream_req_valid_d, upstream_req_is_evict_d, upstream_req_write_d;
  word_data_t                         upstream_req_wdata_q, upstream_req_wdata_d;
  // logic                               upstream_req_valid_d, upstream_req_is_evict_d, upstream_req_write_d;

  addr_t                              upstream_req_addr_q, upstream_req_addr_d;

  logic                               downstream_req_valid_q, downstream_req_valid_d;
  // logic                                              downstream_req_ready_,
  addr_t                              downstream_req_addr_q, downstream_req_addr_d;
  core_meta_t                         downstream_req_meta_q, downstream_req_meta_d;
  logic                               downstream_req_write_q, downstream_req_write_d;
  word_data_t                         downstream_req_wdata_q, downstream_req_wdata_d;

  logic                               tag_bank_gnt, tag_bank_gnt_q;
  logic                               upstream_req_fake_read_q, upstream_req_fake_read_d;

  // cache_dir_fwd_t                     fwd_tx_q, fwd_tx_d;
  dir_ctrl_fwd_t                      fwd_tx_q, fwd_tx_d;
  logic                               fwd_tx_valid_q, fwd_tx_valid_d;

  coherence_rsp_t                     coherence_rsp_q, coherence_rsp_d;
  logic                               coherence_rsp_valid_q, coherence_rsp_valid_d;

  inv_ack_cnt_t                       inv_ack_count;
  logic                               op_decoded;

  sharer_list_t                       inv_receivers, inv_receivers_q;

  `FF(next_line_state_q, next_line_state, HPDCACHE_INVALID, clk_i, rst_ni)
  `FF(next_coherence_meta_q, next_coherence_meta, '0, clk_i, rst_ni)
  `FF(curr_line_meta_q, curr_line_meta, '0, clk_i, rst_ni)
  `FF(inv_receivers_q, inv_receivers, '0, clk_i, rst_ni)
  
  // TODO: meta may not need to be latched
  // `FF(upstream_req_meta_q, upstream_req_meta_i, '0, clk_i, rst_ni)
  // `FF(upstream_req_valid_q, upstream_req_valid_i, 1'b0, clk_i, rst_ni)
  // `FF(upstream_req_is_evict_q, upstream_req_is_evict_i, 1'b0, clk_i, rst_ni)
  // `FF(upstream_req_write_q, upstream_req_write_i, 1'b0, clk_i, rst_ni)
  
  // `FF(upstream_req_addr_q, upstream_req_addr_i, '0, clk_i, rst_ni)

  assign tag_bank_gnt = |(dir_tag_bank_gnt_i);
  `FF(tag_bank_gnt_q, tag_bank_gnt, 1'b0, clk_i, rst_ni)

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if(!rst_ni) begin
      upstream_req_meta_q       <= '0;
      upstream_req_valid_q      <= 1'b0;
      upstream_req_is_evict_q   <= 1'b0;
      upstream_req_write_q      <= 1'b0;
      upstream_req_addr_q       <= '0;
      upstream_req_fake_read_q  <= 1'b0;
      upstream_req_evict_q      <= '0;
    end else if (op_decoded) begin
      upstream_req_valid_q      <= 1'b0; // Clear after decoding the op (one cycle after granted)
      upstream_req_meta_q       <= upstream_req_meta_d;
      upstream_req_is_evict_q   <= upstream_req_is_evict_d;
      upstream_req_write_q      <= upstream_req_write_d;
      upstream_req_addr_q       <= upstream_req_addr_d;
      upstream_req_fake_read_q  <= upstream_req_fake_read_d;
      upstream_req_wdata_q      <= upstream_req_wdata_d;
      upstream_req_evict_q      <= '0;
    end else begin
      // otherwise hold current value
      upstream_req_meta_q       <= upstream_req_meta_d;
      upstream_req_valid_q      <= upstream_req_valid_d;
      upstream_req_is_evict_q   <= upstream_req_is_evict_d;
      upstream_req_write_q      <= upstream_req_write_d;
      upstream_req_addr_q       <= upstream_req_addr_d;
      upstream_req_fake_read_q  <= upstream_req_fake_read_d;
      upstream_req_wdata_q      <= upstream_req_wdata_d;
      upstream_req_evict_q      <= upstream_req_evict_d;
    end
    // else if (upstream_req_valid_i && upstream_req_ready_o && !upstream_req_fake_read_i) begin
    //   // Update on new request
    //   upstream_req_meta_q    <= upstream_req_meta_i;
    //   upstream_req_valid_q   <= upstream_req_valid_i;
    //   upstream_req_is_evict_q<= upstream_req_is_evict_i;
    //   upstream_req_write_q   <= upstream_req_write_i;
    //   upstream_req_addr_q    <= upstream_req_addr_i;
    //   upstream_req_fake_read_q <= upstream_req_fake_read_i;
    // // end else if (tag_bank_gnt) begin
    // //   // Clear on next cycle after granted
    // //   upstream_req_meta_q    <= '0;
    // //   upstream_req_valid_q   <= 1'b0;
    // //   upstream_req_is_evict_q<= 1'b0;
    // //   upstream_req_write_q   <= 1'b0;
    // //   upstream_req_addr_q    <= '0;
    // //   upstream_req_fake_read_q <= 1'b0;
    //   // upstream_req_meta_q    <= upstream_req_meta_d;
    //   // upstream_req_valid_q   <= upstream_req_valid_d;
    //   // upstream_req_is_evict_q<= upstream_req_is_evict_d;
    //   // upstream_req_write_q   <= upstream_req_write_d;
    //   // upstream_req_addr_q    <= upstream_req_addr_d;
    // end else if (upstream_req_evict_i.valid) begin
    //   upstream_req_evict_q   <= upstream_req_evict_i;
    // end
  end

  always_comb begin
    upstream_req_meta_d       = upstream_req_meta_q;
    upstream_req_valid_d      = upstream_req_valid_q;
    upstream_req_is_evict_d   = upstream_req_is_evict_q;
    upstream_req_write_d      = upstream_req_write_q;
    upstream_req_addr_d       = upstream_req_addr_q;
    upstream_req_fake_read_d  = upstream_req_fake_read_q;
    upstream_req_wdata_d      = upstream_req_wdata_q;
    upstream_req_evict_d      = upstream_req_evict_q;

    if (upstream_req_valid_i && upstream_req_ready_o && !upstream_req_fake_read_i) begin
      // Update on new request
      upstream_req_meta_d       = upstream_req_meta_i;
      upstream_req_valid_d      = upstream_req_valid_i;
      upstream_req_is_evict_d   = upstream_req_is_evict_i;
      upstream_req_write_d      = upstream_req_write_i;
      upstream_req_addr_d       = upstream_req_addr_i;
      upstream_req_fake_read_d  = upstream_req_fake_read_i;
      upstream_req_wdata_d      = upstream_req_wdata_i;
    end else if (upstream_req_evict_i.valid) begin
      upstream_req_evict_d   = upstream_req_evict_i;
    end
  end

  // When upstream_req_valid_i AND not busy: give ready hdshk and process new addr
  // assign tag_bank_addr = busy ? tag_bank_addr : upstream_req_addr_i[$clog2(CacheBankDepth) + $clog2(CacheLineWidth/8)-1 : $clog2(CacheLineWidth/8)];

  // assign busy = (upstream_req_valid_i || downstream_req_valid_o || fwd_tx_valid_o || fwd_rx_valid_i || tag_bank_we_o) ? !busy : busy;
  // always_comb begin
  //   if (upstream_req_valid_i || fwd_rx_valid_i) begin
  //     busy_d = 1'b1;
  //   end else if (downstream_req_valid_o || fwd_tx_valid_o || tag_bank_we_o) begin
  //     busy_d = 1'b0;
  //   end
  // end

  // Directory controller is busy when processing a request
  // always_ff @(posedge clk_i or negedge rst_ni) begin
  //   if (!rst_ni) begin
  //     busy <= 1'b0;
  //   end else if ((upstream_req_valid_i || fwd_rx_valid_i) && !upstream_req_fake_read_i) begin
  //     busy <= 1'b1;
  //   end else if (downstream_req_valid_o || fwd_tx_valid_o || tag_bank_write_req) begin
  //     busy <= 1'b0;
  //   end
  // end

  always_comb begin
    if (downstream_req_valid_o || fwd_tx_valid_o || tag_bank_write_req) begin
      busy_d = 1'b0;
    end else if ((upstream_req_valid_i || fwd_rx_valid_i) && !upstream_req_fake_read_i) begin
      busy_d = 1'b1;
    end else begin
      busy_d = busy_q;
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      busy_q <= 1'b0;
    end else begin
      busy_q <= busy_d;
    end
  end

  assign busy = busy_q;

  // assign upstream_req_ready_o = !busy;

  always_comb begin : dir_ctrl_ready
    fwd_rx_ready_o              = 1'b0;
    upstream_req_ready_o        = 1'b0;
    upstream_req_evict_ready_o  = 1'b0;

    // Fwd is sink with higher priority than req
    if (!busy) begin
      if (fwd_rx_valid_i) begin
        fwd_rx_ready_o              = 1'b1;
      end else if (upstream_req_valid_i) begin
        upstream_req_ready_o        = 1'b1;
      end else if (upstream_req_evict_i.valid) begin
        upstream_req_evict_ready_o  = 1'b1;
      end
    end
  end

  // Hold tag addr for write to tag bank
  // always_ff @(posedge clk_i or negedge rst_ni) begin
  //   if (!rst_ni) begin
  //     tag_bank_addr_q <= '0;
  //   end else if (!busy) begin
  //     tag_bank_addr_q <= tag_bank_addr;
  //   end else begin
  //     tag_bank_addr_q <= tag_bank_addr_d;
  //   end
  // end

  // assign tag_bank_addr_d = tag_bank_addr_q;
  // assign tag_bank_addr = upstream_req_addr_i[$clog2(CacheBankDepth) + $clog2(CacheLineWidth/8)-1 : $clog2(CacheLineWidth/8)];

  // Read request
  logic tag_bank_rvalid, tag_bank_rvalid_q, tag_bank_rvalid_d;
  logic [SetAssociativity-1:0] tag_bank_rready;

  always_comb begin
    tag_bank_rvalid_d = tag_bank_rvalid_q;
    tag_bank_addr_d   = tag_bank_addr_q;

    if (!upstream_req_fake_read_i && !busy) begin
      // if (downstream_resp_valid_i) begin
      //   tag_bank_rvalid_d = 1'b1;
      //   tag_bank_addr_d   = downstream_req_addr_q[$clog2(CacheBankDepth) + $clog2(CacheLineWidth/8)-1 : $clog2(CacheLineWidth/8)];
      // end else 
      if (fwd_rx_valid_i) begin
        tag_bank_rvalid_d = 1'b1;
        tag_bank_addr_d   = fwd_rx_i.addr[$clog2(CacheBankDepth) + $clog2(CacheLineWidth/8)-1 : $clog2(CacheLineWidth/8)];
      end else if (upstream_req_valid_i) begin
        tag_bank_rvalid_d = 1'b1;
        tag_bank_addr_d   = upstream_req_addr_i[$clog2(CacheBankDepth) + $clog2(CacheLineWidth/8)-1 : $clog2(CacheLineWidth/8)];
      end else if (upstream_req_evict_i.valid) begin
        tag_bank_rvalid_d = 1'b1;
        tag_bank_addr_d   = upstream_req_evict_i.addr[$clog2(CacheBankDepth) + $clog2(CacheLineWidth/8)-1 : $clog2(CacheLineWidth/8)];
      end
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      tag_bank_rvalid_q <= 1'b0;
      tag_bank_addr_q   <= '0;
    end else if (tag_bank_rvalid_d && |tag_bank_rready) begin
      tag_bank_rvalid_q <= 1'b0;
      tag_bank_addr_q   <= tag_bank_addr_d;      
    end else begin
      tag_bank_rvalid_q <= tag_bank_rvalid_d;
      tag_bank_addr_q   <= tag_bank_addr_d;
    end
  end

  for (genvar i = 0; i < SetAssociativity; i++) begin: gen_tag_bank_access
    tcdm_bank_addr_t tag_bank_addr_int, tag_bank_waddr_int;
    logic tag_bank_read_valid_int;
    logic tag_bank_read_ready_int;
    logic tag_bank_write_req_int;
    tag_data_t tag_bank_rdata_int, tag_bank_wdata_int;

    logic rport_size_matcher, wport_size_matcher, rport_size_matcher_int, wport_size_matcher_int;

    insitu_cache_bank_access_controller #(
      .DEPTH              (CacheBankDepth),
      .NumWordsPerLine    (1),
      .WordWidth          (TagWidth)
    ) i_access_ctrl_tag_bank (
      .clk_i                       (clk_i),
      .rst_ni                      (rst_ni),

      // .upstream_read_addr_i        (tag_bank_addr),
      // .upstream_read_valid_i       (upstream_req_valid_i && !busy && !upstream_req_fake_read_i),
      .upstream_read_addr_i        ({1'b0, tag_bank_addr_d}),
      .upstream_read_valid_i       (tag_bank_rvalid_d),
      .upstream_read_ready_o       (tag_bank_rready[i]),
      .upstream_read_data_o        (tag_bank_rdata[i]),

      .upstream_write_addr_i       ({1'b0, tag_bank_addr_d}),
      .upstream_write_req_i        (tag_bank_write_req),
      // .upstream_write_req_i        ('0),
      .upstream_write_data_i       (tag_bank_wdata[i]),

      .downstream_read_addr_o      ({rport_size_matcher_int, tag_bank_addr_int}),
      .downstream_read_valid_o     (tag_bank_read_valid_int),
      .downstream_read_ready_i     (tag_bank_read_ready_int),
      .downstream_read_data_i      (tag_bank_rdata_int),

      .downstream_write_addr_o     ({wport_size_matcher_int, tag_bank_waddr_int}),
      .downstream_write_req_o      (tag_bank_write_req_int),
      .downstream_write_data_o     (tag_bank_wdata_int),

      // .bank_gnt_i                  (&(l1_data_bank_gnt_i[i]))
      .bank_gnt_i                  ('1)   // FIXME: this blocks outgoing requests
      // .bank_gnt_i                  (&(dir_tag_bank_gnt_i[i]))

    );

    pseudo_dual_port_tcdm_wrapper #(
      .DEPTH              (CacheBankDepth),
      .NumPseudoDualBanks (BankFactor),
      // .NumPseudoDualBanks (1),
      .NumWordsPerLine    (1),
      .WordWidth          (TagWidth)
    ) i_tag_bank_access (
      .clk_i              (clk_i),
      .rst_ni             (rst_ni),

      .read_addr_i        ({1'b0, tag_bank_addr_int}),
      .read_valid_i       (tag_bank_read_valid_int),
      .read_ready_o       (tag_bank_read_ready_int),
      .read_data_o        (tag_bank_rdata_int),

      .write_addr_i       ({1'b0, tag_bank_waddr_int}),
      .write_req_i        (tag_bank_write_req_int),
      .write_data_i       (tag_bank_wdata_int),

      .tcdm_bank_req_o    (tag_bank_req_o[i]),
      .tcdm_bank_we_o     (tag_bank_we_o[i]),
      .tcdm_bank_addr_o   (tag_bank_addr_o[i]),
      .tcdm_bank_wdata_o  (tag_bank_wdata_o[i]),
      .tcdm_bank_be_o     (tag_bank_be_o[i]),
      .tcdm_bank_rdata_i  (tag_bank_rdata_i[i])
    );
  end


  // track which port is used to access tag bank
  // TODO: maybe not needed as the access ctrl handles already
  always_comb begin
    if(tag_bank_req_o[0] == 2'b01) begin
      tag_bank_port_accessed_d = EVEN;
    end else if(tag_bank_req_o[0] == 2'b10) begin
      tag_bank_port_accessed_d = ODD;
    end else if(tag_bank_req_o[0] == 2'b11) begin
      tag_bank_port_accessed_d = BOTH;
    end else begin
      tag_bank_port_accessed_d = BOTH; // Default value
    end
  end

  // always_ff @(posedge clk_i or negedge rst_ni) begin
  //   if (!rst_ni) begin
  //     tag_bank_port_accessed_q <= BOTH;
  //   end else begin
  //     tag_bank_port_accessed_q <= tag_bank_port_accessed_d;
  //   end
  // end

  `FF(tag_bank_port_accessed_q, tag_bank_port_accessed_d, BOTH, clk_i, rst_ni)

  // for (genvar i = 0; i < SetAssociativity; i++) begin: gen_way_selection
  //   cache_tag_t curr_cacheline_tag;
  //   // tag_data_t  curr_cacheline_meta;
  //   // assign curr_cacheline_tag = tag_bank_rdata[i][NumLRUBits +: NumActualTagBits];
  //   always_comb begin
  //     if (tag_bank_port_accessed == EVEN) begin
  //       curr_cacheline_tag = tag_bank_rdata[i][0][NumLRUBits +: NumActualTagBits];
  //       if (curr_cacheline_tag == upstream_req_addr_i[AddrWidth-1 -: NumActualTagBits]) begin
  //         // curr_line_meta = tag_bank_rdata[i][0];
  //         way_hit[i] = 1'b1;
  //         // break;
  //       end else begin
  //         way_hit[i] = 1'b0;
  //         // curr_line_meta = '0;
  //         // continue;
  //       end
  //     end else begin
  //       curr_cacheline_tag = tag_bank_rdata[i][1][NumLRUBits +: NumActualTagBits];
  //       if (curr_cacheline_tag == upstream_req_addr_i[AddrWidth-1 -: NumActualTagBits]) begin
  //         // curr_line_meta = tag_bank_rdata[i][1];
  //         // break;
  //         way_hit[i] = 1'b1;
  //       end else begin
  //         // curr_line_meta = '0;
  //         // continue;
  //         way_hit[i] = 1'b0;
  //       end
  //     end
  //   end
  // end

  // way-selection
  tag_data_t curr_line_meta_reg;
  logic      curr_line_hit;
  logic [$clog2(SetAssociativity)-1:0] way_id, way_id_q;
  cache_tag_t [SetAssociativity-1:0] local_tag;

  always_comb begin
    curr_line_meta_reg = '0;      // default: no match -> zero meta
    curr_line_hit      = 1'b0;
    way_id             = '0;
    // way_id             = 2'b01; // test

    // scan ways once (single always_comb)
    for (int i = 0; i < SetAssociativity; i++) begin
      // tag_data_t local_meta;
      // cache_tag_t local_tag;

      // pick the port data according to tag_bank_port_accessed
      // unique case (tag_bank_port_accessed_q)
      //   EVEN: local_meta = tag_bank_rdata[i][0];
      //   ODD:  local_meta = tag_bank_rdata[i][1];
      //   BOTH: begin
      //     // If BOTH, prefer port 0 (or you can decide other policy)
      //     local_meta = tag_bank_rdata[i][0];
      //   end
      //   default: local_meta = tag_bank_rdata[i][0];
      // endcase

      // extract tag bits from the meta (same slicing you used before)
      local_tag[i] = tag_bank_rdata[i][NumLRUBits +: NumActualTagBits];

      // If not already found a hit, compare and latch
      // if (!curr_line_hit && (local_tag == upstream_req_addr_i[AddrWidth-1 -: NumActualTagBits])) begin
      if (!curr_line_hit &&
          (local_tag[i] == upstream_req_addr_d[AddrWidth-1 -: NumActualTagBits]) &&
          (upstream_req_addr_d[AddrWidth-1 -: NumActualTagBits] != '0) &&
          tag_bank_gnt_q) begin
        curr_line_meta_reg = tag_bank_rdata[i];
        curr_line_hit      = 1'b1;
        way_id             = i;
      end
    end
  end

  // `FF(way_id_q, way_id, '0, clk_i, rst_ni)

  // drive the external name that other logic expects
  assign curr_line_meta = curr_line_meta_reg;

  assign line_coherence_meta = curr_line_meta[TagWidth-1 -: $bits(coherence_meta_t)];
  assign curr_line_state     = line_coherence_meta.line_state;
  assign curr_sharer_list    = line_coherence_meta.sharers;

  assign fwd_msg_type = fwd_rx_i.fwd_msg_type;

  // TODO: integrate with request/response interface
  // Operation classes
  typedef enum logic [3:0] {
    OP_NONE               = 4'd0,
    OP_READ               = 4'd1, // GetS from requester
    OP_WRITE              = 4'd2, // GetE/Upgrade from requester
    OP_GETACK             = 4'd3, // Owner reply with latest data (after probe)
    OP_EVICT_S            = 4'd4, // PutS from evictor
    OP_EVICT_M_OWNER      = 4'd5, // PutM from current owner
    OP_EVICT_M_NONOWNER   = 4'd6, // PutM from non-owner (illegal but Ack)
    OP_EVICT_E_OWNER      = 4'd7, // PutE from owner
    OP_EVICT_E_NONOWNER   = 4'd8  // PutE from non-owner (illegal but Ack)
  } dir_op_t;

  // ---- Inputs this FSM needs
  dir_op_t                       op;
  logic [$clog2(NumCores)-1:0]   req_sid;       // requester core id (for READ/WRITE)
  reqid_t                        req_tid;       // request transaction id
  // logic [$clog2(NumCores)-1:0]   evict_id;    // evictor id (for Put*/Evict*)

  // ---- Per-line state
  dir_line_state_t  state_q, state_d;
  sharer_list_t     sharers_q, sharers_d;

  // ---- Actions (one-cycle pulses)
  typedef struct packed {
    logic send_excl_data;      // GrantE + data to requester
    logic send_sh_data;        // GrantS + data to requester
    logic send_inv_to_sharers; // invalidate all current sharers
    logic send_inv_to_owner;   // invalidate/downgrade current owner
    logic send_probe_owner;    // ask owner for latest data (Read in E/M)
    logic send_evict_ack;      // EvictAck to evictor
    logic send_inv_ack_cnt;    // send expected invalidation ack count to L1
    logic mem_write;           // push dirty to memory (owner PutM)
    logic update_l2_data;      // accept/serialize WT data at L2
    logic update_sharers;      // commit sharers_d to tag/meta RAM
    logic update_state;        // commit state_d to tag/meta RAM
  } dir_actions_t;

  dir_actions_t act, act_q;

  `FF(act_q, act, '0, clk_i, rst_ni)

  // ---- Remember the pending reader when we’re in ESA (E-substate) ----
  logic [$clog2(NumCores)-1:0] pending_req_q, pending_req_d;


  /***************************
  * Cache response bypassing
  ***************************/
  // Cache response signals does not go through directory logic
  always_comb begin : rsp_bypass
    upstream_resp_valid_o = downstream_resp_valid_i;
    upstream_resp_write_o = downstream_resp_write_i;
    upstream_resp_data_o  = downstream_resp_data_i;
    upstream_resp_meta_o  = downstream_resp_meta_i;

    downstream_resp_ready_o = upstream_resp_ready_i;
  end

  /***************************
  * Request operation decoding
  ***************************/
  always_comb begin : req_op_decode
    // req_sid = upstream_req_meta_i.core_id;
    // req_tid = upstream_req_meta_i.req_id;
    // req_sid = upstream_req_meta_q.core_id;
    // req_tid = upstream_req_meta_q.req_id;
    req_sid = upstream_req_meta_d.core_id;
    req_tid = upstream_req_meta_d.req_id;
    op_decoded = 1'b0;

    // if(upstream_req_valid_i) begin
    //   if (upstream_req_is_evict_i) begin
    // if(upstream_req_valid_q && busy && !upstream_req_fake_read_q) begin
    if(upstream_req_valid_d && busy && !upstream_req_fake_read_d) begin
      // if (upstream_req_is_evict_q) begin
      // if (upstream_req_evict_q.valid) begin
      if (upstream_req_evict_d.valid) begin
        case (curr_line_state)
          DIR_LINE_INVALID: begin
            op = OP_EVICT_S; // evictor is non-owner
          end
          DIR_LINE_SHARED: begin
            op = OP_EVICT_S; // evictor is non-owner
          end
          DIR_LINE_EXCLUSIVE: begin
            if (curr_sharer_list[req_sid]) begin
              op = OP_EVICT_E_OWNER; // evictor is owner
            end else begin
              op = OP_EVICT_E_NONOWNER; // evictor is non-owner
            end
          end
          DIR_LINE_MODIFIED: begin
            if (curr_sharer_list[req_sid]) begin
              op = OP_EVICT_M_OWNER; // evictor is owner
            end else begin
              op = OP_EVICT_M_NONOWNER; // evictor is non-owner
            end
          end
          default: begin
            op = OP_NONE;
          end
        endcase
        op_decoded = 1'b1;
      // end else if (upstream_req_write_i) begin
      // end else if (upstream_req_write_q) begin
      end else if (upstream_req_write_d) begin
        op      = OP_WRITE;
        op_decoded = 1'b1;
      // end else if (!upstream_req_write_i) begin
      // end else if (!upstream_req_write_q) begin
      end else if (!upstream_req_write_d) begin
        op      = OP_READ;
        op_decoded = 1'b1;
      end else begin
        op      = OP_NONE;    // default
      end
    end else if (fwd_rx_valid_i) begin
      case (fwd_msg_type)
        GET_ACK: begin
        // 2'b11: begin
          op = OP_GETACK; // GetAck from owner
        end
        // TODO: INV_ACK handle, forward to L1. Need to track new owner. OR between L1s, add core id to outgoing invalidations for inter-L1 forwarding.
        // HPD send INV_ACK to FIFO-based forwarder. Forwarder send it to the owner.
        default: begin
          op = OP_NONE; // other fwd messages not handled here
        end
      endcase
      op_decoded = 1'b1;
    end else begin
      op     = OP_NONE;    // default
    end
  end

  // always_ff @(posedge clk_i or negedge rst_ni) begin
  //   if (!rst_ni) begin
  //     op_q <= OP_NONE;
  //   end else begin
  //     op_q <= op_d;
  //   end
  // end

  // assign op = op_q;
  
  /***************************
  * Action handling
  ***************************/
  always_comb begin : act_req_to_l2_ctrl
    downstream_req_valid_d    = downstream_req_valid_q;
    downstream_req_addr_d     = downstream_req_addr_q;
    downstream_req_meta_d     = downstream_req_meta_q;
    downstream_req_write_d    = downstream_req_write_q;
    downstream_req_wdata_d    = downstream_req_wdata_q;
    // if(act.send_excl_data || act.send_sh_data) begin  // read req to L2
    if (act_q.send_excl_data || act_q.send_sh_data) begin  // read req to L2
      // downstream_req_valid_o    = 1'b1;
      // downstream_req_valid_o    = upstream_req_valid_q || downstream_req_ready_i;
      // downstream_req_addr_o     = upstream_req_addr_q;
      // downstream_req_meta_o     = upstream_req_meta_q;
      // // downstream_req_write_o    = '0;
      // downstream_req_write_o    = upstream_req_write_q;
      // downstream_req_wdata_o    = upstream_req_wdata_i;

      // downstream_req_valid_d    = upstream_req_valid_d;
      downstream_req_valid_d    = 1'b1;
      downstream_req_addr_d     = upstream_req_addr_d;
      // downstream_req_meta_d     = upstream_req_meta_d;
      downstream_req_meta_d.core_id = upstream_req_meta_d.core_id;
      downstream_req_meta_d.is_amo  = upstream_req_meta_d.is_amo;
      downstream_req_meta_d.req_id  = upstream_req_meta_d.req_id;
      downstream_req_meta_d.is_fpu  = upstream_req_meta_d.is_fpu;
      downstream_req_meta_d.data_exclusive  = act_q.send_excl_data;

      downstream_req_write_d    = upstream_req_write_d;
      // downstream_req_write_d    = '0;
      downstream_req_wdata_d    = upstream_req_wdata_i;
    // end else if (act.update_l2_data) begin            // write req to L2
    end else if (act_q.update_l2_data) begin            // write req to L2
      // downstream_req_valid_o    = 1'b1;
      // downstream_req_valid_o    = upstream_req_valid_q || downstream_req_ready_i;
      // downstream_req_addr_o     = upstream_req_addr_q;
      // downstream_req_meta_o     = upstream_req_meta_q;
      // // downstream_req_write_o    = 1'b1;
      // downstream_req_write_o    = upstream_req_write_q;
      // downstream_req_wdata_o    = upstream_req_wdata_i; // no need to latch as observed, could be dangerous
      
      // downstream_req_valid_d    = upstream_req_valid_d;
      downstream_req_valid_d    = 1'b1;
      downstream_req_addr_d     = upstream_req_addr_d;
      downstream_req_meta_d     = upstream_req_meta_d;
      downstream_req_write_d    = upstream_req_write_d;
      // downstream_req_write_d    = 1'b1;
      downstream_req_wdata_d    = upstream_req_wdata_i; // no need to latch as observed, could be dangerous

    // end else if (upstream_req_fake_read_i) begin
    //   // Fake read fall-thru without triggering coherence engine
    //   downstream_req_valid_o    = upstream_req_valid_i;
    //   downstream_req_addr_o     = upstream_req_addr_i;
    //   downstream_req_meta_o     = upstream_req_meta_i;
    //   downstream_req_write_o    = upstream_req_write_i;
    //   downstream_req_wdata_o    = upstream_req_wdata_i;
      
    // end else if (!downstream_req_ready_i) begin
    //   // Hold request until downstream ready
    //   downstream_req_valid_o    = upstream_req_valid_q;
    //   downstream_req_addr_o     = upstream_req_addr_q;
    //   downstream_req_meta_o     = upstream_req_meta_q;
    //   downstream_req_write_o    = upstream_req_write_q;
    //   downstream_req_wdata_o    = upstream_req_wdata_i; // no need to latch as observed, could be dangerous
    // end else begin
    //   // downstream_req_valid_o    = 1'b0;
    //   // downstream_req_addr_o     = '0;
    //   // downstream_req_meta_o     = '0;
    //   // downstream_req_write_o    = 1'b0;
    //   // downstream_req_wdata_o    = '0;

    //   // downstream_req_valid_d    = 1'b0;
    //   // downstream_req_addr_d     = '0;
    //   // downstream_req_meta_d     = '0;
    //   // downstream_req_write_d    = 1'b0;
    //   // downstream_req_wdata_d    = '0;

    //   downstream_req_valid_d    = downstream_req_valid_q;
    //   downstream_req_addr_d     = downstream_req_addr_q;
    //   downstream_req_meta_d     = downstream_req_meta_q;
    //   downstream_req_write_d    = downstream_req_write_q;
    //   downstream_req_wdata_d    = downstream_req_wdata_q;
    end 
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      downstream_req_valid_q <= 1'b0;
      downstream_req_addr_q  <= '0;
      downstream_req_meta_q  <= '0;
      downstream_req_write_q <= 1'b0;
      downstream_req_wdata_q <= '0;
    end else if (downstream_req_ready_i) begin
      // Deassert after handshake
      downstream_req_valid_q <= 1'b0;
      downstream_req_addr_q  <= '0;
      downstream_req_meta_q  <= '0;
      downstream_req_write_q <= 1'b0;
      downstream_req_wdata_q <= '0;
    end else begin
      // Otherwise hold
      downstream_req_valid_q <= downstream_req_valid_d;
      downstream_req_addr_q  <= downstream_req_addr_d;
      downstream_req_meta_q  <= downstream_req_meta_d;
      downstream_req_write_q <= downstream_req_write_d;
      downstream_req_wdata_q <= downstream_req_wdata_d;
    end
  end

  assign downstream_req_valid_o = upstream_req_fake_read_i ? upstream_req_valid_i : downstream_req_valid_d;
  assign downstream_req_addr_o  = upstream_req_fake_read_i ? upstream_req_addr_i : downstream_req_addr_d;
  assign downstream_req_meta_o  = upstream_req_fake_read_i ? upstream_req_meta_i : downstream_req_meta_d;
  assign downstream_req_write_o = upstream_req_fake_read_i ? upstream_req_write_i : downstream_req_write_d;
  assign downstream_req_wdata_o = upstream_req_fake_read_i ? upstream_req_wdata_i : downstream_req_wdata_d;

  always_comb begin
    case (next_coherence_meta.line_state)
      DIR_LINE_INVALID: begin
        next_line_state = HPDCACHE_INVALID;
      end
      DIR_LINE_SHARED: begin
        next_line_state = HPDCACHE_SHARED;
      end
      DIR_LINE_EXCLUSIVE: begin
        next_line_state = HPDCACHE_EXCLUSIVE;
      end
      DIR_LINE_MODIFIED: begin
        next_line_state = HPDCACHE_MODIFIED;
      end      
      default: begin
        next_line_state = HPDCACHE_INVALID;
      end
    endcase
  end

  // always_comb begin : act_fwd_tx
  //   fwd_tx_o.addr           = upstream_req_addr_q;
  //   // fwd_tx_o.line_state     = next_coherence_meta.line_state;
  //   fwd_tx_o.line_state     = next_line_state;
  //   if(act.send_inv_to_owner || act.send_inv_to_sharers) begin
  //     // fwd_tx_o: HPD invalidation and extended tag
  //     fwd_tx_o.fwd_msg_type = INV;
  //     fwd_tx_valid_o        = 1'b1;
  //   end else if(act.send_probe_owner) begin
  //     // fwd_tx_o: HPD interface extension required
  //     fwd_tx_o.fwd_msg_type = GET;
  //     fwd_tx_valid_o        = 1'b1;
  //   end else begin
  //     fwd_tx_o.fwd_msg_type = INV;
  //     fwd_tx_valid_o        = 1'b0;
  //   end
  // end

  // FIXME: need to include destination core id + multiple req (like broadcast?)
  always_comb begin : act_fwd_tx
    fwd_tx_d        = fwd_tx_q;
    fwd_tx_valid_d  = fwd_tx_valid_q;

    // if(act.send_inv_to_owner || act.send_inv_to_sharers) begin
    if(act_q.send_inv_to_owner || act_q.send_inv_to_sharers) begin
      fwd_tx_d.addr           = upstream_req_addr_d;
      // fwd_tx_d.line_state     = next_line_state;
      fwd_tx_d.line_state     = next_line_state_q;
      fwd_tx_d.fwd_msg_type   = INV;
      fwd_tx_valid_d          = 1'b1;
      fwd_tx_d.inv_receivers  = inv_receivers_q;
    // end else if(act.send_probe_owner) begin
    end else if(act_q.send_probe_owner) begin
      fwd_tx_d.addr           = upstream_req_addr_d;
      // fwd_tx_d.line_state     = next_line_state;
      fwd_tx_d.line_state     = next_line_state_q;
      fwd_tx_d.fwd_msg_type   = GET;
      fwd_tx_valid_d          = 1'b1;
      fwd_tx_d.inv_receivers  = '0;
    end
    // else begin
    //   fwd_tx_d.fwd_msg_type = INV;
    //   fwd_tx_valid_d        = 1'b0;
    // end
  end

  assign fwd_tx_o        = fwd_tx_d;
  assign fwd_tx_valid_o  = fwd_tx_valid_d;

  always_ff @(posedge clk_i or negedge rst_ni) begin : act_fwd_tx_ff
    if (!rst_ni) begin
      fwd_tx_q        <= '0;
      fwd_tx_valid_q  <= 1'b0;
    end else if (fwd_tx_valid_o && fwd_tx_ready_i) begin
      // Clear after handshake
      fwd_tx_q        <= '0;
      fwd_tx_valid_q  <= 1'b0;
    end else begin
      fwd_tx_q        <= fwd_tx_d;
      fwd_tx_valid_q  <= fwd_tx_valid_d;
    end
  end

  // always_comb begin : act_coherence_rsp
  //   if(act.send_evict_ack) begin
  //     coherence_rsp_o.core_id     = req_sid;
  //     coherence_rsp_o.req_id      = req_tid;
  //     coherence_rsp_o.addr        = upstream_req_addr_q;
  //     coherence_rsp_o.is_inv_ack_cnt  = 1'b0;
  //     coherence_rsp_o.inv_ack_cnt = '0; // no data
  //     coherence_rsp_valid_o       = 1'b1;
  //   end else if (act.send_inv_ack_cnt) begin
  //     coherence_rsp_o.core_id     = req_sid;
  //     coherence_rsp_o.req_id      = req_tid;
  //     coherence_rsp_o.addr        = upstream_req_addr_q;
  //     coherence_rsp_o.is_inv_ack_cnt  = 1'b1;
  //     coherence_rsp_o.inv_ack_cnt = inv_ack_count;
  //     coherence_rsp_valid_o       = 1'b1;
  //   end else begin
  //     coherence_rsp_o       = '0;
  //     coherence_rsp_valid_o = 1'b0;
  //   end
  // end

  always_comb begin : act_coherence_rsp
    coherence_rsp_d       = coherence_rsp_q;
    coherence_rsp_valid_d = coherence_rsp_valid_q;

    // if(act.send_evict_ack) begin
    if(act_q.send_evict_ack) begin
      coherence_rsp_d.core_id         = req_sid;
      coherence_rsp_d.req_id          = req_tid;
      coherence_rsp_d.addr            = upstream_req_addr_d;
      coherence_rsp_d.is_inv_ack_cnt  = 1'b0;
      coherence_rsp_d.inv_ack_cnt     = '0; // no data
      coherence_rsp_valid_d           = 1'b1;
    // end else if (act.send_inv_ack_cnt) begin
    end else if (act_q.send_inv_ack_cnt) begin
      coherence_rsp_d.core_id         = req_sid;
      coherence_rsp_d.req_id          = req_tid;
      coherence_rsp_d.addr            = upstream_req_addr_d;
      coherence_rsp_d.is_inv_ack_cnt  = 1'b1;
      coherence_rsp_d.inv_ack_cnt     = inv_ack_count;
      coherence_rsp_valid_d           = 1'b1;
    end 
    // else begin
    //   coherence_rsp_d       = '0;
    //   coherence_rsp_valid_d = 1'b0;
    // end
  end

  assign coherence_rsp_o       = coherence_rsp_d;
  assign coherence_rsp_valid_o = coherence_rsp_valid_d;

  always_ff @(posedge clk_i or negedge rst_ni) begin : act_coherence_rsp_ff
    if (!rst_ni) begin
      coherence_rsp_q       <= '0;
      coherence_rsp_valid_q <= 1'b0;
    end else if (coherence_rsp_valid_o && coherence_rsp_ready_i) begin
      // Clear after handshake
      coherence_rsp_q       <= '0;
      coherence_rsp_valid_q <= 1'b0;
    end else begin
      coherence_rsp_q       <= coherence_rsp_d;
      coherence_rsp_valid_q <= coherence_rsp_valid_d;
    end
  end

  // TODO: not sure if needed, L2 can handle eviction whenever it likes
  // always_comb begin : act_mem_write
  //   if(act.mem_write) begin
      
  //   end else begin

  //   end
  // end
  
  always_comb begin : act_write_to_tag_bank
    // tag_bank_waddr = '0;
    tag_bank_write_req = 1'b0;
    tag_bank_wdata = '0;
    // if(act.update_sharers || act.update_state) begin
    if(act_q.update_sharers || act_q.update_state) begin
      // tag_bank_waddr = tag_bank_addr_d;
      tag_bank_write_req = 1'b1;
      // tag_bank_wdata[way_id] = {next_coherence_meta, curr_line_meta[(TagWidth - $bits(next_coherence_meta)) - 1:0]};
      tag_bank_wdata[way_id] = {next_coherence_meta_q, curr_line_meta_q[(TagWidth - $bits(next_coherence_meta_q)) - 1:0]};
    end
  end

  /***************************
  * Coherence FSM
  ***************************/
  // Seed current state/meta from tag read
  // always_comb begin
  //   state_q   = curr_line_state;
  //   sharers_q = curr_sharer_list;
  // end

  // Next-state logic of main FSM
  dir_line_state_t current_state;
  sharer_list_t    current_sharers;
  // assign tag_bank_gnt = |(dir_tag_bank_gnt_i);
  assign current_state   = tag_bank_gnt_q ? curr_line_state : state_q;
  assign current_sharers = tag_bank_gnt_q ? curr_sharer_list : sharers_q;
  always_comb begin
    // Defaults: hold
    state_d       = state_q;
    sharers_d     = sharers_q;
    pending_req_d = pending_req_q;
    act           = '0;
    inv_ack_count = '0;
    inv_receivers = '0;

    // unique case (state_q)
    unique case (current_state)
      // Invalid state (I)
      DIR_LINE_INVALID: begin
        unique case (op)
          OP_READ: begin  // Receiving Read op
            // Send exclusive to requester; transition to E
            act.send_excl_data = 1'b1;
            sharers_d          = '0;
            sharers_d          = set_bit(sharers_d, req_sid);
            act.update_sharers = 1'b1;
            state_d            = DIR_LINE_EXCLUSIVE;
            act.update_state       = 1'b1;
          end
          OP_WRITE: begin
            // Accept WT @L2; requester becomes owner (M)
            act.update_l2_data = 1'b1;
            sharers_d          = '0;
            sharers_d          = set_bit(sharers_d, req_sid);
            act.update_sharers = 1'b1;
            state_d            = DIR_LINE_MODIFIED;
            act.update_state       = 1'b1;
          end
          // Any eviction against I: just ack
          OP_EVICT_S, OP_EVICT_M_NONOWNER, OP_EVICT_E_OWNER, OP_EVICT_E_NONOWNER: begin
            act.send_evict_ack = 1'b1;
          end
          default: ;
        endcase
      end

      // Share state (S)
      DIR_LINE_SHARED: begin
        unique case (op)
          OP_READ: begin
            act.send_sh_data   = 1'b1;
            sharers_d          = set_bit(sharers_d, req_sid);
            act.update_sharers = 1'b1;     // stay S
          end
          OP_WRITE: begin
            // Upgrade: invalidate all sharers, serialize WT, owner=req
            act.send_inv_to_sharers = 1'b1;
            act.update_l2_data      = 1'b1;
            // inv_ack_count           = count_set_bits(sharers_q);
            inv_ack_count           = count_set_bits(current_sharers);
            sharers_d               = '0;
            sharers_d               = set_bit(sharers_d, req_sid);
            act.update_sharers      = 1'b1;
            state_d                 = DIR_LINE_MODIFIED;
            act.update_state        = 1'b1;
            inv_receivers           = current_sharers & ~(1'b1 << req_sid);
            // inv_receivers           = current_sharers;
          end
          // Evictions remove bit; S->I if last sharer leaves
          OP_EVICT_S, OP_EVICT_M_NONOWNER, OP_EVICT_E_NONOWNER, OP_EVICT_E_OWNER, OP_EVICT_M_OWNER: begin
            // sharers_d          = clr_bit(sharers_d, evict_id);
            sharers_d          = clr_bit(sharers_d, req_sid);
            act.update_sharers = 1'b1;
            act.send_evict_ack = 1'b1;
            state_d            = (sharers_d == '0) ? DIR_LINE_INVALID : DIR_LINE_SHARED;
            act.update_state   = 1'b1;
          end
          default: ;
        endcase
      end

      // Exclusive state (E)
      DIR_LINE_EXCLUSIVE: begin
        unique case (op)
          OP_READ: begin
            // Another reader arrives: probe owner first; go ESA
            act.send_probe_owner = 1'b1;
            pending_req_d        = req_sid;
            state_d              = DIR_LINE_ESA;
            act.update_state     = 1'b1;
          end
          OP_WRITE: begin
            // Writer arrives: invalidate current owner; serialize WT; new owner=req
            act.send_inv_to_owner = 1'b1;   // FIXME: don't need this, for temp debug xbar
            act.update_l2_data    = 1'b1;
            sharers_d             = '0;
            sharers_d             = set_bit(sharers_d, req_sid);
            act.update_sharers    = 1'b1;
            state_d               = DIR_LINE_MODIFIED;
            act.update_state      = 1'b1;
            inv_receivers         = current_sharers;
          end
          OP_GETACK: begin
            // No outstanding probe → ignore
          end
          OP_EVICT_S, OP_EVICT_M_NONOWNER, OP_EVICT_E_NONOWNER: begin
            act.send_evict_ack = 1'b1;
          end
          OP_EVICT_M_OWNER: begin
            act.mem_write      = 1'b1;
            act.send_evict_ack = 1'b1;
            sharers_d          = '0;
            act.update_sharers = 1'b1;
            state_d            = DIR_LINE_INVALID;
            act.update_state       = 1'b1;
          end
          OP_EVICT_E_OWNER: begin
            act.send_evict_ack = 1'b1;
            sharers_d          = '0;       // clear owner
            act.update_sharers = 1'b1;
            state_d            = DIR_LINE_INVALID;
            act.update_state       = 1'b1;
          end
          default: ;
        endcase
      end

      // ES_A state (transient state between E/M and S, waiting for GetAck)
      DIR_LINE_ESA: begin
        unique case (op)
          OP_READ, OP_WRITE: begin
            // Stall others on this line; arbiters should queue
          end
          OP_GETACK: begin
            // Owner returned latest data → serve pending reader, then S
            act.send_sh_data   = 1'b1;     // to pending_req_q
            // sharers_d          = set_bit(sharers_q, pending_req_q);
            sharers_d          = set_bit(current_sharers, pending_req_q);
            act.update_sharers = 1'b1;
            state_d            = DIR_LINE_SHARED; // TODO: S or E if only one sharer left
            act.update_state       = 1'b1;
          end
          // Evictions while waiting: Ack them; still respond to pending read once GETACK arrives
          OP_EVICT_S, OP_EVICT_M_NONOWNER, OP_EVICT_E_NONOWNER: begin
            act.send_evict_ack = 1'b1;
          end
          OP_EVICT_M_OWNER: begin
            act.mem_write  = 1'b1;
            act.send_evict_ack = 1'b1;
            // when GETACK/data arrives, we still reply to the waiting reader
          end
          OP_EVICT_E_OWNER: begin
            act.send_evict_ack = 1'b1;
          end
          default: ;
        endcase
      end

      // modified state (M)
      DIR_LINE_MODIFIED: begin
        unique case (op)
          OP_READ: begin
            // Someone wants to read: probe owner then S
            if (current_sharers[req_sid] == 1'b1) begin
              // Owner read on M line: effectively exclusive read, no probe needed
              act.send_excl_data   = 1'b1;
              // TODO: this transition might be redudant
              // Keep L1 L2 consistent or tolerate E/M inconsistency?
              state_d              = DIR_LINE_EXCLUSIVE;
              act.update_state     = 1'b1;
            end else begin
              act.send_probe_owner = 1'b1;
              pending_req_d        = req_sid;
              state_d              = DIR_LINE_ESA;
              act.update_state     = 1'b1;
            end
          end
          OP_WRITE: begin
            // Another writer: invalidate current owner; serialize WT; new owner=req
            act.send_inv_to_owner = 1'b1; // FIXME: no need
            act.update_l2_data    = 1'b1;
            sharers_d             = '0;
            sharers_d             = set_bit(sharers_d, req_sid);
            act.update_sharers    = 1'b1;
            state_d               = DIR_LINE_MODIFIED;
            inv_receivers         = current_sharers;
          end
          OP_EVICT_S, OP_EVICT_M_NONOWNER, OP_EVICT_E_NONOWNER: begin
            act.send_evict_ack = 1'b1;
          end
          OP_EVICT_M_OWNER: begin
            act.mem_write  = 1'b1;
            act.send_evict_ack = 1'b1;
            sharers_d          = '0;
            act.update_sharers = 1'b1;
            state_d            = DIR_LINE_INVALID;
            act.update_state       = 1'b1;
          end
          OP_EVICT_E_OWNER: begin
            // “Owner evicts E” is illegal in M but we just clear & Ack
            act.send_evict_ack = 1'b1;
            sharers_d          = '0;
            act.update_sharers = 1'b1;
            state_d            = DIR_LINE_INVALID;
            act.update_state       = 1'b1;
          end
          default: ;
        endcase
      end

      default: ;
    endcase
  end

  // State registers
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      state_q       <= DIR_LINE_INVALID;
      sharers_q     <= '0;
      pending_req_q <= '0;
    // end else if (upstream_req_valid_i & upstream_req_ready_o) begin
    // end else if (curr_line_hit) begin
    // end else if (tag_bank_gnt) begin
    //   state_q       <= curr_line_state;
    //   sharers_q     <= curr_sharer_list;
    //   pending_req_q <= pending_req_d;
    end else begin
      state_q       <= state_d;
      sharers_q     <= sharers_d;
      // state_q       <= DIR_LINE_INVALID;
      // sharers_q     <= '0;
      pending_req_q <= pending_req_d;
    end
  end

  // Optionally compose the new meta to write back to the tag word when act.update_sharers is set
  assign next_coherence_meta.line_state = state_d;   // or state_d if you write in same cycle
  assign next_coherence_meta.sharers    = sharers_d; // or sharers_d

  // To manipulate the sharer bit-vector
  function automatic sharer_list_t set_bit(sharer_list_t sharers, int unsigned sid);
    return (sharers | (sharer_list_t'(1) << sid));
  endfunction
  function automatic sharer_list_t clr_bit(sharer_list_t sharers, int unsigned sid);
    return (sharers & ~(sharer_list_t'(1) << sid));
  endfunction
  function automatic inv_ack_cnt_t count_set_bits(sharer_list_t sharers);
    inv_ack_cnt_t count;
    count = '0;
    for (int i = 0; i < NumCores; i++) begin
      if (sharers[i]) begin
        count = count + 1;
      end
    end
    return count;
  endfunction


endmodule