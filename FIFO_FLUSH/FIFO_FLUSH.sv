// Design a fifo which has different data widths on the read and the write interface. 
// The write interface can send 4-bits per cycle whereas the read interface expects 32-bits per cycle.
// Along with the asymmetrical data widths the fifo should also support the ability for the read interface to issue a flush request. 
// This is needed whenever the write interface doesn't have the complete 32-bits of data but the read interface wants to read from fifo and thus can issue a flush.
// During a flush request the fifo should send all of the data written prior and on the cycle the flush request was seen. 
// Once all of the data is read the flush can be marked as completed. 
// Fifo should support the ability to write new data while the flush request is being serviced. 
// The fifo must be sized such that it is able to store 128-bits of data exactly.

// Interface Definition
// The interface to the fifo consists of the following ports:

// fifo_wr_valid_i -> Input to the module which signals that write data is valid
// fifo_wr_data_i -> The 4-bit write data input
// fifo_data_avail_o -> Output flag which tells that a read can be issued
// fifo_rd_valid_i -> Input to the module which signals 32-bit data is read
// fifo_rd_data_o -> 32-bit read data associated given as output
// fifo_flush_i -> Fifo flush input to the module
// fifo_flush_done_o -> Output signal which marks the flush as complete
// fifo_empty_o -> Fifo empty flag (fifo has no valid data)
// fifo_full_o -> Fifo full flag

// Interface Requirements
// The interface guarantees that the write request will never be seen whenever fifo has 128-bits of data
// The interface guarantees that the fifo_rd_valid_i will only be asserted if the fifo_data_avail_o signal is high.
// The fifo_rd_data_o should be sent on the same cycle as when the fifo_rd_valid_i is seen
// The interface guarantees that the flush request would only be asserted if the fifo isn’t empty
// The fifo_flush_i signal would remain asserted until the fifo_flush_done_o output is seen
// In case fifo has partial data (data less than 32-bits) during a flush request, 
// the specifications allow the fifo data to be padded with 0x0 to form the complete 32-bits worth of data
// The data written on the same cycle as when the flush request was asserted should also be flushed before the fifo_flush_done_o signal is asserted. 
// This implies that the flush data should only consist of the data already stored in the fifo and the data written (if any) on the same cycle as the flush request was asserted.
// The fifo should allow any new data to be written into the fifo while the flush is being serviced. 
// The new data written one cycle after the flush request should not be given out as part of the flush request
// All the flops (if any) should be positive edge triggered with asynchronous resets


module FIFO_FLUSH (vld_rd_data,flush_done,rd_data,full,empty,rd,wr,wr_data,flush_req,clk,rst);
  parameter depth = 32;
  parameter rd_width = 32;
  parameter wr_width = 4;
  parameter addr  = $clog2(depth);
  
  output logic full,empty,flush_done,vld_rd_data;
  input logic clk,rst,rd,wr,flush_req;
  input logic [wr_width-1:0] wr_data; 
  output logic [rd_width-1:0] rd_data; 
  
  logic [rd_width-1:0] rd_data_nxt,rd_data_ff;
  logic [addr:0] rd_ptr, wr_ptr, diff;
  logic [wr_width-1:0] FIFO [depth-1:0];
    
  always_ff @(posedge clk or negedge rst) begin
    if (!rst) begin
      for (int i=0;i<depth;i++) FIFO[i] <= '0;
    end
    else if (wr && !full) begin
      FIFO[wr_ptr[addr-1:0]] <= wr_data;//write, curving out wrap bit
    end
  end
  
  always @(posedge clk or negedge rst) begin
    if (!rst) wr_ptr <= '0;
    else if (wr && !full) begin
      wr_ptr <= wr_ptr + 6'd1;
    end
  end   
  
  assign diff = wr_ptr - rd_ptr;
  assign vld_rd_data = (diff >= 6'd8) ? '1 : '0; // when 32bit data is available
  assign rd_data =  rd_data_ff;//read
  
  always @(posedge clk or negedge rst) begin
    if (!rst) rd_data_ff <= '0;
    else begin
      rd_data_ff <= rd_data_nxt; // read data flop
    end
  end 
  
  always_comb begin
    rd_data_nxt = '0;
    for (int i=0; i<8 ;i++) begin
      if ((rd || flush_req) && !empty) begin
        if (vld_rd_data) rd_data_nxt[(i*4)+:4] = FIFO [rd_ptr[addr-1:0]+i]; //curving out wrap bit
        else if (!vld_rd_data && i<diff) rd_data_nxt[(i*4)+:4] = FIFO [i]; // when less than 32bits is in FIFO, but flush req comes in
        else if (!vld_rd_data && wr && i==diff) rd_data_nxt[(i*4)+:4] = wr_data; // to ensure data out = data in at same cycle
        else rd_data_nxt[(i*4)+:4] = '0;
      end
    end
  end
  
  always @(posedge clk or negedge rst) begin
    if (!rst) rd_ptr <= '0;
    else if ((rd || flush_req) && !empty) begin
      rd_ptr <= (vld_rd_data) ? rd_ptr + 6'd8 : (wr) ? rd_ptr + diff + 6'd1 : rd_ptr + diff;  // increments rd ptr as per data read
    end
  end 
  
  assign full = ({!wr_ptr[addr], wr_ptr[addr-1:0]} == rd_ptr) ? '1 :'0;
     
  always_comb begin
    empty = '0;
    if (wr_ptr == rd_ptr) begin
      empty = '1;
    end
  end 
  
  always_comb begin
    flush_done = '0;
    if (flush_req && empty) begin
      flush_done = '1;
    end
  end 
  
endmodule
