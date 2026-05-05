// Author: Ho Tin Hung

// `define CACHE_DIRECT  // bypass directory controller

module cachepool_l2_wrapper
  import cachepool_pkg::*;
  import coherence_pkg::*; 
  #(
  /*************************
  * Core Access Parameters *
  *************************/
  /// Number of spatz core complex
  parameter int unsigned NumPorts                                         = 10,
  /// Coalescer Extned Factor
  parameter int unsigned CoalExtFactor                                    = 1,
  /// Meta information payload from spatz/snitch
  parameter type         core_meta_t                                      = logic[7:0],
  /// Address width of both narrow request from spatz
  parameter int unsigned AddrWidth                                        = 32,
  /// Width of word (granularity of non-blocking write)
  parameter int unsigned WordWidth                                        = 64,
  /// Width of Tag Bank data
  parameter int unsigned TagWidth                                         = 64,

  /**********************
  * Cache Configuration *
  **********************/
  /// Number of Cache entries
  parameter int unsigned NumCacheEntry                                    = 512,
  /// Word width of cache line (512b default)
  parameter int unsigned CacheLineWidth                                   = 512,
  /// Number of Associatity
  parameter int unsigned SetAssociativity                                 = 4,
  /// Number of Pseudo-Dual Banks
  parameter int unsigned BankFactor                                       = 2,

  // Additional parameters
  parameter int unsigned NumL1CacheCtrl                                   = 4,
  parameter int unsigned NumTagBankPerCtrl                                = 4,
  parameter int unsigned NumDataBankPerCtrl                               = 4,
  parameter int unsigned SpatzAxiAddrWidth                                = 32,
  parameter int unsigned TCDMAddrWidth                                    = 32,
  parameter int unsigned L1CacheWayEntry                                  = 4,
  // parameter int unsigned L1BankFactor                                     = 2,
  // parameter int unsigned L1LineWidth                                      = 512,
  parameter int unsigned NumMetaBankPerWay                                = 2,

  /***************************
  * ReqRsp Bus Configuration *
  ***************************/
  /// ReqRsp data width
  parameter int unsigned  RefillDataWidth                                 = 128,
  parameter type          refill_req_t                                    = logic,
  parameter type          refill_rsp_t                                    = logic,
  parameter type          burst_req_t                                     = logic,

  /**************************
  * FIFO SRAM Configuration *
  **************************/
  parameter type          impl_in_t                                       = logic,

  /*************************
  * Additional Types       *
  *************************/
  // parameter type          cache_refill_req_chan_t                         = logic,
  // parameter type          cache_refill_rsp_chan_t                         = logic,
  parameter type          cache_trans_req_t                               = logic,
  parameter type          cache_trans_rsp_t                               = logic,
  parameter type          tag_data_t                                      = logic,
  parameter type          cacheline_data_t                                = logic,
  parameter type          reqid_t                                         = logic,
  // parameter type          fwd_msg_type_t                                  = logic,
  parameter type          cache_dir_fwd_t                                 = logic,
  parameter type          dir_ctrl_fwd_t                                  = logic,
  parameter type          sharer_list_t                                   = logic,
  // parameter type          l0_line_state_t                                 = logic,
  parameter type          coherence_rsp_t                                 = logic,
  parameter type          coherence_evict_t                               = logic,

  /***********************
  * Dependent Parameters *
  ***********************/
  // Dependent parameter, do not override. Burst length of each visit.
  localparam int unsigned BurstLength                                     = CacheLineWidth/RefillDataWidth,
  // Dependent parameter, do not override. Depth of cache bank.
  localparam int unsigned CacheWaysEntry                                  = NumCacheEntry/SetAssociativity,
  // Dependent parameter, do not override. Number of data bank per way.
  localparam int unsigned NumDataBankPerWay                               = BankFactor * (CacheLineWidth/WordWidth),
  // Dependent parameter, do not override. Number of meta bank per way.
  localparam int unsigned NumTagBankPerWay                                = BankFactor,
  // Dependent parameter, do not override. Address type.
  localparam type         addr_t                                          = logic [AddrWidth-1:0],
  // Dependent parameter, do not override. Address type.
  localparam type         tcdm_bank_addr_t                                = logic [$clog2(CacheWaysEntry)-$clog2(BankFactor)-1:0],
  // Dependent parameter, do not override. TCDM Tag type.
  localparam type         tcdm_tag_data_t                                 = logic [TagWidth-1:0],
  // Dependent parameter, do not override. word type.
  localparam type         word_data_t                                     = logic [WordWidth-1:0],
  localparam type         write_strb_t                                    = logic [CacheLineWidth/8-1:0]
  )(


  /// Clock, positive edge triggered.
  input  logic                                                            clk_i,
  /// Reset, active low.
  input  logic                                                            rst_ni,

  // input  logic          [$clog2(AddrWidth)-1:0] dynamic_offset_i,

  /// Sync Control Signals
  input  logic                                                            cache_sync_valid_i,
  output logic                                                            cache_sync_ready_o,
  /*  00-> flush+invalidation
      01-> flush only
      10-> invalidation only
      11-> all tag initialization*/
  input  logic [1:0]                                                      cache_sync_insn_i,

  /// Cache Partitioning Signals
  input  tcdm_bank_addr_t                                                 bank_depth_for_SPM_i,

  /// spatz requests
  input  logic                                              core_req_valid_i,
  output logic                                              core_req_ready_o,
  input  addr_t                                             core_req_addr_i,
  input  core_meta_t                                        core_req_meta_i,
  input  logic                                              core_req_write_i,
  input  word_data_t                                        core_req_wdata_i,
  input  logic                                              core_req_fake_read_i,
  input  coherence_evict_t                                  upstream_req_evict_i,
  output logic                                              upstream_req_evict_ready_o,
  // input  write_strb_t                                       core_req_wstrb_i,

  /// spatz responses
  output logic                                              core_resp_valid_o,
  input  logic                                              core_resp_ready_i,
  output logic                                              core_resp_write_o,
  output word_data_t                                        core_resp_data_o,
  output core_meta_t                                        core_resp_meta_o,
  // output logic                                              core_resp_exclusive_o,

  // FWD message for directory controller
  input  cache_dir_fwd_t                                          fwd_rx_i,
  input  logic                                                    fwd_rx_valid_i,
  output logic                                                    fwd_rx_ready_o,
  output dir_ctrl_fwd_t                                           fwd_tx_o,
  output logic                                                    fwd_tx_valid_o,
  input  logic                                                    fwd_tx_ready_i,

  // Coherence response to L1 cache controller
  output coherence_rsp_t                                     coherence_rsp_o,
  output logic                                               coherence_rsp_valid_o,
  input  logic                                               coherence_rsp_ready_i,

  /// FIFO SRAM Configuration
  input   impl_in_t       [1:0]                                           impl_i,

  // cache refill ports
  output cache_trans_req_t    cache_refill_req_o,
  input  cache_trans_rsp_t    cache_refill_rsp_i,

  // bitmasks from outside
  input logic             [SpatzAxiAddrWidth-1:0] bitmask_lo_i,
  input logic             [SpatzAxiAddrWidth-1:0] bitmask_up_i,
  input logic             [$clog2(TCDMAddrWidth)-1:0] dynamic_offset_i,
  
  input logic             [$clog2(NumL1CacheCtrl)-1:0]  cb_id_i
);

  localparam NumSelBits = $clog2(NumL1CacheCtrl);
  localparam NumWordPerLine = 1;
  
  parameter int unsigned SRAMBeWidth        = ($bits(tag_data_t) + 32'd8 - 32'd1) / 32'd8;
  parameter int unsigned CoherenceMetaBytes = ($bits(coherence_meta_t) + 32'd8 - 32'd1) / 32'd8;

  typedef logic [SRAMBeWidth-1:0]       sram_be_t; 
  
  sram_be_t     [NumTagBankPerCtrl-1:0] meta_bank_be;

  refill_req_t     cache_refill_req;
  burst_req_t      cache_refill_burst;
  logic            cache_refill_req_valid, cache_refill_req_ready;
  refill_rsp_t     cache_refill_rsp;
  logic            cache_refill_rsp_valid, cache_refill_rsp_ready;

  logic            [NumTagBankPerCtrl-1:0] l1_tag_bank_req;
  logic            [NumTagBankPerCtrl-1:0] l1_tag_bank_we;
  tcdm_bank_addr_t [NumTagBankPerCtrl-1:0] l1_tag_bank_addr;
  tag_data_t       [NumTagBankPerCtrl-1:0] l1_tag_bank_wdata;
  logic            [NumTagBankPerCtrl-1:0] l1_tag_bank_be;
  tag_data_t       [NumTagBankPerCtrl-1:0] l1_tag_bank_rdata;

  logic            [NumDataBankPerCtrl-1:0] l1_data_bank_req;
  logic            [NumDataBankPerCtrl-1:0] l1_data_bank_we;
  tcdm_bank_addr_t [NumDataBankPerCtrl-1:0] l1_data_bank_addr;
  // data_t           [NumDataBankPerCtrl-1:0] l1_data_bank_wdata;
  cacheline_data_t [NumDataBankPerCtrl-1:0] l1_data_bank_wdata;
  logic            [NumDataBankPerCtrl-1:0] l1_data_bank_be;
  // data_t           [NumDataBankPerCtrl-1:0] l1_data_bank_rdata;
  cacheline_data_t [NumDataBankPerCtrl-1:0] l1_data_bank_rdata;
  logic            [NumDataBankPerCtrl-1:0] l1_data_bank_gnt;

  logic            [NumTagBankPerCtrl-1:0] l1_cache_tag_bank_gnt;
  logic            [NumTagBankPerCtrl-1:0] l1_dir_tag_bank_gnt;

  // Tag bank access for directory controller
  logic            [NumTagBankPerCtrl-1:0] l1_dir_tag_bank_req;
  logic            [NumTagBankPerCtrl-1:0] l1_dir_tag_bank_we;
  tcdm_bank_addr_t [NumTagBankPerCtrl-1:0] l1_dir_tag_bank_addr;
  tag_data_t       [NumTagBankPerCtrl-1:0] l1_dir_tag_bank_wdata;
  logic            [NumTagBankPerCtrl-1:0] l1_dir_tag_bank_be;
  tag_data_t       [NumTagBankPerCtrl-1:0] l1_dir_tag_bank_rdata;

  // Tag bank end-signals
  logic            [NumTagBankPerCtrl-1:0] tag_bank_req;
  logic            [NumTagBankPerCtrl-1:0] tag_bank_we;
  tcdm_bank_addr_t [NumTagBankPerCtrl-1:0] tag_bank_addr;
  tag_data_t       [NumTagBankPerCtrl-1:0] tag_bank_wdata;
  logic            [NumTagBankPerCtrl-1:0] tag_bank_be;
  tag_data_t       [NumTagBankPerCtrl-1:0] tag_bank_rdata;

  logic            [NumTagBankPerCtrl-1:0] is_cache_meta;

  logic            l2_dir_resp_valid;
  logic            l2_dir_resp_ready;
  logic            l2_dir_resp_write;
  word_data_t      l2_dir_resp_data;
  core_meta_t      l2_dir_resp_meta;

  logic            dir_l2_req_valid;
  logic            dir_l2_req_ready;
  addr_t           dir_l2_req_addr;
  core_meta_t      dir_l2_req_meta;
  logic            dir_l2_req_write;
  word_data_t      dir_l2_req_wdata;

  // cache_dir_fwd_t  fwd_rx_i
  
  cahcepool_dir_ctrl #(
    // Core Parameters
    .AddrWidth           (AddrWidth          ),
    .WordWidth           (WordWidth          ),
    .TagWidth            (TagWidth           ),
    .NumTagBankPerCtrl   (NumTagBankPerCtrl  ),
    .NumCacheEntry       (NumCacheEntry     ),
    .SetAssociativity    (SetAssociativity   ),
    .CacheLineWidth      (CacheLineWidth    ),
    .NumDataBankPerCtrl  (NumDataBankPerCtrl),
    .NumMetaBankPerWay   (NumMetaBankPerWay),
    // TODO: remove hardcoding, expose to tile-level
    .NumCores            (4          ),
    .NumCoherenceStates  (4          ),
    // Type Parameters
    .addr_t              (addr_t             ),
    .word_data_t         (word_data_t        ),
    .core_meta_t         (core_meta_t        ),
    .tag_data_t          (tag_data_t         ),
    .tcdm_bank_addr_t    (tcdm_bank_addr_t   ),
    .reqid_t                  (reqid_t                ),
    // .fwd_msg_type_t           (fwd_msg_type_t         ),
    .cache_dir_fwd_t          (cache_dir_fwd_t        ),
    .dir_ctrl_fwd_t           (dir_ctrl_fwd_t         ),
    .sharer_list_t            (sharer_list_t          ),
    // .dir_cache_fwd_t          (dir_cache_fwd_t        ),
    // .l0_line_state_t          (l0_line_state_t        )
    .coherence_rsp_t          (coherence_rsp_t        ),
    .coherence_evict_t        (coherence_evict_t      )
  ) i_l2_directory_ctrl (
    .clk_i                       (clk_i                          ),
    .rst_ni                      (rst_ni                         ),
    .dynamic_offset_i            (dynamic_offset_i                ),
    // Core Interface
    .upstream_req_valid_i        (core_req_valid_i               ),
`ifdef CACHE_DIRECT
    .upstream_req_ready_o        (               ),
`else
    .upstream_req_ready_o        (core_req_ready_o               ),
`endif
    .upstream_req_addr_i         (core_req_addr_i                ),
    .upstream_req_meta_i         (core_req_meta_i                ),
    .upstream_req_write_i        (core_req_write_i               ),
    .upstream_req_wdata_i        (core_req_wdata_i               ),
    .upstream_req_is_evict_i     (1'b0                           ),
    .upstream_req_fake_read_i    (core_req_fake_read_i           ),
    .upstream_req_evict_i        (upstream_req_evict_i           ),
    .upstream_req_evict_ready_o  (upstream_req_evict_ready_o     ),

    .upstream_resp_valid_o       (core_resp_valid_o              ),
    .upstream_resp_ready_i       (core_resp_ready_i              ),
    .upstream_resp_write_o       (core_resp_write_o              ),
    .upstream_resp_data_o        (core_resp_data_o               ),
    .upstream_resp_meta_o        (core_resp_meta_o               ),

    // L2 Cache Interface
    .downstream_req_valid_o      (dir_l2_req_valid),
    .downstream_req_ready_i      (dir_l2_req_ready),
    .downstream_req_addr_o       (dir_l2_req_addr),
    .downstream_req_meta_o       (dir_l2_req_meta),
    .downstream_req_write_o      (dir_l2_req_write),
    .downstream_req_wdata_o      (dir_l2_req_wdata),

    .downstream_resp_valid_i     (l2_dir_resp_valid),
    .downstream_resp_ready_o     (l2_dir_resp_ready),
    .downstream_resp_write_i     (l2_dir_resp_write),
    .downstream_resp_data_i      (l2_dir_resp_data),
    .downstream_resp_meta_i      (l2_dir_resp_meta),

    .fwd_rx_i                    (fwd_rx_i),
    .fwd_rx_valid_i              (fwd_rx_valid_i),
    .fwd_rx_ready_o              (fwd_rx_ready_o),
    .fwd_tx_o                    (fwd_tx_o),
    .fwd_tx_valid_o              (fwd_tx_valid_o),
    .fwd_tx_ready_i              (fwd_tx_ready_i),

    .coherence_rsp_o             (coherence_rsp_o),
    .coherence_rsp_valid_o       (coherence_rsp_valid_o),
    .coherence_rsp_ready_i       (coherence_rsp_ready_i),

    // Tag Bank Interface
    .tag_bank_req_o              (l1_dir_tag_bank_req                ),
    .tag_bank_we_o               (l1_dir_tag_bank_we                 ),
    .tag_bank_addr_o             (l1_dir_tag_bank_addr               ),
    .tag_bank_wdata_o            (l1_dir_tag_bank_wdata              ),
    .tag_bank_be_o               (l1_dir_tag_bank_be                 ),
    // .tag_bank_rdata_i            (l1_dir_tag_bank_rdata              ),
    .tag_bank_rdata_i            (tag_bank_rdata                     ),

    .l1_data_bank_gnt_i          (l1_data_bank_gnt),
    .dir_tag_bank_gnt_i          (l1_dir_tag_bank_gnt)
  );
  
  cachepool_cache_ctrl #(
    // Core
    .NumPorts         (NumPorts      ),
    .CoalExtFactor    (CoalExtFactor       ),
    .AddrWidth        (AddrWidth        ),
    .WordWidth        (WordWidth        ),    // cacheline unit (512bit), maybe too wide for backend
    .TagWidth         (TagWidth     ),
    // Cache
    .NumCacheEntry    (NumCacheEntry  ),
    .CacheLineWidth   (CacheLineWidth        ),
    .SetAssociativity (SetAssociativity      ),
    .BankFactor       (BankFactor       ),
    .RefillDataWidth  (RefillDataWidth    ),
    // Type
    .core_meta_t      (core_meta_t        ),
    .impl_in_t        (impl_in_t          ),
    .refill_req_t     (refill_req_t),
    .refill_rsp_t     (refill_rsp_t),
    .burst_req_t      (burst_req_t        )
  ) i_l1_controller (
    .clk_i                 (clk_i                          ),
    .rst_ni                (rst_ni                         ),
    .impl_i                ('0                             ),
    // Sync Control
    .cache_sync_valid_i    (cache_sync_valid_i                 ),
    .cache_sync_ready_o    (cache_sync_ready_o             ),
    .cache_sync_insn_i     (cache_sync_insn_i                  ),
    // SPM Size
    // The calculation of spm region in cache is different
    // than other modules (needs to times 2)
    // Currently assume full cache
    .bank_depth_for_SPM_i  ('0                              ),
    // Request
`ifdef CACHE_DIRECT
    .core_req_valid_i      (core_req_valid_i            ),
    // .core_req_ready_o      (core_req_ready_o            ),
    .core_req_ready_o      (dir_l2_req_ready             ),
    .core_req_addr_i       (core_req_addr_i             ),
    .core_req_meta_i       (core_req_meta_i             ),
    .core_req_write_i      (core_req_write_i            ),
    .core_req_wdata_i      (core_req_wdata_i            ),
`else
    .core_req_valid_i      (dir_l2_req_valid             ),
    .core_req_ready_o      (dir_l2_req_ready             ),
    .core_req_addr_i       (dir_l2_req_addr              ),
    .core_req_meta_i       (dir_l2_req_meta              ),
    .core_req_write_i      (dir_l2_req_write             ),
    .core_req_wdata_i      (dir_l2_req_wdata             ),
`endif
    // .core_req_wstrb_i      (core_req_wstrb_i            ),
    // Response
    // .core_resp_valid_o     (core_resp_valid_o          ),
    // .core_resp_ready_i     (core_resp_ready_i          ),
    // .core_resp_write_o     (core_resp_write_o          ),
    // .core_resp_data_o      (core_resp_data_o           ),
    // .core_resp_meta_o      (core_resp_meta_o           ),
    .core_resp_valid_o     (l2_dir_resp_valid),
    .core_resp_ready_i     (l2_dir_resp_ready),
    .core_resp_write_o     (l2_dir_resp_write),
    .core_resp_data_o      (l2_dir_resp_data),
    .core_resp_meta_o      (l2_dir_resp_meta),
    // TCDM Refill
    .refill_req_o          (cache_refill_req           ),
    .refill_burst_o        (cache_refill_burst         ),
    .refill_req_valid_o    (cache_refill_req_valid     ),
    .refill_req_ready_i    (cache_refill_req_ready     ),
    .refill_rsp_i          (cache_refill_rsp           ),
    .refill_rsp_valid_i    (cache_refill_rsp_valid     ),
    .refill_rsp_ready_o    (cache_refill_rsp_ready     ),
    // Tag Banks
    .tcdm_tag_bank_req_o   (l1_tag_bank_req            ),
    .tcdm_tag_bank_we_o    (l1_tag_bank_we             ),
    .tcdm_tag_bank_addr_o  (l1_tag_bank_addr           ),
    .tcdm_tag_bank_wdata_o (l1_tag_bank_wdata          ),
    .tcdm_tag_bank_be_o    (l1_tag_bank_be             ),
    // .tcdm_tag_bank_rdata_i (l1_tag_bank_rdata          ),
    .tcdm_tag_bank_rdata_i (tag_bank_rdata             ),
    // Data Banks
    .tcdm_data_bank_req_o  (l1_data_bank_req           ),
    .tcdm_data_bank_we_o   (l1_data_bank_we            ),
    .tcdm_data_bank_addr_o (l1_data_bank_addr          ),
    .tcdm_data_bank_wdata_o(l1_data_bank_wdata         ),
    .tcdm_data_bank_be_o   (l1_data_bank_be            ),
    .tcdm_data_bank_rdata_i(l1_data_bank_rdata         ),
    // .tcdm_data_bank_gnt_i  (l1_data_bank_gnt           ),
    .tcdm_data_bank_gnt_i  (l1_cache_tag_bank_gnt      ),     // TODO: test
    .tcdm_meta_bank_gnt_i  (l1_cache_tag_bank_gnt      )
  );

`ifdef CACHE_DIRECT
  assign tag_bank_req   = l1_tag_bank_req;
  assign tag_bank_we    = l1_tag_bank_we;
  assign tag_bank_addr  = l1_tag_bank_addr;
  assign tag_bank_wdata = l1_tag_bank_wdata;
  assign tag_bank_be    = l1_tag_bank_be;

  assign core_req_ready_o = dir_l2_req_ready;
  // assign is_cache_meta    = {NumTagBankPerCtrl{1'b1}};
`else
  cache_dir_tag_arb #(
    .NumTagBankPerCtrl   (NumTagBankPerCtrl ),
    .tcdm_bank_addr_t    (tcdm_bank_addr_t  ),
    .tag_data_t          (tag_data_t        )
  ) i_tag_bank_req_arb (
    .clk_i                  (clk_i),
    .rst_ni                 (rst_ni),

    .cache_tag_bank_req_i   (l1_tag_bank_req),
    .cache_tag_bank_we_i    (l1_tag_bank_we),
    .cache_tag_bank_addr_i  (l1_tag_bank_addr),
    .cache_tag_bank_wdata_i (l1_tag_bank_wdata),
    .cache_tag_bank_be_i    (l1_tag_bank_be),
    // .cache_tag_bank_be_i    ({2'b01, 2'b01, 2'b01, 2'b01}), // cache ctrl modify only lower word (29-bit)
    
    .dir_tag_bank_req_i     (l1_dir_tag_bank_req),
    .dir_tag_bank_we_i      (l1_dir_tag_bank_we),
    .dir_tag_bank_addr_i    (l1_dir_tag_bank_addr),
    .dir_tag_bank_wdata_i   (l1_dir_tag_bank_wdata),
    .dir_tag_bank_be_i      (l1_dir_tag_bank_be),

    .tag_bank_req_o         (tag_bank_req),
    .tag_bank_we_o          (tag_bank_we),
    .tag_bank_addr_o        (tag_bank_addr),
    .tag_bank_wdata_o       (tag_bank_wdata),
    .tag_bank_be_o          (tag_bank_be),

    .is_cache_meta_o        (is_cache_meta),
    .cache_tag_bank_gnt_o   (l1_cache_tag_bank_gnt),
    .dir_tag_bank_gnt_o     (l1_dir_tag_bank_gnt)

  );
`endif

  always_comb begin : bank_addr_scramble
    // TODO: use info and cb to calculate ID correctly
    cache_refill_req_o.q = '{
      addr : cache_refill_req.addr,
      write: cache_refill_req.write,
      data : cache_refill_req.wdata,
      strb : cache_refill_req.wstrb,
      // We always want full size from cache
      size : $clog2(RefillDataWidth/8),
      amo  : reqrsp_pkg::AMONone,
      default : '0
    };

    // ID 0 reserved for bypass cache
    cache_refill_req_o.q.user = '{
      // bank_id : cb + 1,
      bank_id : cb_id_i + 1,
      info    : cache_refill_req.info,
      burst   : cache_refill_burst,
      default : '0
    };
    cache_refill_req_o.q_valid = cache_refill_req_valid;
    cache_refill_req_o.p_ready = cache_refill_rsp_ready;

    cache_refill_rsp = '{
      data  : cache_refill_rsp_i.p.data,
      write : cache_refill_rsp_i.p.write,
      info  : cache_refill_rsp_i.p.user.info,
      default   :'0
    };
    cache_refill_rsp_valid = cache_refill_rsp_i.p_valid;
    cache_refill_req_ready = cache_refill_rsp_i.q_ready;


    // Pass the lower bits first
    // cache_refill_req_o.q.addr  =   cache_refill_req.addr & bitmask_lo;
    cache_refill_req_o.q.addr  =   cache_refill_req.addr & bitmask_lo_i;
    // Shift the upper part to its location
    // cache_refill_req_o.q.addr |= ((cache_refill_req.addr & bitmask_up) << NumSelBits);
    cache_refill_req_o.q.addr |= ((cache_refill_req.addr & bitmask_up_i) << NumSelBits);
    // Add back the removed cache bank ID
    // cache_refill_req_o.q.addr |= (cb << dynamic_offset);
    cache_refill_req_o.q.addr |= (cb_id_i << dynamic_offset_i);

  end

  // TODO: arbitration logic between dir ctrl and cache ctrl for tag bank access

  // assign cache_meta_be = is_cache_meta ? {{CoherenceMetaBytes{1'b0}}, {SRAMBeWidth-CoherenceMetaBytes {1'b1}}} : {SRAMBeWidth{1'b1}};

  for (genvar j = 0; j < NumTagBankPerCtrl; j++) begin
    // assign meta_bank_be[j] = is_cache_meta[j] ? {{CoherenceMetaBytes{1'b0}}, {SRAMBeWidth-CoherenceMetaBytes {1'b1}}} : {SRAMBeWidth{1'b1}};
    assign meta_bank_be[j] = l1_cache_tag_bank_gnt[j] ? {{CoherenceMetaBytes{1'b0}}, {SRAMBeWidth-CoherenceMetaBytes {1'b1}}} : {SRAMBeWidth{1'b1}};

    tc_sram_impl #(
      .NumWords  (L1CacheWayEntry/BankFactor),
      .DataWidth ($bits(tag_data_t)           ),
      // .ByteWidth ($bits(tag_data_t)           ),
      .ByteWidth (32'd8                       ),
      .NumPorts  (1                           ),
      .Latency   (1                           ),
      .SimInit   ("zeros"                     ),
      // .PrintSimCfg(1),
      .impl_in_t (impl_in_t                   )
    ) i_meta_bank (
      .clk_i  (clk_i                   ),
      .rst_ni (rst_ni                  ),
      .impl_i ('0                      ),
      .impl_o (/* unsed */             ),
      // .req_i  (l1_tag_bank_req  [j]),
      // .we_i   (l1_tag_bank_we   [j]),
      // .addr_i (l1_tag_bank_addr [j]),
      // .wdata_i(l1_tag_bank_wdata[j]),
      // .be_i   (l1_tag_bank_be   [j]),
      // .rdata_o(l1_tag_bank_rdata[j])
      .req_i  (tag_bank_req  [j]),
      .we_i   (tag_bank_we   [j]),
      .addr_i (tag_bank_addr [j]),
      .wdata_i(tag_bank_wdata[j]),
      // .be_i   (tag_bank_be   [j]),
      .be_i   (meta_bank_be[j]  ),
      .rdata_o(tag_bank_rdata[j])
    );

    // tc_sram_meta_impl #(
    //   .NumWords  (L1CacheWayEntry/BankFactor),
    //   .DataWidth ($bits(tag_data_t)           ),
    //   .ByteWidth ($bits(tag_data_t)           ),
    //   .NumPorts  (1                           ),
    //   .Latency   (1                           ),
    //   .SimInit   ("zeros"                     ),
    //   .impl_in_t (impl_in_t                   ),
    //   .NumBitsCacheMeta (29)                          // TODO: remove hardcoding
    // ) i_meta_bank (
    //   .clk_i  (clk_i                   ),
    //   .rst_ni (rst_ni                  ),
    //   .impl_i ('0                      ),
    //   .impl_o (/* unsed */             ),
    //   .req_i  (tag_bank_req  [j]),
    //   .we_i   (tag_bank_we   [j]),
    //   .addr_i (tag_bank_addr [j]),
    //   .wdata_i(tag_bank_wdata[j]),
    //   .be_i   (tag_bank_be   [j]),
    //   // .is_cache_meta_i (1'b0),
    //   .is_cache_meta_i (is_cache_meta[j]),
    //   .rdata_o(tag_bank_rdata[j])
    // );
  end

  // TODO: Should we use a single large bank or multiple narrow ones?
  for (genvar j = 0; j < NumDataBankPerCtrl; j = j+NumWordPerLine) begin : gen_l1_data_banks
    tc_sram_impl #(
      .NumWords   (L1CacheWayEntry/BankFactor),
      .DataWidth  (CacheLineWidth), // L2 write granularity of cacheline, may require changes later
      .ByteWidth  (CacheLineWidth), // L2 write granularity of cacheline, may require changes later
      .NumPorts   (1          ),
      .Latency    (1          ),
      // .PrintSimCfg(1),
      .SimInit    ("zeros"    )
    ) i_data_bank (
      .clk_i  (clk_i                       ),
      .rst_ni (rst_ni                      ),
      .impl_i ('0                          ),
      .impl_o (/* unsed */                 ),
      .req_i  ( l1_data_bank_req  [j]  ),
      .we_i   ( l1_data_bank_we   [j]  ),
      .addr_i ( l1_data_bank_addr [j]  ),
      .wdata_i( l1_data_bank_wdata[j+:NumWordPerLine]),
      .be_i   ( l1_data_bank_be   [j+:NumWordPerLine]),
      .rdata_o( l1_data_bank_rdata[j+:NumWordPerLine])
    );

    assign l1_data_bank_gnt[j+:NumWordPerLine] = {NumWordPerLine{1'b1}};
    // assign l1_data_bank_gnt[j+1] = 1'b1;
    // assign l1_data_bank_gnt[j+2] = 1'b1;
    // assign l1_data_bank_gnt[j+3] = 1'b1;
  end

  // for (genvar j = 0; j < NumDataBankPerCtrl; j++) begin : gen_l1_data_banks
  //   tc_sram_impl #(
  //     .NumWords   (L1CacheWayEntry/BankFactor),
  //     .DataWidth  (DataWidth),
  //     .ByteWidth  (DataWidth),
  //     .NumPorts   (1),
  //     .Latency    (1),
  //     .SimInit    ("zeros")
  //   ) i_data_bank (
  //     .clk_i  (clk_i                    ),
  //     .rst_ni (rst_ni                   ),
  //     .impl_i ('0                       ),
  //     .impl_o (/* unsed */              ),
  //     .req_i  (l1_data_bank_req  [j]),
  //     .we_i   (l1_data_bank_we   [j]),
  //     .addr_i (l1_data_bank_addr [j]),
  //     .wdata_i(l1_data_bank_wdata[j]),
  //     .be_i   (l1_data_bank_be   [j]),
  //     .rdata_o(l1_data_bank_rdata[j])
  //   );

  //   assign l1_data_bank_gnt[j] = 1'b1;
  // end
endmodule

