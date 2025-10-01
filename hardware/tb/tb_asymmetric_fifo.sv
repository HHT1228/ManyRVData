`timescale 1ns/1ps

module tb_asymmetric_fifo;

  // --- Parameters ---
  localparam int unsigned N_IN        = 5;
  localparam int unsigned DATA_WIDTH  = 8;
  localparam int unsigned DEPTH       = 13;    // non-power-of-two to stress wrap-around
  localparam bit          FALL_THROUGH= 1'b0;  // must be 0 for N_IN>1

  typedef logic [DATA_WIDTH-1:0] dtype_t;
  localparam int unsigned ADDR_DEPTH  = (DEPTH > 1) ? $clog2(DEPTH) : 1;

  // --- DUT I/O ---
  logic  clk, rst_ni, flush_i, testmode_i;
  logic  full_o, empty_o;
  logic  [ADDR_DEPTH-1:0] usage_o;
  logic  push_i, pop_i;

  // Packed 2-D port: left dim = data width, right dim = lane index
  dtype_t [N_IN-1:0] data_i;
  dtype_t            data_o;

  // --- Instantiate DUT ---
  asymmetric_fifo #(
    .FALL_THROUGH(FALL_THROUGH),
    .DATA_WIDTH  (DATA_WIDTH),
    .DEPTH       (DEPTH),
    .dtype       (dtype_t),
    .N_IN        (N_IN)
  ) dut (
    .clk_i      (clk),
    .rst_ni     (rst_ni),
    .flush_i    (flush_i),
    .testmode_i (testmode_i),
    .full_o     (full_o),
    .empty_o    (empty_o),
    .usage_o    (usage_o),
    .data_i     (data_i),
    .push_i     (push_i),
    .data_o     (data_o),
    .pop_i      (pop_i)
  );

  // --- Clock ---
  initial clk = 1'b0;
  always #5 clk = ~clk;

  // --- Scoreboard & state ---
  dtype_t                exp_q [$];    // expected contents
  int unsigned           gen_base;     // generator base (advances by N_IN per accepted push)
  dtype_t                burst   [N_IN]; // pre-declared so no declarations after statements
  int                    k;           // loop variable used in several places

  // Pack N_IN lanes into a flat vector (lane 0 -> least-significant slice)
  function automatic logic [N_IN*DATA_WIDTH-1:0]
    pack_lanes (input dtype_t lanes [N_IN]);
    logic [N_IN*DATA_WIDTH-1:0] flat;
    int i;
    begin
      flat = '0;
      for (i = 0; i < N_IN; i++) begin
        flat[(i+1)*DATA_WIDTH-1 -: DATA_WIDTH] = lanes[i];
      end
      return flat;
    end
  endfunction

  // --- Drive one push attempt (accepts if ~full_o on posedge) ---
  task automatic drive_push(input dtype_t lanes [N_IN]);
    logic [N_IN*DATA_WIDTH-1:0] flat;
    int                         i;
    begin
      flat = pack_lanes(lanes);

      // Setup before active edge
      @(negedge clk);
      data_i = flat;     // legal packed assignment (same total width)
      push_i = 1'b1;

      // Handshake/accept
      @(posedge clk);
      if (!full_o) begin
        for (i = 0; i < N_IN; i++) begin
          exp_q.push_back(lanes[i]);
        end
      end

      // Deassert after the edge
      @(negedge clk);
      push_i = 1'b0;
    end
  endtask

  // --- Drive one pop attempt (accepts if ~empty_o on posedge) ---
  task automatic drive_pop();
    dtype_t exp;
    begin
      @(negedge clk);
      pop_i = 1'b1;

      @(posedge clk);
      if (!empty_o) begin
        if (exp_q.size() == 0) begin
          $fatal(1, "[TB] DUT popped while expected queue is empty!");
        end
        exp = exp_q[0];
        assert (data_o === exp)
          else $fatal(1, "[TB] Mismatch: got %0d exp %0d @t=%0t", data_o, exp, $time);
        void'(exp_q.pop_front());
      end

      @(negedge clk);
      pop_i = 1'b0;
    end
  endtask

  // --- Random mixed traffic ---
  task automatic random_traffic(input int cycles);
    dtype_t lanes [N_IN];
    int     t;
    bit     do_push, do_pop;
    begin
      for (t = 0; t < cycles; t++) begin
        // Next 5-lane vector
        for (k = 0; k < N_IN; k++) lanes[k] = dtype_t'(gen_base + k);

        // Choose operations
        do_push = $urandom_range(0,1);
        do_pop  = $urandom_range(0,1);

        if (do_push) drive_push(lanes);
        if (do_pop)  drive_pop();

        if (do_push) gen_base += N_IN;

        // Check usage against scoreboard (width-truncated compare is OK)
        // @(posedge clk);
        // assert (usage_o == logic'(exp_q.size()[ADDR_DEPTH-1:0]))
        //   else $fatal(1, "[TB] usage_o=%0d expected=%0d @t=%0t",
        //               usage_o, exp_q.size(), $time);
      @(posedge clk);
      assert (int'(usage_o) == exp_q.size())
        else $fatal(1, "[TB] usage_o=%0d expected=%0d @t=%0t",
                    int'(usage_o), exp_q.size(), $time);
      end
    end
  endtask

  // --- Test sequence ---
  initial begin
    // Defaults
    rst_ni     = 1'b0;
    flush_i    = 1'b0;
    testmode_i = 1'b0;
    push_i     = 1'b0;
    pop_i      = 1'b0;
    gen_base   = 0;
    data_i     = '0;

    // Reset
    repeat (3) @(posedge clk);
    rst_ni = 1'b1;
    repeat (2) @(posedge clk);

    // (1) Deterministic burst then a couple pops
    for (k = 0; k < N_IN; k++) burst[k] = dtype_t'(100 + k);
    drive_push(burst);
    drive_pop();
    drive_pop();

    // (2) Randomized traffic to hit simultaneous push/pop and wrap-around
    random_traffic(80);

    // (3) Flush test
    @(negedge clk);
    flush_i = 1'b1;
    @(posedge clk);
    flush_i = 1'b0;
    exp_q.delete();
    @(posedge clk);
    assert (empty_o) else $fatal(1, "[TB] not empty after flush");
    assert (usage_o == '0) else $fatal(1, "[TB] usage nonzero after flush");

    // (4) Fill to 'full' (cannot accept another 5-lane burst), then drain to empty
    gen_base = 200;
    do begin
      for (k = 0; k < N_IN; k++) burst[k] = dtype_t'(gen_base + k);
      drive_push(burst);
      gen_base += N_IN;
    end while (!full_o);

    while (!empty_o) drive_pop();

    $display("[TB] All tests PASSED.");
    $finish;
  end

endmodule
