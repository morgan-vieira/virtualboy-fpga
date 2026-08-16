//
// User core top-level
//
// Instantiated by the real top-level: apf_top
//

`default_nettype none

module core_top (

//
// physical connections
//

///////////////////////////////////////////////////
// clock inputs 74.25mhz. not phase aligned, so treat these domains as asynchronous

input   wire            clk_74a, // mainclk1
input   wire            clk_74b, // mainclk1 

///////////////////////////////////////////////////
// cartridge interface
// switches between 3.3v and 5v mechanically
// output enable for multibit translators controlled by pic32

// GBA AD[15:8]
inout   wire    [7:0]   cart_tran_bank2,
output  wire            cart_tran_bank2_dir,

// GBA AD[7:0]
inout   wire    [7:0]   cart_tran_bank3,
output  wire            cart_tran_bank3_dir,

// GBA A[23:16]
inout   wire    [7:0]   cart_tran_bank1,
output  wire            cart_tran_bank1_dir,

// GBA [7] PHI#
// GBA [6] WR#
// GBA [5] RD#
// GBA [4] CS1#/CS#
//     [3:0] unwired
inout   wire    [7:4]   cart_tran_bank0,
output  wire            cart_tran_bank0_dir,

// GBA CS2#/RES#
inout   wire            cart_tran_pin30,
output  wire            cart_tran_pin30_dir,
// when GBC cart is inserted, this signal when low or weak will pull GBC /RES low with a special circuit
// the goal is that when unconfigured, the FPGA weak pullups won't interfere.
// thus, if GBC cart is inserted, FPGA must drive this high in order to let the level translators
// and general IO drive this pin.
output  wire            cart_pin30_pwroff_reset,

// GBA IRQ/DRQ
inout   wire            cart_tran_pin31,
output  wire            cart_tran_pin31_dir,

// infrared
input   wire            port_ir_rx,
output  wire            port_ir_tx,
output  wire            port_ir_rx_disable, 

// GBA link port
inout   wire            port_tran_si,
output  wire            port_tran_si_dir,
inout   wire            port_tran_so,
output  wire            port_tran_so_dir,
inout   wire            port_tran_sck,
output  wire            port_tran_sck_dir,
inout   wire            port_tran_sd,
output  wire            port_tran_sd_dir,
 
///////////////////////////////////////////////////
// cellular psram 0 and 1, two chips (64mbit x2 dual die per chip)

output  wire    [21:16] cram0_a,
inout   wire    [15:0]  cram0_dq,
input   wire            cram0_wait,
output  wire            cram0_clk,
output  wire            cram0_adv_n,
output  wire            cram0_cre,
output  wire            cram0_ce0_n,
output  wire            cram0_ce1_n,
output  wire            cram0_oe_n,
output  wire            cram0_we_n,
output  wire            cram0_ub_n,
output  wire            cram0_lb_n,

output  wire    [21:16] cram1_a,
inout   wire    [15:0]  cram1_dq,
input   wire            cram1_wait,
output  wire            cram1_clk,
output  wire            cram1_adv_n,
output  wire            cram1_cre,
output  wire            cram1_ce0_n,
output  wire            cram1_ce1_n,
output  wire            cram1_oe_n,
output  wire            cram1_we_n,
output  wire            cram1_ub_n,
output  wire            cram1_lb_n,

///////////////////////////////////////////////////
// sdram, 512mbit 16bit

output  wire    [12:0]  dram_a,
output  wire    [1:0]   dram_ba,
inout   wire    [15:0]  dram_dq,
output  wire    [1:0]   dram_dqm,
output  wire            dram_clk,
output  wire            dram_cke,
output  wire            dram_ras_n,
output  wire            dram_cas_n,
output  wire            dram_we_n,

///////////////////////////////////////////////////
// sram, 1mbit 16bit

output  wire    [16:0]  sram_a,
inout   wire    [15:0]  sram_dq,
output  wire            sram_oe_n,
output  wire            sram_we_n,
output  wire            sram_ub_n,
output  wire            sram_lb_n,

///////////////////////////////////////////////////
// vblank driven by dock for sync in a certain mode

input   wire            vblank,

///////////////////////////////////////////////////
// i/o to 6515D breakout usb uart

output  wire            dbg_tx,
input   wire            dbg_rx,

///////////////////////////////////////////////////
// i/o pads near jtag connector user can solder to

output  wire            user1,
input   wire            user2,

///////////////////////////////////////////////////
// RFU internal i2c bus 

inout   wire            aux_sda,
output  wire            aux_scl,

///////////////////////////////////////////////////
// RFU, do not use
output  wire            vpll_feed,


//
// logical connections
//

///////////////////////////////////////////////////
// video, audio output to scaler
output  wire    [23:0]  video_rgb,
output  wire            video_rgb_clock,
output  wire            video_rgb_clock_90,
output  wire            video_de,
output  wire            video_skip,
output  wire            video_vs,
output  wire            video_hs,
    
output  wire            audio_mclk,
input   wire            audio_adc,
output  wire            audio_dac,
output  wire            audio_lrck,

///////////////////////////////////////////////////
// bridge bus connection
// synchronous to clk_74a
output  wire            bridge_endian_little,
input   wire    [31:0]  bridge_addr,
input   wire            bridge_rd,
output  reg     [31:0]  bridge_rd_data,
input   wire            bridge_wr,
input   wire    [31:0]  bridge_wr_data,

///////////////////////////////////////////////////
// controller data
// 
// key bitmap:
//   [0]    dpad_up
//   [1]    dpad_down
//   [2]    dpad_left
//   [3]    dpad_right
//   [4]    face_a
//   [5]    face_b
//   [6]    face_x
//   [7]    face_y
//   [8]    trig_l1
//   [9]    trig_r1
//   [10]   trig_l2
//   [11]   trig_r2
//   [12]   trig_l3
//   [13]   trig_r3
//   [14]   face_select
//   [15]   face_start
//   [31:28] type
// joy values - unsigned
//   [ 7: 0] lstick_x
//   [15: 8] lstick_y
//   [23:16] rstick_x
//   [31:24] rstick_y
// trigger values - unsigned
//   [ 7: 0] ltrig
//   [15: 8] rtrig
//
input   wire    [31:0]  cont1_key,
input   wire    [31:0]  cont2_key,
input   wire    [31:0]  cont3_key,
input   wire    [31:0]  cont4_key,
input   wire    [31:0]  cont1_joy,
input   wire    [31:0]  cont2_joy,
input   wire    [31:0]  cont3_joy,
input   wire    [31:0]  cont4_joy,
input   wire    [15:0]  cont1_trig,
input   wire    [15:0]  cont2_trig,
input   wire    [15:0]  cont3_trig,
input   wire    [15:0]  cont4_trig
    
);

// not using the IR port, so turn off both the LED, and
// disable the receive circuit to save power
assign port_ir_tx = 0;
assign port_ir_rx_disable = 1;

// bridge endianness
assign bridge_endian_little = 0;

// cart is unused, so set all level translators accordingly
// directions are 0:IN, 1:OUT
assign cart_tran_bank3 = 8'hzz;
assign cart_tran_bank3_dir = 1'b0;
assign cart_tran_bank2 = 8'hzz;
assign cart_tran_bank2_dir = 1'b0;
assign cart_tran_bank1 = 8'hzz;
assign cart_tran_bank1_dir = 1'b0;
assign cart_tran_bank0 = 4'hf;
assign cart_tran_bank0_dir = 1'b1;
assign cart_tran_pin30 = 1'b0;      // reset or cs2, we let the hw control it by itself
assign cart_tran_pin30_dir = 1'bz;
assign cart_pin30_pwroff_reset = 1'b0;  // hardware can control this
assign cart_tran_pin31 = 1'bz;      // input
assign cart_tran_pin31_dir = 1'b0;  // input

// link port is unused, set to input only to be safe
// each bit may be bidirectional in some applications
assign port_tran_so = 1'bz;
assign port_tran_so_dir = 1'b0;     // SO is output only
assign port_tran_si = 1'bz;
assign port_tran_si_dir = 1'b0;     // SI is input only
assign port_tran_sck = 1'bz;
assign port_tran_sck_dir = 1'b0;    // clock direction can change
assign port_tran_sd = 1'bz;
assign port_tran_sd_dir = 1'b0;     // SD is input and not used

// tie off the rest of the pins we are not using
assign cram0_a = 'h0;
assign cram0_dq = {16{1'bZ}};
assign cram0_clk = 0;
assign cram0_adv_n = 1;
assign cram0_cre = 0;
assign cram0_ce0_n = 1;
assign cram0_ce1_n = 1;
assign cram0_oe_n = 1;
assign cram0_we_n = 1;
assign cram0_ub_n = 1;
assign cram0_lb_n = 1;

assign cram1_a = 'h0;
assign cram1_dq = {16{1'bZ}};
assign cram1_clk = 0;
assign cram1_adv_n = 1;
assign cram1_cre = 0;
assign cram1_ce0_n = 1;
assign cram1_ce1_n = 1;
assign cram1_oe_n = 1;
assign cram1_we_n = 1;
assign cram1_ub_n = 1;
assign cram1_lb_n = 1;

assign dram_a = 'h0;
assign dram_ba = 'h0;
assign dram_dq = {16{1'bZ}};
assign dram_dqm = 'h0;
assign dram_clk = 'h0;
assign dram_cke = 'h0;
assign dram_ras_n = 'h1;
assign dram_cas_n = 'h1;
assign dram_we_n = 'h1;

assign dbg_tx = 1'bZ;
assign user1 = 1'bZ;
assign aux_scl = 1'bZ;
assign vpll_feed = 1'bZ;


// for bridge write data, we just broadcast it to all bus devices
// for bridge read data, we have to mux it
// add your own devices here
always @(*) begin
    casex(bridge_addr)
    default: begin
        bridge_rd_data <= 0;
    end
    32'h10xxxxxx: begin
        bridge_rd_data <= core_cfg;
    end
    32'hF8xxxxxx: begin
        bridge_rd_data <= cmd_bridge_rd_data;
    end
    endcase
end


//
// core settings
//
// one register behind the Core Settings menu. bits 1:0 are the controller
// mapping: the Pocket has twelve inputs and the machine has fourteen, so
// which two go missing is a user's choice rather than ours, and
// host_pad_map.v carries the layout and the reasoning. bit 2 turns on the
// diagnostic overlay below. APF reads the register back and writes it whole
// every frame, so it answers reads as well as writes.

    reg     [31:0]  core_cfg = 32'd0;
always @(posedge clk_74a) begin
    if(bridge_wr && bridge_addr == 32'h10000000) core_cfg <= bridge_wr_data;
end


//
// host/target command handler
//
    wire            reset_n;                // driven by host commands, can be used as core-wide reset
    wire    [31:0]  cmd_bridge_rd_data;
    
// bridge host commands
// synchronous to clk_74a
    wire            status_boot_done = pll_core_locked_s; 
    wire            status_setup_done = pll_core_locked_s; // rising edge triggers a target command
    wire            status_running = reset_n; // we are running as soon as reset_n goes high

    wire            dataslot_requestread;
    wire    [15:0]  dataslot_requestread_id;
    wire            dataslot_requestread_ack = 1;
    wire            dataslot_requestread_ok = 1;

    wire            dataslot_requestwrite;
    wire    [15:0]  dataslot_requestwrite_id;
    wire    [31:0]  dataslot_requestwrite_size;
    wire            dataslot_requestwrite_ack = 1;
    wire            dataslot_requestwrite_ok = 1;

    wire            dataslot_update;
    wire    [15:0]  dataslot_update_id;
    wire    [31:0]  dataslot_update_size;
    
    wire            dataslot_allcomplete;

    wire     [31:0] rtc_epoch_seconds;
    wire     [31:0] rtc_date_bcd;
    wire     [31:0] rtc_time_bcd;
    wire            rtc_valid;

    wire            savestate_supported;
    wire    [31:0]  savestate_addr;
    wire    [31:0]  savestate_size;
    wire    [31:0]  savestate_maxloadsize;

    wire            savestate_start;
    wire            savestate_start_ack;
    wire            savestate_start_busy;
    wire            savestate_start_ok;
    wire            savestate_start_err;

    wire            savestate_load;
    wire            savestate_load_ack;
    wire            savestate_load_busy;
    wire            savestate_load_ok;
    wire            savestate_load_err;
    
    wire            osnotify_inmenu;

// bridge target commands
// synchronous to clk_74a

    reg             target_dataslot_read;       
    reg             target_dataslot_write;
    reg             target_dataslot_getfile;    // require additional param/resp structs to be mapped
    reg             target_dataslot_openfile;   // require additional param/resp structs to be mapped
    
    wire            target_dataslot_ack;        
    wire            target_dataslot_done;
    wire    [2:0]   target_dataslot_err;

    reg     [15:0]  target_dataslot_id;
    reg     [31:0]  target_dataslot_slotoffset;
    reg     [31:0]  target_dataslot_bridgeaddr;
    reg     [31:0]  target_dataslot_length;
    
    wire    [31:0]  target_buffer_param_struct; // to be mapped/implemented when using some Target commands
    wire    [31:0]  target_buffer_resp_struct;  // to be mapped/implemented when using some Target commands
    
// bridge data slot access
// synchronous to clk_74a

    wire    [9:0]   datatable_addr;
    wire            datatable_wren;
    wire    [31:0]  datatable_data;
    wire    [31:0]  datatable_q;

core_bridge_cmd icb (

    .clk                ( clk_74a ),
    .reset_n            ( reset_n ),

    .bridge_endian_little   ( bridge_endian_little ),
    .bridge_addr            ( bridge_addr ),
    .bridge_rd              ( bridge_rd ),
    .bridge_rd_data         ( cmd_bridge_rd_data ),
    .bridge_wr              ( bridge_wr ),
    .bridge_wr_data         ( bridge_wr_data ),
    
    .status_boot_done       ( status_boot_done ),
    .status_setup_done      ( status_setup_done ),
    .status_running         ( status_running ),

    .dataslot_requestread       ( dataslot_requestread ),
    .dataslot_requestread_id    ( dataslot_requestread_id ),
    .dataslot_requestread_ack   ( dataslot_requestread_ack ),
    .dataslot_requestread_ok    ( dataslot_requestread_ok ),

    .dataslot_requestwrite      ( dataslot_requestwrite ),
    .dataslot_requestwrite_id   ( dataslot_requestwrite_id ),
    .dataslot_requestwrite_size ( dataslot_requestwrite_size ),
    .dataslot_requestwrite_ack  ( dataslot_requestwrite_ack ),
    .dataslot_requestwrite_ok   ( dataslot_requestwrite_ok ),

    .dataslot_update            ( dataslot_update ),
    .dataslot_update_id         ( dataslot_update_id ),
    .dataslot_update_size       ( dataslot_update_size ),
    
    .dataslot_allcomplete   ( dataslot_allcomplete ),

    .rtc_epoch_seconds      ( rtc_epoch_seconds ),
    .rtc_date_bcd           ( rtc_date_bcd ),
    .rtc_time_bcd           ( rtc_time_bcd ),
    .rtc_valid              ( rtc_valid ),
    
    .savestate_supported    ( savestate_supported ),
    .savestate_addr         ( savestate_addr ),
    .savestate_size         ( savestate_size ),
    .savestate_maxloadsize  ( savestate_maxloadsize ),

    .savestate_start        ( savestate_start ),
    .savestate_start_ack    ( savestate_start_ack ),
    .savestate_start_busy   ( savestate_start_busy ),
    .savestate_start_ok     ( savestate_start_ok ),
    .savestate_start_err    ( savestate_start_err ),

    .savestate_load         ( savestate_load ),
    .savestate_load_ack     ( savestate_load_ack ),
    .savestate_load_busy    ( savestate_load_busy ),
    .savestate_load_ok      ( savestate_load_ok ),
    .savestate_load_err     ( savestate_load_err ),

    .osnotify_inmenu        ( osnotify_inmenu ),
    
    .target_dataslot_read       ( target_dataslot_read ),
    .target_dataslot_write      ( target_dataslot_write ),
    .target_dataslot_getfile    ( target_dataslot_getfile ),
    .target_dataslot_openfile   ( target_dataslot_openfile ),
    
    .target_dataslot_ack        ( target_dataslot_ack ),
    .target_dataslot_done       ( target_dataslot_done ),
    .target_dataslot_err        ( target_dataslot_err ),

    .target_dataslot_id         ( target_dataslot_id ),
    .target_dataslot_slotoffset ( target_dataslot_slotoffset ),
    .target_dataslot_bridgeaddr ( target_dataslot_bridgeaddr ),
    .target_dataslot_length     ( target_dataslot_length ),

    .target_buffer_param_struct ( target_buffer_param_struct ),
    .target_buffer_resp_struct  ( target_buffer_resp_struct ),
    
    .datatable_addr         ( datatable_addr ),
    .datatable_wren         ( datatable_wren ),
    .datatable_data         ( datatable_data ),
    .datatable_q            ( datatable_q )

);



////////////////////////////////////////////////////////////////////////////////////////



// the CPU and its bus
//
// everything Virtual Boy computes in the clk_cpu domain: the CPU's state
// machine, mem_bus, work RAM and the cartridge's read side run on the
// 39.936 MHz clock, and cpu_clock_enable ticks architectural 20 MHz time
// into the CPU -- 625 enables per 1248 clocks, which against the same-VCO
// video clock is exactly 400,000 CPU cycles per 20 ms frame. the constants
// are checked against the fit report's PLL counters (cpu_clock_enable.v
// says how). the CPU advances per tick, so the clock only needs to carry
// bus answers between ticks (cpu.v says why that closes timing). the
// cartridge loads over the APF bridge (see cart_rom.v): data.json's slot 0
// lands at bridge 0x00000000, and its "reset core while loading" bit means
// reset_n is low for the whole load. the CPU is gated on
// dataslot_allcomplete besides, so it cannot boot before the first image is
// in. devices that don't exist yet answer zero, matching mem_bus's unmapped
// rule.

    wire cart_load_wr = bridge_wr && bridge_addr[31:16] == 16'h0000;

    wire dataslot_allcomplete_s;
synch_3 s_dsac(dataslot_allcomplete, dataslot_allcomplete_s, clk_cpu);

    wire cpu_ce;

cpu_clock_enable ce_gen (
    .clk                    ( clk_cpu ),
    .reset_n                ( reset_n ),
    .ce                     ( cpu_ce )
);

    wire        cpu_req;
    wire [26:1] cpu_addr;
    wire        cpu_we;
    wire [1:0]  cpu_be;
    wire [15:0] cpu_wdata;
    wire [15:0] cpu_rdata;
    wire        cpu_ready;
    wire [31:0] cpu_dbg_pc;
    wire        cpu_dbg_halted;

    wire        cart_rom_sel;
    wire [15:0] cart_rom_rdata;

    wire        vip_sel;
    wire [15:0] vip_rdata;
    wire        vip_ready;

    wire        vsu_sel;
    wire signed [15:0] vsu_sample_left;
    wire signed [15:0] vsu_sample_right;

    wire        misc_sel;
    wire [15:0] timer_rdata;
    wire [15:0] pad_rdata;
    wire        timer_irq;
    wire        pad_irq;
    wire        vip_irq;

    // the misc region's two devices decode disjoint registers and answer
    // zero everywhere else, so one answer is the other's zero.
    wire [15:0] misc_rdata = timer_rdata | pad_rdata;

cpu vb_cpu (
    .clk                    ( clk_cpu ),
    .ce                     ( cpu_ce ),
    .reset_n                ( reset_n && dataslot_allcomplete_s ),

    .req                    ( cpu_req ),
    .addr                   ( cpu_addr ),
    .we                     ( cpu_we ),
    .be                     ( cpu_be ),
    .wdata                  ( cpu_wdata ),
    .rdata                  ( cpu_rdata ),
    .ready                  ( cpu_ready ),

    // five hardware sources ranked with the VIP highest and the game pad
    // lowest; three of them exist so far, and this is the priority encoder
    // TODO section 3 was waiting on a second source for.
    .irq_valid              ( vip_irq || timer_irq || pad_irq ),
    .irq_level              ( vip_irq   ? 4'd4 :
                              timer_irq ? 4'd1 : 4'd0 ),

    .dbg_pc                 ( cpu_dbg_pc ),
    .dbg_halted             ( cpu_dbg_halted )
);

mem_bus vb_bus (
    .clk                    ( clk_cpu ),
    .reset_n                ( reset_n ),

    .req                    ( cpu_req ),
    .addr                   ( cpu_addr ),
    .we                     ( cpu_we ),
    .be                     ( cpu_be ),
    .wdata                  ( cpu_wdata ),
    .rdata                  ( cpu_rdata ),
    .ready                  ( cpu_ready ),

    .vip_sel                ( vip_sel ),
    .vsu_sel                ( vsu_sel ),
    .misc_sel               ( misc_sel ),
    .exp_sel                ( ),
    .cart_ram_sel           ( ),
    .cart_rom_sel           ( cart_rom_sel ),

    .vip_rdata              ( vip_rdata ),
    .vip_ready              ( vip_ready ),
    .misc_rdata             ( misc_rdata ),
    .cart_ram_rdata         ( 16'd0 ),
    .cart_rom_rdata         ( cart_rom_rdata )
);

    wire [1:0]  vip_display_pixel;
    wire [7:0]  vip_display_luma;
    wire        vip_dram_req;
    wire [15:0] vip_dram_addr;
    wire        vip_dram_we;
    wire [1:0]  vip_dram_be;
    wire [15:0] vip_dram_wdata;
    wire [15:0] vip_dram_rdata;
    wire        vip_dram_ready;

vip vb_vip (
    .clk                    ( clk_cpu ),
    .reset_n                ( reset_n && dataslot_allcomplete_s ),

    .cpu_sel                ( vip_sel ),
    .cpu_addr               ( cpu_addr ),
    .cpu_we                 ( cpu_we ),
    .cpu_be                 ( cpu_be ),
    .cpu_wdata              ( cpu_wdata ),
    .cpu_rdata              ( vip_rdata ),
    .cpu_ready              ( vip_ready ),
    .irq                    ( vip_irq ),

    .dram_req               ( vip_dram_req ),
    .dram_addr              ( vip_dram_addr ),
    .dram_we                ( vip_dram_we ),
    .dram_be                ( vip_dram_be ),
    .dram_wdata             ( vip_dram_wdata ),
    .dram_rdata             ( vip_dram_rdata ),
    .dram_ready             ( vip_dram_ready ),

    .display_clk            ( clk_core_12288 ),
    .display_eye            ( 1'b0 ),
    .display_x              ( vidout_x[8:0] ),
    .display_y              ( vidout_y[7:0] ),
    .display_pixel          ( vip_display_pixel ),
    .display_luma           ( vip_display_luma )
);

pocket_sram vip_dram_sram (
    .clk                    ( clk_cpu ),
    .reset_n                ( reset_n ),
    .req                    ( vip_dram_req ),
    .addr                   ( {1'b0, vip_dram_addr} ),
    .we                     ( vip_dram_we ),
    .be                     ( vip_dram_be ),
    .wdata                  ( vip_dram_wdata ),
    .rdata                  ( vip_dram_rdata ),
    .ready                  ( vip_dram_ready ),
    .sram_a                 ( sram_a ),
    .sram_dq                ( sram_dq ),
    .sram_oe_n              ( sram_oe_n ),
    .sram_we_n              ( sram_we_n ),
    .sram_ub_n              ( sram_ub_n ),
    .sram_lb_n              ( sram_lb_n )
);

// the timer answers the misc region's registers at 0x18/0x1C/0x20; the
// WCR at 0x24 stays inside cpu.v, which intercepts those reads before the
// bus answer lands. resets with the CPU so architectural time and the
// 20 us grid start together on every cartridge load.
timer vb_timer (
    .clk                    ( clk_cpu ),
    .reset_n                ( reset_n && dataslot_allcomplete_s ),
    .ce                     ( cpu_ce ),

    .sel                    ( misc_sel ),
    .addr                   ( cpu_addr ),
    .we                     ( cpu_we ),
    .be                     ( cpu_be ),
    .wdata                  ( cpu_wdata ),
    .rdata                  ( timer_rdata ),

    .irq                    ( timer_irq )
);

// the game pad answers the misc region's registers at 0x10/0x14/0x28. its
// report is the Pocket's controller through host_pad_map, synchronized out
// of clk_74a here rather than inside the pad, which only ever sees a value
// already in its own domain.

    wire [15:0] cont1_key_s;
synch_3 #(.WIDTH(16)) s_cont1(cont1_key[15:0], cont1_key_s, clk_cpu);

    wire [1:0]  pad_cfg_s;
synch_3 #(.WIDTH(2)) s_padcfg(core_cfg[1:0], pad_cfg_s, clk_cpu);

    wire [15:0] pad_buttons;

host_pad_map vb_pad_map (
    .key                    ( cont1_key_s ),
    .cfg                    ( pad_cfg_s ),
    .buttons                ( pad_buttons )
);

game_pad vb_pad (
    .clk                    ( clk_cpu ),
    .reset_n                ( reset_n && dataslot_allcomplete_s ),
    .ce                     ( cpu_ce ),

    .sel                    ( misc_sel ),
    .addr                   ( cpu_addr ),
    .we                     ( cpu_we ),
    .be                     ( cpu_be ),
    .wdata                  ( cpu_wdata ),
    .rdata                  ( pad_rdata ),

    .buttons                ( pad_buttons ),

    .irq                    ( pad_irq )
);

vsu vb_vsu (
    .clk                    ( clk_cpu ),
    .reset_n                ( reset_n && dataslot_allcomplete_s ),
    .ce                     ( cpu_ce ),

    .sel                    ( vsu_sel ),
    .addr                   ( cpu_addr ),
    .we                     ( cpu_we ),
    .be                     ( cpu_be ),
    .wdata                  ( cpu_wdata ),

    .sample_left            ( vsu_sample_left ),
    .sample_right           ( vsu_sample_right )
);

cart_rom vb_cart (
    .load_clk               ( clk_74a ),
    .load_begin             ( dataslot_requestwrite ),
    .load_wr                ( cart_load_wr ),
    .load_addr              ( bridge_addr ),
    .load_data              ( bridge_wr_data ),

    .clk                    ( clk_cpu ),
    .sel                    ( cart_rom_sel ),
    .addr                   ( cpu_addr ),
    .rdata                  ( cart_rom_rdata )
);

// the test-ROM status convention (src/roms/README.md): ROMs report through
// the halfword at WRAM 0x05000000. this latch only observes the bus, so it
// is host-side presentation, not Virtual Boy hardware.

    reg [15:0]  rom_status;

always @(posedge clk_cpu or negedge reset_n) begin
    if(~reset_n) begin
        rom_status <= 16'h0000;
    end else if(cpu_req && cpu_we && cpu_addr == 26'h2800000) begin
        if(cpu_be[0]) rom_status[7:0]  <= cpu_wdata[7:0];
        if(cpu_be[1]) rom_status[15:8] <= cpu_wdata[15:8];
    end
end

// into the video domain for the display. two flops per bundle, no handshake:
// the values only need to read correctly once they hold still, which is when
// a maintainer reads them.
    reg [15:0]  disp_status_m, disp_status;
    reg [15:0]  disp_pc_m, disp_pc;
    reg         disp_halted_m, disp_halted;
    reg         disp_diag_m, disp_diag;

always @(posedge clk_core_12288) begin
    disp_status_m <= rom_status;
    disp_status   <= disp_status_m;
    disp_pc_m     <= cpu_dbg_pc[16:1];
    disp_pc       <= disp_pc_m;
    disp_halted_m <= cpu_dbg_halted;
    disp_halted   <= disp_halted_m;
    disp_diag_m   <= core_cfg[2];
    disp_diag     <= disp_diag_m;
end


// video generation
//
// the raster belongs to host_video_timing; everything here only supplies colour.
// that module carries the reasoning for 480x512 at 12.288 MHz being the machine's
// 20 ms frame.

assign video_rgb_clock = clk_core_12288;
assign video_rgb_clock_90 = clk_core_12288_90deg;
assign video_rgb = !video_de_q      ? 24'h000000 :
                    overlay_on_q    ? overlay_rgb_q :
                                      {vip_display_luma, 16'h0000};
assign video_de = video_de_q;
assign video_skip = 1'b0;
assign video_vs = video_vs_q;
assign video_hs = video_hs_q;

    localparam  VID_H_ACTIVE = 'd384;
    localparam  VID_V_ACTIVE = 'd224;

    wire        vidout_de;
    wire        vidout_vs;
    wire        vidout_hs;
    wire [9:0]  vidout_x;
    wire [9:0]  vidout_y;
    reg         video_de_q;
    reg         video_vs_q;
    reg         video_hs_q;

host_video_timing #(
    .H_ACTIVE               ( VID_H_ACTIVE ),
    .V_ACTIVE               ( VID_V_ACTIVE )
) hvt (
    .clk                    ( clk_core_12288 ),
    .reset_n                ( reset_n ),

    .de                     ( vidout_de ),
    .hs                     ( vidout_hs ),
    .vs                     ( vidout_vs ),
    .x                      ( vidout_x ),
    .y                      ( vidout_y )
);

// the diagnostic overlay, off unless Core Settings turns it on
//
// what the status-reporting ROMs' pass criteria read, restored over the VIP's
// picture rather than instead of it: the centre square outlines always and
// fills solid red when the CPU halts, and two rows of sixteen cells show the
// ROM status halfword (top, MSB left) and PC bits 16-1 (bottom). a maintainer
// reads the failing check number straight off the top row.
//
// off by default because the VIP owns this screen now. a ROM that draws its
// own picture -- every vip-* image, and pad -- would have this drawn on top
// of it, and so would a game, so it is opt-in per ROM rather than furniture.

    localparam  SQUARE      = 'd112;
    localparam  SQUARE_X    = (VID_H_ACTIVE - SQUARE) / 2;
    localparam  SQUARE_Y    = (VID_V_ACTIVE - SQUARE) / 2;

    localparam  CELLS_X     = (VID_H_ACTIVE - 16*16) / 2;
    localparam  STATUS_Y    = 'd24;
    localparam  PC_Y        = 'd184;
    localparam  CELL_H      = 'd16;

    wire        in_square =
                    vidout_x >= SQUARE_X && vidout_x < SQUARE_X+SQUARE &&
                    vidout_y >= SQUARE_Y && vidout_y < SQUARE_Y+SQUARE;

    wire        square_edge = in_square &&
                    (vidout_x == SQUARE_X || vidout_x == SQUARE_X+SQUARE-1 ||
                     vidout_y == SQUARE_Y || vidout_y == SQUARE_Y+SQUARE-1);

    wire [9:0]  cell_x    = vidout_x - CELLS_X;
    wire [3:0]  cell_idx  = cell_x[7:4];
    wire        in_cells  = vidout_x >= CELLS_X && vidout_x < CELLS_X + 16*16 &&
                            cell_x[3:0] < 14;   // 2px gap marks positions
    wire        status_row = in_cells && vidout_y >= STATUS_Y &&
                             vidout_y < STATUS_Y + CELL_H;
    wire        pc_row     = in_cells && vidout_y >= PC_Y &&
                             vidout_y < PC_Y + CELL_H;

    wire        status_bit = disp_status[4'd15 - cell_idx];
    wire        pc_bit     = disp_pc[4'd15 - cell_idx];

    wire        overlay_on = disp_diag &&
                    (square_edge || (in_square && disp_halted) ||
                     status_row || pc_row);

    wire [23:0] overlay_rgb =
                    (square_edge || in_square) ? 24'hFF0000 :
                    status_row ? (status_bit ? 24'hFFFFFF : 24'h282828) :
                                 (pc_bit     ? 24'hFFFFFF : 24'h282828);

    reg         overlay_on_q;
    reg [23:0]  overlay_rgb_q;

// Framebuffer RAM has one display-clock cycle of read latency, so the overlay
// takes the same clock or it would land a pixel early.
always @(posedge clk_core_12288 or negedge reset_n) begin
    if(~reset_n) begin
        video_de_q <= 1'b0;
        video_vs_q <= 1'b0;
        video_hs_q <= 1'b0;
        overlay_on_q <= 1'b0;
    end else begin
        video_de_q <= vidout_de;
        video_vs_q <= vidout_vs;
        video_hs_q <= vidout_hs;
        overlay_on_q <= overlay_on;
    end
end

always @(posedge clk_core_12288) overlay_rgb_q <= overlay_rgb;




//
// APF audio is signed 16-bit stereo I2S at 48 kHz.
//

assign audio_mclk = clk_core_12288;

audio_i2s audio_output (
    .source_clk             ( clk_cpu ),
    .source_left            ( vsu_sample_left ),
    .source_right           ( vsu_sample_right ),
    .mclk                   ( clk_core_12288 ),
    .reset_n                ( reset_n && dataslot_allcomplete_s ),
    .dac                    ( audio_dac ),
    .lrck                   ( audio_lrck )
);


///////////////////////////////////////////////


    wire    clk_core_12288;
    wire    clk_cpu;
    wire    clk_core_12288_90deg;
    
    wire    pll_core_locked;
    wire    pll_core_locked_s;
synch_3 s01(pll_core_locked, pll_core_locked_s, clk_74a);

mf_pllbase mp1 (
    .refclk         ( clk_74a ),
    .rst            ( 0 ),

    .outclk_0       ( clk_core_12288 ),
    .outclk_1       ( clk_core_12288_90deg ),
    // the CPU domain: same VCO as the video clock, so the two never drift
    .outclk_2       ( clk_cpu ),

    .locked         ( pll_core_locked )
);


    
endmodule
