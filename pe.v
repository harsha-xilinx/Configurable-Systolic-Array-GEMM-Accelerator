`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 17.11.2025 06:31:51
// Design Name: 
// Module Name: pe
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


module pe #(parameter DW=8,
 ACCW = 32,
 SATURATE = 1'b1   // 1 = clamp to max on overflow
)(
input clk, rst_n,

input [DW-1:0] A_in, 
input A_valid_in,
input [DW-1:0] B_in, 
input B_valid_in,

input  clear_acc, // synchronous clear accumulator

output [ACCW-1:0] C_out,
output C_valid_out,

// status
output  overflow, // 1 if saturation/overflow happened on last update
// Overflow in a PE happens when data atfer accumlate is more than its Width
    // passthrough outputs
output  [DW-1:0]            A_out,
output                      A_out_valid,
output  [DW-1:0]            B_out,
output                      B_out_valid
    );

// product width
localparam  PRODW = 2*DW;

reg overflow_reg, overflow_nxt;

// stage 0 latches
reg [DW-1:0] A_01, B_01;
reg  A_01_valid, B_01_valid;

// stage 1 latches



reg [PRODW-1:0] prod_1_out_tmp;
reg [ACCW-1:0] acc_1_out, acc_1_out_nxt; 
reg [ACCW:0] acc_1_out_tmp;
reg acc_1_valid, acc_1_valid_nxt, acc_1_valid_tmp;


//stage 0 code
always@ (posedge clk, negedge rst_n)
begin
if (~rst_n)
  begin
  A_01 <= 'b0;
  B_01 <= 'b0;
  A_01_valid <= 1'b0;
  B_01_valid <= 1'b0;
  end
else
  begin
  A_01 <= A_in;
  B_01 <= B_in;
  A_01_valid <= A_valid_in;
  B_01_valid <= B_valid_in;  
  end
end

// stage 1 code
always@(posedge clk, negedge rst_n)
begin
if(~rst_n)
  begin
    acc_1_out <= 0;
    acc_1_valid <= 0 ;
    overflow_reg <= 0;
  end
else
  begin
    acc_1_out <= acc_1_out_nxt;
    acc_1_valid <= acc_1_valid_nxt ;
    overflow_reg <= overflow_nxt;    
  end
end

// Write logic for Overflow reg
always@*
begin

  prod_1_out_tmp = A_01 * B_01; 
  //prod_1_valid_tmp = 1'b1;
  acc_1_out_tmp = {1'b0, acc_1_out} + {1'b0, prod_1_out_tmp};
  acc_1_valid_tmp = A_01_valid & B_01_valid; 
  overflow_nxt = acc_1_out_tmp[ACCW];
  
  
  if (~clear_acc)
  begin
    if (overflow_nxt) // overflow case
    begin
        if (SATURATE)
          begin
          acc_1_out_nxt = {ACCW{1'b1}};
          acc_1_valid_nxt = acc_1_valid_tmp;
          end
        else
          begin
          acc_1_out_nxt =  acc_1_out_tmp[ACCW-1:0] ; 
          acc_1_valid_nxt = acc_1_valid_tmp;
          end
    end
    else // non overflow case
    begin
      acc_1_out_nxt = acc_1_out_tmp[ACCW-1:0];
      acc_1_valid_nxt = acc_1_valid_tmp; 
    end
  end
  else
    begin
    acc_1_out_nxt = 0;
    acc_1_valid_nxt = 0;
    end 
end

assign overflow = overflow_reg;
assign C_out = acc_1_out;
assign C_valid_out = acc_1_valid;


assign A_out = A_01;
assign A_out_valid = A_01_valid;
assign B_out = B_01; 
assign B_out_valid = B_01_valid;

endmodule

`timescale 1ns/1ps

module tb_pe;

    // ---- Parameters ----
    localparam DW     = 8;
    localparam ACCW   = 32;
    localparam SATURATE = 1'b1;

    localparam CLK_PERIOD = 10;

    // ---- DUT signals ----
    reg                   clk, rst_n;
    reg  [DW-1:0]         A_in, B_in;
    reg                   A_valid_in, B_valid_in;
    reg                   clear_acc;

    wire [ACCW-1:0]       C_out;
    wire                  C_valid_out;
    wire                  overflow;

    wire [DW-1:0]         A_out, B_out;
    wire                  A_out_valid, B_out_valid;

    // ---- Instantiate DUT ----
    pe #(
        .DW(DW),
        .ACCW(ACCW),
        .SATURATE(SATURATE)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .A_in(A_in),
        .A_valid_in(A_valid_in),
        .B_in(B_in),
        .B_valid_in(B_valid_in),
        .clear_acc(clear_acc),
        .C_out(C_out),
        .C_valid_out(C_valid_out),
        .overflow(overflow),
        .A_out(A_out),
        .A_out_valid(A_out_valid),
        .B_out(B_out),
        .B_out_valid(B_out_valid)
    );

    // ---- Clock ----
    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    // ---- Reference model ----
    reg [ACCW:0] ref_acc;  // one extra bit for overflow detection

    task ref_reset;
    begin
        ref_acc = 0;
    end
    endtask

    task ref_step(input [DW-1:0] a,
                  input [DW-1:0] b,
                  input valid);
        reg [ACCW:0] tmp;
    begin
        if (valid) begin
            tmp = ref_acc + a*b;

            if (SATURATE && tmp[ACCW]) begin
                ref_acc = {ACCW{1'b1}};
            end else begin
                ref_acc = tmp[ACCW-1:0];
            end
        end
    end
    endtask


    // ---- Test Procedure ----
    integer i;

    initial begin
        $display("---- Starting PE Testbench ----");

        // Initialize
        A_in=0; B_in=0; A_valid_in=0; B_valid_in=0;
        clear_acc=0;
        rst_n=0;
        ref_reset;

        // Apply reset
        repeat(5) @(posedge clk);
        rst_n = 1;
        @(posedge clk);

        // ----------- Test 1: Simple MAC sequence ---------------
        $display("[T1] basic accumulation");

        send(5, 3);  ref_step(5,3,1);
        send(2, 7);  ref_step(2,7,1);
        send(10,1);  ref_step(10,1,1);

        // Give pipeline 3 cycles to flush
        repeat(3) @(posedge clk);

        check_output;

        // ----------- Test 2: Clear accumulator -------------------
        $display("[T2] clear_acc test");
        clear_acc = 1;
        @(posedge clk);
        clear_acc = 0;
        ref_reset;

        repeat(2) @(posedge clk);

        if (C_out !== 0) begin
            $fatal("clear_acc FAILED! C_out=%0d", C_out);
        end

        $display("clear_acc OK");

        // ----------- Test 3: Saturation / Overflow ---------------
        $display("[T3] starting saturation/overflow test");

        for (i=0; i<20; i=i+1) begin
            send(255,255);   // guaranteed huge product
            ref_step(255,255,1);
        end

        repeat(5) @(posedge clk);
        check_output;

        // ----------- Test 4: Random test phase -------------------
        $display("[T4] random stimulus test");

        ref_reset;
        clear_acc=1;
        @(posedge clk);
        clear_acc=0;

        for (i=0; i<200; i=i+1) begin
            A_in = $random;
            B_in = $random;
            A_valid_in = $random % 2;
            B_valid_in = A_valid_in;  // match DUT assumption
            ref_step(A_in,B_in,A_valid_in);
            @(posedge clk);
        end

        repeat(5) @(posedge clk);
        check_output;

        $display("---- ALL TESTS PASSED ----");
        $finish;
    end

    // ---- Helper tasks ----
    task send(input [DW-1:0] a, b);
    begin
        A_in=a; B_in=b;
        A_valid_in=1; B_valid_in=1;
        @(posedge clk);
        A_valid_in=0; B_valid_in=0;
    end
    endtask

    task check_output;
    begin
        if (C_out !== ref_acc[ACCW-1:0]) begin
            $fatal("FAIL: DUT C_out=%0d  ref=%0d", 
                    C_out, ref_acc[ACCW-1:0]);
        end else begin
            $display("PASS: Output matches reference: %0d", C_out);
        end
    end
    endtask

endmodule
