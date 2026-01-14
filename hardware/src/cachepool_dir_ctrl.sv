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
  parameter type tag_data_t       = logic [TagWidth-1:0],   // 64-bit representation, not actual tag-tag
  // parameter type cache_tag_t      = logic,
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
  localparam int unsigned NumLRUBits     = $clog2(SetAssociativity);
  localparam int unsigned NumActualTagBits     = AddrWidth - $clog2(CacheLineWidth/8) - $clog2(CacheBankDepth);

  /**
  * Type definitions
  */
  // Coherence metadata as exntension to L2 tags
  // typedef logic [$clog2(NumCoherenceStates)-1:0] dir_line_state_t;
  typedef logic [NumCores-1:0]                   sharer_list_t;
  typedef logic [NumActualTagBits-1:0]           cache_tag_t;

  typedef struct packed {
    dir_line_state_t      line_state;
    sharer_list_t         sharers;
  } coherence_meta_t;
  
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

  /**
  * Internal signals
  */
  // logic            tag_bank_req_r, tag_bank_req_w;
  // tcdm_bank_addr_t tag_bank_addr_r, tag_bank_addr_w;
  // tag_data_t       tag_bank_rdata, tag_bank_wdata;
  tcdm_bank_addr_t                    tag_bank_addr;
  // tag_data_t [NumTagBankPerCtrl-1:0]  tag_bank_rdata;
  tag_data_t [SetAssociativity-1:0]   tag_bank_rdata;
  tag_data_t                          curr_line_meta;
  // logic                               curr_line_meta_valid;
  coherence_meta_t                    line_coherence_meta;
  dir_line_state_t                    curr_line_state;
  sharer_list_t                       curr_sharer_list;
  pseudo_port_t                       tag_bank_port_accessed;

  assign tag_bank_addr = upstream_req_addr_i[$clog2(CacheBankDepth) + $clog2(CacheLineWidth/8)-1 : $clog2(CacheLineWidth/8)];

  // TODO: connect write signals
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


  // track which port is used to access tag bank
  always_comb begin
    if(tag_bank_req_o[0] == 2'b01) begin
      tag_bank_port_accessed = EVEN;
    end else if(tag_bank_req_o[0] == 2'b10) begin
      tag_bank_port_accessed = ODD;
    end else if(tag_bank_req_o[0] == 2'b11) begin
      tag_bank_port_accessed = BOTH;
    end else begin
      tag_bank_port_accessed = BOTH; // Default value
    end
  end

  for (genvar i = 0; i < SetAssociativity; i++) begin: gen_way_selection
    cache_tag_t curr_cachelien_tag;
    // tag_data_t  curr_cacheline_meta;
    // assign curr_cachelien_tag = tag_bank_rdata[i][NumLRUBits +: NumActualTagBits];
    if (tag_bank_port_accessed == EVEN) begin
      curr_cachelien_tag = tag_bank_rdata[i][0][NumLRUBits +: NumActualTagBits];
      if (curr_cachelien_tag == upstream_req_addr_i[AddrWidth-1 -: NumActualTagBits]) begin
        curr_line_meta = tag_bank_rdata[i][0];
      end else begin
        curr_line_meta = '0;
      end
    end else begin
      curr_cachelien_tag = tag_bank_rdata[i][1][NumLRUBits +: NumActualTagBits];
      if (curr_cachelien_tag == upstream_req_addr_i[AddrWidth-1 -: NumActualTagBits]) begin
        curr_line_meta = tag_bank_rdata[i][1];
      end else begin
        curr_line_meta = '0;
      end
    end

    
  end

  assign line_coherence_meta = curr_line_meta[0][TagWidth-1 -: $bits(coherence_meta_t)];
  assign curr_line_state     = line_coherence_meta.line_state;
  assign curr_sharer_list    = line_coherence_meta.sharers;

  // Coherence FSM
  // TODO: integrate with your request/response interface
  // Operation classes (columns in your table)
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
  } dir_op_e;

  // TODO: reorganize and rename this part
  // ---- Inputs this FSM needs (provide these from your request/resp decode) ----
  dir_op_e                       op_i;          // TODO: decode from *_{req,resp}_* signals
  logic [$clog2(NumCores)-1:0]   req_id_i;      // requester core id (for READ/WRITE)
  logic [$clog2(NumCores)-1:0]   evict_id_i;    // evictor id (for Put*/Evict*)

  // ---- Inputs this FSM needs (provide these from your request/resp decode) ----
  dir_op_e                       op_i;          // TODO: decode from *_{req,resp}_* signals
  logic [$clog2(NumCores)-1:0]   req_id_i;      // requester core id (for READ/WRITE)
  logic [$clog2(NumCores)-1:0]   evict_id_i;    // evictor id (for Put*/Evict*)

  // ---- Per-line state we already extracted from the tag word ----
  dir_line_state_t  state_q, state_d;
  sharer_list_t     sharers_q, sharers_d;

  // ---- Actions (one-cycle pulses) to hook to your engines later ----
  typedef struct packed {
    logic send_excl_data;      // GrantE + data to requester
    logic send_sh_data;        // GrantS + data to requester
    logic send_inv_to_sharers; // invalidate all current sharers
    logic send_inv_to_owner;   // invalidate/downgrade current owner
    logic send_probe_owner;    // ask owner for latest data (Read in E/M)
    logic send_evict_ack;      // EvictAck to evictor
    logic writeback_mem;       // push dirty to memory (owner PutM)
    logic update_l2_data;      // accept/serialize WT data at L2
    logic update_sharers;      // commit sharers_d to tag/meta RAM
  } dir_actions_t;

  dir_actions_t act;

  // ---- Remember the pending reader when we’re in ESA (E-substate) ----
  logic [$clog2(NumCores)-1:0] pending_req_q, pending_req_d;

  // Helpers to manipulate the sharer bit-vector
  function automatic sharer_list_t set_bit(sharer_list_t lst, int unsigned id);
    return (lst | (sharer_list_t'(1) << id));
  endfunction
  function automatic sharer_list_t clr_bit(sharer_list_t lst, int unsigned id);
    return (lst & ~(sharer_list_t'(1) << id));
  endfunction

  // Seed current state/meta from tag read
  always_comb begin
    state_q   = curr_line_state;
    sharers_q = curr_sharer_list;
  end

  // TODO: review logic in detail
  // Next-state logic
  always_comb begin
    // Defaults: hold
    state_d       = state_q;
    sharers_d     = sharers_q;
    pending_req_d = pending_req_q;
    act           = '0;

    unique case (state_q)

      // ---------------- I ----------------
      DIR_LINE_INVALID: begin
        unique case (op_i)
          OP_READ: begin
            // Send exclusive to requester; become E
            act.send_excl_data = 1'b1;
            sharers_d          = '0;
            sharers_d          = set_bit(sharers_d, req_id_i);
            act.update_sharers = 1'b1;
            state_d            = DIR_LINE_EXCLUSIVE;
          end
          OP_WRITE: begin
            // Accept WT @L2; requester becomes owner (M)
            act.update_l2_data = 1'b1;
            sharers_d          = '0;
            sharers_d          = set_bit(sharers_d, req_id_i);
            act.update_sharers = 1'b1;
            state_d            = DIR_LINE_MODIFIED;
          end
          // Any eviction against I: just ack
          OP_EVICT_S, OP_EVICT_M_NONOWNER, OP_EVICT_E_OWNER, OP_EVICT_E_NONOWNER: begin
            act.send_evict_ack = 1'b1;
          end
          default: ;
        endcase
      end

      // ---------------- S ----------------
      DIR_LINE_SHARED: begin
        unique case (op_i)
          OP_READ: begin
            act.send_sh_data   = 1'b1;
            sharers_d          = set_bit(sharers_d, req_id_i);
            act.update_sharers = 1'b1;     // stay S
          end
          OP_WRITE: begin
            // Upgrade: invalidate all sharers, serialize WT, owner=req
            act.send_inv_to_sharers = 1'b1;
            act.update_l2_data      = 1'b1;
            sharers_d               = '0;
            sharers_d               = set_bit(sharers_d, req_id_i);
            act.update_sharers      = 1'b1;
            state_d                 = DIR_LINE_MODIFIED;
          end
          // Evictions remove bit; S->I if last sharer leaves
          OP_EVICT_S, OP_EVICT_M_NONOWNER, OP_EVICT_E_NONOWNER, OP_EVICT_E_OWNER, OP_EVICT_M_OWNER: begin
            sharers_d          = clr_bit(sharers_d, evict_id_i);
            act.update_sharers = 1'b1;
            act.send_evict_ack = 1'b1;
            state_d            = (sharers_d == '0) ? DIR_LINE_INVALID : DIR_LINE_SHARED;
          end
          default: ;
        endcase
      end

      // ---------------- E ----------------
      DIR_LINE_EXCLUSIVE: begin
        unique case (op_i)
          OP_READ: begin
            // Another reader arrives: probe owner first; go ESA
            act.send_probe_owner = 1'b1;
            pending_req_d        = req_id_i;
            state_d              = DIR_LINE_ESA;
          end
          OP_WRITE: begin
            // Writer arrives: invalidate current owner; serialize WT; new owner=req
            act.send_inv_to_owner = 1'b1;
            act.update_l2_data    = 1'b1;
            sharers_d             = '0;
            sharers_d             = set_bit(sharers_d, req_id_i);
            act.update_sharers    = 1'b1;
            state_d               = DIR_LINE_MODIFIED;
          end
          OP_GETACK: begin
            // No outstanding probe → ignore
          end
          OP_EVICT_S, OP_EVICT_M_NONOWNER, OP_EVICT_E_NONOWNER: begin
            act.send_evict_ack = 1'b1;
          end
          OP_EVICT_M_OWNER: begin
            act.writeback_mem  = 1'b1;
            act.send_evict_ack = 1'b1;
            sharers_d          = '0;
            act.update_sharers = 1'b1;
            state_d            = DIR_LINE_INVALID;
          end
          OP_EVICT_E_OWNER: begin
            act.send_evict_ack = 1'b1;
            sharers_d          = '0;       // clear owner
            act.update_sharers = 1'b1;
            state_d            = DIR_LINE_INVALID;
          end
          default: ;
        endcase
      end

      // ---------------- ESA (E-substate: waiting owner data) ----------------
      DIR_LINE_ESA: begin
        unique case (op_i)
          OP_READ, OP_WRITE: begin
            // Stall others on this line; arbiters should queue
          end
          OP_GETACK: begin
            // Owner returned latest data → serve pending reader, then S
            act.send_sh_data   = 1'b1;     // to pending_req_q
            sharers_d          = set_bit(sharers_q, pending_req_q);
            act.update_sharers = 1'b1;
            state_d            = DIR_LINE_SHARED;
          end
          // Evictions while waiting: Ack them; still respond to pending read once GETACK arrives
          OP_EVICT_S, OP_EVICT_M_NONOWNER, OP_EVICT_E_NONOWNER: begin
            act.send_evict_ack = 1'b1;
          end
          OP_EVICT_M_OWNER: begin
            act.writeback_mem  = 1'b1;
            act.send_evict_ack = 1'b1;
            // when GETACK/data arrives, we still reply to the waiting reader
          end
          OP_EVICT_E_OWNER: begin
            act.send_evict_ack = 1'b1;
          end
          default: ;
        endcase
      end

      // ---------------- M ----------------
      DIR_LINE_MODIFIED: begin
        unique case (op_i)
          OP_READ: begin
            // Someone wants to read: probe owner then S
            act.send_probe_owner = 1'b1;
            pending_req_d        = req_id_i;
            state_d              = DIR_LINE_ESA;
          end
          OP_WRITE: begin
            // Another writer: invalidate current owner; serialize WT; new owner=req
            act.send_inv_to_owner = 1'b1;
            act.update_l2_data    = 1'b1;
            sharers_d             = '0;
            sharers_d             = set_bit(sharers_d, req_id_i);
            act.update_sharers    = 1'b1;
            state_d               = DIR_LINE_MODIFIED;
          end
          OP_EVICT_S, OP_EVICT_M_NONOWNER, OP_EVICT_E_NONOWNER: begin
            act.send_evict_ack = 1'b1;
          end
          OP_EVICT_M_OWNER: begin
            act.writeback_mem  = 1'b1;
            act.send_evict_ack = 1'b1;
            sharers_d          = '0;
            act.update_sharers = 1'b1;
            state_d            = DIR_LINE_INVALID;
          end
          OP_EVICT_E_OWNER: begin
            // “Owner evicts E” is illegal in M but we just clear & Ack
            act.send_evict_ack = 1'b1;
            sharers_d          = '0;
            act.update_sharers = 1'b1;
            state_d            = DIR_LINE_INVALID;
          end
          default: ;
        endcase
      end

      default: ;
    endcase
  end

  // State registers (per line)
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      state_q       <= DIR_LINE_INVALID;
      sharers_q     <= '0;
      pending_req_q <= '0;
    end else begin
      state_q       <= state_d;
      sharers_q     <= sharers_d;
      pending_req_q <= pending_req_d;
    end
  end

  // Optionally compose the new meta to write back to the tag word when act.update_sharers is set
  coherence_meta_t next_meta;
  assign next_meta.line_state = state_q;   // or state_d if you write in same cycle
  assign next_meta.sharers    = sharers_q; // or sharers_d


endmodule