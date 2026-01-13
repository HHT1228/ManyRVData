// Author: Ho Tin Hung

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
  // Tag bank end-signals
  output logic            [NumTagBankPerCtrl-1:0] tag_bank_req_o,
  output logic            [NumTagBankPerCtrl-1:0] tag_bank_we_o,
  output tcdm_bank_addr_t [NumTagBankPerCtrl-1:0] tag_bank_addr_o,
  output tag_data_t       [NumTagBankPerCtrl-1:0] tag_bank_wdata_o,
  output logic            [NumTagBankPerCtrl-1:0] tag_bank_be_o
);

  // Pending storage for a cache request when dir has priority
  logic             [NumTagBankPerCtrl-1:0] pending_valid_q;
  logic             [NumTagBankPerCtrl-1:0] pending_we_q;
  tcdm_bank_addr_t  [NumTagBankPerCtrl-1:0] pending_addr_q;
  tag_data_t        [NumTagBankPerCtrl-1:0] pending_wdata_q;
  logic             [NumTagBankPerCtrl-1:0] pending_be_q;

  // genvar i;
  // generate
  for (genvar i = 0; i < NumTagBankPerCtrl; i++) begin : gen_arb
    // Capture cache request when dir is busy; release one cycle after dir deasserts
    always_ff @(posedge clk_i or negedge rst_ni) begin
      if (!rst_ni) begin
        pending_valid_q[i] <= 1'b0;
        pending_we_q[i]    <= '0;
        pending_addr_q[i]  <= '0;
        pending_wdata_q[i] <= '0;
        pending_be_q[i]    <= '0;
      end else begin
        if (dir_tag_bank_req_i[i]) begin
          // Dir has priority; latch cache request if present and nothing pending
          if (cache_tag_bank_req_i[i] && !pending_valid_q[i]) begin
            pending_valid_q[i] <= 1'b1;
            pending_we_q[i]    <= cache_tag_bank_we_i[i];
            pending_addr_q[i]  <= cache_tag_bank_addr_i[i];
            pending_wdata_q[i] <= cache_tag_bank_wdata_i[i];
            pending_be_q[i]    <= cache_tag_bank_be_i[i];
          end
        end else begin
          // Dir released; present pending for one cycle
          if (pending_valid_q[i]) begin
            pending_valid_q[i] <= 1'b0;
          end
        end
      end
    end

    // Mux with priority: dir > pending-cache > direct-cache
    always_comb begin
      // Default: pass-through cache
      tag_bank_req_o[i]   = cache_tag_bank_req_i[i];
      tag_bank_we_o[i]    = cache_tag_bank_we_i[i];
      tag_bank_addr_o[i]  = cache_tag_bank_addr_i[i];
      tag_bank_wdata_o[i] = cache_tag_bank_wdata_i[i];
      tag_bank_be_o[i]    = cache_tag_bank_be_i[i];

      // If a pending cache request exists, drive it (unless dir overrides below)
      if (pending_valid_q[i]) begin
        tag_bank_req_o[i]   = 1'b1;
        tag_bank_we_o[i]    = pending_we_q[i];
        tag_bank_addr_o[i]  = pending_addr_q[i];
        tag_bank_wdata_o[i] = pending_wdata_q[i];
        tag_bank_be_o[i]    = pending_be_q[i];
      end

      // Dir has highest priority
      if (dir_tag_bank_req_i[i]) begin
        tag_bank_req_o[i]   = dir_tag_bank_req_i[i];
        tag_bank_we_o[i]    = dir_tag_bank_we_i[i];
        tag_bank_addr_o[i]  = dir_tag_bank_addr_i[i];
        tag_bank_wdata_o[i] = dir_tag_bank_wdata_i[i];
        tag_bank_be_o[i]    = dir_tag_bank_be_i[i];
      end
    end
  end
  // endgenerate

endmodule