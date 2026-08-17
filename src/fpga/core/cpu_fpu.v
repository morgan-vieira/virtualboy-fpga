`default_nettype none
//
// The V810's floating-point unit: the eight format VII operations that share
// opcode 0x3E with Nintendo's extended instructions. One operation at a time,
// started by the CPU at execute and answered with a done pulse a few clocks
// later; the CPU charges the architectural cycles, so nothing here counts
// time -- it only has to finish well inside the charge's drain (the longest
// walk is DIVF.S at ~30 clocks against a 44-cycle charge).
//
// Semantics follow beetle-vb's fpu path (v810_cpu.cpp + fpu-new/softfloat.c),
// which was corrected against real hardware, over what IEEE or the V810
// manual would suggest where they differ:
//
//  - Only normal reals and zero are operands. NaNs, infinities and non-zero
//    denormals raise the reserved operand exception before any arithmetic
//    [Scroll, CPU > Data Types].
//  - Rounding is to nearest, ties to even, the only mode the part has
//    [TKCW fixed at 0x000000E0].
//  - Overflow does not produce infinity: the exponent wraps by -192 and the
//    wrapped result is written before the exception is raised [softfloat.c's
//    "Mednafen hack" in roundAndPackFloat32].
//  - A result below the normal range is flushed to a signed zero with FUD and
//    FPR set and no exception -- unless it rounds up to the minimum normal,
//    which stands with FPR alone [beetle-vb FPU_Math_Template; deviates from
//    the manual's claim that DIVF.S stores a denormal, and the scroll agrees
//    with beetle that zero is used as the result].
//  - Flags land before any exception is raised, and a killed result (FRO,
//    FIV, FZD) leaves the condition flags and the destination untouched
//    [Scroll, CPU > Floating-Point; beetle-vb CheckFPInputException].
//
// The condition-flag rule for the value-producing operations is beetle's
// SetFPUOPNonFPUFlags: a zero result of either sign gives Z with S and CY
// clear; anything else copies the sign bit into both S and CY. OV always
// clears. CVT.SW and TRNC.SW instead set S and Z from the integer and leave
// CY alone.
//

module cpu_fpu (
    input  wire logic        clk,
    input  wire logic        reset_n,

    // One-clock start pulse; op is the format VII sub-opcode's low four bits
    // (only 0, 2-7 and 0xB arrive here). a is reg2, the destination and left
    // operand; b is reg1.
    input  wire logic        start,
    input  wire logic [3:0]  op,
    input  wire logic [31:0] a,
    input  wire logic [31:0] b,
    // Drops the operation on the floor; the CPU aborts long operations when
    // an interrupt arrives [V810 manual Table 6-2].
    input  wire logic        abort,

    output logic             busy,
    output logic             done,       // one-clock pulse; outputs valid with it

    output logic [31:0]      result,
    output logic             wr_result,  // write result to reg2
    output logic             flags_wr,   // update Z/S/OV (OV always to 0)
    output logic             cy_wr,      // update CY too (all but CVT.SW/TRNC.SW)
    output logic             flag_cy,
    output logic             flag_s,
    output logic             flag_z,
    // {FRO, FIV, FZD, FOV, FUD, FPR}, ORed into PSW bits 9-4 by the CPU.
    output logic [5:0]       fp_flags,
    output logic             exc,        // raise the FP exception (handler 0xFFFFFF60)
    output logic [15:0]      exc_code
);

    localparam logic [3:0] OP_CMPF = 4'h0;
    localparam logic [3:0] OP_CVTW = 4'h2;   // CVT.WS: word to float
    localparam logic [3:0] OP_CVTS = 4'h3;   // CVT.SW: float to word, nearest
    localparam logic [3:0] OP_ADDF = 4'h4;
    localparam logic [3:0] OP_SUBF = 4'h5;
    localparam logic [3:0] OP_MULF = 4'h6;
    localparam logic [3:0] OP_DIVF = 4'h7;
    localparam logic [3:0] OP_TRNC = 4'hB;   // TRNC.SW: float to word, toward zero

    typedef enum logic [3:0] {
        IDLE,
        CHECK,      // reserved operands, zero specials, dispatch
        ADD_ALIGN,  // ADDF/SUBF: align the smaller operand
        ADD_SUM,    // add or subtract the aligned mantissas
        MUL_PROD,   // MULF: consume the 24x24 product
        DIV_RUN,    // DIVF: one quotient bit per clock
        CVT_INT,    // CVT.SW / TRNC.SW: shift and round to integer
        NORM,       // shift the leading 1 to the top of the frame
        ROUND,      // round to nearest even, classify
        DENORM,     // re-round in the subnormal position: flush or promote
        FINISH      // one clock to present registered outputs
    } state_t;

    state_t state;

    // The operation in flight.
    logic [3:0]  cur_op;
    logic [31:0] fa, fb;

    // Operand fields. After CHECK passes, exp == 0 means a true zero.
    wire logic        a_sign = fa[31];
    wire logic [7:0]  a_exp  = fa[30:23];
    wire logic        b_sign = fb[31];
    wire logic [7:0]  b_exp  = fb[30:23];
    wire logic        a_zero = a_exp == 8'd0;
    wire logic        b_zero = b_exp == 8'd0;
    wire logic [23:0] a_mant = {1'b1, fa[22:0]};
    wire logic [23:0] b_mant = {1'b1, fb[22:0]};

    // SUBF is ADDF with reg1's sign flipped.
    wire logic beff_sign = cur_op == OP_SUBF ? ~b_sign : b_sign;

    // NaNs, infinities and non-zero denormals; zero itself passes.
    function automatic logic reserved(input logic [31:0] v);
        return v[30:0] != 31'd0 && (v[30:23] == 8'h00 || v[30:23] == 8'hFF);
    endfunction

    // ------------------------------------------------------------------
    // The shared normalize/round frame: value = (m / 2^33) x 2^(e - 127),
    // so a normalized m carries its leading 1 at bit 33 and e is the packed
    // exponent field a normal result would take. Bits lost below the frame
    // are jammed into bit 0; the jam never rises above the sticky region,
    // because a large normalize shift only happens when nothing was jammed
    // (the argument softfloat's subtract path rests on).
    // ------------------------------------------------------------------

    logic [33:0]        norm_m;
    logic signed [11:0] norm_e;
    logic               r_sign;

    // Post-NORM frame.
    logic [33:0]        m_q;
    logic signed [11:0] e_q;

    // Add/sub operands, aligned by ADD_ALIGN.
    logic [33:0] add_big_q, add_small_q;
    logic        add_sub;                  // effective subtraction
    logic signed [11:0] add_e;

    // Divide bookkeeping.
    logic [24:0] div_rem;
    logic [25:0] div_q;
    logic [4:0]  div_cnt;

    // Registered results, presented with done.
    logic [31:0] res_d;
    logic        wr_d, flags_d, cy_wr_d;
    logic        cy_d, s_d, z_d;
    logic [5:0]  fpf_d;
    logic        exc_d;
    logic [15:0] code_d;

    // The 24x24 product on the DSP path, operands registered at CHECK.
    // mul_b doubles as the divisor DIV_RUN subtracts.
    logic [23:0] mul_a, mul_b;
    wire logic [47:0] mul_p = mul_a * mul_b;

    function automatic logic [5:0] clz34(input logic [33:0] v);
        logic [5:0] n;
        integer i;
        n = 6'd34;
        for (i = 0; i < 34; i = i + 1)
            if (v[i]) n = 6'd33 - i[5:0];
        return n;
    endfunction

    // Signed-float less-than for CMPF.S; +0 and -0 compare equal.
    function automatic logic flt(input logic [31:0] x, input logic [31:0] y);
        if (x[30:0] == 31'd0 && y[30:0] == 31'd0) return 1'b0;
        if (x[31] != y[31])                       return x[31];
        return x[31] ? x[30:0] > y[30:0] : x[30:0] < y[30:0];
    endfunction

    // Present a finished value-producing result: condition flags from the
    // packed word per SetFPUOPNonFPUFlags, plus the FP status that came out.
    task automatic present(input logic [31:0] value, input logic [5:0] fpf,
                           input logic raise, input logic [15:0] code);
        res_d   <= value;
        wr_d    <= 1'b1;
        flags_d <= 1'b1;
        cy_wr_d <= 1'b1;
        z_d     <= value[30:0] == 31'd0;
        s_d     <= value[30:0] != 31'd0 && value[31];
        cy_d    <= value[30:0] != 31'd0 && value[31];
        fpf_d   <= fpf;
        exc_d   <= raise;
        code_d  <= code;
        state   <= FINISH;
    endtask

    // Kill the operation: FP status flag and exception only, nothing written.
    task automatic kill(input logic [5:0] fpf, input logic [15:0] code);
        wr_d    <= 1'b0;
        flags_d <= 1'b0;
        cy_wr_d <= 1'b0;
        fpf_d   <= fpf;
        exc_d   <= 1'b1;
        code_d  <= code;
        state   <= FINISH;
    endtask

    always_ff @(posedge clk or negedge reset_n) begin : machine
        // Blocking scratch, never read across cycles.
        logic        chk_a, chk_b;
        logic [5:0]  lz;
        logic [11:0] diff;
        logic [33:0] abig, asmall, asmall_sh;
        logic [34:0] sum;
        logic        jam;
        logic [23:0] mant;
        logic [24:0] rounded;
        logic        g, rs, inexact, up;
        logic signed [11:0] e2, dsh12;
        logic [5:0]  dsh;
        logic [33:0] dm;
        logic [24:0] rs25, rem_nx;
        logic [25:0] q_nx;
        logic [63:0] wide;
        logic [7:0]  csh;
        logic [31:0] mag, ires;

        if (!reset_n) begin
            state <= IDLE;
            done  <= 1'b0;
        end else begin
            done <= 1'b0;

            if (abort) begin
                state <= IDLE;
            end else begin
                case (state)

                    IDLE: if (start) begin
                        cur_op <= op;
                        fa     <= a;
                        fb     <= b;
                        state  <= CHECK;
                    end

                    CHECK: begin
                        // Registered here so the DSP sees stable operands one
                        // clock before MUL_PROD consumes the product.
                        mul_a <= a_mant;
                        mul_b <= b_mant;

                        // Reserved operands first, then the divide specials:
                        // the priority order FRO > FIV > FZD is the documented
                        // one [Scroll, CPU > Floating-Point].
                        chk_a = cur_op == OP_CMPF || cur_op == OP_ADDF
                                || cur_op == OP_SUBF || cur_op == OP_MULF
                                || cur_op == OP_DIVF;
                        chk_b = chk_a || cur_op == OP_CVTS
                                || cur_op == OP_TRNC;

                        if ((chk_a && reserved(fa))
                            || (chk_b && reserved(fb))) begin
                            kill(6'b100000, 16'hFF60);
                        end else begin
                            case (cur_op)
                                OP_CMPF: begin
                                    // result <- reg2 - reg1, flags only:
                                    // Z with S and CY clear on equality,
                                    // else S = CY = (reg2 < reg1).
                                    wr_d    <= 1'b0;
                                    flags_d <= 1'b1;
                                    cy_wr_d <= 1'b1;
                                    z_d     <= fa == fb
                                               || (fa[30:0] == 31'd0
                                                   && fb[30:0] == 31'd0);
                                    s_d     <= flt(fa, fb);
                                    cy_d    <= flt(fa, fb);
                                    fpf_d   <= 6'd0;
                                    exc_d   <= 1'b0;
                                    state   <= FINISH;
                                end

                                OP_ADDF, OP_SUBF: begin
                                    if (a_zero && b_zero)
                                        // Same effective signs keep the sign;
                                        // opposites give +0 under round-to-
                                        // nearest [softfloat addFloat32Sigs].
                                        present({a_sign && beff_sign, 31'd0},
                                                6'd0, 1'b0, 16'h0);
                                    else if (a_zero)
                                        present({beff_sign, fb[30:0]},
                                                6'd0, 1'b0, 16'h0);
                                    else if (b_zero)
                                        present(fa, 6'd0, 1'b0, 16'h0);
                                    else
                                        state <= ADD_ALIGN;
                                end

                                OP_MULF: begin
                                    if (a_zero || b_zero)
                                        present({a_sign ^ b_sign, 31'd0},
                                                6'd0, 1'b0, 16'h0);
                                    else begin
                                        r_sign <= a_sign ^ b_sign;
                                        state  <= MUL_PROD;
                                    end
                                end

                                OP_DIVF: begin
                                    if (b_zero && a_zero)
                                        kill(6'b010000, 16'hFF70);  // 0/0: FIV
                                    else if (b_zero)
                                        kill(6'b001000, 16'hFF68);  // x/0: FZD
                                    else if (a_zero)
                                        present({a_sign ^ b_sign, 31'd0},
                                                6'd0, 1'b0, 16'h0);
                                    else begin
                                        r_sign  <= a_sign ^ b_sign;
                                        div_rem <= {1'b0, a_mant};
                                        div_q   <= 26'd0;
                                        div_cnt <= 5'd25;
                                        state   <= DIV_RUN;
                                    end
                                end

                                OP_CVTW: begin
                                    if (fb == 32'd0)
                                        present(32'd0, 6'd0, 1'b0, 16'h0);
                                    else begin
                                        r_sign <= fb[31];
                                        mag    = fb[31] ? -fb : fb;
                                        norm_m <= {2'b00, mag};
                                        norm_e <= 12'sd160;
                                        state  <= NORM;
                                    end
                                end

                                OP_CVTS, OP_TRNC: state <= CVT_INT;

                                default: state <= IDLE;
                            endcase
                        end
                    end

                    ADD_ALIGN: begin
                        // Both operands enter at bit 32 of the frame, leaving
                        // nine guard bits under the mantissa; the smaller
                        // shifts right with its lost bits jammed into bit 0.
                        if (a_exp > b_exp
                            || (a_exp == b_exp && a_mant >= b_mant)) begin
                            abig    = {1'b0, a_mant, 9'd0};
                            asmall  = {1'b0, b_mant, 9'd0};
                            diff   = {4'd0, a_exp} - {4'd0, b_exp};
                            add_e <= $signed({4'd0, a_exp}) + 12'sd1;
                            r_sign <= a_sign;
                        end else begin
                            abig    = {1'b0, b_mant, 9'd0};
                            asmall  = {1'b0, a_mant, 9'd0};
                            diff   = {4'd0, b_exp} - {4'd0, a_exp};
                            add_e <= $signed({4'd0, b_exp}) + 12'sd1;
                            r_sign <= beff_sign;
                        end
                        if (diff > 12'd33) begin
                            jam      = asmall != 34'd0;
                            asmall_sh = 34'd0;
                        end else begin
                            jam      = (asmall
                                        & ~(34'h3_FFFF_FFFF << diff[5:0]))
                                       != 34'd0;
                            asmall_sh = asmall >> diff[5:0];
                        end
                        add_big_q   <= abig;
                        add_small_q <= asmall_sh | {33'd0, jam};
                        add_sub     <= a_sign != beff_sign;
                        state       <= ADD_SUM;
                    end

                    ADD_SUM: begin
                        if (add_sub)
                            sum = {1'b0, add_big_q} - {1'b0, add_small_q};
                        else
                            sum = {1'b0, add_big_q} + {1'b0, add_small_q};
                        // Operands entered at bit 32, so a carry lands
                        // exactly at the frame's anchor bit 33.
                        norm_m <= sum[33:0];
                        norm_e <= add_e;
                        state  <= NORM;
                    end

                    MUL_PROD: begin
                        // Product of two [1,2) mantissas: MSB at bit 47 or
                        // 46. Keep the top 34 bits and jam the rest.
                        norm_m <= {mul_p[47:15],
                                   mul_p[14] || mul_p[13:0] != 14'd0};
                        norm_e <= $signed({4'd0, a_exp})
                                  + $signed({4'd0, b_exp}) - 12'sd126;
                        state  <= NORM;
                    end

                    DIV_RUN: begin
                        // Restoring divide: 26 quotient bits give the [0.5,2)
                        // quotient a mantissa, a guard and a round bit; the
                        // remainder is the sticky. The first bit is the
                        // unshifted compare -- the quotient can reach 2.
                        rs25 = div_cnt == 5'd25 ? div_rem
                                                : {div_rem[23:0], 1'b0};
                        if (rs25 >= {1'b0, mul_b}) begin
                            rem_nx = rs25 - {1'b0, mul_b};
                            q_nx   = {div_q[24:0], 1'b1};
                        end else begin
                            rem_nx = rs25;
                            q_nx   = {div_q[24:0], 1'b0};
                        end
                        div_rem <= rem_nx;
                        div_q   <= q_nx;
                        div_cnt <= div_cnt - 5'd1;
                        if (div_cnt == 5'd0) begin
                            norm_m <= {q_nx, 8'd0}
                                      | {33'd0, rem_nx != 25'd0};
                            norm_e <= $signed({4'd0, a_exp})
                                      - $signed({4'd0, b_exp}) + 12'sd127;
                            state  <= NORM;
                        end
                    end

                    CVT_INT: begin
                        // Float to integer. Out of word range raises the
                        // invalid operation exception and kills the result
                        // [softfloat float32_to_int32; manual CVT.SW note].
                        if (b_exp >= 8'd158) begin
                            if (fb == 32'hCF00_0000) begin
                                // Exactly -2^31 is representable.
                                res_d   <= 32'h8000_0000;
                                wr_d    <= 1'b1;
                                flags_d <= 1'b1;
                                cy_wr_d <= 1'b0;
                                z_d     <= 1'b0;
                                s_d     <= 1'b1;
                                fpf_d   <= 6'd0;
                                exc_d   <= 1'b0;
                                state   <= FINISH;
                            end else begin
                                kill(6'b010000, 16'hFF70);
                            end
                        end else begin
                            // Integer part lands in [63:32]: guard at 31,
                            // sticky below, both zero for exact conversions.
                            wide = {8'd0, b_zero ? 24'd0 : b_mant, 32'd0};
                            if (b_exp >= 8'd150)
                                wide = wide << (b_exp - 8'd150);
                            else begin
                                csh = 8'd150 - b_exp;
                                // Everything shifts out: pure sticky, except
                                // for a true zero, which converts exactly.
                                if (csh > 8'd56) wide = {63'd0, !b_zero};
                                else             wide = wide >> csh;
                            end
                            inexact = wide[31:0] != 32'd0;
                            up = cur_op == OP_CVTS
                                 && wide[31]
                                 && (wide[30:0] != 31'd0 || wide[32]);
                            mag  = wide[63:32] + {31'd0, up};
                            ires = b_sign ? -mag : mag;
                            res_d   <= ires;
                            wr_d    <= 1'b1;
                            flags_d <= 1'b1;
                            cy_wr_d <= 1'b0;
                            z_d     <= ires == 32'd0;
                            s_d     <= ires[31];
                            fpf_d   <= inexact ? 6'b000001 : 6'd0;
                            exc_d   <= 1'b0;
                            state   <= FINISH;
                        end
                    end

                    NORM: begin
                        if (norm_m == 34'd0)
                            // Exact zero, positive under round-to-nearest.
                            present(32'd0, 6'd0, 1'b0, 16'h0);
                        else begin
                            lz    = clz34(norm_m);
                            m_q   <= norm_m << lz;
                            e_q   <= norm_e - $signed({6'd0, lz});
                            state <= ROUND;
                        end
                    end

                    ROUND: begin
                        // Mantissa at [33:10], guard at 9, sticky below.
                        mant    = m_q[33:10];
                        g       = m_q[9];
                        rs      = m_q[8:0] != 9'd0;
                        inexact = g || rs;
                        up      = g && (rs || m_q[10]);
                        rounded = {1'b0, mant} + {24'd0, up};
                        e2      = rounded[24] ? e_q + 12'sd1 : e_q;
                        mant    = rounded[24] ? 24'h80_0000 : rounded[23:0];

                        if (e_q <= 12'sd0)
                            // Classified before rounding, the way softfloat's
                            // zExp < 0 branch is.
                            state <= DENORM;
                        else if (e2 >= 12'sd255)
                            // Overflow: the wrapped result is written and the
                            // flags land before the exception is raised.
                            present({r_sign, e2[7:0] - 8'd192, mant[22:0]},
                                    inexact ? 6'b000101 : 6'b000100,
                                    1'b1, 16'hFF64);
                        else
                            present({r_sign, e2[7:0], mant[22:0]},
                                    inexact ? 6'b000001 : 6'd0,
                                    1'b0, 16'h0);
                    end

                    DENORM: begin
                        // Re-round in the subnormal position. Rounding up to
                        // the minimum normal stands with FPR alone; anything
                        // else flushes to a signed zero with FUD and FPR.
                        dsh12 = 12'sd1 - e_q;
                        dsh   = dsh12 > 12'sd33 ? 6'd33 : dsh12[5:0];
                        jam   = (m_q & ~(34'h3_FFFF_FFFF << dsh)) != 34'd0;
                        dm    = (m_q >> dsh) | {33'd0, jam};
                        up    = dm[9] && (dm[8:0] != 9'd0 || dm[10]);
                        rounded = {1'b0, dm[33:10]} + {24'd0, up};
                        if (rounded[23:0] == 24'h80_0000)
                            present({r_sign, 8'd1, 23'd0},
                                    6'b000001, 1'b0, 16'h0);
                        else
                            present({r_sign, 31'd0},
                                    6'b000011, 1'b0, 16'h0);
                    end

                    FINISH: begin
                        done  <= 1'b1;
                        state <= IDLE;
                    end

                    default: state <= IDLE;
                endcase
            end
        end
    end

    assign busy      = state != IDLE;
    assign result    = res_d;
    assign wr_result = wr_d;
    assign flags_wr  = flags_d;
    assign cy_wr     = cy_wr_d;
    assign flag_cy   = cy_d;
    assign flag_s    = s_d;
    assign flag_z    = z_d;
    assign fp_flags  = fpf_d;
    assign exc       = exc_d;
    assign exc_code  = code_d;

endmodule

`default_nettype wire
