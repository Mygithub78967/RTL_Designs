
// MIPS32 pipelined processor design with limited RISC V instruction set 

module MIPS32 (clk_1,clk_2,rst);
  input logic clk_1,clk_2,rst;
  
  logic halted, branched, cond;// Flops, halted=1 when HLT executes, branched=1 when branch happens, cond=1/0 when branch fails BNEQZ/BEQZ
  
  logic [31:0] Reg [31:0]; // Reg bank
  logic [31:0] I_Mem [511:0];// Instruction Memory
  logic [31:0] D_Mem [511:0];// Data Memory
  
  //General Purpose Registers
  logic [31:0] IR_1,PC,NPC_1,Imm,A,B_1,ALUOUT_1,LMD; // general purpose registers
  logic [31:0] IR_2,NPC_2,B_2,ALUOUT_2,ALUOUT_3;
  logic [31:0] IR_3,IR_4;
  
  logic [2:0] inst_type_1,inst_type_2,inst_type_3; // instruction type regs
  
  //parameters for selecting ALU Operations
  parameter ADD   = 6'b0;
  parameter SUB   = 6'd1;
  parameter AND   = 6'd2;
  parameter OR    = 6'd3;
  parameter SLT   = 6'd4;
  parameter MUL   = 6'd5;
  parameter HLT   = 6'd63;
  parameter LW    = 6'd8;
  parameter SW    = 6'd9;
  parameter ADDI  = 6'hA;
  parameter SUBI  = 6'hB;
  parameter SLTI  = 6'hC;
  parameter BNEQZ = 6'hD;
  parameter BEQZ  = 6'hE;
  
  
  //parameters for selecting instruction type
  parameter RR     = 3'b0;
  parameter RM     = 3'd1;
  parameter LOAD   = 3'd2;
  parameter STORE  = 3'd3;
  parameter BRANCH = 3'd4;
  parameter HALT   = 3'd5;
  
  //Instruction Fetch Stage
  
  always @(posedge clk_1 or negedge rst) begin
    if (!rst) begin
      NPC_1 <= '0;
      IR_1  <= '0;
      PC    <= '0;
      branched <= '0;
    end
    else if (halted == '0) begin
      if ((IR_3[31:26] == BEQZ && cond == 1'b1) || 
          (IR_3[31:26] == BNEQZ && cond == 1'b0)) begin // when branching
        NPC_1    <= ALUOUT_1 + 32'd1;
        PC       <= ALUOUT_1 + 32'd1;
        IR_1     <= I_Mem[ALUOUT_1]; //Instruction fetched into IR from instruction mem, stored from 0 upon reset
        branched <= 1'b1;
      end
      else begin // without branch PC increments by 1 to point to next instruction
        NPC_1 <= PC + 32'd1;
        PC    <= PC + 32'd1;
        IR_1  <= I_Mem[PC];
        branched    <= '0;
      end
    end
  end
  
  //Instruction Decode Stage
  always @(posedge clk_2 or negedge rst) begin
    if (!rst) begin
      A           <= '0;
      B_1         <= '0;
      Imm         <= '0;
      NPC_2       <= '0;
      IR_2        <= '0;
      inst_type_1 <= '0;
    end
    else if (halted == '0) begin // HLT not executed yet
      A     <= (IR_1[25:21] == '0) ? '0 : Reg[IR_1[25:21]]; // RS1 stored in reg A
      B_1   <= (IR_1[20:16] == '0) ? '0 : Reg[IR_1[20:16]]; // RS2 stored in reg B
      Imm   <= {{16{IR_1[15]}},{IR_1[15:0]}}; // Immediate data stored in reg Imm 
      NPC_2 <= NPC_1;
      IR_2  <= IR_1;
      
      case (IR_1[31:26]) // Opcode checked to determine instruction type
        ADD,SUB,AND,OR,MUL,SLT : inst_type_1 <= RR;
        ADDI,SUBI,SLTI         : inst_type_1 <= RM;
        BEQZ,BNEQZ             : inst_type_1 <= BRANCH;
        LW                     : inst_type_1 <= LOAD;
        SW                     : inst_type_1 <= STORE;
        HLT                    : inst_type_1 <= HALT;
      endcase
    end
  end
  
  // Instruction E Stage 
  always @(posedge clk_1 or negedge rst) begin
    if (!rst) begin
      ALUOUT_1         <= '0;
      cond             <= '0;
      B_2              <= '0;
      IR_3             <= '0;
      inst_type_2      <= '0;   
    end
    else if (halted == '0) begin // HLT not executed yet
      IR_3        <= IR_2;
      inst_type_2 <= inst_type_1;
      
      case (inst_type_1) // Check instruction type to define ALU operation
        RR         : begin // Register type instruction 
          case(IR_2[31:26])
            ADD : ALUOUT_1 <= A + B_1;
            SUB : ALUOUT_1 <= A - B_1;
            AND : ALUOUT_1 <= A && B_1;
            OR  : ALUOUT_1 <= A || B_1;
            MUL : ALUOUT_1 <= A * B_1;
            SLT : ALUOUT_1 <= A < B_1;
          endcase
        end
        
        RM         : begin // Immediate data type instruction 
          case(IR_2[31:26])
            ADDI : ALUOUT_1 <= A + Imm;
            SUBI : ALUOUT_1 <= A - Imm;
            SLTI : ALUOUT_1 <= A < Imm;
          endcase
        end
        
        LOAD,STORE : begin // Memory type instruction 
          ALUOUT_1 <= A + Imm;
          B_2      <= B_1;
        end
        
        BRANCH     : begin // Branch type instruction 
          ALUOUT_1 <= NPC_2 + Imm;
          cond   <= (ALUOUT_3 == '0) ? 1'b1 : '0;
        end
               
      endcase
    end
  end
    
  //MEM Stage (Storing/Retreiving result to/from Data memory)
  always @(posedge clk_2 or negedge rst) begin
      if (!rst) begin
        inst_type_3 <= '0;
        IR_4        <= '0;
        ALUOUT_2    <= '0;
        LMD         <= '0;
      end
      else if (halted == '0) begin
        inst_type_3 <= inst_type_2;
        IR_4        <= IR_3;
        
        case (inst_type_2)
          RR,RM  : ALUOUT_2 <= ALUOUT_1;
          LOAD   : LMD      <= D_Mem[ALUOUT_1];
          STORE  : if (branched == '0) D_Mem[ALUOUT_1] <= B_2;
        endcase
      end
    end
    
    
  //Write Back Stage (Writing results back to the Destination Reg of Reg file)
    
   always @(posedge clk_1 or negedge rst) begin
     if (!rst) begin
       halted           <= '0;
     end
     else if (branched == '0) begin
        case (inst_type_3)
          RR     : Reg[IR_4[15:11]] <= ALUOUT_2;
          RM     : Reg[IR_4[20:16]] <= ALUOUT_2;
          LOAD   : Reg[IR_4[20:16]] <= LMD;
          HALT    : halted <= 1'b1;
        endcase
      end
    end
  
  // flop to set/reset cond flag after barnch decision
   always @(posedge clk_1 or negedge rst) begin
     if (!rst) begin
       ALUOUT_3        <= '0;
     end
     else begin
       ALUOUT_3        <= ALUOUT_2;
     end
   end
    
endmodule
