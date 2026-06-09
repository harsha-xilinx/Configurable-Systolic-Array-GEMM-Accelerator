`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 22.11.2025 00:36:33
// Design Name: 
// Module Name: output_collector
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


module output_collector #(
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
reg [ACCW-1:0] mem [0:N*N-1];
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
       streaming =1'b1;
      end
    else if(!sample_acc)
      begin
      c_out_flat_reg <= acc_in_flat;
      c_out_valid_reg <= 1'b0;
      end
    end  
end

      
`
/*    else if(stream_ready)
      begin
        if (j< N*N)
          begin
          stream_data_reg <= mem[j];
          stream_valid_reg <= 1'b1;
          j= j+1;
          end
        else
          begin
          stream_data_reg <= 'b0;
          stream_valid_reg <= 1'b0;
          end          
      end
    end
end
*/
assign stream_data = stream_data_reg;
assign stream_valid = stream_valid_reg;
assign c_out_flat = c_out_flat_reg;
assign c_out_valid = c_out_valid_reg;

endmodule

