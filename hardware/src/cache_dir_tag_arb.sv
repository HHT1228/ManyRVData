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
  output logic            [NumTagBankPerCtrl-1:0] tag_bank_be_o,

  output logic            [NumTagBankPerCtrl-1:0] is_cache_meta_o
);

  // FIXME: pending latching may need a FIFO
  typedef struct packed {
    logic             req;
    logic             we;
    tcdm_bank_addr_t  addr;
    tag_data_t        wdata;
    logic             be;
  } tag_bank_req_pack_t;

  tag_bank_req_pack_t [NumTagBankPerCtrl-1:0] cache_req_pack_push, cache_req_pack_pop;
  logic [NumTagBankPerCtrl-1:0] latch_cache_req, serve_pend_cache_req;
  logic [NumTagBankPerCtrl-1:0] fifo_full, fifo_empty;

  for (genvar i = 0; i < NumTagBankPerCtrl; i++) begin
    assign cache_req_pack_push[i].req   = cache_tag_bank_req_i[i];
    assign cache_req_pack_push[i].we    = cache_tag_bank_we_i[i];
    assign cache_req_pack_push[i].addr  = cache_tag_bank_addr_i[i];
    assign cache_req_pack_push[i].wdata = cache_tag_bank_wdata_i[i];
    assign cache_req_pack_push[i].be    = cache_tag_bank_be_i[i];

    assign serve_pend_cache_req[i] = !dir_tag_bank_req_i[i] && !fifo_empty[i];

    always_comb begin
      if(dir_tag_bank_req_i[i]) begin
        if(cache_tag_bank_req_i[i]) begin
          latch_cache_req[i] = 1'b1;      // push cache req to fifo when both coming in on same cycle
        end else begin
          latch_cache_req[i] = 1'b0;
        end
        // Prioritize directory request to output
        tag_bank_req_o[i]   = dir_tag_bank_req_i[i];
        tag_bank_we_o[i]    = dir_tag_bank_we_i[i];
        tag_bank_addr_o[i]  = dir_tag_bank_addr_i[i];
        tag_bank_wdata_o[i] = dir_tag_bank_wdata_i[i];
        tag_bank_be_o[i]    = dir_tag_bank_be_i[i];
        is_cache_meta_o[i]  = 1'b0;
      end else if (cache_tag_bank_req_i[i]) begin
        if(fifo_empty[i]) begin
          // cache request coming in with empty fifo, fall through
          tag_bank_req_o[i]   = cache_tag_bank_req_i[i];
          tag_bank_we_o[i]    = cache_tag_bank_we_i[i];
          tag_bank_addr_o[i]  = cache_tag_bank_addr_i[i];
          tag_bank_wdata_o[i] = cache_tag_bank_wdata_i[i];
          tag_bank_be_o[i]    = cache_tag_bank_be_i[i];
          is_cache_meta_o[i]  = 1'b1;
          latch_cache_req[i]  = 1'b0;
        end else begin
          // otherwise serve buffered req first and buffer current req
          tag_bank_req_o[i]   = cache_req_pack_pop[i].req;
          tag_bank_we_o[i]    = cache_req_pack_pop[i].we;
          tag_bank_addr_o[i]  = cache_req_pack_pop[i].addr;
          tag_bank_wdata_o[i] = cache_req_pack_pop[i].wdata;
          tag_bank_be_o[i]    = cache_req_pack_pop[i].be;
          is_cache_meta_o[i]  = 1'b1;
          latch_cache_req[i]  = 1'b1;
        end
      end else begin
        // No incoming requests, serve buffered req if any
        tag_bank_req_o[i]   = cache_req_pack_pop[i].req;
        tag_bank_we_o[i]    = cache_req_pack_pop[i].we;
        tag_bank_addr_o[i]  = cache_req_pack_pop[i].addr;
        tag_bank_wdata_o[i] = cache_req_pack_pop[i].wdata;
        tag_bank_be_o[i]    = cache_req_pack_pop[i].be;
        is_cache_meta_o[i]  = 1'b1;
        latch_cache_req[i]  = 1'b0; 
      end
    end

    fifo_v3 #(
      .FALL_THROUGH      (1'b0),
      .DATA_WIDTH        ( $bits(tag_bank_req_pack_t)),
      .DEPTH             (4),
      .dtype             (tag_bank_req_pack_t)
    ) i_cache_req_buf (
      .clk_i        (clk_i),
      .rst_ni       (rst_ni),
      .flush_i      (1'b0),
      .testmode_i   (1'b0),
      .full_o       (fifo_full[i]),
      .empty_o      (fifo_empty[i]),
      .usage_o      (),
      .data_i       (cache_req_pack_push[i]),
      .push_i       (latch_cache_req[i]),
      .data_o       (cache_req_pack_pop[i]),
      .pop_i        (serve_pend_cache_req[i])
    );
  end

  // // Pending storage for a cache request when dir has priority
  // logic             [NumTagBankPerCtrl-1:0] pending_valid_q;
  // logic             [NumTagBankPerCtrl-1:0] pending_we_q;
  // tcdm_bank_addr_t  [NumTagBankPerCtrl-1:0] pending_addr_q;
  // tag_data_t        [NumTagBankPerCtrl-1:0] pending_wdata_q;
  // logic             [NumTagBankPerCtrl-1:0] pending_be_q;

  // // genvar i;
  // // generate
  // for (genvar i = 0; i < NumTagBankPerCtrl; i++) begin : gen_arb
  //   // Capture cache request when dir is busy; release one cycle after dir deasserts
  //   always_ff @(posedge clk_i or negedge rst_ni) begin
  //     if (!rst_ni) begin
  //       pending_valid_q[i] <= 1'b0;
  //       pending_we_q[i]    <= '0;
  //       pending_addr_q[i]  <= '0;
  //       pending_wdata_q[i] <= '0;
  //       pending_be_q[i]    <= '0;
  //     end else begin
  //       if (dir_tag_bank_req_i[i]) begin
  //         // Dir has priority; latch cache request if present
  //         if (cache_tag_bank_req_i[i]) begin
  //           pending_valid_q[i] <= 1'b1;
  //           pending_we_q[i]    <= cache_tag_bank_we_i[i];
  //           pending_addr_q[i]  <= cache_tag_bank_addr_i[i];
  //           pending_wdata_q[i] <= cache_tag_bank_wdata_i[i];
  //           pending_be_q[i]    <= cache_tag_bank_be_i[i];
  //         end
  //       end else begin
  //         // Dir released; present pending for one cycle
  //         if (pending_valid_q[i]) begin
  //           pending_valid_q[i] <= 1'b0;
  //         end
  //       end
  //     end
  //   end

  //   // Mux with priority: dir > pending-cache > direct-cache
  //   always_comb begin
  //     // Default: pass-through cache
  //     tag_bank_req_o[i]   = cache_tag_bank_req_i[i];
  //     tag_bank_we_o[i]    = cache_tag_bank_we_i[i];
  //     tag_bank_addr_o[i]  = cache_tag_bank_addr_i[i];
  //     tag_bank_wdata_o[i] = cache_tag_bank_wdata_i[i];
  //     tag_bank_be_o[i]    = cache_tag_bank_be_i[i];

  //     // If a pending cache request exists, drive it (unless dir overrides below)
  //     if (pending_valid_q[i]) begin
  //       tag_bank_req_o[i]   = 1'b1;
  //       tag_bank_we_o[i]    = pending_we_q[i];
  //       tag_bank_addr_o[i]  = pending_addr_q[i];
  //       tag_bank_wdata_o[i] = pending_wdata_q[i];
  //       tag_bank_be_o[i]    = pending_be_q[i];
  //     end

  //     // Dir has highest priority
  //     if (dir_tag_bank_req_i[i]) begin
  //       tag_bank_req_o[i]   = dir_tag_bank_req_i[i];
  //       tag_bank_we_o[i]    = dir_tag_bank_we_i[i];
  //       tag_bank_addr_o[i]  = dir_tag_bank_addr_i[i];
  //       tag_bank_wdata_o[i] = dir_tag_bank_wdata_i[i];
  //       tag_bank_be_o[i]    = dir_tag_bank_be_i[i];
  //     end
  //   end
  // end

endmodule