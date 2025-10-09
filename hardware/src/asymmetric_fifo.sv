// Modified from fifo_v3.sv in common_cells

`include "common_cells/assertions.svh"
// - Accepts N_IN items per push via data_i[N_IN]
// - Pops 1 item per pop (same as original)
module asymmetric_fifo #(
    parameter bit          FALL_THROUGH = 1'b0,      // unchanged semantics; enforced N_IN==1
    parameter int unsigned DATA_WIDTH   = 32,
    parameter int unsigned DEPTH        = 8,
    parameter type dtype                = logic [DATA_WIDTH-1:0],
    parameter int unsigned N_IN         = 1,         // NEW: number of items accepted per push
    // DO NOT OVERWRITE THIS PARAMETER
    parameter int unsigned ADDR_DEPTH   = (DEPTH > 1) ? $clog2(DEPTH) : 1
)(
    input  logic  clk_i,
    input  logic  rst_ni,
    input  logic  flush_i,
    input  logic  testmode_i,

    // status flags
    output logic  full_o,
    output logic  empty_o,
    output logic  [ADDR_DEPTH-1:0] usage_o,

    // NEW: accept N_IN items per push (array of dtype)
    input  dtype  [N_IN-1:0] data_i,        // CHANGED: was `input dtype data_i`
    input  logic  push_i,

    // unchanged: pop one item per cycle
    output dtype  data_o,
    input  logic  pop_i
);

    // local parameter
    localparam int unsigned FifoDepth = (DEPTH > 0) ? DEPTH : 1;

    // clock gating control (unchanged)
    logic gate_clock;

    // pointers
    logic [ADDR_DEPTH - 1:0] read_pointer_n,  read_pointer_q;
    logic [ADDR_DEPTH - 1:0] write_pointer_n, write_pointer_q;

    // occupancy counter (one extra bit)
    logic [ADDR_DEPTH:0] status_cnt_n, status_cnt_q;

    // storage
    dtype [FifoDepth - 1:0] mem_n, mem_q;

    assign usage_o = status_cnt_q[ADDR_DEPTH-1:0];

    // Flags: "full" now means we cannot accept a whole burst of N_IN
    if (DEPTH == 0) begin : gen_pass_through
        assign empty_o = ~push_i;
        assign full_o  = ~pop_i;
    end else begin : gen_fifo
        // free space >= N_IN  <=>  status_cnt_q <= FifoDepth - N_IN
        assign full_o  = (status_cnt_q > (FifoDepth[ADDR_DEPTH:0] - N_IN[ADDR_DEPTH:0]));
        // unchanged empty flag (fall-through veto applied below)
        assign empty_o = (status_cnt_q == 0) & ~(FALL_THROUGH & push_i);
    end

    // read / write comb
    always_comb begin : read_write_comb
        // defaults
        read_pointer_n  = read_pointer_q;
        write_pointer_n = write_pointer_q;
        status_cnt_n    = status_cnt_q;
        // In DEPTH==0 passthrough, show first element; else read head
        data_o          = (DEPTH == 0) ? data_i[0] : mem_q[read_pointer_q]; // CHANGED (index [0])
        mem_n           = mem_q;
        gate_clock      = 1'b1;

        // --------------- PUSH (burst of N_IN) ---------------
        if (push_i && ~full_o) begin
            // write N_IN consecutive elements with wrap-around
            logic [ADDR_DEPTH-1:0] wp;
            wp = write_pointer_q;
            for (int unsigned k = 0; k < N_IN; k++) begin
                mem_n[wp] = data_i[k];
                if (wp == FifoDepth[ADDR_DEPTH-1:0] - 1) wp = '0;
                else                                     wp = wp + 1;
            end
            write_pointer_n = wp;

            // occupy N_IN
            status_cnt_n = status_cnt_q + N_IN[ADDR_DEPTH:0];

            // un-gate clock to commit mem_n
            gate_clock = 1'b0;
        end

        // --------------- POP (one item) ---------------
        if (pop_i && ~empty_o) begin
            if (read_pointer_n == FifoDepth[ADDR_DEPTH-1:0] - 1) read_pointer_n = '0;
            else                                                 read_pointer_n = read_pointer_q + 1;
            status_cnt_n = status_cnt_q - 1;
        end

        // If both happen, net effect is +N_IN - 1
        if (push_i && pop_i && ~full_o && ~empty_o) begin
            status_cnt_n = status_cnt_q + N_IN[ADDR_DEPTH:0] - 1;
        end

        // --------------- FALL-THROUGH (only meaningful for N_IN==1) ---------------
        if (FALL_THROUGH && (status_cnt_q == 0) && push_i) begin
            // Asymmetric fall-through for N_IN>1 would drop data_i[1..]; we forbid N_IN>1 below.
            data_o = data_i[0];
            if (pop_i) begin
                status_cnt_n    = status_cnt_q;
                read_pointer_n  = read_pointer_q;
                write_pointer_n = write_pointer_q;
            end
        end
    end

    // sequential: pointers and count
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if(~rst_ni) begin
            read_pointer_q  <= '0;
            write_pointer_q <= '0;
            status_cnt_q    <= '0;
        end else begin
            if (flush_i) begin
                read_pointer_q  <= '0;
                write_pointer_q <= '0;
                status_cnt_q    <= '0;
            end else begin
                read_pointer_q  <= read_pointer_n;
                write_pointer_q <= write_pointer_n;
                status_cnt_q    <= status_cnt_n;
            end
        end
    end

    // sequential: memory (coarse clock gating)
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if(~rst_ni) begin
            mem_q <= {FifoDepth{dtype'('0)}};
        end else if (!gate_clock) begin
            mem_q <= mem_n;
        end
    end

`ifndef COMMON_CELLS_ASSERTS_OFF
    `ASSERT_INIT(depth_pos,  DEPTH > 0, "DEPTH must be greater than 0.")
    `ASSERT_INIT(n_in_range, (N_IN >= 1) && (N_IN <= FifoDepth),
                 "N_IN must be in 1..DEPTH.")
    `ASSERT_INIT(fall_through_n1, !(FALL_THROUGH && (N_IN != 1)),
                 "FALL_THROUGH is only supported for N_IN==1 (to avoid data loss).")

    `ASSERT(full_write, full_o |-> ~push_i, clk_i, !rst_ni,
            "Trying to push although FIFO cannot accept a full N_IN burst.")

    `ASSERT(empty_read, empty_o |-> ~pop_i, clk_i, !rst_ni,
            "Trying to pop data although the FIFO is empty.")
`endif

endmodule // asymmetric_fifo
