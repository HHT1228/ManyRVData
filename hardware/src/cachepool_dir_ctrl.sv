// Author: Ho Tin Hung

module cahcepool_dir_ctrl #(
  
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
  parameter type addr_t           = logic [AddrWidth-1:0],
  parameter type word_data_t      = logic [WordWidth-1:0],
  parameter type core_meta_t      = logic,
  parameter type tag_data_t       = logic [TagWidth-1:0],
  parameter type tcdm_bank_addr_t = logic

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

  // Response to L1
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

  input  logic            [SetAssociativity-1:0][NumMetaBankPerWay-1:0]           l1_data_bank_gnt_i
);

  /**
  * Local parameters
  */
  localparam int unsigned CacheBankDepth = NumCacheEntry/SetAssociativity;

  /**
  * Type definitions
  */
  // Coherence metadata as exntension to L2 tags
  typedef logic [$clog2(NumCoherenceStates)-1:0] line_state_t;
  typedef logic [NumCores-1:0]                   sharer_list_t;
  typedef struct packed {
    line_state_t      line_state;
    sharer_list_t     sharers;
  } coherence_meta_t;

  /**
  * Internal signals
  */
  // logic            tag_bank_req_r, tag_bank_req_w;
  // tcdm_bank_addr_t tag_bank_addr_r, tag_bank_addr_w;
  // tag_data_t       tag_bank_rdata, tag_bank_wdata;
  tcdm_bank_addr_t                    tag_bank_addr;
  // tag_data_t [NumTagBankPerCtrl-1:0]  tag_bank_rdata;
  tag_data_t [SetAssociativity-1:0]   tag_bank_rdata;
  coherence_meta_t                    line_coherence_meta;
  line_state_t                        curr_line_state;
  sharer_list_t                       curr_sharer_list;

  assign tag_bank_addr = upstream_req_addr_i[$clog2(CacheBankDepth) + $clog2(CacheLineWidth/8)-1 : $clog2(CacheLineWidth/8)];

  // TODO: 4-way instead of 8
  for (genvar i = 0; i < SetAssociativity; i++) begin: gen_tag_bank_access
    tcdm_bank_addr_t tag_bank_addr_int;
    logic tag_bank_read_valid_int;
    logic tag_bank_read_ready_int;
    tag_data_t tag_bank_rdata_int;

    insitu_cache_bank_access_controller #(
      .DEPTH              (CacheBankDepth),
      .NumWordsPerLine    (1),
      .WordWidth          (TagWidth)
    ) i_access_ctrl_tag_bank (
      .clk_i                       (clk_i),
      .rst_ni                      (rst_ni),

      .upstream_read_addr_i        (tag_bank_addr),
      .upstream_read_valid_i       (upstream_req_valid_i),
      .upstream_read_ready_o       (),
      .upstream_read_data_o        (tag_bank_rdata[i]),

      .upstream_write_addr_i       (),
      .upstream_write_req_i        (),
      .upstream_write_data_i       (),

      .downstream_read_addr_o      (tag_bank_addr_int),
      .downstream_read_valid_o     (tag_bank_read_valid_int),
      .downstream_read_ready_i     (tag_bank_read_ready_int),
      .downstream_read_data_i      (tag_bank_rdata_int),

      .downstream_write_addr_o     (),
      .downstream_write_req_o      (),
      .downstream_write_data_o     (),

      .bank_gnt_i                  (&(l1_data_bank_gnt_i[i]))

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

      .read_addr_i        (tag_bank_addr_int),
      .read_valid_i       (tag_bank_read_valid_int),
      .read_ready_o       (tag_bank_read_ready_int),
      .read_data_o        (tag_bank_rdata_int),

      .write_addr_i       (),
      .write_req_i        (),
      .write_data_i       (),

      .tcdm_bank_req_o    (tag_bank_req_o[i]),
      .tcdm_bank_we_o     (tag_bank_we_o[i]),
      .tcdm_bank_addr_o   (tag_bank_addr_o[i]),
      .tcdm_bank_wdata_o  (tag_bank_wdata_o[i]),
      .tcdm_bank_be_o     (tag_bank_be_o[i]),
      .tcdm_bank_rdata_i  (tag_bank_rdata_i[i])
    );
  end

  // FIXME: which port to use? [0] is clearly wrong
  // TODO: need to track which port is used to access tag bank (odd/even/both, 2-bit flag)
  assign line_coherence_meta = tag_bank_rdata[0][TagWidth-1 -: $bits(coherence_meta_t)];
  assign curr_line_state     = line_coherence_meta.line_state;
  assign curr_sharer_list    = line_coherence_meta.sharers;

  // Coherence FSM


endmodule