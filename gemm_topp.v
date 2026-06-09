`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 28.11.2025 12:19:50
// Design Name: 
// Module Name: gemm_topp
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module gemm_topp #(parameter N=8, K=8, DW=16, ACCW=32, STREAM=1, K_WIDTH = 8, SATURATE=1)(

input clk, rst_n,

input wr_en_A,
input [DW-1:0] wdata_A,
input load_done_A,

input wr_en_B,
input [DW-1:0] wdata_B,
input load_done_B,

// Parallel output 
output   [(N*N*ACCW)-1:0]       c_out_flat,
output                         c_out_valid,  // 1-cycle pulse when c_out_flat is updated

// Streaming output 
output  [ACCW-1:0]             stream_data,
output                         stream_valid,
input                          stream_ready, 

input   start,
input   [K_WIDTH-1:0] K_length
  );

//------------------------------------------------------------
// Wire to take data from Buffer and Feed to Controller
//------------------------------------------------------------
wire [DW*N-1:0] data_buf_cntlr_A;
wire [DW*N-1:0] data_buf_cntlr_B;

wire [N-1:0] buf_cntlr_A_valid;
wire [N-1:0] buf_cntlr_B_valid;


//------------------------------------------------------------
// Wire to take data from  Controller to Systolic Array
//------------------------------------------------------------
wire [DW*N-1:0] cntlr_pe_A;
wire [DW*N-1:0] cntlr_pe_B;

wire [N-1:0] cntlr_pe_A_valid;
wire [N-1:0] cntlr_pe_B_valid;


//----------------
// MISCELLANEOUS
//-------------------
wire sample_acc;
wire clear_acc;  // to clear acc in Systolic array

wire [N*N*ACCW-1:0] sa_clctr_cflat;

wire rd_en_buffer_cntlr_A;
wire rd_en_buffer_cntlr_B;

// ----------------------------
// Instantiate Ping-Pong Buffer for A
// (parameters: N,K,DW,MODE). MODE choose such that rd_data is packed N elements
// MODE 0 -> Row wise
// ----------------------------
    
io_buffer_ping_pong  #(.N(N),
.K(K), .DW(DW),.MODE(0)) io_buffer_pp_A (
.clk(clk),
.rst_n(rst_n),
.wr_en(wr_en_A),
.wdata(wdata_A),
.load_done(load_done_A),

.rd_en(rd_en_buffer_cntlr_A),
.rd_data(data_buf_cntlr_A),
.rd_valid(buf_cntlr_A_valid),
 
.swap_req(1'b0), // unused in this integration (controller manages timing via rd_en)
.swap_ack());

// ----------------------------
// Instantiate Ping-Pong Buffer for B
// (parameters: N,K,DW,MODE). MODE choose such that rd_data is packed N elements
// MODE 1 -> column wise
// ----------------------------
io_buffer_ping_pong  #(.N(N),
.K(K), .DW(DW),.MODE(1)) io_buffer_pp_B (
.clk(clk),
.rst_n(rst_n),
.wr_en(wr_en_B),
.wdata(wdata_B),
.load_done(load_done_B),

.rd_en(rd_en_buffer_cntlr_B),
.rd_data(data_buf_cntlr_B),
.rd_valid(buf_cntlr_B_valid),
 
.swap_req(1'b0), // unused in this integration (controller manages timing via rd_en)
.swap_ack());

// ----------------------------
// Instantiate Controller
// ----------------------------

controller #( .N(N),
     .DW(DW),
     .K_WIDTH(K_WIDTH)) cntrl_a_b (
     .clk(clk),
     .rst_n(rst_n),
     .start(start),
     .K_length(K_length),
     .A_buffer_data(data_buf_cntlr_A),
     .B_buffer_data(data_buf_cntlr_B),
     .A_buffer_valid(buf_cntlr_A_valid),
     .B_buffer_valid(buf_cntlr_B_valid),
     
    .A_out(cntlr_pe_A),
    .A_out_valid(cntlr_pe_A_valid),
    .A_read_enable(rd_en_buffer_cntlr_A),
    .B_out(cntlr_pe_B),
    .B_out_valid(cntlr_pe_B_valid),
    .B_read_enable(rd_en_buffer_cntlr_B),
    .clear_acc(clear_acc), // clear_acc -> connects to Systolic array
    .compute_valid(),   // Not using this so remain unconnected
    .sample_acc(sample_acc),     // connected to collector
    .tile_done() // Not using this so remain unconnected  
     
);

systolic_array #( .N(N),
    .DW(DW),
    .ACCW(ACCW),
    .SATURATE(SATURATE)) u_sys_array (
    .clk(clk),
    .rst_n(rst_n),
    .A_in(cntlr_pe_A),
    .A_valid(cntlr_pe_A_valid),
    .B_in(cntlr_pe_B),
    .B_valid(cntlr_pe_B_valid),
    .clear_acc(clear_acc), // connects to Controller to clear accumlator
    .c_flat(sa_clctr_cflat),
    .c_valid_flat()
);


//-------------------------------------------------------------------
// OUTPUT COLLECTOR
//---------------------------------------------------------------------
output_collector_clk #(
.N(N), .ACCW(ACCW), .STREAM(STREAM)
) u_collector(
.clk(clk),
.rst_n(rst_n),
.acc_in_flat(sa_clctr_cflat),
.sample_acc(sample_acc),  // connected to controller
.c_out_flat(c_out_flat),
.c_out_valid(c_out_valid),
.stream_data(stream_data),
.stream_valid(stream_valid),
.stream_ready(stream_ready)
);

endmodule


module tb_gemm_top;

    parameter N = 4;
    parameter K = 4;
    parameter DW = 16;
    parameter ACCW = 32;

reg clk, rst_n;

reg wr_en_A;
reg [DW-1:0] wdata_A;
reg load_done_A;

reg wr_en_B;
reg [DW-1:0] wdata_B;
reg load_done_B;

// Parallel output 
wire   [(N*N*ACCW)-1:0]       c_out_flat;
wire                         c_out_valid;  // 1-cycle pulse when c_out_flat is updated

// Streaming output 
wire  [ACCW-1:0]             stream_data;
wire                         stream_valid;
reg                          stream_ready; 

reg   start;
reg   [7:0] K_length;

gemm_topp #(.N(N), .K(K), .DW(DW), .ACCW(ACCW), .STREAM(1), .K_WIDTH(8), .SATURATE(0)) u_gemm_top_dut(
 .clk(clk), .rst_n(rst_n),

.wr_en_A(wr_en_A),
.wdata_A(wdata_A),
.load_done_A(load_done_A),

.wr_en_B(wr_en_B),
.wdata_B(wdata_B),
.load_done_B(load_done_B),

// Parallel output 
.c_out_flat(c_out_flat),
.c_out_valid(c_out_valid),  // 1-cycle pulse when c_out_flat is updated

// Streaming output 
.stream_data(stream_data),
.stream_valid(stream_valid),
.stream_ready(stream_ready), 

.start(start),
.K_length(K_length) );


    // clock
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    // reset and default
    initial begin
        rst_n = 1'b0;
        wr_en_A = 0; wdata_A = 0; load_done_A = 0;
        wr_en_B = 0; wdata_B = 0; load_done_B = 0;
        stream_ready = 1'b1;
        start = 0; K_length = K;
        #20;
        rst_n = 1'b1;
        #20;
        run_test();
    end

    // -------------------------------------------------------------------------
    // test procedure: write matrices, start accelerator, wait for result, compare
    // -------------------------------------------------------------------------
    integer i, r, c, idx, kk, mismatches, acc;
    reg signed [DW-1:0] Amat [0:N-1][0:K-1];
    reg signed [DW-1:0] Bmat [0:K-1][0:N-1];
    reg signed [ACCW-1:0] C_expected [0:N-1][0:N-1];
    reg signed [ACCW-1:0] C_dut [0:N-1][0:N-1];
  reg [ACCW-1:0] tmp;
    task run_test;
        begin
            // prepare small test matrices (small numbers to avoid overflow)
            // A: 1..N*K row-major
            for (r=0; r<N; r=r+1)
                for (c=0; c<K; c=c+1)
                    Amat[r][c] = r*K + c + 1; // 1..16 for 4x4

            // B: small known matrix; identity here so C==A (easy debug)
            for (r=0; r<K; r=r+1)
                for (c=0; c<N; c=c+1)
                    Bmat[r][c] = (r==c) ? 1 : 0;

            // compute expected C = A x B (simple integer math)
            for (r=0; r<N; r=r+1) begin
                for (c=0; c<N; c=c+1) begin
                    //integer kk;
                    //integer acc;
                    acc = 0;
                    for (kk=0; kk<K; kk=kk+1) begin
                        acc = acc + Amat[r][kk] * Bmat[kk][c];
                    end
                    C_expected[r][c] = acc;
                end
            end

            // --------- write A into buffer (row-major, pulse load_done every N writes) ---------
            #10;
            for (i=0; i<N*K; i=i+1) begin
                wr_en_A = 1;
                wdata_A = Amat[i / K][i % K]; // note: i/K gives row for row-major sequential
                // provide load_done at end of each row (after K writes per row)
                if ((i % K) == (K-1)) begin
                    load_done_A = 1'b1;
                end else begin
                    load_done_A = 1'b0;
                end
                @(posedge clk);
            end
            // finish writes
            wr_en_A = 0;
            load_done_A = 0;

            // small gap
            repeat(2) @(posedge clk);

            // --------- write B into buffer (B is written column-major for our IO buffer MODE=1 earlier)
            // The buffer MODE=1 variant expects B's input in column-major order (B00,B10,B20,B30 ...).
            // We'll write columns sequentially: for col in 0..N-1, write rows 0..N-1, pulse load_done per column.
            #10;
            for (c=0; c<N; c=c+1) begin
                for (r=0; r<K; r=r+1) begin
                    wr_en_B = 1;
                    wdata_B = Bmat[r][c];
                    // load_done on end of each column (i.e., after N writes)
                    if (r == K-1) load_done_B = 1;
                    else load_done_B = 0;
                    @(posedge clk);
                end
            end
            wr_en_B = 0; load_done_B = 0;

            // small gap
            repeat(2) @(posedge clk);

            // --------- start accelerator ----------
            @(posedge clk);
            start = 1;
            K_length = K;
            @(posedge clk);
            start = 0;

            // wait until collector signals c_out_valid
            wait (c_out_valid == 1);
            @(posedge clk); // align to edge

            // read c_out_flat and unpack to C_dut
            for (r=0; r<N; r=r+1) begin
                for (c=0; c<N; c=c+1) begin
                    idx = r*N + c;
                    // select ACCW bits
                   // reg [ACCW-1:0] tmp;
                    tmp = c_out_flat[idx*ACCW +: ACCW];
                    // interpret as signed two's complement
                    if (tmp[ACCW-1])
                        C_dut[r][c] = $signed(tmp) - (1 << 0); // $signed(tmp) already signed in Verilog-2001
                    else
                        C_dut[r][c] = tmp;
                end
            end

            // compare
            //integer mismatches;
            mismatches = 0;
            for (r=0; r<N; r=r+1) begin
                for (c=0; c<N; c=c+1) begin
                    if (C_dut[r][c] !== C_expected[r][c]) begin
                        $display("Mismatch at (%0d,%0d): expected %0d, got %0d", r, c, C_expected[r][c], C_dut[r][c]);
                        mismatches = mismatches + 1;
                    end
                end
            end

            if (mismatches == 0) $display("*** TEST PASS: gemm_topp 4x4 OK ***");
            else $display("*** TEST FAIL: %0d mismatches ***", mismatches);

            #50;
            $finish;
        end
    endtask

endmodule
