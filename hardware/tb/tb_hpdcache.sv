// Simple hpdcache testbench (scaffold)
// Purpose: Observe basic handshakes and get familiar with the module.
// NOTE:
// - This TB assumes the cv-hpdcache sources (hpdcache_pkg, typedefs, submodules)
//   are available on your simulator's +incdir/+libext or compile file list.
// - The request/response struct fields depend on hpdcache_pkg. Fill the few
//   TODOs below after confirming field names (addr, size, data, be, op, uc, etc.).
// - The top-level design supports WT with a write buffer when wtEn=1. A true
//   "WT without write buffer" configuration is not exposed at top-level; the
//   TB uses a fast memory to make WT behavior look naive.

`timescale 1ns/1ps

`include "hpdcache_typedef.svh"  // from cv-hpdcache
import hpdcache_pkg::*;           // from cv-hpdcache

module tb_hpdcache;
  // Clock/reset
  logic clk;
  logic rst_n;
  initial clk = 0;
  always #5 clk = ~clk; // 100 MHz

  // Optional waveform dumping (use +dump)
  initial begin
    if ($test$plusargs("dump")) begin
      $dumpfile("tb_hpdcache.vcd");
      $dumpvars(0, tb_hpdcache);
    end
  end

  task automatic reset_dut();
    rst_n = 0;
    repeat (5) @(posedge clk);
    rst_n = 1;
    @(posedge clk);
  endtask

  // ---------------------------------------------------------------------------
  // Minimal configuration
  // ---------------------------------------------------------------------------
  // TODO: Replace TB_CFG with a valid cfg from hpdcache_pkg or construct one.
  // For a simple run, pick a small cache with 1 requester and set WT enabled.
  // If your package provides helpers, use them here. Example (pseudo-code):
  // localparam hpdcache_cfg_t TB_CFG = make_cfg(
  //   .nRequesters(1), .wtEn(1), .wbEn(0), .memDataWidth(64), .reqDataWidth(64)
  // );
  localparam hpdcache_cfg_t TB_CFG = '0; // PLACEHOLDER: set real fields!

  // ---------------------------------------------------------------------------
  // Types (match hpdcache_pkg definitions)
  // ---------------------------------------------------------------------------
  // If your hpdcache_pkg already typedefs these, you can skip overrides below
  // and rely on defaults. Otherwise, uncomment and align with your version.
  // typedef struct packed {
  //   logic [TB_CFG.u.paWidth-1:0]  addr;
  //   logic [2:0]                   size;      // bytes = 1<<size
  //   logic                         write;     // 0=read, 1=write
  //   logic                         uc;        // uncacheable
  //   logic [TB_CFG.reqDataWidth-1:0] data;
  //   logic [TB_CFG.reqDataWidth/8-1:0] be;
  //   logic [3:0]                   sid;
  //   logic [3:0]                   tid;
  //   logic                         need_rsp;
  // } tb_req_t;
  // typedef struct packed {
  //   logic [TB_CFG.reqDataWidth-1:0] data;
  //   logic                          error;
  //   logic [3:0]                    sid;
  //   logic [3:0]                    tid;
  // } tb_rsp_t;

  // ---------------------------------------------------------------------------
  // Core side signals (1 requester for simplicity)
  // ---------------------------------------------------------------------------
  localparam int N_REQ = 1; // Must match TB_CFG.u.nRequesters

  logic                  core_req_valid   [N_REQ];
  logic                  core_req_ready   [N_REQ];
  hpdcache_req_t         core_req         [N_REQ];
  logic                  core_req_abort   [N_REQ];
  hpdcache_tag_t         core_req_tag     [N_REQ];
  hpdcache_pma_t         core_req_pma     [N_REQ];

  logic                  core_rsp_valid   [N_REQ];
  hpdcache_rsp_t         core_rsp         [N_REQ];

  // ---------------------------------------------------------------------------
  // Memory side signals (simple, single-ported memory model)
  // ---------------------------------------------------------------------------
  // Read channel
  logic                 mem_req_read_ready;
  logic                 mem_req_read_valid;
  hpdcache_mem_req_t    mem_req_read;

  logic                 mem_resp_read_ready;
  logic                 mem_resp_read_valid;
  hpdcache_mem_resp_r_t mem_resp_read;

  // Write channel
  logic                 mem_req_write_ready;
  logic                 mem_req_write_valid;
  hpdcache_mem_req_t    mem_req_write;

  logic                 mem_req_write_data_ready;
  logic                 mem_req_write_data_valid;
  hpdcache_mem_req_w_t  mem_req_write_data;

  logic                 mem_resp_write_ready;
  logic                 mem_resp_write_valid;
  hpdcache_mem_resp_w_t mem_resp_write;

  // Perf/Status/Config
  logic evt_cache_write_miss, evt_cache_read_miss;
  logic evt_uncached_req, evt_cmo_req, evt_write_req, evt_read_req;
  logic evt_prefetch_req, evt_req_on_hold, evt_rtab_rollback;
  logic evt_stall_refill, evt_stall;

  logic wbuf_empty;

  logic cfg_enable;
  logic cfg_default_wb;

  // For WT mode parameters we don't use in this TB
  logic [7:0] cfg_wbuf_threshold;
  logic       cfg_wbuf_reset_timecnt_on_write;
  logic       cfg_wbuf_sequential_waw;
  logic       cfg_wbuf_inhibit_write_coalescing;
  logic       cfg_prefetch_updt_plru;
  logic       cfg_error_on_cacheable_amo;
  logic       cfg_rtab_single_entry;

  // ---------------------------------------------------------------------------
  // DUT
  // ---------------------------------------------------------------------------
  hpdcache #(
    .HPDcacheCfg(TB_CFG)
    // Optionally override type params if needed
  ) dut (
    .clk_i(clk),
    .rst_ni(rst_n),

    .wbuf_flush_i(1'b0),

    .core_req_valid_i(core_req_valid),
    .core_req_ready_o(core_req_ready),
    .core_req_i(core_req),
    .core_req_abort_i(core_req_abort),
    .core_req_tag_i(core_req_tag),
    .core_req_pma_i(core_req_pma),

    .core_rsp_valid_o(core_rsp_valid),
    .core_rsp_o(core_rsp),

    .mem_req_read_ready_i(mem_req_read_ready),
    .mem_req_read_valid_o(mem_req_read_valid),
    .mem_req_read_o(mem_req_read),

    .mem_resp_read_ready_o(mem_resp_read_ready),
    .mem_resp_read_valid_i(mem_resp_read_valid),
    .mem_resp_read_i(mem_resp_read),

    .mem_req_write_ready_i(mem_req_write_ready),
    .mem_req_write_valid_o(mem_req_write_valid),
    .mem_req_write_o(mem_req_write),

    .mem_req_write_data_ready_i(mem_req_write_data_ready),
    .mem_req_write_data_valid_o(mem_req_write_data_valid),
    .mem_req_write_data_o(mem_req_write_data),

    .mem_resp_write_ready_o(mem_resp_write_ready),
    .mem_resp_write_valid_i(mem_resp_write_valid),
    .mem_resp_write_i(mem_resp_write),

    .evt_cache_write_miss_o(evt_cache_write_miss),
    .evt_cache_read_miss_o(evt_cache_read_miss),
    .evt_uncached_req_o(evt_uncached_req),
    .evt_cmo_req_o(evt_cmo_req),
    .evt_write_req_o(evt_write_req),
    .evt_read_req_o(evt_read_req),
    .evt_prefetch_req_o(evt_prefetch_req),
    .evt_req_on_hold_o(evt_req_on_hold),
    .evt_rtab_rollback_o(evt_rtab_rollback),
    .evt_stall_refill_o(evt_stall_refill),
    .evt_stall_o(evt_stall),

    .wbuf_empty_o(wbuf_empty),

    .cfg_enable_i(cfg_enable),
    .cfg_wbuf_threshold_i(cfg_wbuf_threshold),
    .cfg_wbuf_reset_timecnt_on_write_i(cfg_wbuf_reset_timecnt_on_write),
    .cfg_wbuf_sequential_waw_i(cfg_wbuf_sequential_waw),
    .cfg_wbuf_inhibit_write_coalescing_i(cfg_wbuf_inhibit_write_coalescing),
    .cfg_prefetch_updt_plru_i(cfg_prefetch_updt_plru),
    .cfg_error_on_cacheable_amo_i(cfg_error_on_cacheable_amo),
    .cfg_rtab_single_entry_i(cfg_rtab_single_entry),
    .cfg_default_wb_i(cfg_default_wb)
  );

  // ---------------------------------------------------------------------------
  // Tiny memory model: zero-latency ready, fixed read latency, accept writes
  // ---------------------------------------------------------------------------
  localparam int READ_LAT = 4;

  // Ready is always asserted to keep things simple
  assign mem_req_read_ready        = 1'b1;
  assign mem_req_write_ready       = 1'b1;
  assign mem_req_write_data_ready  = 1'b1;

  // Simple read responder: after READ_LAT cycles from request valid, return
  // deterministic data (here just a counter). We don't inspect the request ID
  // or address in this scaffold.
  int unsigned read_cnt;
  initial begin
    mem_resp_read_valid = 0;
    mem_resp_read       = '0;
    read_cnt            = 0;
    forever begin
      @(posedge clk);
      if (mem_req_read_valid) begin
        fork
          begin
            automatic int idelay = READ_LAT;
            repeat (idelay) @(posedge clk);
            mem_resp_read_valid <= 1'b1;
            mem_resp_read       <= '0; // TODO: set proper ID/data fields
            @(posedge clk);
            mem_resp_read_valid <= 1'b0;
            read_cnt++;
          end
        join_none
      end
    end
  end

  // Simple write responder: when a write request + data are seen, return an ack
  initial begin
    mem_resp_write_valid = 0;
    mem_resp_write       = '0;
    forever begin
      @(posedge clk);
      if (mem_req_write_valid && mem_req_write_data_valid) begin
        mem_resp_write_valid <= 1'b1;
        mem_resp_write       <= '0; // TODO: set proper ID/resp fields
        @(posedge clk);
        mem_resp_write_valid <= 1'b0;
      end
    end
  end

  // ---------------------------------------------------------------------------
  // Simple core stimulus (read then write)
  // ---------------------------------------------------------------------------
  // Helper: clear core signals
  task automatic clear_core();
    for (int i = 0; i < N_REQ; i++) begin
      core_req_valid[i] = 0;
      core_req[i]       = '0;
      core_req_abort[i] = 0;
      core_req_tag[i]   = '0;
      core_req_pma[i]   = '0;
    end
  endtask

  // Drive a single read
  task automatic drive_read(input logic [63:0] addr);
    // TODO: set request fields according to your hpdcache_req_t
    // Example (pseudo-code):
    // core_req[0].addr      = addr;
    // core_req[0].size      = 3'd3; // 8 bytes
    // core_req[0].write     = 1'b0;
    // core_req[0].uc        = 1'b0; // cacheable
    // core_req[0].need_rsp  = 1'b1;
    core_req_valid[0] = 1'b1;
    @(posedge clk);
    while (!core_req_ready[0]) @(posedge clk);
    core_req_valid[0] = 1'b0;
  endtask

  // Drive a single write
  task automatic drive_write(input logic [63:0] addr, input logic [63:0] data);
    // TODO: set request fields according to your hpdcache_req_t
    // Example (pseudo-code):
    // core_req[0].addr      = addr;
    // core_req[0].size      = 3'd3; // 8 bytes
    // core_req[0].write     = 1'b1;
    // core_req[0].data      = data;
    // core_req[0].be        = 8'hFF;
    // core_req[0].uc        = 1'b0; // cacheable
    // core_req[0].need_rsp  = 1'b1;
    core_req_valid[0] = 1'b1;
    @(posedge clk);
    while (!core_req_ready[0]) @(posedge clk);
    core_req_valid[0] = 1'b0;
  endtask

  // Observe responses
  always @(posedge clk) begin
    if (core_rsp_valid[0]) begin
      $display("[%0t] RSP: %p", $time, core_rsp[0]);
    end
  end

  // ---------------------------------------------------------------------------
  // Test sequence
  // ---------------------------------------------------------------------------
  initial begin
    // Default config inputs
    cfg_enable                       = 1'b0;
    cfg_default_wb                   = 1'b0; // prefer WT by default
    cfg_wbuf_threshold               = '0;
    cfg_wbuf_reset_timecnt_on_write  = 1'b0;
    cfg_wbuf_sequential_waw          = 1'b0;
    cfg_wbuf_inhibit_write_coalescing= 1'b1; // act naive
    cfg_prefetch_updt_plru           = 1'b0;
    cfg_error_on_cacheable_amo       = 1'b0;
    cfg_rtab_single_entry            = 1'b1;

    clear_core();
    reset_dut();

    // Enable after reset
    cfg_enable = 1'b1;

    // Basic sequence: read miss -> fill, then write-through
    drive_read(64'h0000_1000);
    repeat (10) @(posedge clk);

    drive_write(64'h0000_1000, 64'hDEAD_BEEF_CAFE_FEED);
    repeat (20) @(posedge clk);

    $display("[%0t] Test done.", $time);
    $finish;
  end

endmodule
