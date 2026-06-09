`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 22.11.2025 13:03:50
// Design Name: 
// Module Name: output_collector_clk
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
/////////////////////////////////////////////////////////////////////////////////
//Note : In this code we have a very important concept, how to enable 1 signal, if another signal is high at previous clk
/////////////////////////////////////////////////////////////////////////////////

module output_collector_clk #(
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

reg [(N*N*ACCW)-1:0] c_out_flat_reg;
reg c_out_valid_reg;
reg [(ACCW)-1:0] stream_data_reg;
reg stream_valid_reg;
integer i;
reg streaming;
reg [N*N+1:0] cntr = 'b0;
reg [ACCW-1:0] mem [0:N*N-1];

reg sample_acc_reg;
reg sample_acc_nxt;

always@(posedge clk, negedge rst_n)
begin
  if(!rst_n)
  begin
   sample_acc_reg <=1'b0;
   sample_acc_nxt <= 1'b0;
  end
  else
  begin
   sample_acc_reg <= sample_acc;
   sample_acc_nxt <= sample_acc_reg;
  end
end

always@(posedge clk, negedge rst_n)
begin
  if (!rst_n)
    begin
    c_out_flat_reg <= 'b0;
    c_out_valid_reg <= 1'b0;
    end
  else
    begin
    if (sample_acc)
      begin
      c_out_flat_reg <= acc_in_flat;
      c_out_valid_reg <= 1'b1;
      for(i=0; i<N*N; i=i+1)
       mem[i]<= acc_in_flat[i*ACCW+:ACCW];
       //streaming =1'b1;
      end
    else if(!sample_acc)
      begin
      c_out_flat_reg <= 'b0;
      c_out_valid_reg <= 1'b0;
      end
    end
end

always@(posedge clk, negedge rst_n)
begin
   if(!rst_n)
     begin
     stream_data_reg <= 'b0;
     stream_valid_reg <= 1'b0;
     cntr <= N*N+1'b0;
     end
   else
     begin
       if(sample_acc_nxt || streaming)
       begin
        if (cntr <  N*N)
        begin
        stream_data_reg <= mem[cntr];
        stream_valid_reg <= 1'b1;
        cntr <= cntr+1'b1;
        streaming <= 1'b1;
        end
        else
        begin
        cntr <= N*N+1'b1;
        stream_data_reg <= 'b0;
        stream_valid_reg <= 1'b0; 
        streaming <= 1'b0;       
        end
       end
       else
       begin
        cntr <= 'b0;
        stream_data_reg <= 'b0;
        stream_valid_reg <= 1'b0; 
        streaming <= 1'b0;        
       end
     end
end

assign stream_data = stream_data_reg;
assign stream_valid = stream_valid_reg;
assign c_out_flat = c_out_flat_reg;
assign c_out_valid = c_out_valid_reg;

endmodule

module tb_output_collector_clk;

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

    output_collector_clk #(
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

