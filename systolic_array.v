`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 26.11.2025 14:46:12
// Design Name: 
// Module Name: systolic_array
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


module systolic_array #(
    parameter N    = 8,
    parameter DW   = 16,
    parameter ACCW = 32,
    parameter SATURATE = 1'b1
)(
    input  wire                     clk,
    input  wire                     rst_n,

    // Left-edge A inputs (row-wise)
    input  wire [N*DW-1:0]          A_in,
    input  wire [N-1:0]             A_valid,

    // Top-edge B inputs (column-wise)
    input  wire [N*DW-1:0]          B_in,
    input  wire [N-1:0]             B_valid,

    input  wire                     clear_acc,

    output wire [(N*N*ACCW)-1:0]    c_flat,
    output wire [N*N-1:0]           c_valid_flat
);

    // ------------------------------------------------------------
    // Flattened internal buses
    // index = r*N + c
    // ------------------------------------------------------------
    wire [DW-1:0] A_bus      [0:N*N-1];
    wire          A_vbus     [0:N*N-1];
    wire [DW-1:0] B_bus      [0:N*N-1];
    wire          B_vbus     [0:N*N-1];

    wire [DW-1:0] A_right    [0:N*N-1];
    wire          A_right_v  [0:N*N-1];
    wire [DW-1:0] B_down     [0:N*N-1];
    wire          B_down_v   [0:N*N-1];

    wire [ACCW-1:0] C_acc    [0:N*N-1];
    wire            C_valid  [0:N*N-1];
  
    genvar r, c;
    generate
        for (r = 0; r < N; r = r + 1) 
        begin : gen_rows
            for (c = 0; c < N; c = c + 1) 
            begin : gen_cols

                // Compute linear index
                localparam IDX = r*N + c;

                // -------------------------- A wiring (left ? right)
                if (c == 0) begin : left_edge
                    assign A_bus[IDX]  = A_in[r*DW +: DW];
                    assign A_vbus[IDX] = A_valid[r];
                end else begin : inner_A
                    assign A_bus[IDX]  = A_right[IDX-1];
                    assign A_vbus[IDX] = A_right_v[IDX-1];
                end

                // -------------------------- B wiring (top ? bottom)
                if (r == 0) begin : top_edge
                    assign B_bus[IDX]  = B_in[c*DW +: DW];
                    assign B_vbus[IDX] = B_valid[c];
                end else begin : inner_B
                    assign B_bus[IDX]  = B_down[IDX-N];
                    assign B_vbus[IDX] = B_down_v[IDX-N];
                end

                // ---------------------- PE instantiation -------------------
                pe #(
                    .DW(DW),
                    .ACCW(ACCW),
                    .SATURATE(SATURATE)
                ) pe_inst (
                    .clk(clk),
                    .rst_n(rst_n),

                    .A_in(A_bus[IDX]),
                    .A_valid_in(A_vbus[IDX]),
                    .B_in(B_bus[IDX]),
                    .B_valid_in(B_vbus[IDX]),

                    .clear_acc(clear_acc),

                    .C_out(C_acc[IDX]),
                    .C_valid_out(C_valid[IDX]),

                    .overflow(),

                    .A_out(A_right[IDX]),
                    .A_out_valid(A_right_v[IDX]),
                    .B_out(B_down[IDX]),
                    .B_out_valid(B_down_v[IDX])
                );
            end
        end
    endgenerate

    // ------------------------------------------------------------
    // Flatten C_acc and C_valid to output
    // ------------------------------------------------------------
    generate
        for (r = 0; r < N; r = r + 1) begin : gen_flat_rows2
            for (c = 0; c < N; c = c + 1) 
            begin : gen_flat_cols2
                localparam IDX2 = r*N + c;
                assign c_flat[IDX2*ACCW +: ACCW] = C_acc[IDX2];
                assign c_valid_flat[IDX2]        = C_valid[IDX2];
            end
        end
    endgenerate

endmodule


`timescale 1ns/1ps

`timescale 1ns/1ps

module tb_systolic_4x4;

    localparam N     = 4;
    localparam DW    = 16;
    localparam ACCW  = 32;

    reg                   clk, rst_n;
    reg  [N*DW-1:0]       A_in;
    reg  [N*DW-1:0]       B_in;
    reg  [N-1:0]          A_valid;
    reg  [N-1:0]          B_valid;

    wire [N*N*ACCW-1:0]   c_flat;
    wire [N*N-1:0]        c_valid_flat;

    // --------------------------
    // Instantiate DUT
    // --------------------------
    systolic_array #(
        .N(N), .DW(DW), .ACCW(ACCW)
    ) sys_array_4 (
        .clk(clk),
        .rst_n(rst_n),
        .A_in(A_in),
        .A_valid(A_valid),
        .B_in(B_in),
        .B_valid(B_valid),
        .clear_acc(1'b0),   // no reset during test
        .c_flat(c_flat),
        .c_valid_flat(c_valid_flat)
    );

    // --------------------------
    // Clock generation
    // --------------------------
    initial begin
        clk = 0;
        forever #5 clk = ~clk;   // 100 MHz
    end

    // --------------------------
    // Reset
    // --------------------------
    initial begin
        rst_n = 0;
        A_in = 0;
        B_in = 0;
        A_valid = 0;
        B_valid = 0;
        #20 rst_n = 1;
    end

    // --------------------------
    // Simple 4x4 test
    // --------------------------
    integer i, j;
    reg [DW-1:0] A_mat [0:N-1][0:N-1];
    reg [DW-1:0] B_mat [0:N-1][0:N-1];

    initial begin
        // Initialize A matrix
        for (i=0;i<N;i=i+1)
            for (j=0;j<N;j=j+1)
                A_mat[i][j] = i*N + j + 1;

        // Identity matrix B
        for (i=0;i<N;i=i+1)
            for (j=0;j<N;j=j+1)
                B_mat[i][j] = (i==j) ? 1 : 0;

        // Wait for reset
        @(posedge rst_n);
        #10;

        // Feed inputs row-wise (A) and column-wise (B)
        for (i=0;i<N;i=i+1) begin
            // Flatten A row
            for (j=0;j<N;j=j+1)
                A_in[j*DW +: DW] = A_mat[i][j];

            // Flatten B column
            for (j=0;j<N;j=j+1)
                B_in[j*DW +: DW] = B_mat[j][i];

            A_valid = 4'b1111;
            B_valid = 4'b1111;
            @(posedge clk);
        end

        // Remove valid after feeding
        A_valid = 0;
        B_valid = 0;

        // Wait a few cycles for pipeline to propagate
        repeat(N+2) @(posedge clk);

        // Display results
        $display("===== ACC OUTPUT (FLAT) =====");
        for (i=0;i<N*N;i=i+1)
            $display("c_flat[%0d] = %0d", i, c_flat[i*ACCW +: ACCW]);

        $finish;
    end

endmodule
