`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 24.11.2025 07:19:06
// Design Name: 
// Module Name: io_buffer_ping_pong
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
//NOTE: THIS CODE WILL WORK CORRECTLY, WHEN NUMBER OF ROWS = NUMBER OF COLUMNS "OR" NUMBER OF COLUMNS> NUMBER OF ROWS
//BECAUSE OUTPUT: RD_DATA IS SET IN THAT MANNER


module io_buffer_ping_pong #(parameter N=8,K=8,
DW=16, MODE=0)(
input clk, rst_n,

input wr_en,
input [DW-1:0] wdata,
input load_done,

input rd_en,
output  [DW*K-1:0] rd_data,
output reg rd_valid,

input swap_req,
output reg swap_ack
    );

localparam ELEMS= N*K;

// storage: two buffers ping/pong
reg [DW-1:0] ping_mem [0:ELEMS-1];
reg [DW-1:0] pong_mem [0:ELEMS-1];

reg read_sel; // 0-> read from ping, 1-> read from pong
reg write_sel; // 0-> write to ping, 1-> write to pong
reg bank_full;
wire bank_full_reg;
reg [$clog2(N):0]     written_rows;

reg [$clog2(ELEMS+1)-1:0]   wr_ptr;    // 0..ELEMS-1
reg [DW*K-1:0] rd_data_reg;

integer i, m, j ;
always@ (posedge clk, negedge rst_n)
begin
  if(!rst_n)
  begin
  write_sel <= 1'b0;
  wr_ptr <= 'b0;
  bank_full <= 1'b0;
  written_rows <= 'b0;
  end
  else
  begin
    bank_full <= 1'b0;
    if (wr_en)
    begin
      if (!write_sel)
        begin
          ping_mem[wr_ptr] <= wdata;
        end
      else
        begin
          pong_mem[wr_ptr] <= wdata;
        end 

        
      if (wr_ptr == ELEMS-1)
        wr_ptr <= 0;
      else
        wr_ptr <= wr_ptr + 1; 
        
      
      if (load_done)
      begin 
      if (written_rows==N-1 && swap_req)
      begin
            swap_ack      <= 1;
            written_rows  <= 0;
            wr_ptr        <= 0;
            write_sel     <= ~write_sel;
            bank_full     <= 1'b1;
            //bank_full_reg <= bank_full;
      end
      else
      begin
           written_rows <= written_rows+1'b1;
      end    
      end
    end
  end
end


// =========================================================
//  READ LOGIC
//  PACK_MODE = 0 ? row-major read
//  PACK_MODE = 1 ? column-major read
// =========================================================

always@(posedge clk, negedge rst_n)
begin
  if (!rst_n)
  begin
    rd_data_reg <= 'b0;
    rd_valid <= 1'b0;
    m <= 'b0;
  end
  else
  begin
    if (rd_en && bank_full_reg | m > 0 &&  m < N*K)
    begin
      if (MODE == 0)                   // ROW-MAJOR READ
      begin
        if (m < N*K) 
        begin
         for (i=0; i<K; i=i+1)
          begin
          rd_data_reg[i*DW+:DW] <= write_sel? ping_mem[i+m] : pong_mem[i+m]; 
          rd_valid <= 1'b1;
          end         
        m=m+K;
        end
      end
      else if (MODE == 1)                   // COLUMN-MAJOR READ
      begin
        if (m < K)  // m should be less than Number of columns 
        begin
          for (i=0; i<N; i=i+1)  // i should be less than Number of rows
          begin
          rd_data_reg[i*DW+:DW] <= write_sel? ping_mem[(K*i)+m] : pong_mem[(K*i)+m]; 
          rd_valid <= 1'b1;
          end
          m = m+1'b1;
        end
        else
        begin
          m <='b0;
        end
      end
    end 
    else
    begin
     m<= 'b0;
    end
  end
end

assign  bank_full_reg = bank_full;
assign  rd_data = rd_data_reg;
endmodule

module tb_io_ping_pong_buffer;
localparam N=4;
localparam K=6;
localparam DW=16;
localparam MODE=0;

reg clk, rst_n;
reg wr_en;
reg [DW-1:0] wdata;
reg load_done;

reg rd_en ; 
wire  [DW*K-1:0] rd_data ;
wire rd_valid;

reg swap_req ;
wire swap_ack;

io_buffer_ping_pong #(.N(N), .K(K), .DW(DW), .MODE(MODE)) ppbuffer(.clk(clk), .rst_n(rst_n), .wr_en(wr_en), .wdata(wdata), .load_done(load_done), .rd_en(rd_en), .rd_data(rd_data), .rd_valid(rd_valid), .swap_req(swap_req), .swap_ack(swap_ack));

initial
begin
clk=1'b0; rst_n=1'b0;
#10; rst_n=1'b1;
end

always
begin
#5; clk=~clk;
end
/*
initial
begin
wr_en=1'b1; wdata=16'd0;
#30;wdata=16'd1;load_done=1'b0;
#10;wdata=16'd2;
#10;wdata=16'd3;
#10;wdata=16'd4;
#10;wdata=16'd5;load_done=1'b1;
#10;wdata=16'd6;load_done=1'b0;
#10;wdata=16'd7;
#10;wdata=16'd8;
#10;wdata=16'd9;
#10;wdata=16'd10;
#10;wdata=16'd11;load_done=1'b1;
#10;wdata=16'd12;load_done=1'b0;
#10;wdata=16'd13;
#10;wdata=16'd14;rd_en= 1'b1;
#10;wdata=16'd15;
#10;wdata=16'd16;
#10;wdata=16'd17;load_done=1'b1;
#10;wdata=16'd18;load_done=1'b0;
#10;wdata=16'd19; 
#10;wdata=16'd20;
#10;wdata=16'd21;swap_req=1'b1;
#10;wdata=16'd22;
#10;wdata=16'd23;load_done=1'b1;
#10;load_done=1'b0;
#1000; $finish;
end */

initial
begin
wr_en=1'b1; wdata=16'd0;load_done=1'b0;
#10;  wdata=16'd1;load_done=1'b0;

forever
begin
#50;load_done='b1;
#10;load_done=1'b0;
end
end

always
begin
#10; wdata=wdata+1'b1;
end 

initial
begin
swap_req = 1'b0;
#200;swap_req=1'b1; rd_en=1'b1;
end

initial
begin
#1000;$finish;
end

endmodule
