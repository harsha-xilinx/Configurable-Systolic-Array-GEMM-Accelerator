`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 17.11.2025 19:34:53
// Design Name: 
// Module Name: controller
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
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//  ?. Notes for NXN Parametric Controller
//
// N is parameterized, so same code works for 4×4, 8×8, or 16×16 arrays.
//
// DW is data width, e.g., INT8/INT16/FP16.
//
// K_length is tile depth, normally equal to N for square matrices.
//
// FSM states handle fill ? compute ? drain ? sample phases.
//
// Can be extended for weight-stationary arrays, multi-tile streaming, or pipelined input.

// TILE_DONE is asserted means this matrix multiplication is completed
//////////////////////////////////////////////////////////////////////////////////


module controller #(parameter 
     N = 4,
     DW = 8,
     K_WIDTH = 4
) (
    input  wire clk,
    input  wire rst_n,
    input  wire start,
    input  wire [K_WIDTH-1:0] K_length,
    input  wire [DW*N-1:0] A_buffer_data,
    input  wire [DW*N-1:0] B_buffer_data,
    input  wire [N-1:0] A_buffer_valid,
    input  wire [N-1:0] B_buffer_valid,
    
    output reg  [DW*N-1:0] A_out,
    output reg  [N-1:0] A_out_valid,
    output reg  A_read_enable,
    output reg  [DW*N-1:0] B_out,
    output reg  [N-1:0] B_out_valid,
    output reg  B_read_enable,
    output reg  clear_acc,
    output reg  compute_valid,
    output reg  sample_acc,
    output reg  tile_done
    );

    // Internal counters
    reg [K_WIDTH-1:0] col_count;
    reg [2:0] state_reg, state_nxt;
    
        localparam IDLE   = 3'd0,
               CLEAR  = 3'd1,
               STREAM = 3'd2,
               DRAIN  = 3'd3,
               SAMPLE = 3'd4;

    always @(posedge clk or negedge rst_n) 
    begin
        if (!rst_n) 
        begin
            state_reg <= IDLE;
            col_count <= 0;
            A_out <= 0;
            B_out <= 0;
            A_out_valid <= 0;
            B_out_valid <= 0;
            A_read_enable <= 0;
            B_read_enable <= 0;
            clear_acc <= 0;
            compute_valid <= 0;
            sample_acc <= 0;
            tile_done <= 0;
        end
        else
        begin
           state_reg <= state_nxt;
        end
    end
    
    always@*
    begin
    case (state_reg)
                    IDLE: 
                    begin
                    clear_acc <= 0;
                    compute_valid <= 0;
                    sample_acc <= 0;
                    tile_done <= 0;
                    if (start)
                      state_nxt <= CLEAR;
                    end
                    
                    CLEAR: 
                    begin
                    clear_acc <= 1;
                    col_count <= 0;
                    state_nxt <= STREAM;
                    end
                    
                    STREAM: 
                    begin
                    clear_acc <= 0;
                    compute_valid <= 1;

                    // Feed A and B from buffers
                    A_out <= A_buffer_data;
                    B_out <= B_buffer_data;
                    A_out_valid <= {N{1'b1}};
                    B_out_valid <= {N{1'b1}};
                    A_read_enable <= 1;
                    B_read_enable <= 1;

                    // Increment counter
                    col_count <= col_count + 1;
                    if (col_count == K_length-1)
                        state_reg <= DRAIN;
                    end
                    
                    DRAIN: 
                    begin
                    // Stop reading new data
                    A_read_enable <= 0;
                    B_read_enable <= 0;
                    // Keep compute valid to propagate remaining MACs
                    compute_valid <= 1;
                    col_count <= col_count + 1;
                    if (col_count == K_length + N - 2) 
                    state_reg <= SAMPLE;
                    end
                    
                    SAMPLE: 
                    begin
                    compute_valid <= 0;
                    sample_acc <= 1;
                    tile_done <= 1;
                    state_reg <= IDLE;
                    end

    endcase  
    end
endmodule


module tb_controller;

    parameter N = 4;
    parameter DW = 8;
    parameter K_WIDTH = 4;

    // Clock & reset
    reg clk;
    reg rst_n;

    // Controller inputs
    reg start;
    reg [K_WIDTH-1:0] K_length;
    reg [DW*N-1:0] A_buffer_data;
    reg [DW*N-1:0] B_buffer_data;
    reg [N-1:0] A_buffer_valid;
    reg [N-1:0] B_buffer_valid;

    // Controller outputs
    wire [DW*N-1:0] A_out;
    wire [N-1:0] A_out_valid;
    wire A_read_enable;
    wire [DW*N-1:0] B_out;
    wire [N-1:0] B_out_valid;
    wire B_read_enable;
    wire clear_acc;
    wire compute_valid;
    wire sample_acc;
    wire tile_done;

    // Instantiate the controller
    controller #(
        .N(N),
        .DW(DW),
        .K_WIDTH(K_WIDTH)
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .K_length(K_length),
        .A_buffer_data(A_buffer_data),
        .B_buffer_data(B_buffer_data),
        .A_buffer_valid(A_buffer_valid),
        .B_buffer_valid(B_buffer_valid),
        .A_out(A_out),
        .A_out_valid(A_out_valid),
        .A_read_enable(A_read_enable),
        .B_out(B_out),
        .B_out_valid(B_out_valid),
        .B_read_enable(B_read_enable),
        .clear_acc(clear_acc),
        .compute_valid(compute_valid),
        .sample_acc(sample_acc),
        .tile_done(tile_done)
    );

    // Clock generation
    initial clk = 0;
    always #5 clk = ~clk; // 100MHz clock

    // Test stimulus
    integer i, j;
    reg [DW-1:0] A_mem[0:N-1][0:N-1];
    reg [DW-1:0] B_mem[0:N-1][0:N-1];

    initial begin
        // Reset
        rst_n = 0;
        start = 0;
        K_length = N; // Tile depth
        A_buffer_data = 0;
        B_buffer_data = 0;
        A_buffer_valid = 0;
        B_buffer_valid = 0;


        // Initialize A and B matrices
        for (i=0; i<N; i=i+1) begin
            for (j=0; j<N; j=j+1) begin
                A_mem[i][j] = i*10 + j; // Example values
                B_mem[i][j] = j*10 + i;
            end
        end

        #20;
        rst_n = 1;
        #10;
        start = 1;
        #10;
        start = 0;

        // Feed data for each column of A / row of B
        for (i=0; i<N; i=i+1) begin
            A_buffer_data = {A_mem[3][i], A_mem[2][i], A_mem[1][i], A_mem[0][i]};
            B_buffer_data = {B_mem[i][3], B_mem[i][2], B_mem[i][1], B_mem[i][0]};
            A_buffer_valid = {N{1'b1}};
            B_buffer_valid = {N{1'b1}};
            #10; // Wait one cycle
        end

        // Wait extra cycles for drain/sample
        #100;
        $finish;
    end

    // Optional: monitor outputs
    initial begin
        $display("Time\tA_out\tB_out\tclear\tcompute\tsample\ttile_done");
        $monitor("%0t\t%h\t%h\t%b\t%b\t%b\t%b", 
                 $time, A_out, B_out, clear_acc, compute_valid, sample_acc, tile_done);
    end

endmodule


