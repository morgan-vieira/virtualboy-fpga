`default_nettype none
//
// Maps the Pocket's controller onto the Virtual Boy's 16-bit report. Named
// for the host side on purpose: the machine's pad has two D-pads and
// fourteen buttons, the Pocket has one D-pad and eight, and no mapping can
// reach all fourteen at once. Which two go missing is the only real choice
// here, so it is a setting rather than a constant.
//
// The default is the layout morgan-vieira chose (Controller.md, 2026-08-16,
// which settles TODO's open decision 2): the Pocket's D-pad is the left
// pad, its face buttons are the right pad in the diamond the hardware
// already draws, and L and R are the machine's A and B, the two buttons
// games press most. That leaves Select and Start standing in for the
// machine's L and R, and the machine's own Select and Start unreachable --
// which the note flags with "or swap with L/R if preferred", so the swap is
// the second setting.
//
// Report bit numbering is the scroll's, and game_pad.v carries the note on
// why the wiki article numbers the same bits backwards.
//

module host_pad_map (
    // The Pocket's key bitmap, in the APF layout core_top documents.
    input  wire logic [15:0] key,

    // cfg[0]: the Pocket D-pad drives the machine's right pad instead of
    //         its left, swapping the face buttons with it. Games built
    //         around the right pad want this.
    // cfg[1]: Select and Start report as the machine's Select and Start
    //         rather than as its L and R.
    input  wire logic [1:0]  cfg,

    output wire logic [15:0] buttons
);

    // APF's key bitmap: 0 up, 1 down, 2 left, 3 right, 4 A, 5 B, 6 X, 7 Y,
    // 8 L1, 9 R1, 14 Select, 15 Start. The face cluster reads as a D-pad in
    // the SNES arrangement the diamond suggests -- X up, B down, Y left,
    // A right.
    wire logic [3:0] dpad  = {key[3],  key[2],  key[1], key[0]}; // R,L,D,U
    wire logic [3:0] faces = {key[4],  key[7],  key[5], key[6]}; // A,Y,B,X

    wire logic [3:0] pad_l = cfg[0] ? faces : dpad;
    wire logic [3:0] pad_r = cfg[0] ? dpad  : faces;

    wire logic sel_start = cfg[1];

    assign buttons = {
        pad_r[1],               // 15 RD  right pad down
        pad_r[2],               // 14 RL  right pad left
        sel_start & key[14],    // 13 SEL
        sel_start & key[15],    // 12 STA
        pad_l[0],               // 11 LU  left pad up
        pad_l[1],               // 10 LD  left pad down
        pad_l[2],               //  9 LL  left pad left
        pad_l[3],               //  8 LR  left pad right
        pad_r[3],               //  7 RR  right pad right
        pad_r[0],               //  6 RU  right pad up
        !sel_start & key[14],   //  5 LT  L, the machine's rear left
        !sel_start & key[15],   //  4 RT  R, the machine's rear right
        key[9],                 //  3 B
        key[8],                 //  2 A
        1'b1,                   //  1 SGN a standard controller always sets
        1'b0                    //  0 PWR low battery, and the Pocket's
                                //        battery never reaches the core
    };

endmodule

`default_nettype wire
