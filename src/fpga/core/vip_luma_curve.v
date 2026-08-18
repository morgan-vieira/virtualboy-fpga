`default_nettype none

// Gamma-encodes a VIP exposure count for the Pocket's panel.
//
// BRTA/BRTB/BRTC are exposure times, not display levels. A pixel lit for 33 of
// a column's 50 ns ticks is 13% of full LED drive, and handing 33/255 straight
// to the scaler renders a title screen at half brightness -- which is what this
// core did before.
//
// The table is round(255 * (exposure/255) ** (1/2.2)): LED output is linear in
// duty cycle, so exposure is linear light, and a 2.2 display wants it encoded
// with the plain inverse. beetle-vb does exactly this and nothing else
// (`mednafen/vb/vip.c` MakeColorLUT), so we follow it.
//
// We used to follow MiSTer's SDR table instead, as round(255 *
// (exposure/255) ** (1.4/2.2)) -- the same encode against the 1.4 rendering
// gamma a dark surround wants. On the Pocket that was too dark to play
// [morgan-vieira, 2026-08-18], so the departure is deliberate and it is a
// readability choice, not a claim about the hardware. Upstream Mednafen's
// variant is a third option we reject: its 1.75x LED-on scale clips every
// exposure from 146 up to the same white, flattening the top half of a
// BRTA/BRTB/BRTC fade.
//
// Ours is generated from the formula rather than copied, so vip_luma_curve's
// bench checks every entry against it.
//
// Absolute, not normalized. A game that halves BRTA gets a dimmer picture,
// because full drive is an exposure of 255 and nothing rescales to the
// brightest level a frame happens to use.

module vip_luma_curve (
    input  logic [7:0] exposure,
    output logic [7:0] luma
);

    always_comb begin
        case (exposure)
            8'd000: luma = 8'd000;  8'd001: luma = 8'd021;  8'd002: luma = 8'd028;  8'd003: luma = 8'd034;
            8'd004: luma = 8'd039;  8'd005: luma = 8'd043;  8'd006: luma = 8'd046;  8'd007: luma = 8'd050;
            8'd008: luma = 8'd053;  8'd009: luma = 8'd056;  8'd010: luma = 8'd059;  8'd011: luma = 8'd061;
            8'd012: luma = 8'd064;  8'd013: luma = 8'd066;  8'd014: luma = 8'd068;  8'd015: luma = 8'd070;
            8'd016: luma = 8'd072;  8'd017: luma = 8'd074;  8'd018: luma = 8'd076;  8'd019: luma = 8'd078;
            8'd020: luma = 8'd080;  8'd021: luma = 8'd082;  8'd022: luma = 8'd084;  8'd023: luma = 8'd085;
            8'd024: luma = 8'd087;  8'd025: luma = 8'd089;  8'd026: luma = 8'd090;  8'd027: luma = 8'd092;
            8'd028: luma = 8'd093;  8'd029: luma = 8'd095;  8'd030: luma = 8'd096;  8'd031: luma = 8'd098;
            8'd032: luma = 8'd099;  8'd033: luma = 8'd101;  8'd034: luma = 8'd102;  8'd035: luma = 8'd103;
            8'd036: luma = 8'd105;  8'd037: luma = 8'd106;  8'd038: luma = 8'd107;  8'd039: luma = 8'd109;
            8'd040: luma = 8'd110;  8'd041: luma = 8'd111;  8'd042: luma = 8'd112;  8'd043: luma = 8'd114;
            8'd044: luma = 8'd115;  8'd045: luma = 8'd116;  8'd046: luma = 8'd117;  8'd047: luma = 8'd118;
            8'd048: luma = 8'd119;  8'd049: luma = 8'd120;  8'd050: luma = 8'd122;  8'd051: luma = 8'd123;
            8'd052: luma = 8'd124;  8'd053: luma = 8'd125;  8'd054: luma = 8'd126;  8'd055: luma = 8'd127;
            8'd056: luma = 8'd128;  8'd057: luma = 8'd129;  8'd058: luma = 8'd130;  8'd059: luma = 8'd131;
            8'd060: luma = 8'd132;  8'd061: luma = 8'd133;  8'd062: luma = 8'd134;  8'd063: luma = 8'd135;
            8'd064: luma = 8'd136;  8'd065: luma = 8'd137;  8'd066: luma = 8'd138;  8'd067: luma = 8'd139;
            8'd068: luma = 8'd140;  8'd069: luma = 8'd141;  8'd070: luma = 8'd142;  8'd071: luma = 8'd143;
            8'd072: luma = 8'd144;  8'd073: luma = 8'd144;  8'd074: luma = 8'd145;  8'd075: luma = 8'd146;
            8'd076: luma = 8'd147;  8'd077: luma = 8'd148;  8'd078: luma = 8'd149;  8'd079: luma = 8'd150;
            8'd080: luma = 8'd151;  8'd081: luma = 8'd151;  8'd082: luma = 8'd152;  8'd083: luma = 8'd153;
            8'd084: luma = 8'd154;  8'd085: luma = 8'd155;  8'd086: luma = 8'd156;  8'd087: luma = 8'd156;
            8'd088: luma = 8'd157;  8'd089: luma = 8'd158;  8'd090: luma = 8'd159;  8'd091: luma = 8'd160;
            8'd092: luma = 8'd160;  8'd093: luma = 8'd161;  8'd094: luma = 8'd162;  8'd095: luma = 8'd163;
            8'd096: luma = 8'd164;  8'd097: luma = 8'd164;  8'd098: luma = 8'd165;  8'd099: luma = 8'd166;
            8'd100: luma = 8'd167;  8'd101: luma = 8'd167;  8'd102: luma = 8'd168;  8'd103: luma = 8'd169;
            8'd104: luma = 8'd170;  8'd105: luma = 8'd170;  8'd106: luma = 8'd171;  8'd107: luma = 8'd172;
            8'd108: luma = 8'd173;  8'd109: luma = 8'd173;  8'd110: luma = 8'd174;  8'd111: luma = 8'd175;
            8'd112: luma = 8'd175;  8'd113: luma = 8'd176;  8'd114: luma = 8'd177;  8'd115: luma = 8'd178;
            8'd116: luma = 8'd178;  8'd117: luma = 8'd179;  8'd118: luma = 8'd180;  8'd119: luma = 8'd180;
            8'd120: luma = 8'd181;  8'd121: luma = 8'd182;  8'd122: luma = 8'd182;  8'd123: luma = 8'd183;
            8'd124: luma = 8'd184;  8'd125: luma = 8'd184;  8'd126: luma = 8'd185;  8'd127: luma = 8'd186;
            8'd128: luma = 8'd186;  8'd129: luma = 8'd187;  8'd130: luma = 8'd188;  8'd131: luma = 8'd188;
            8'd132: luma = 8'd189;  8'd133: luma = 8'd190;  8'd134: luma = 8'd190;  8'd135: luma = 8'd191;
            8'd136: luma = 8'd192;  8'd137: luma = 8'd192;  8'd138: luma = 8'd193;  8'd139: luma = 8'd194;
            8'd140: luma = 8'd194;  8'd141: luma = 8'd195;  8'd142: luma = 8'd195;  8'd143: luma = 8'd196;
            8'd144: luma = 8'd197;  8'd145: luma = 8'd197;  8'd146: luma = 8'd198;  8'd147: luma = 8'd199;
            8'd148: luma = 8'd199;  8'd149: luma = 8'd200;  8'd150: luma = 8'd200;  8'd151: luma = 8'd201;
            8'd152: luma = 8'd202;  8'd153: luma = 8'd202;  8'd154: luma = 8'd203;  8'd155: luma = 8'd203;
            8'd156: luma = 8'd204;  8'd157: luma = 8'd205;  8'd158: luma = 8'd205;  8'd159: luma = 8'd206;
            8'd160: luma = 8'd206;  8'd161: luma = 8'd207;  8'd162: luma = 8'd207;  8'd163: luma = 8'd208;
            8'd164: luma = 8'd209;  8'd165: luma = 8'd209;  8'd166: luma = 8'd210;  8'd167: luma = 8'd210;
            8'd168: luma = 8'd211;  8'd169: luma = 8'd212;  8'd170: luma = 8'd212;  8'd171: luma = 8'd213;
            8'd172: luma = 8'd213;  8'd173: luma = 8'd214;  8'd174: luma = 8'd214;  8'd175: luma = 8'd215;
            8'd176: luma = 8'd215;  8'd177: luma = 8'd216;  8'd178: luma = 8'd217;  8'd179: luma = 8'd217;
            8'd180: luma = 8'd218;  8'd181: luma = 8'd218;  8'd182: luma = 8'd219;  8'd183: luma = 8'd219;
            8'd184: luma = 8'd220;  8'd185: luma = 8'd220;  8'd186: luma = 8'd221;  8'd187: luma = 8'd221;
            8'd188: luma = 8'd222;  8'd189: luma = 8'd223;  8'd190: luma = 8'd223;  8'd191: luma = 8'd224;
            8'd192: luma = 8'd224;  8'd193: luma = 8'd225;  8'd194: luma = 8'd225;  8'd195: luma = 8'd226;
            8'd196: luma = 8'd226;  8'd197: luma = 8'd227;  8'd198: luma = 8'd227;  8'd199: luma = 8'd228;
            8'd200: luma = 8'd228;  8'd201: luma = 8'd229;  8'd202: luma = 8'd229;  8'd203: luma = 8'd230;
            8'd204: luma = 8'd230;  8'd205: luma = 8'd231;  8'd206: luma = 8'd231;  8'd207: luma = 8'd232;
            8'd208: luma = 8'd232;  8'd209: luma = 8'd233;  8'd210: luma = 8'd233;  8'd211: luma = 8'd234;
            8'd212: luma = 8'd234;  8'd213: luma = 8'd235;  8'd214: luma = 8'd235;  8'd215: luma = 8'd236;
            8'd216: luma = 8'd236;  8'd217: luma = 8'd237;  8'd218: luma = 8'd237;  8'd219: luma = 8'd238;
            8'd220: luma = 8'd238;  8'd221: luma = 8'd239;  8'd222: luma = 8'd239;  8'd223: luma = 8'd240;
            8'd224: luma = 8'd240;  8'd225: luma = 8'd241;  8'd226: luma = 8'd241;  8'd227: luma = 8'd242;
            8'd228: luma = 8'd242;  8'd229: luma = 8'd243;  8'd230: luma = 8'd243;  8'd231: luma = 8'd244;
            8'd232: luma = 8'd244;  8'd233: luma = 8'd245;  8'd234: luma = 8'd245;  8'd235: luma = 8'd246;
            8'd236: luma = 8'd246;  8'd237: luma = 8'd247;  8'd238: luma = 8'd247;  8'd239: luma = 8'd248;
            8'd240: luma = 8'd248;  8'd241: luma = 8'd249;  8'd242: luma = 8'd249;  8'd243: luma = 8'd249;
            8'd244: luma = 8'd250;  8'd245: luma = 8'd250;  8'd246: luma = 8'd251;  8'd247: luma = 8'd251;
            8'd248: luma = 8'd252;  8'd249: luma = 8'd252;  8'd250: luma = 8'd253;  8'd251: luma = 8'd253;
            8'd252: luma = 8'd254;  8'd253: luma = 8'd254;
            default: luma = 8'd255;
        endcase
    end

endmodule

`default_nettype wire
