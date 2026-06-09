Systolic Output controller
`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 18.11.2025 01:08:49
// Design Name: 
// Module Name: systolic_output_collector
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


module systolic_output_collector #(
    parameter  N = 8,                   // array dimension (NxN)
     ACCW = 32,               // accumulator width (bits)
      STREAM = 1 )(
    input clk, rst_n,
    input [(N*N*ACCW)-1:0]       acc_in_flat, 
    input sample_acc,   // sample (1-cycle pulse) - controller should pulse this

    // Parallel output 
    output   [(N*N*ACCW)-1:0]       c_out_flat,
    output                         c_out_valid,  // 1-cycle pulse when c_out_flat is updated

    // Streaming output 
    output  [ACCW-1:0]             stream_data,
    output                         stream_valid,
    input                          stream_ready
    );
integer i,k;
reg c_out_valid_reg ;
reg [N:0] cntr;
reg [(N*N*ACCW)-1:0] c_out_flat_reg;
reg [ACCW-1:0] mem [0:(N*N)-1];
integer data_num;
reg [ACCW-1:0] stream_data_reg;
reg stream_valid_reg;
always@ (posedge clk, negedge rst_n)
begin
  if (!rst_n)
  begin
    c_out_flat_reg  <= 'b0; 
    c_out_valid_reg <= 1'b0;
  end
  else
  begin
    //push values 
    if (sample_acc)
     begin
     c_out_flat_reg <= acc_in_flat;
     c_out_valid_reg <= 1'b1;
     for (i = 0; i < N*N; i = i + 1)
         mem[i] <= acc_in_flat[i*ACCW +: ACCW];
     data_num = N*N;
     cntr <= 'b0;
     end     
    else
    begin
    c_out_valid_reg <= 1'b0;
    c_out_flat_reg  <= 'b0; 
    end 
  end
end

always@ (posedge clk, negedge rst_n)
begin
   if(!rst_n)
   begin
     stream_data_reg <= 'b0;
     stream_valid_reg <= 1'b0;
     cntr <= 'b0;
   end
   else
   begin
     if (cntr < data_num )
     begin
       if (stream_ready)
       begin
         k= cntr;
         stream_data_reg <= mem[k];
         stream_valid_reg <= 1'b1;
         cntr= cntr+1'b1;
       end
     end
     else
     begin
     stream_data_reg <= 'b0;
     stream_valid_reg <= 1'b0;
     cntr <= data_num;        
     end     
   end
end
   
assign  stream_data = stream_data_reg;
assign  stream_valid = stream_valid_reg;
assign c_out_flat = c_out_flat_reg;
assign c_out_valid = c_out_valid_reg;

endmodule

module tb_systolic_output_cntrlr;

localparam N=4;
localparam ACCW = 16;
localparam STREAM=1;
localparam T=10;

    reg clk, rst_n;
    reg [(N*N*ACCW)-1:0]       acc_in_flat ;
    reg sample_acc ;   // sample (1-cycle pulse) - controller should pulse this

    // Parallel output 
    wire   [(N*N*ACCW)-1:0]       c_out_flat;
    wire                         c_out_valid ;  // 1-cycle pulse when c_out_flat is updated

    // Streaming output 
    wire  [ACCW-1:0]             stream_data ;
    wire                         stream_valid ;
    reg                          stream_ready ;

    systolic_output_collector #(
        .N(N),
        .ACCW(ACCW),
        .STREAM(STREAM)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .acc_in_flat(acc_in_flat),
        .sample_acc(sample_acc),
        .c_out_flat(c_out_flat),
        .c_out_valid(c_out_valid),
        .stream_data(stream_data),
        .stream_valid(stream_valid),
        .stream_ready(stream_ready)
    );
 
always
begin
#(5); clk=~clk;
end

initial
begin
rst_n=1'b0;clk=1'b0;
#20; rst_n=1'b1;
end

initial
begin
acc_in_flat= 256'b0; sample_acc=1'b0; stream_ready=1'b0;
#20;sample_acc=1'b1; stream_ready=1'b1; acc_in_flat=256'habcdefabcdefabcdabcdefabcdefabcdabcdefabcdefabcdabcdefabcdefabcd;
#10; sample_acc=1'b0; acc_in_flat=256'h0;
#500;sample_acc=1'b1; stream_ready=1'b1; acc_in_flat=256'haaaabbbbccccddddeeeeffffaaaabbbbccccddddeeeeffffaaaabbbbccccdddd;
#10; sample_acc=1'b0; acc_in_flat=256'h0;
#500; $finish;
end

endmodule
