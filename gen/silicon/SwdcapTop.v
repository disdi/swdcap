// Generator : SpinalHDL dev    git head : 90b7d8eeed46e20e102df498516ebe845c9e4a6e
// Component : SwdcapTop
// Git hash  : 266063c1c68604cc9f263b59ed845a495f33f63a

`timescale 1ns/1ps

module SwdcapTop (
  input  wire          swclk,
  input  wire          swdio_i,
  output wire          swdio_o,
  output wire          swdio_oe,
  input  wire [7:0]    eio_in,
  output wire [7:0]    eio_out,
  input  wire          reset,
  input  wire          clk
);

  wire                decoder_id_io_bus_sel;
  wire                decoder_eio_io_bus_sel;
  wire                core_io_swdio_write;
  wire                core_io_swdio_writeEnable;
  wire                core_io_ap_cmd_valid;
  wire                core_io_ap_cmd_payload_rnw;
  wire       [1:0]    core_io_ap_cmd_payload_addr;
  wire       [7:0]    core_io_ap_cmd_payload_apSel;
  wire       [31:0]   core_io_ap_cmd_payload_wdata;
  wire                gateway_swdLogic_dmiCmd_ccToggle_io_output_valid;
  wire                gateway_swdLogic_dmiCmd_ccToggle_io_output_payload_write;
  wire       [31:0]   gateway_swdLogic_dmiCmd_ccToggle_io_output_payload_data;
  wire       [9:0]    gateway_swdLogic_dmiCmd_ccToggle_io_output_payload_address;
  wire                gateway_systemLogic_bus_rsp_ccToggle_io_output_valid;
  wire                gateway_systemLogic_bus_rsp_ccToggle_io_output_payload_error;
  wire       [31:0]   gateway_systemLogic_bus_rsp_ccToggle_io_output_payload_data;
  wire       [31:0]   decoder_id_io_bus_rdata;
  wire                decoder_id_io_bus_error;
  wire       [31:0]   decoder_eio_io_bus_rdata;
  wire                decoder_eio_io_bus_error;
  wire       [7:0]    decoder_eio_io_eio_out;
  wire                gateway_swdLogic_apCmd_valid;
  wire                gateway_swdLogic_apCmd_payload_rnw;
  wire       [1:0]    gateway_swdLogic_apCmd_payload_addr;
  wire       [7:0]    gateway_swdLogic_apCmd_payload_apSel;
  wire       [31:0]   gateway_swdLogic_apCmd_payload_wdata;
  wire                gateway_swdLogic_apRsp_valid;
  wire                gateway_swdLogic_apRsp_payload_error;
  wire       [31:0]   gateway_swdLogic_apRsp_payload_data;
  reg        [9:0]    gateway_swdLogic_dmiAddr;
  reg        [31:0]   gateway_swdLogic_lastRead;
  wire                gateway_swdLogic_dmiCmd_valid;
  wire                gateway_swdLogic_dmiCmd_payload_write;
  wire       [31:0]   gateway_swdLogic_dmiCmd_payload_data;
  wire       [9:0]    gateway_swdLogic_dmiCmd_payload_address;
  wire                gateway_swdLogic_dmiRsp_valid;
  wire                gateway_swdLogic_dmiRsp_payload_error;
  wire       [31:0]   gateway_swdLogic_dmiRsp_payload_data;
  wire                gateway_swdLogic_isDmiData;
  wire                gateway_swdLogic_localHit;
  reg                 gateway_swdLogic_local_valid;
  reg        [31:0]   gateway_swdLogic_local_data;
  reg                 gateway_swdLogic_dmiWasRead;
  reg                 gateway_swdLogic_dmiPending;
  wire                gateway_swdLogic_dmiRspHit;
  wire                when_DebugTransportModuleSwd_l70;
  wire                gateway_systemLogic_bus_cmd_valid;
  wire                gateway_systemLogic_bus_cmd_ready;
  wire                gateway_systemLogic_bus_cmd_payload_write;
  wire       [31:0]   gateway_systemLogic_bus_cmd_payload_data;
  wire       [9:0]    gateway_systemLogic_bus_cmd_payload_address;
  wire                gateway_systemLogic_bus_rsp_valid;
  wire                gateway_systemLogic_bus_rsp_payload_error;
  wire       [31:0]   gateway_systemLogic_bus_rsp_payload_data;
  wire                io_output_toStream_valid;
  reg                 io_output_toStream_ready;
  wire                io_output_toStream_payload_write;
  wire       [31:0]   io_output_toStream_payload_data;
  wire       [9:0]    io_output_toStream_payload_address;
  wire                gateway_systemLogic_cmd_valid;
  wire                gateway_systemLogic_cmd_ready;
  wire                gateway_systemLogic_cmd_payload_write;
  wire       [31:0]   gateway_systemLogic_cmd_payload_data;
  wire       [9:0]    gateway_systemLogic_cmd_payload_address;
  reg                 io_output_toStream_rValid;
  wire                io_output_toStream_fire;
  (* async_reg = "true" , altera_attribute = "-name ADV_NETLIST_OPT_ALLOWED NEVER_ALLOW" *) reg                 io_output_toStream_rData_write;
  (* async_reg = "true" , altera_attribute = "-name ADV_NETLIST_OPT_ALLOWED NEVER_ALLOW" *) reg        [31:0]   io_output_toStream_rData_data;
  (* async_reg = "true" , altera_attribute = "-name ADV_NETLIST_OPT_ALLOWED NEVER_ALLOW" *) reg        [9:0]    io_output_toStream_rData_address;
  wire                when_Stream_l477;
  wire       [1:0]    decoder_window;
  wire       [7:0]    decoder_offset;
  wire                decoder_rsp_valid;
  reg                 decoder_rsp_payload_error;
  reg        [31:0]   decoder_rsp_payload_data;
  wire                gateway_systemLogic_bus_cmd_fire;
  wire                when_SwdcapTop_l77;
  wire                when_SwdcapTop_l86;
  wire                when_SwdcapTop_l99;
  reg                 decoder_rsp_stage_valid;
  reg                 decoder_rsp_stage_payload_error;
  reg        [31:0]   decoder_rsp_stage_payload_data;

  SwdPhyDp core (
    .io_swdio_read           (swdio_i                                  ), //i
    .io_swdio_write          (core_io_swdio_write                      ), //o
    .io_swdio_writeEnable    (core_io_swdio_writeEnable                ), //o
    .io_ap_cmd_valid         (core_io_ap_cmd_valid                     ), //o
    .io_ap_cmd_payload_rnw   (core_io_ap_cmd_payload_rnw               ), //o
    .io_ap_cmd_payload_addr  (core_io_ap_cmd_payload_addr[1:0]         ), //o
    .io_ap_cmd_payload_apSel (core_io_ap_cmd_payload_apSel[7:0]        ), //o
    .io_ap_cmd_payload_wdata (core_io_ap_cmd_payload_wdata[31:0]       ), //o
    .io_ap_rsp_valid         (gateway_swdLogic_apRsp_valid             ), //i
    .io_ap_rsp_payload_error (gateway_swdLogic_apRsp_payload_error     ), //i
    .io_ap_rsp_payload_data  (gateway_swdLogic_apRsp_payload_data[31:0]), //i
    .swclk                   (swclk                                    ), //i
    .reset                   (reset                                    )  //i
  );
  FlowCCByToggle gateway_swdLogic_dmiCmd_ccToggle (
    .io_input_valid            (gateway_swdLogic_dmiCmd_valid                                  ), //i
    .io_input_payload_write    (gateway_swdLogic_dmiCmd_payload_write                          ), //i
    .io_input_payload_data     (gateway_swdLogic_dmiCmd_payload_data[31:0]                     ), //i
    .io_input_payload_address  (gateway_swdLogic_dmiCmd_payload_address[9:0]                   ), //i
    .io_output_valid           (gateway_swdLogic_dmiCmd_ccToggle_io_output_valid               ), //o
    .io_output_payload_write   (gateway_swdLogic_dmiCmd_ccToggle_io_output_payload_write       ), //o
    .io_output_payload_data    (gateway_swdLogic_dmiCmd_ccToggle_io_output_payload_data[31:0]  ), //o
    .io_output_payload_address (gateway_swdLogic_dmiCmd_ccToggle_io_output_payload_address[9:0]), //o
    .swclk                     (swclk                                                          ), //i
    .reset                     (reset                                                          ), //i
    .clk                       (clk                                                            )  //i
  );
  FlowCCByToggle_1 gateway_systemLogic_bus_rsp_ccToggle (
    .io_input_valid          (gateway_systemLogic_bus_rsp_valid                                ), //i
    .io_input_payload_error  (gateway_systemLogic_bus_rsp_payload_error                        ), //i
    .io_input_payload_data   (gateway_systemLogic_bus_rsp_payload_data[31:0]                   ), //i
    .io_output_valid         (gateway_systemLogic_bus_rsp_ccToggle_io_output_valid             ), //o
    .io_output_payload_error (gateway_systemLogic_bus_rsp_ccToggle_io_output_payload_error     ), //o
    .io_output_payload_data  (gateway_systemLogic_bus_rsp_ccToggle_io_output_payload_data[31:0]), //o
    .clk                     (clk                                                              ), //i
    .reset                   (reset                                                            ), //i
    .swclk                   (swclk                                                            ), //i
    .reset_1                 (reset                                                            )  //i
  );
  IdWindow decoder_id (
    .io_bus_sel    (decoder_id_io_bus_sel                         ), //i
    .io_bus_write  (gateway_systemLogic_bus_cmd_payload_write     ), //i
    .io_bus_offset (decoder_offset[7:0]                           ), //i
    .io_bus_wdata  (gateway_systemLogic_bus_cmd_payload_data[31:0]), //i
    .io_bus_rdata  (decoder_id_io_bus_rdata[31:0]                 ), //o
    .io_bus_error  (decoder_id_io_bus_error                       ), //o
    .clk           (clk                                           ), //i
    .reset         (reset                                         )  //i
  );
  Eio decoder_eio (
    .io_bus_sel    (decoder_eio_io_bus_sel                        ), //i
    .io_bus_write  (gateway_systemLogic_bus_cmd_payload_write     ), //i
    .io_bus_offset (decoder_offset[7:0]                           ), //i
    .io_bus_wdata  (gateway_systemLogic_bus_cmd_payload_data[31:0]), //i
    .io_bus_rdata  (decoder_eio_io_bus_rdata[31:0]                ), //o
    .io_bus_error  (decoder_eio_io_bus_error                      ), //o
    .io_eio_in     (eio_in[7:0]                                   ), //i
    .io_eio_out    (decoder_eio_io_eio_out[7:0]                   ), //o
    .clk           (clk                                           ), //i
    .reset         (reset                                         )  //i
  );
  assign swdio_o = core_io_swdio_write;
  assign swdio_oe = core_io_swdio_writeEnable;
  assign gateway_swdLogic_isDmiData = (gateway_swdLogic_apCmd_payload_addr == 2'b10);
  assign gateway_swdLogic_localHit = (gateway_swdLogic_apCmd_valid && (! gateway_swdLogic_isDmiData));
  assign gateway_swdLogic_dmiCmd_valid = (gateway_swdLogic_apCmd_valid && gateway_swdLogic_isDmiData);
  assign gateway_swdLogic_dmiCmd_payload_write = (! gateway_swdLogic_apCmd_payload_rnw);
  assign gateway_swdLogic_dmiCmd_payload_address = gateway_swdLogic_dmiAddr;
  assign gateway_swdLogic_dmiCmd_payload_data = gateway_swdLogic_apCmd_payload_wdata;
  assign gateway_swdLogic_dmiRspHit = (gateway_swdLogic_dmiRsp_valid && gateway_swdLogic_dmiPending);
  assign when_DebugTransportModuleSwd_l70 = (gateway_swdLogic_dmiWasRead && (! gateway_swdLogic_dmiRsp_payload_error));
  assign gateway_swdLogic_apRsp_valid = (gateway_swdLogic_local_valid || gateway_swdLogic_dmiRspHit);
  assign gateway_swdLogic_apRsp_payload_error = (gateway_swdLogic_dmiRspHit && gateway_swdLogic_dmiRsp_payload_error);
  assign gateway_swdLogic_apRsp_payload_data = (gateway_swdLogic_local_valid ? gateway_swdLogic_local_data : gateway_swdLogic_dmiRsp_payload_data);
  assign io_output_toStream_valid = gateway_swdLogic_dmiCmd_ccToggle_io_output_valid;
  assign io_output_toStream_payload_write = gateway_swdLogic_dmiCmd_ccToggle_io_output_payload_write;
  assign io_output_toStream_payload_data = gateway_swdLogic_dmiCmd_ccToggle_io_output_payload_data;
  assign io_output_toStream_payload_address = gateway_swdLogic_dmiCmd_ccToggle_io_output_payload_address;
  assign io_output_toStream_fire = (io_output_toStream_valid && io_output_toStream_ready);
  always @(*) begin
    io_output_toStream_ready = gateway_systemLogic_cmd_ready;
    if(when_Stream_l477) begin
      io_output_toStream_ready = 1'b1;
    end
  end

  assign when_Stream_l477 = (! gateway_systemLogic_cmd_valid);
  assign gateway_systemLogic_cmd_valid = io_output_toStream_rValid;
  assign gateway_systemLogic_cmd_payload_write = io_output_toStream_rData_write;
  assign gateway_systemLogic_cmd_payload_data = io_output_toStream_rData_data;
  assign gateway_systemLogic_cmd_payload_address = io_output_toStream_rData_address;
  assign gateway_systemLogic_bus_cmd_valid = gateway_systemLogic_cmd_valid;
  assign gateway_systemLogic_cmd_ready = gateway_systemLogic_bus_cmd_ready;
  assign gateway_systemLogic_bus_cmd_payload_write = gateway_systemLogic_cmd_payload_write;
  assign gateway_systemLogic_bus_cmd_payload_data = gateway_systemLogic_cmd_payload_data;
  assign gateway_systemLogic_bus_cmd_payload_address = gateway_systemLogic_cmd_payload_address;
  assign gateway_swdLogic_dmiRsp_valid = gateway_systemLogic_bus_rsp_ccToggle_io_output_valid;
  assign gateway_swdLogic_dmiRsp_payload_error = gateway_systemLogic_bus_rsp_ccToggle_io_output_payload_error;
  assign gateway_swdLogic_dmiRsp_payload_data = gateway_systemLogic_bus_rsp_ccToggle_io_output_payload_data;
  assign gateway_swdLogic_apCmd_valid = core_io_ap_cmd_valid;
  assign gateway_swdLogic_apCmd_payload_rnw = core_io_ap_cmd_payload_rnw;
  assign gateway_swdLogic_apCmd_payload_addr = core_io_ap_cmd_payload_addr;
  assign gateway_swdLogic_apCmd_payload_apSel = core_io_ap_cmd_payload_apSel;
  assign gateway_swdLogic_apCmd_payload_wdata = core_io_ap_cmd_payload_wdata;
  assign gateway_systemLogic_bus_cmd_ready = 1'b1;
  assign decoder_window = gateway_systemLogic_bus_cmd_payload_address[9 : 8];
  assign decoder_offset = gateway_systemLogic_bus_cmd_payload_address[7 : 0];
  assign gateway_systemLogic_bus_cmd_fire = (gateway_systemLogic_bus_cmd_valid && gateway_systemLogic_bus_cmd_ready);
  assign decoder_rsp_valid = gateway_systemLogic_bus_cmd_fire;
  always @(*) begin
    decoder_rsp_payload_error = 1'b1;
    if(when_SwdcapTop_l77) begin
      decoder_rsp_payload_error = 1'b0;
    end
    if(when_SwdcapTop_l86) begin
      decoder_rsp_payload_error = decoder_id_io_bus_error;
    end
    if(when_SwdcapTop_l99) begin
      decoder_rsp_payload_error = decoder_eio_io_bus_error;
    end
  end

  always @(*) begin
    decoder_rsp_payload_data = 32'h0;
    if(when_SwdcapTop_l86) begin
      decoder_rsp_payload_data = decoder_id_io_bus_rdata;
    end
    if(when_SwdcapTop_l99) begin
      decoder_rsp_payload_data = decoder_eio_io_bus_rdata;
    end
  end

  assign when_SwdcapTop_l77 = ((decoder_window == 2'b00) && (decoder_offset <= 8'h7f));
  assign decoder_id_io_bus_sel = (gateway_systemLogic_bus_cmd_fire && (decoder_window == 2'b01));
  assign when_SwdcapTop_l86 = (decoder_window == 2'b01);
  assign decoder_eio_io_bus_sel = (gateway_systemLogic_bus_cmd_fire && (decoder_window == 2'b10));
  assign eio_out = decoder_eio_io_eio_out;
  assign when_SwdcapTop_l99 = (decoder_window == 2'b10);
  assign gateway_systemLogic_bus_rsp_valid = decoder_rsp_stage_valid;
  assign gateway_systemLogic_bus_rsp_payload_error = decoder_rsp_stage_payload_error;
  assign gateway_systemLogic_bus_rsp_payload_data = decoder_rsp_stage_payload_data;
  always @(posedge swclk or posedge reset) begin
    if(reset) begin
      gateway_swdLogic_dmiAddr <= 10'h0;
      gateway_swdLogic_lastRead <= 32'h0;
      gateway_swdLogic_local_valid <= 1'b0;
      gateway_swdLogic_dmiPending <= 1'b0;
    end else begin
      gateway_swdLogic_local_valid <= gateway_swdLogic_localHit;
      if(gateway_swdLogic_localHit) begin
        case(gateway_swdLogic_apCmd_payload_addr)
          2'b01 : begin
            if(!gateway_swdLogic_apCmd_payload_rnw) begin
              gateway_swdLogic_dmiAddr <= gateway_swdLogic_apCmd_payload_wdata[9 : 0];
            end
          end
          default : begin
          end
        endcase
      end
      if(gateway_swdLogic_dmiCmd_valid) begin
        gateway_swdLogic_dmiPending <= 1'b1;
      end
      if(gateway_swdLogic_dmiRspHit) begin
        gateway_swdLogic_dmiPending <= 1'b0;
        if(when_DebugTransportModuleSwd_l70) begin
          gateway_swdLogic_lastRead <= gateway_swdLogic_dmiRsp_payload_data;
        end
      end
    end
  end

  always @(posedge swclk) begin
    if(gateway_swdLogic_localHit) begin
      gateway_swdLogic_local_data <= 32'h0;
      case(gateway_swdLogic_apCmd_payload_addr)
        2'b00 : begin
          gateway_swdLogic_local_data <= 32'h74726976;
        end
        2'b01 : begin
          if(gateway_swdLogic_apCmd_payload_rnw) begin
            gateway_swdLogic_local_data <= {22'h0,gateway_swdLogic_dmiAddr};
          end
        end
        2'b11 : begin
          gateway_swdLogic_local_data <= gateway_swdLogic_lastRead;
        end
        default : begin
        end
      endcase
    end
    if(gateway_swdLogic_dmiCmd_valid) begin
      gateway_swdLogic_dmiWasRead <= gateway_swdLogic_apCmd_payload_rnw;
    end
  end

  always @(posedge clk or posedge reset) begin
    if(reset) begin
      io_output_toStream_rValid <= 1'b0;
      decoder_rsp_stage_valid <= 1'b0;
    end else begin
      if(io_output_toStream_ready) begin
        io_output_toStream_rValid <= io_output_toStream_valid;
      end
      decoder_rsp_stage_valid <= decoder_rsp_valid;
    end
  end

  always @(posedge clk) begin
    if(io_output_toStream_fire) begin
      io_output_toStream_rData_write <= io_output_toStream_payload_write;
      io_output_toStream_rData_data <= io_output_toStream_payload_data;
      io_output_toStream_rData_address <= io_output_toStream_payload_address;
    end
    decoder_rsp_stage_payload_error <= decoder_rsp_payload_error;
    decoder_rsp_stage_payload_data <= decoder_rsp_payload_data;
  end


endmodule

module Eio (
  input  wire          io_bus_sel,
  input  wire          io_bus_write,
  input  wire [7:0]    io_bus_offset,
  input  wire [31:0]   io_bus_wdata,
  output reg  [31:0]   io_bus_rdata,
  output reg           io_bus_error,
  input  wire [7:0]    io_eio_in,
  output wire [7:0]    io_eio_out,
  input  wire          clk,
  input  wire          reset
);

  wire       [7:0]    io_eio_in_buffercc_io_dataOut;
  wire       [7:0]    inSync;
  reg        [7:0]    outReg;
  wire                when_Eio_l31;

  (* keep_hierarchy = "TRUE" *) BufferCC_3 io_eio_in_buffercc (
    .io_dataIn  (io_eio_in[7:0]                    ), //i
    .io_dataOut (io_eio_in_buffercc_io_dataOut[7:0]), //o
    .clk        (clk                               ), //i
    .reset      (reset                             )  //i
  );
  assign inSync = io_eio_in_buffercc_io_dataOut;
  assign io_eio_out = outReg;
  always @(*) begin
    io_bus_rdata = 32'h0;
    case(io_bus_offset)
      8'h0 : begin
        io_bus_rdata = {24'd0, inSync};
      end
      8'h01 : begin
        io_bus_rdata = {24'd0, outReg};
      end
      default : begin
      end
    endcase
  end

  always @(*) begin
    io_bus_error = 1'b0;
    case(io_bus_offset)
      8'h0 : begin
      end
      8'h01 : begin
      end
      default : begin
        io_bus_error = 1'b1;
      end
    endcase
  end

  assign when_Eio_l31 = (io_bus_sel && io_bus_write);
  always @(posedge clk or posedge reset) begin
    if(reset) begin
      outReg <= 8'h0;
    end else begin
      case(io_bus_offset)
        8'h0 : begin
        end
        8'h01 : begin
          if(when_Eio_l31) begin
            outReg <= io_bus_wdata[7:0];
          end
        end
        default : begin
        end
      endcase
    end
  end


endmodule

module IdWindow (
  input  wire          io_bus_sel,
  input  wire          io_bus_write,
  input  wire [7:0]    io_bus_offset,
  input  wire [31:0]   io_bus_wdata,
  output reg  [31:0]   io_bus_rdata,
  output reg           io_bus_error,
  input  wire          clk,
  input  wire          reset
);

  reg        [31:0]   scratch;
  wire                when_IdWindow_l28;

  always @(*) begin
    io_bus_rdata = 32'h0;
    case(io_bus_offset)
      8'h0 : begin
        io_bus_rdata = 32'h43445753;
      end
      8'h01 : begin
        io_bus_rdata = 32'h00000100;
      end
      8'h02 : begin
        io_bus_rdata = 32'h00000001;
      end
      8'h03 : begin
        io_bus_rdata = 32'h0;
      end
      8'h04 : begin
        io_bus_rdata = 32'h00000808;
      end
      8'h05 : begin
        io_bus_rdata = 32'h0;
      end
      8'h06 : begin
        io_bus_rdata = 32'h0;
      end
      8'h07 : begin
        io_bus_rdata = scratch;
      end
      default : begin
      end
    endcase
  end

  always @(*) begin
    io_bus_error = 1'b0;
    case(io_bus_offset)
      8'h0 : begin
      end
      8'h01 : begin
      end
      8'h02 : begin
      end
      8'h03 : begin
      end
      8'h04 : begin
      end
      8'h05 : begin
      end
      8'h06 : begin
      end
      8'h07 : begin
      end
      default : begin
        io_bus_error = 1'b1;
      end
    endcase
  end

  assign when_IdWindow_l28 = (io_bus_sel && io_bus_write);
  always @(posedge clk or posedge reset) begin
    if(reset) begin
      scratch <= 32'h0;
    end else begin
      case(io_bus_offset)
        8'h0 : begin
        end
        8'h01 : begin
        end
        8'h02 : begin
        end
        8'h03 : begin
        end
        8'h04 : begin
        end
        8'h05 : begin
        end
        8'h06 : begin
        end
        8'h07 : begin
          if(when_IdWindow_l28) begin
            scratch <= io_bus_wdata;
          end
        end
        default : begin
        end
      endcase
    end
  end


endmodule

module FlowCCByToggle_1 (
  input  wire          io_input_valid,
  input  wire          io_input_payload_error,
  input  wire [31:0]   io_input_payload_data,
  output wire          io_output_valid,
  output wire          io_output_payload_error,
  output wire [31:0]   io_output_payload_data,
  input  wire          clk,
  input  wire          reset,
  input  wire          swclk,
  input  wire          reset_1
);

  wire                inputArea_target_buffercc_io_dataOut;
  (* altera_attribute = "-name ADV_NETLIST_OPT_ALLOWED NEVER_ALLOW" *) reg                 inputArea_target;
  (* altera_attribute = "-name ADV_NETLIST_OPT_ALLOWED NEVER_ALLOW" *) reg                 inputArea_data_error;
  (* altera_attribute = "-name ADV_NETLIST_OPT_ALLOWED NEVER_ALLOW" *) reg        [31:0]   inputArea_data_data;
  wire                outputArea_target;
  (* altera_attribute = "-name ADV_NETLIST_OPT_ALLOWED NEVER_ALLOW" *) reg                 outputArea_hit;
  wire                outputArea_flow_valid;
  wire                outputArea_flow_payload_error;
  wire       [31:0]   outputArea_flow_payload_data;
  (* altera_attribute = "-name ADV_NETLIST_OPT_ALLOWED NEVER_ALLOW" *) reg                 outputArea_flow_m2sPipe_valid;
  (* async_reg = "true" , altera_attribute = "-name ADV_NETLIST_OPT_ALLOWED NEVER_ALLOW" *) reg                 outputArea_flow_m2sPipe_payload_error;
  (* async_reg = "true" , altera_attribute = "-name ADV_NETLIST_OPT_ALLOWED NEVER_ALLOW" *) reg        [31:0]   outputArea_flow_m2sPipe_payload_data;

  (* keep_hierarchy = "TRUE" *) BufferCC_2 inputArea_target_buffercc (
    .io_dataIn  (inputArea_target                    ), //i
    .io_dataOut (inputArea_target_buffercc_io_dataOut), //o
    .swclk      (swclk                               ), //i
    .reset      (reset_1                             )  //i
  );
  assign outputArea_target = inputArea_target_buffercc_io_dataOut;
  assign outputArea_flow_valid = (outputArea_target != outputArea_hit);
  assign outputArea_flow_payload_error = inputArea_data_error;
  assign outputArea_flow_payload_data = inputArea_data_data;
  assign io_output_valid = outputArea_flow_m2sPipe_valid;
  assign io_output_payload_error = outputArea_flow_m2sPipe_payload_error;
  assign io_output_payload_data = outputArea_flow_m2sPipe_payload_data;
  always @(posedge clk or posedge reset) begin
    if(reset) begin
      inputArea_target <= 1'b0;
    end else begin
      if(io_input_valid) begin
        inputArea_target <= (! inputArea_target);
      end
    end
  end

  always @(posedge clk) begin
    if(io_input_valid) begin
      inputArea_data_error <= io_input_payload_error;
      inputArea_data_data <= io_input_payload_data;
    end
  end

  always @(posedge swclk or posedge reset_1) begin
    if(reset_1) begin
      outputArea_flow_m2sPipe_valid <= 1'b0;
      outputArea_hit <= 1'b0;
    end else begin
      outputArea_hit <= outputArea_target;
      outputArea_flow_m2sPipe_valid <= outputArea_flow_valid;
    end
  end

  always @(posedge swclk) begin
    if(outputArea_flow_valid) begin
      outputArea_flow_m2sPipe_payload_error <= outputArea_flow_payload_error;
      outputArea_flow_m2sPipe_payload_data <= outputArea_flow_payload_data;
    end
  end


endmodule

module FlowCCByToggle (
  input  wire          io_input_valid,
  input  wire          io_input_payload_write,
  input  wire [31:0]   io_input_payload_data,
  input  wire [9:0]    io_input_payload_address,
  output wire          io_output_valid,
  output wire          io_output_payload_write,
  output wire [31:0]   io_output_payload_data,
  output wire [9:0]    io_output_payload_address,
  input  wire          swclk,
  input  wire          reset,
  input  wire          clk
);

  wire                toplevel_reset_asyncAssertSyncDeassert_buffercc_io_dataOut;
  wire                inputArea_target_buffercc_io_dataOut;
  wire                toplevel_reset_asyncAssertSyncDeassert;
  wire                toplevel_reset_synchronized;
  (* altera_attribute = "-name ADV_NETLIST_OPT_ALLOWED NEVER_ALLOW" *) reg                 inputArea_target;
  (* altera_attribute = "-name ADV_NETLIST_OPT_ALLOWED NEVER_ALLOW" *) reg                 inputArea_data_write;
  (* altera_attribute = "-name ADV_NETLIST_OPT_ALLOWED NEVER_ALLOW" *) reg        [31:0]   inputArea_data_data;
  (* altera_attribute = "-name ADV_NETLIST_OPT_ALLOWED NEVER_ALLOW" *) reg        [9:0]    inputArea_data_address;
  wire                outputArea_target;
  reg                 outputArea_hit;
  wire                outputArea_flow_valid;
  wire                outputArea_flow_payload_write;
  wire       [31:0]   outputArea_flow_payload_data;
  wire       [9:0]    outputArea_flow_payload_address;

  (* keep_hierarchy = "TRUE" *) BufferCC toplevel_reset_asyncAssertSyncDeassert_buffercc (
    .io_dataIn  (toplevel_reset_asyncAssertSyncDeassert                    ), //i
    .io_dataOut (toplevel_reset_asyncAssertSyncDeassert_buffercc_io_dataOut), //o
    .clk        (clk                                                       ), //i
    .reset      (reset                                                     )  //i
  );
  (* keep_hierarchy = "TRUE" *) BufferCC_1 inputArea_target_buffercc (
    .io_dataIn                   (inputArea_target                    ), //i
    .io_dataOut                  (inputArea_target_buffercc_io_dataOut), //o
    .clk                         (clk                                 ), //i
    .toplevel_reset_synchronized (toplevel_reset_synchronized         )  //i
  );
  assign toplevel_reset_asyncAssertSyncDeassert = (1'b0 ^ 1'b0);
  assign toplevel_reset_synchronized = toplevel_reset_asyncAssertSyncDeassert_buffercc_io_dataOut;
  assign outputArea_target = inputArea_target_buffercc_io_dataOut;
  assign outputArea_flow_valid = (outputArea_target != outputArea_hit);
  assign outputArea_flow_payload_write = inputArea_data_write;
  assign outputArea_flow_payload_data = inputArea_data_data;
  assign outputArea_flow_payload_address = inputArea_data_address;
  assign io_output_valid = outputArea_flow_valid;
  assign io_output_payload_write = outputArea_flow_payload_write;
  assign io_output_payload_data = outputArea_flow_payload_data;
  assign io_output_payload_address = outputArea_flow_payload_address;
  always @(posedge swclk or posedge reset) begin
    if(reset) begin
      inputArea_target <= 1'b0;
    end else begin
      if(io_input_valid) begin
        inputArea_target <= (! inputArea_target);
      end
    end
  end

  always @(posedge swclk) begin
    if(io_input_valid) begin
      inputArea_data_write <= io_input_payload_write;
      inputArea_data_data <= io_input_payload_data;
      inputArea_data_address <= io_input_payload_address;
    end
  end

  always @(posedge clk or posedge toplevel_reset_synchronized) begin
    if(toplevel_reset_synchronized) begin
      outputArea_hit <= 1'b0;
    end else begin
      outputArea_hit <= outputArea_target;
    end
  end


endmodule

module SwdPhyDp (
  input  wire          io_swdio_read,
  output wire          io_swdio_write,
  output wire          io_swdio_writeEnable,
  output wire          io_ap_cmd_valid,
  output wire          io_ap_cmd_payload_rnw,
  output wire [1:0]    io_ap_cmd_payload_addr,
  output wire [7:0]    io_ap_cmd_payload_apSel,
  output wire [31:0]   io_ap_cmd_payload_wdata,
  input  wire          io_ap_rsp_valid,
  input  wire          io_ap_rsp_payload_error,
  input  wire [31:0]   io_ap_rsp_payload_data,
  input  wire          swclk,
  input  wire          reset
);

  wire                phy_io_swdio_write;
  wire                phy_io_swdio_writeEnable;
  wire                phy_io_dp_cmd_valid;
  wire                phy_io_dp_cmd_payload_apNdp;
  wire                phy_io_dp_cmd_payload_rnw;
  wire       [1:0]    phy_io_dp_cmd_payload_addr;
  wire                phy_io_dp_wr_valid;
  wire       [31:0]   phy_io_dp_wr_payload_data;
  wire                phy_io_dp_wr_payload_parityOk;
  wire                dp_io_dp_rsp_valid;
  wire       [2:0]    dp_io_dp_rsp_payload_ack;
  wire       [31:0]   dp_io_dp_rsp_payload_rdata;
  wire                dp_io_ap_cmd_valid;
  wire                dp_io_ap_cmd_payload_rnw;
  wire       [1:0]    dp_io_ap_cmd_payload_addr;
  wire       [7:0]    dp_io_ap_cmd_payload_apSel;
  wire       [31:0]   dp_io_ap_cmd_payload_wdata;

  SwdPhy phy (
    .io_swdio_read             (io_swdio_read                   ), //i
    .io_swdio_write            (phy_io_swdio_write              ), //o
    .io_swdio_writeEnable      (phy_io_swdio_writeEnable        ), //o
    .io_dp_cmd_valid           (phy_io_dp_cmd_valid             ), //o
    .io_dp_cmd_payload_apNdp   (phy_io_dp_cmd_payload_apNdp     ), //o
    .io_dp_cmd_payload_rnw     (phy_io_dp_cmd_payload_rnw       ), //o
    .io_dp_cmd_payload_addr    (phy_io_dp_cmd_payload_addr[1:0] ), //o
    .io_dp_rsp_valid           (dp_io_dp_rsp_valid              ), //i
    .io_dp_rsp_payload_ack     (dp_io_dp_rsp_payload_ack[2:0]   ), //i
    .io_dp_rsp_payload_rdata   (dp_io_dp_rsp_payload_rdata[31:0]), //i
    .io_dp_wr_valid            (phy_io_dp_wr_valid              ), //o
    .io_dp_wr_payload_data     (phy_io_dp_wr_payload_data[31:0] ), //o
    .io_dp_wr_payload_parityOk (phy_io_dp_wr_payload_parityOk   ), //o
    .swclk                     (swclk                           ), //i
    .reset                     (reset                           )  //i
  );
  SwdDp dp (
    .io_dp_cmd_valid           (phy_io_dp_cmd_valid             ), //i
    .io_dp_cmd_payload_apNdp   (phy_io_dp_cmd_payload_apNdp     ), //i
    .io_dp_cmd_payload_rnw     (phy_io_dp_cmd_payload_rnw       ), //i
    .io_dp_cmd_payload_addr    (phy_io_dp_cmd_payload_addr[1:0] ), //i
    .io_dp_rsp_valid           (dp_io_dp_rsp_valid              ), //o
    .io_dp_rsp_payload_ack     (dp_io_dp_rsp_payload_ack[2:0]   ), //o
    .io_dp_rsp_payload_rdata   (dp_io_dp_rsp_payload_rdata[31:0]), //o
    .io_dp_wr_valid            (phy_io_dp_wr_valid              ), //i
    .io_dp_wr_payload_data     (phy_io_dp_wr_payload_data[31:0] ), //i
    .io_dp_wr_payload_parityOk (phy_io_dp_wr_payload_parityOk   ), //i
    .io_ap_cmd_valid           (dp_io_ap_cmd_valid              ), //o
    .io_ap_cmd_payload_rnw     (dp_io_ap_cmd_payload_rnw        ), //o
    .io_ap_cmd_payload_addr    (dp_io_ap_cmd_payload_addr[1:0]  ), //o
    .io_ap_cmd_payload_apSel   (dp_io_ap_cmd_payload_apSel[7:0] ), //o
    .io_ap_cmd_payload_wdata   (dp_io_ap_cmd_payload_wdata[31:0]), //o
    .io_ap_rsp_valid           (io_ap_rsp_valid                 ), //i
    .io_ap_rsp_payload_error   (io_ap_rsp_payload_error         ), //i
    .io_ap_rsp_payload_data    (io_ap_rsp_payload_data[31:0]    ), //i
    .swclk                     (swclk                           ), //i
    .reset                     (reset                           )  //i
  );
  assign io_swdio_writeEnable = phy_io_swdio_writeEnable;
  assign io_swdio_write = phy_io_swdio_write;
  assign io_ap_cmd_valid = dp_io_ap_cmd_valid;
  assign io_ap_cmd_payload_rnw = dp_io_ap_cmd_payload_rnw;
  assign io_ap_cmd_payload_addr = dp_io_ap_cmd_payload_addr;
  assign io_ap_cmd_payload_apSel = dp_io_ap_cmd_payload_apSel;
  assign io_ap_cmd_payload_wdata = dp_io_ap_cmd_payload_wdata;

endmodule

module BufferCC_3 (
  input  wire [7:0]    io_dataIn,
  output wire [7:0]    io_dataOut,
  input  wire          clk,
  input  wire          reset
);

  (* async_reg = "true" *) reg        [7:0]    buffers_0;
  (* async_reg = "true" *) reg        [7:0]    buffers_1;

  assign io_dataOut = buffers_1;
  always @(posedge clk) begin
    buffers_0 <= io_dataIn;
    buffers_1 <= buffers_0;
  end


endmodule

module BufferCC_2 (
  input  wire          io_dataIn,
  output wire          io_dataOut,
  input  wire          swclk,
  input  wire          reset
);

  (* async_reg = "true" , altera_attribute = "-name ADV_NETLIST_OPT_ALLOWED NEVER_ALLOW" *) reg                 buffers_0;
  (* altera_attribute = "-name ADV_NETLIST_OPT_ALLOWED NEVER_ALLOW" , async_reg = "true" *) reg                 buffers_1;

  assign io_dataOut = buffers_1;
  always @(posedge swclk or posedge reset) begin
    if(reset) begin
      buffers_0 <= 1'b0;
      buffers_1 <= 1'b0;
    end else begin
      buffers_0 <= io_dataIn;
      buffers_1 <= buffers_0;
    end
  end


endmodule

module BufferCC_1 (
  input  wire          io_dataIn,
  output wire          io_dataOut,
  input  wire          clk,
  input  wire          toplevel_reset_synchronized
);

  (* async_reg = "true" , altera_attribute = "-name ADV_NETLIST_OPT_ALLOWED NEVER_ALLOW" *) reg                 buffers_0;
  (* async_reg = "true" *) reg                 buffers_1;

  assign io_dataOut = buffers_1;
  always @(posedge clk or posedge toplevel_reset_synchronized) begin
    if(toplevel_reset_synchronized) begin
      buffers_0 <= 1'b0;
      buffers_1 <= 1'b0;
    end else begin
      buffers_0 <= io_dataIn;
      buffers_1 <= buffers_0;
    end
  end


endmodule

module BufferCC (
  input  wire          io_dataIn,
  output wire          io_dataOut,
  input  wire          clk,
  input  wire          reset
);

  (* async_reg = "true" *) reg                 buffers_0;
  (* async_reg = "true" *) reg                 buffers_1;

  initial begin
  `ifndef SYNTHESIS
    buffers_1 = 1'b0;
  `endif
  end

  assign io_dataOut = buffers_1;
  always @(posedge clk or posedge reset) begin
    if(reset) begin
      buffers_0 <= 1'b1;
      buffers_1 <= 1'b1;
    end else begin
      buffers_0 <= io_dataIn;
      buffers_1 <= buffers_0;
    end
  end


endmodule

module SwdDp (
  input  wire          io_dp_cmd_valid,
  input  wire          io_dp_cmd_payload_apNdp,
  input  wire          io_dp_cmd_payload_rnw,
  input  wire [1:0]    io_dp_cmd_payload_addr,
  output wire          io_dp_rsp_valid,
  output wire [2:0]    io_dp_rsp_payload_ack,
  output wire [31:0]   io_dp_rsp_payload_rdata,
  input  wire          io_dp_wr_valid,
  input  wire [31:0]   io_dp_wr_payload_data,
  input  wire          io_dp_wr_payload_parityOk,
  output wire          io_ap_cmd_valid,
  output wire          io_ap_cmd_payload_rnw,
  output wire [1:0]    io_ap_cmd_payload_addr,
  output wire [7:0]    io_ap_cmd_payload_apSel,
  output wire [31:0]   io_ap_cmd_payload_wdata,
  input  wire          io_ap_rsp_valid,
  input  wire          io_ap_rsp_payload_error,
  input  wire [31:0]   io_ap_rsp_payload_data,
  input  wire          swclk,
  input  wire          reset
);

  reg                 orunDetect;
  reg                 stickyOrun;
  reg                 stickyCmp;
  reg                 stickyErr;
  reg                 wdataErr;
  reg                 cdbgPwrUpReq;
  reg                 csysPwrUpReq;
  reg        [31:0]   select_1;
  wire       [3:0]    dpBankSel;
  reg        [31:0]   rdBuffer;
  reg                 apBusy;
  reg                 apWasRead;
  reg                 apDiscard;
  wire                anySticky;
  reg        [31:0]   ctrlStat;
  wire                isRdbuffRead;
  wire                gated;
  reg        [2:0]    ack;
  wire                when_SwdDp_l79;
  wire                when_SwdDp_l81;
  reg        [31:0]   dpReadData;
  reg                 last_pendingWrite;
  reg                 last_isApReg;
  reg        [1:0]    last_addrReg;
  reg                 apWrFire;
  wire                when_SwdDp_l133;
  wire                when_SwdDp_l141;
  wire                when_SwdDp_l142;
  wire                when_SwdDp_l143;
  wire                when_SwdDp_l144;
  wire                when_SwdDp_l145;
  wire                when_SwdDp_l151;
  wire                apRdFire;

  assign dpBankSel = select_1[3 : 0];
  assign anySticky = (((stickyOrun || stickyCmp) || stickyErr) || wdataErr);
  always @(*) begin
    ctrlStat = 32'h0;
    ctrlStat[0] = orunDetect;
    ctrlStat[1] = stickyOrun;
    ctrlStat[4] = stickyCmp;
    ctrlStat[5] = stickyErr;
    ctrlStat[7] = wdataErr;
    ctrlStat[28] = cdbgPwrUpReq;
    ctrlStat[29] = cdbgPwrUpReq;
    ctrlStat[30] = csysPwrUpReq;
    ctrlStat[31] = csysPwrUpReq;
  end

  assign isRdbuffRead = (((! io_dp_cmd_payload_apNdp) && io_dp_cmd_payload_rnw) && (io_dp_cmd_payload_addr == 2'b11));
  assign gated = (io_dp_cmd_payload_apNdp || isRdbuffRead);
  assign when_SwdDp_l79 = (anySticky && gated);
  always @(*) begin
    if(when_SwdDp_l79) begin
      ack = 3'b100;
    end else begin
      if(when_SwdDp_l81) begin
        ack = 3'b010;
      end else begin
        ack = 3'b001;
      end
    end
  end

  assign when_SwdDp_l81 = (apBusy && gated);
  always @(*) begin
    case(io_dp_cmd_payload_addr)
      2'b00 : begin
        dpReadData = 32'h0ba11aab;
      end
      2'b01 : begin
        dpReadData = ((dpBankSel == 4'b0000) ? ctrlStat : 32'h0);
      end
      2'b10 : begin
        dpReadData = rdBuffer;
      end
      default : begin
        dpReadData = rdBuffer;
      end
    endcase
  end

  assign io_dp_rsp_valid = io_dp_cmd_valid;
  assign io_dp_rsp_payload_ack = ack;
  assign io_dp_rsp_payload_rdata = (io_dp_cmd_payload_apNdp ? rdBuffer : dpReadData);
  always @(*) begin
    apWrFire = 1'b0;
    if(io_dp_wr_valid) begin
      if(!when_SwdDp_l133) begin
        if(last_pendingWrite) begin
          if(last_isApReg) begin
            apWrFire = 1'b1;
          end
        end
      end
    end
  end

  assign when_SwdDp_l133 = (! io_dp_wr_payload_parityOk);
  assign when_SwdDp_l141 = io_dp_wr_payload_data[1];
  assign when_SwdDp_l142 = io_dp_wr_payload_data[2];
  assign when_SwdDp_l143 = io_dp_wr_payload_data[3];
  assign when_SwdDp_l144 = io_dp_wr_payload_data[4];
  assign when_SwdDp_l145 = io_dp_wr_payload_data[0];
  assign when_SwdDp_l151 = (dpBankSel == 4'b0000);
  assign apRdFire = (((io_dp_cmd_valid && io_dp_cmd_payload_apNdp) && io_dp_cmd_payload_rnw) && (ack == 3'b001));
  assign io_ap_cmd_valid = (apRdFire || apWrFire);
  assign io_ap_cmd_payload_rnw = apRdFire;
  assign io_ap_cmd_payload_addr = (apRdFire ? io_dp_cmd_payload_addr : last_addrReg);
  assign io_ap_cmd_payload_apSel = select_1[31 : 24];
  assign io_ap_cmd_payload_wdata = io_dp_wr_payload_data;
  always @(posedge swclk or posedge reset) begin
    if(reset) begin
      orunDetect <= 1'b0;
      stickyOrun <= 1'b0;
      stickyCmp <= 1'b0;
      stickyErr <= 1'b0;
      wdataErr <= 1'b0;
      cdbgPwrUpReq <= 1'b0;
      csysPwrUpReq <= 1'b0;
      select_1 <= 32'h0;
      rdBuffer <= 32'h0;
      apBusy <= 1'b0;
      apWasRead <= 1'b0;
      apDiscard <= 1'b0;
      last_pendingWrite <= 1'b0;
    end else begin
      if(io_dp_cmd_valid) begin
        last_pendingWrite <= ((! io_dp_cmd_payload_rnw) && (ack == 3'b001));
      end
      if(io_ap_rsp_valid) begin
        if(apDiscard) begin
          apDiscard <= 1'b0;
          apBusy <= 1'b0;
        end else begin
          if(apBusy) begin
            apBusy <= 1'b0;
            if(io_ap_rsp_payload_error) begin
              stickyErr <= 1'b1;
            end else begin
              if(apWasRead) begin
                rdBuffer <= io_ap_rsp_payload_data;
              end
            end
          end
        end
      end
      if(io_dp_wr_valid) begin
        last_pendingWrite <= 1'b0;
        if(when_SwdDp_l133) begin
          wdataErr <= 1'b1;
        end else begin
          if(last_pendingWrite) begin
            if(!last_isApReg) begin
              case(last_addrReg)
                2'b00 : begin
                  if(when_SwdDp_l141) begin
                    stickyCmp <= 1'b0;
                  end
                  if(when_SwdDp_l142) begin
                    stickyErr <= 1'b0;
                  end
                  if(when_SwdDp_l143) begin
                    wdataErr <= 1'b0;
                  end
                  if(when_SwdDp_l144) begin
                    stickyOrun <= 1'b0;
                  end
                  if(when_SwdDp_l145) begin
                    if(apBusy) begin
                      apDiscard <= 1'b1;
                    end
                    apBusy <= 1'b0;
                  end
                end
                2'b01 : begin
                  if(when_SwdDp_l151) begin
                    orunDetect <= io_dp_wr_payload_data[0];
                    cdbgPwrUpReq <= io_dp_wr_payload_data[28];
                    csysPwrUpReq <= io_dp_wr_payload_data[30];
                  end
                end
                2'b10 : begin
                  select_1 <= io_dp_wr_payload_data;
                end
                default : begin
                end
              endcase
            end
          end
        end
      end
      if(io_ap_cmd_valid) begin
        apBusy <= 1'b1;
        apWasRead <= apRdFire;
      end
    end
  end

  always @(posedge swclk) begin
    if(io_dp_cmd_valid) begin
      last_isApReg <= io_dp_cmd_payload_apNdp;
      last_addrReg <= io_dp_cmd_payload_addr;
    end
  end


endmodule

module SwdPhy (
  input  wire          io_swdio_read,
  output wire          io_swdio_write,
  output wire          io_swdio_writeEnable,
  output wire          io_dp_cmd_valid,
  output wire          io_dp_cmd_payload_apNdp,
  output wire          io_dp_cmd_payload_rnw,
  output wire [1:0]    io_dp_cmd_payload_addr,
  input  wire          io_dp_rsp_valid,
  input  wire [2:0]    io_dp_rsp_payload_ack,
  input  wire [31:0]   io_dp_rsp_payload_rdata,
  output wire          io_dp_wr_valid,
  output wire [31:0]   io_dp_wr_payload_data,
  output wire          io_dp_wr_payload_parityOk,
  input  wire          swclk,
  input  wire          reset
);
  localparam EState_IDLE = 4'd0;
  localparam EState_HEADER = 4'd1;
  localparam EState_ACK = 4'd2;
  localparam EState_READ_DATA = 4'd3;
  localparam EState_WR_TRN = 4'd4;
  localparam EState_WRITE_DATA = 4'd5;
  localparam EState_RELEASE_1 = 4'd6;
  localparam EState_ERROR = 4'd7;
  localparam EState_RESET_WAIT = 4'd8;

  wire       [5:0]    _zz_lineReset_counter_valueNext;
  wire       [0:0]    _zz_lineReset_counter_valueNext_1;
  reg                 oData;
  reg                 oDrive;
  reg                 rspHold_valid;
  reg        [2:0]    rspHold_payload_ack;
  reg        [31:0]   rspHold_payload_rdata;
  wire       [2:0]    ackNow;
  reg                 cmdValid;
  reg                 cmdPayload_apNdp;
  reg                 cmdPayload_rnw;
  reg        [1:0]    cmdPayload_addr;
  reg                 wrValid;
  reg        [31:0]   wrPayload_data;
  reg                 wrPayload_parityOk;
  reg                 lineReset_counter_willIncrement;
  wire                lineReset_counter_willDecrement;
  reg                 lineReset_counter_willClear;
  wire                lineReset_counter_willLoad;
  reg        [5:0]    lineReset_counter_valueNext;
  reg        [5:0]    lineReset_counter_value;
  wire                lineReset_counter_willOverflowIfInc;
  wire                lineReset_counter_willUnderflowIfDec;
  wire                lineReset_counter_willOverflow;
  wire                lineReset_counter_willUnderflow;
  wire                when_SwdPhy_l76;
  wire                when_SwdPhy_l78;
  reg        [3:0]    state;
  reg        [5:0]    cnt;
  reg        [5:0]    hdr;
  reg        [31:0]   wShift;
  wire                when_SwdPhy_l103;
  wire                _zz_cmdPayload_apNdp;
  wire                _zz_cmdPayload_rnw;
  wire                _zz_cmdPayload_addr;
  wire                _zz_cmdPayload_addr_1;
  wire                when_SwdPhy_l110;
  wire                when_SwdPhy_l126;
  wire                when_SwdPhy_l128;
  wire                when_SwdPhy_l143;
  wire                when_SwdPhy_l151;
  wire                when_SwdPhy_l159;
  wire                when_SwdPhy_l169;
  wire                when_SwdPhy_l179;
  `ifndef SYNTHESIS
  reg [79:0] state_string;
  `endif


  assign _zz_lineReset_counter_valueNext_1 = lineReset_counter_willIncrement;
  assign _zz_lineReset_counter_valueNext = {5'd0, _zz_lineReset_counter_valueNext_1};
  `ifndef SYNTHESIS
  always @(*) begin
    case(state)
      EState_IDLE : state_string = "IDLE      ";
      EState_HEADER : state_string = "HEADER    ";
      EState_ACK : state_string = "ACK       ";
      EState_READ_DATA : state_string = "READ_DATA ";
      EState_WR_TRN : state_string = "WR_TRN    ";
      EState_WRITE_DATA : state_string = "WRITE_DATA";
      EState_RELEASE_1 : state_string = "RELEASE_1 ";
      EState_ERROR : state_string = "ERROR     ";
      EState_RESET_WAIT : state_string = "RESET_WAIT";
      default : state_string = "??????????";
    endcase
  end
  `endif

  assign io_swdio_write = oData;
  assign io_swdio_writeEnable = oDrive;
  assign ackNow = (io_dp_rsp_valid ? io_dp_rsp_payload_ack : rspHold_payload_ack);
  assign io_dp_cmd_valid = cmdValid;
  assign io_dp_cmd_payload_apNdp = cmdPayload_apNdp;
  assign io_dp_cmd_payload_rnw = cmdPayload_rnw;
  assign io_dp_cmd_payload_addr = cmdPayload_addr;
  assign io_dp_wr_valid = wrValid;
  assign io_dp_wr_payload_data = wrPayload_data;
  assign io_dp_wr_payload_parityOk = wrPayload_parityOk;
  always @(*) begin
    lineReset_counter_willIncrement = 1'b0;
    if(!when_SwdPhy_l76) begin
      if(when_SwdPhy_l78) begin
        lineReset_counter_willIncrement = 1'b1;
      end
    end
  end

  assign lineReset_counter_willDecrement = 1'b0;
  always @(*) begin
    lineReset_counter_willClear = 1'b0;
    if(when_SwdPhy_l76) begin
      lineReset_counter_willClear = 1'b1;
    end
  end

  assign lineReset_counter_willLoad = 1'b0;
  assign lineReset_counter_willOverflowIfInc = (lineReset_counter_value == 6'h32);
  assign lineReset_counter_willUnderflowIfDec = (lineReset_counter_value == 6'h0);
  assign lineReset_counter_willOverflow = (lineReset_counter_willOverflowIfInc && lineReset_counter_willIncrement);
  always @(*) begin
    lineReset_counter_valueNext = (lineReset_counter_value + _zz_lineReset_counter_valueNext);
    if(lineReset_counter_willOverflow) begin
      lineReset_counter_valueNext = 6'h0;
    end
    if(lineReset_counter_willClear) begin
      lineReset_counter_valueNext = 6'h0;
    end
  end

  assign lineReset_counter_willUnderflow = (lineReset_counter_willUnderflowIfDec && lineReset_counter_willDecrement);
  assign when_SwdPhy_l76 = (oDrive || (! io_swdio_read));
  assign when_SwdPhy_l78 = (! lineReset_counter_willOverflowIfInc);
  assign when_SwdPhy_l103 = (cnt == 6'h06);
  assign _zz_cmdPayload_apNdp = hdr[0];
  assign _zz_cmdPayload_rnw = hdr[1];
  assign _zz_cmdPayload_addr = hdr[2];
  assign _zz_cmdPayload_addr_1 = hdr[3];
  assign when_SwdPhy_l110 = ((((((_zz_cmdPayload_apNdp ^ _zz_cmdPayload_rnw) ^ _zz_cmdPayload_addr) ^ _zz_cmdPayload_addr_1) == hdr[4]) && (! hdr[5])) && io_swdio_read);
  assign when_SwdPhy_l126 = (cnt == 6'h02);
  assign when_SwdPhy_l128 = (ackNow == 3'b001);
  assign when_SwdPhy_l143 = (cnt == 6'h20);
  assign when_SwdPhy_l151 = (cnt == 6'h01);
  assign when_SwdPhy_l159 = (cnt == 6'h20);
  assign when_SwdPhy_l169 = (cnt == 6'h01);
  assign when_SwdPhy_l179 = (! io_swdio_read);
  always @(posedge swclk or posedge reset) begin
    if(reset) begin
      oData <= 1'b0;
      oDrive <= 1'b0;
      rspHold_valid <= 1'b0;
      cmdValid <= 1'b0;
      wrValid <= 1'b0;
      lineReset_counter_value <= 6'h0;
      state <= EState_RESET_WAIT;
      cnt <= 6'h0;
    end else begin
      rspHold_valid <= io_dp_rsp_valid;
      cmdValid <= 1'b0;
      wrValid <= 1'b0;
      lineReset_counter_value <= lineReset_counter_valueNext;
      case(state)
        EState_IDLE : begin
          oDrive <= 1'b0;
          if(io_swdio_read) begin
            state <= EState_HEADER;
            cnt <= 6'h0;
          end
        end
        EState_HEADER : begin
          cnt <= (cnt + 6'h01);
          if(when_SwdPhy_l103) begin
            if(when_SwdPhy_l110) begin
              cmdValid <= 1'b1;
              state <= EState_ACK;
              cnt <= 6'h0;
            end else begin
              state <= EState_ERROR;
            end
          end
        end
        EState_ACK : begin
          oDrive <= 1'b1;
          oData <= ackNow[cnt[1 : 0]];
          cnt <= (cnt + 6'h01);
          if(when_SwdPhy_l126) begin
            cnt <= 6'h0;
            if(when_SwdPhy_l128) begin
              if(cmdPayload_rnw) begin
                state <= EState_READ_DATA;
              end else begin
                state <= EState_WR_TRN;
              end
            end else begin
              state <= EState_RELEASE_1;
            end
          end
        end
        EState_READ_DATA : begin
          oDrive <= 1'b1;
          oData <= ((cnt == 6'h20) ? (^rspHold_payload_rdata) : rspHold_payload_rdata[cnt[4 : 0]]);
          cnt <= (cnt + 6'h01);
          if(when_SwdPhy_l143) begin
            state <= EState_RELEASE_1;
            cnt <= 6'h0;
          end
        end
        EState_WR_TRN : begin
          oDrive <= 1'b0;
          cnt <= (cnt + 6'h01);
          if(when_SwdPhy_l151) begin
            state <= EState_WRITE_DATA;
            cnt <= 6'h0;
          end
        end
        EState_WRITE_DATA : begin
          cnt <= (cnt + 6'h01);
          if(when_SwdPhy_l159) begin
            wrValid <= 1'b1;
            state <= EState_IDLE;
          end
        end
        EState_RELEASE_1 : begin
          oDrive <= 1'b0;
          cnt <= (cnt + 6'h01);
          if(when_SwdPhy_l169) begin
            state <= EState_IDLE;
            cnt <= 6'h0;
          end
        end
        EState_ERROR : begin
          oDrive <= 1'b0;
        end
        default : begin
          oDrive <= 1'b0;
          if(when_SwdPhy_l179) begin
            state <= EState_IDLE;
          end
        end
      endcase
      if(lineReset_counter_willOverflowIfInc) begin
        state <= EState_RESET_WAIT;
      end
    end
  end

  always @(posedge swclk) begin
    if(io_dp_rsp_valid) begin
      rspHold_payload_ack <= io_dp_rsp_payload_ack;
      rspHold_payload_rdata <= io_dp_rsp_payload_rdata;
    end
    case(state)
      EState_IDLE : begin
      end
      EState_HEADER : begin
        hdr <= {io_swdio_read,hdr[5 : 1]};
        if(when_SwdPhy_l103) begin
          if(when_SwdPhy_l110) begin
            cmdPayload_apNdp <= _zz_cmdPayload_apNdp;
            cmdPayload_rnw <= _zz_cmdPayload_rnw;
            cmdPayload_addr <= {_zz_cmdPayload_addr_1,_zz_cmdPayload_addr};
          end
        end
      end
      EState_ACK : begin
      end
      EState_READ_DATA : begin
      end
      EState_WR_TRN : begin
      end
      EState_WRITE_DATA : begin
        wShift <= {io_swdio_read,wShift[31 : 1]};
        if(when_SwdPhy_l159) begin
          wrPayload_data <= wShift;
          wrPayload_parityOk <= ((^wShift) == io_swdio_read);
        end
      end
      EState_RELEASE_1 : begin
      end
      EState_ERROR : begin
      end
      default : begin
      end
    endcase
  end


endmodule
