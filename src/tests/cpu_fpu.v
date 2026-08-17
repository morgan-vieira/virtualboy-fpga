`timescale 1ns/1ps
//
// Exercises cpu_fpu against hand-picked vectors whose expected words were
// derived from the reference model: beetle-vb's fpu path (softfloat.c with
// the Mednafen overflow hack) -- reproduced with float64 arithmetic rounded
// back to float32, which is exact for these operations, then the V810's
// overflow wrap and flush-to-zero applied per beetle-vb. Each vector states
// the full contract: result word, whether it writes, the condition flags,
// the FP status flags, and the exception code.
//
// Sub-opcodes: 0 CMPF.S, 2 CVT.WS, 3 CVT.SW, 4 ADDF.S, 5 SUBF.S, 6 MULF.S,
// 7 DIVF.S, B TRNC.SW. fp_flags is {FRO,FIV,FZD,FOV,FUD,FPR}.
//

module cpu_fpu_tb;

    reg clk = 1'b0;
    always #5 clk = ~clk;

    reg reset_n = 1'b0;
    reg start = 1'b0;
    reg abort = 1'b0;
    reg [3:0] op = 4'd0;
    reg [31:0] a = 32'd0, b = 32'd0;

    wire        busy, done;
    wire [31:0] result;
    wire        wr_result, flags_wr, cy_wr;
    wire        flag_cy, flag_s, flag_z;
    wire [5:0]  fp_flags;
    wire        exc;
    wire [15:0] exc_code;

    cpu_fpu dut (
        .clk(clk), .reset_n(reset_n),
        .start(start), .op(op), .a(a), .b(b), .abort(abort),
        .busy(busy), .done(done),
        .result(result), .wr_result(wr_result),
        .flags_wr(flags_wr), .cy_wr(cy_wr),
        .flag_cy(flag_cy), .flag_s(flag_s), .flag_z(flag_z),
        .fp_flags(fp_flags), .exc(exc), .exc_code(exc_code)
    );

    integer cycles;

    task automatic run(input [3:0] o, input [31:0] va, input [31:0] vb);
        begin
            @(negedge clk);
            op    = o;
            a     = va;
            b     = vb;
            start = 1'b1;
            @(negedge clk);
            start = 1'b0;
            cycles = 0;
            while (!done) begin
                @(negedge clk);
                cycles = cycles + 1;
                if (cycles > 100)
                    $fatal(1, "op %0h a=%08x b=%08x: no done after 100 clocks",
                           o, va, vb);
            end
        end
    endtask

    // A value-producing pass: result written, condition flags per
    // SetFPUOPNonFPUFlags, chosen FP status flags, no exception.
    task automatic expect_val(input [3:0] o, input [31:0] va, input [31:0] vb,
                              input [31:0] want, input [5:0] fpf,
                              input string what);
        begin
            run(o, va, vb);
            if (!wr_result || !flags_wr || !cy_wr)
                $fatal(1, "%0s: expected a written result with full flags", what);
            if (result !== want)
                $fatal(1, "%0s: result %08x, expected %08x", what, result, want);
            if (fp_flags !== fpf)
                $fatal(1, "%0s: fp_flags %06b, expected %06b", what, fp_flags, fpf);
            if (exc)
                $fatal(1, "%0s: unexpected exception %04x", what, exc_code);
            if (flag_z !== (want[30:0] == 31'd0))
                $fatal(1, "%0s: Z is %b for %08x", what, flag_z, want);
            if (flag_s !== (want[30:0] != 31'd0 && want[31]))
                $fatal(1, "%0s: S is %b for %08x", what, flag_s, want);
            if (flag_cy !== (want[30:0] != 31'd0 && want[31]))
                $fatal(1, "%0s: CY is %b for %08x", what, flag_cy, want);
        end
    endtask

    // An overflow: wrapped result written, flags from it, FOV exception.
    task automatic expect_ovf(input [3:0] o, input [31:0] va, input [31:0] vb,
                              input [31:0] want, input [5:0] fpf,
                              input string what);
        begin
            run(o, va, vb);
            if (!wr_result || !flags_wr)
                $fatal(1, "%0s: overflow must still write its wrapped result", what);
            if (result !== want)
                $fatal(1, "%0s: result %08x, expected %08x", what, result, want);
            if (fp_flags !== fpf)
                $fatal(1, "%0s: fp_flags %06b, expected %06b", what, fp_flags, fpf);
            if (!exc || exc_code !== 16'hFF64)
                $fatal(1, "%0s: expected the FOV exception, got exc=%b code=%04x",
                       what, exc, exc_code);
        end
    endtask

    // A killed operation: nothing written, no condition flags, one FP status
    // flag, the named exception code.
    task automatic expect_kill(input [3:0] o, input [31:0] va, input [31:0] vb,
                               input [5:0] fpf, input [15:0] code,
                               input string what);
        begin
            run(o, va, vb);
            if (wr_result || flags_wr || cy_wr)
                $fatal(1, "%0s: a killed op must write nothing", what);
            if (fp_flags !== fpf)
                $fatal(1, "%0s: fp_flags %06b, expected %06b", what, fp_flags, fpf);
            if (!exc || exc_code !== code)
                $fatal(1, "%0s: expected code %04x, got exc=%b code=%04x",
                       what, code, exc, exc_code);
        end
    endtask

    // A conversion result: S and Z from the integer, CY untouched.
    task automatic expect_int(input [3:0] o, input [31:0] vb,
                              input [31:0] want, input [5:0] fpf,
                              input string what);
        begin
            run(o, 32'h0, vb);
            if (!wr_result || !flags_wr || cy_wr)
                $fatal(1, "%0s: conversions write S/Z but never CY", what);
            if (result !== want)
                $fatal(1, "%0s: result %08x, expected %08x", what, result, want);
            if (fp_flags !== fpf)
                $fatal(1, "%0s: fp_flags %06b, expected %06b", what, fp_flags, fpf);
            if (exc)
                $fatal(1, "%0s: unexpected exception %04x", what, exc_code);
            if (flag_z !== (want == 32'd0) || flag_s !== want[31])
                $fatal(1, "%0s: S/Z %b/%b for %08x", what, flag_s, flag_z, want);
        end
    endtask

    // A compare: flags only.
    task automatic expect_cmp(input [31:0] va, input [31:0] vb,
                              input z, input s, input string what);
        begin
            run(4'h0, va, vb);
            if (wr_result || !flags_wr || !cy_wr)
                $fatal(1, "%0s: CMPF writes flags and nothing else", what);
            if (flag_z !== z || flag_s !== s || flag_cy !== s)
                $fatal(1, "%0s: Z/S/CY %b/%b/%b, expected %b/%b/%b",
                       what, flag_z, flag_s, flag_cy, z, s, s);
            if (fp_flags !== 6'd0 || exc)
                $fatal(1, "%0s: CMPF raised something", what);
        end
    endtask

    initial begin
        repeat (3) @(negedge clk);
        reset_n = 1'b1;

        // ---- ADDF.S ----
        expect_val(4'h4, 32'h3F800000, 32'h3F800000, 32'h40000000, 6'b000000,
                   "addf 1+1");
        expect_val(4'h4, 32'h40200000, 32'h3F800000, 32'h40600000, 6'b000000,
                   "addf 2.5+1");
        // 1.0 + 2^-24 sits exactly on the rounding tie and goes to even.
        expect_val(4'h4, 32'h3F800000, 32'h33800000, 32'h3F800000, 6'b000001,
                   "addf tie to even down");
        expect_val(4'h4, 32'h3F800001, 32'h33800000, 32'h3F800002, 6'b000001,
                   "addf tie to even up");
        expect_val(4'h4, 32'h3F800000, 32'hBF800000, 32'h00000000, 6'b000000,
                   "addf x + -x is +0");
        expect_val(4'h4, 32'h80000000, 32'h80000000, 32'h80000000, 6'b000000,
                   "addf -0 + -0 keeps -0");
        expect_val(4'h4, 32'h00000000, 32'hC0400000, 32'hC0400000, 6'b000000,
                   "addf 0 + x is x");
        expect_ovf(4'h4, 32'h7F7FFFFF, 32'h7F7FFFFF, 32'h1FFFFFFF, 6'b000100,
                   "addf overflow wraps the exponent");

        // ---- SUBF.S ----
        expect_val(4'h5, 32'h40A00000, 32'h40A00000, 32'h00000000, 6'b000000,
                   "subf x - x is +0");
        expect_val(4'h5, 32'h3F800000, 32'h34000000, 32'h3F7FFFFE, 6'b000000,
                   "subf borrows across the exponent");
        expect_val(4'h5, 32'h00800001, 32'h00800000, 32'h00000000, 6'b000011,
                   "subf tiny difference flushes to +0");
        expect_val(4'h5, 32'h00800000, 32'h00C00000, 32'h80000000, 6'b000011,
                   "subf flush keeps the sign");
        expect_val(4'h5, 32'h00000000, 32'h40400000, 32'hC0400000, 6'b000000,
                   "subf 0 - x is -x");

        // ---- MULF.S ----
        expect_val(4'h6, 32'h40400000, 32'h40A00000, 32'h41700000, 6'b000000,
                   "mulf 3*5");
        expect_val(4'h6, 32'hC0000000, 32'h40400000, 32'hC0C00000, 6'b000000,
                   "mulf sign");
        expect_val(4'h6, 32'h3F800001, 32'h3F800001, 32'h3F800002, 6'b000001,
                   "mulf rounds with sticky");
        expect_val(4'h6, 32'h40400000, 32'h00000000, 32'h00000000, 6'b000000,
                   "mulf by zero");
        expect_val(4'h6, 32'hC0400000, 32'h00000000, 32'h80000000, 6'b000000,
                   "mulf zero sign is the xor");
        expect_ovf(4'h6, 32'h5F800000, 32'h5F800000, 32'h1F800000, 6'b000100,
                   "mulf overflow");
        expect_val(4'h6, 32'h0D800000, 32'h0D800000, 32'h00000000, 6'b000011,
                   "mulf underflow flushes");

        // ---- DIVF.S ----
        expect_val(4'h7, 32'h3F800000, 32'h40000000, 32'h3F000000, 6'b000000,
                   "divf 1/2");
        expect_val(4'h7, 32'h41700000, 32'h40400000, 32'h40A00000, 6'b000000,
                   "divf 15/3");
        expect_val(4'h7, 32'h3F800000, 32'h40400000, 32'h3EAAAAAB, 6'b000001,
                   "divf 1/3 rounds");
        expect_val(4'h7, 32'h00000000, 32'hC0A00000, 32'h80000000, 6'b000000,
                   "divf 0/x");
        expect_ovf(4'h7, 32'h7F7FFFFF, 32'h00800000, 32'h5E7FFFFF, 6'b000100,
                   "divf overflow");
        expect_val(4'h7, 32'h00800000, 32'h40000000, 32'h00000000, 6'b000011,
                   "divf underflow flushes");
        // The boundary that rounds back up to the minimum normal: FPR alone.
        expect_val(4'h7, 32'h00FFFFFF, 32'h40000000, 32'h00800000, 6'b000001,
                   "divf rounds up to min normal");
        expect_val(4'h7, 32'h00800000, 32'h3F800001, 32'h00000000, 6'b000011,
                   "divf just under min normal flushes");
        expect_kill(4'h7, 32'h40A00000, 32'h00000000, 6'b001000, 16'hFF68,
                    "divf x/0 is FZD");
        expect_kill(4'h7, 32'h00000000, 32'h00000000, 6'b010000, 16'hFF70,
                    "divf 0/0 is FIV");

        // ---- reserved operands ----
        expect_kill(4'h4, 32'h7FC00000, 32'h3F800000, 6'b100000, 16'hFF60,
                    "NaN left operand");
        expect_kill(4'h4, 32'h3F800000, 32'h7F800000, 6'b100000, 16'hFF60,
                    "infinity right operand");
        expect_kill(4'h6, 32'h00000001, 32'h3F800000, 6'b100000, 16'hFF60,
                    "denormal operand");
        expect_kill(4'h7, 32'hFF800000, 32'h00000000, 6'b100000, 16'hFF60,
                    "FRO outranks FZD");
        expect_kill(4'h0, 32'h7FC00000, 32'h3F800000, 6'b100000, 16'hFF60,
                    "CMPF checks operands");
        expect_kill(4'h3, 32'h00000000, 32'hFF800001, 6'b100000, 16'hFF60,
                    "CVT.SW checks its source");

        // ---- CVT.WS ----
        expect_val(4'h2, 32'h0, 32'd5, 32'h40A00000, 6'b000000, "cvt.ws 5");
        expect_val(4'h2, 32'h0, -32'sd7, 32'hC0E00000, 6'b000000, "cvt.ws -7");
        expect_val(4'h2, 32'h0, 32'd0, 32'h00000000, 6'b000000, "cvt.ws 0");
        expect_val(4'h2, 32'h0, 32'h80000000, 32'hCF000000, 6'b000000,
                   "cvt.ws INT_MIN");
        expect_val(4'h2, 32'h0, 32'h7FFFFFFF, 32'h4F000000, 6'b000001,
                   "cvt.ws INT_MAX rounds");
        expect_val(4'h2, 32'h0, 32'd16777217, 32'h4B800000, 6'b000001,
                   "cvt.ws 2^24+1 ties to even");

        // ---- CVT.SW ----
        expect_int(4'h3, 32'h40A00000, 32'd5, 6'b000000, "cvt.sw 5.0");
        expect_int(4'h3, 32'hC0E00000, -32'sd7, 6'b000000, "cvt.sw -7.0");
        expect_int(4'h3, 32'h3F000000, 32'd0, 6'b000001, "cvt.sw 0.5 ties to 0");
        expect_int(4'h3, 32'h3FC00000, 32'd2, 6'b000001, "cvt.sw 1.5 ties to 2");
        expect_int(4'h3, 32'h40200000, 32'd2, 6'b000001, "cvt.sw 2.5 ties to 2");
        expect_int(4'h3, 32'h00000000, 32'd0, 6'b000000, "cvt.sw +0");
        expect_int(4'h3, 32'hCF000000, 32'h80000000, 6'b000000,
                   "cvt.sw exactly INT_MIN");
        expect_int(4'h3, 32'h30000000, 32'd0, 6'b000001,
                   "cvt.sw tiny value is inexact zero");
        expect_kill(4'h3, 32'h0, 32'h4F000000, 6'b010000, 16'hFF70,
                    "cvt.sw 2^31 is FIV");
        expect_kill(4'h3, 32'h0, 32'hCF000001, 6'b010000, 16'hFF70,
                    "cvt.sw below INT_MIN is FIV");

        // ---- TRNC.SW ----
        expect_int(4'hB, 32'h3FF33333, 32'd1, 6'b000001, "trnc 1.9 -> 1");
        expect_int(4'hB, 32'hBFF33333, -32'sd1, 6'b000001, "trnc -1.9 -> -1");
        expect_int(4'hB, 32'h40200000, 32'd2, 6'b000001, "trnc 2.5 -> 2");
        expect_int(4'hB, 32'hCF000000, 32'h80000000, 6'b000000,
                   "trnc exactly INT_MIN");
        expect_kill(4'hB, 32'h0, 32'h4F000000, 6'b010000, 16'hFF70,
                    "trnc 2^31 is FIV");

        // ---- CMPF.S ----
        expect_cmp(32'h3F800000, 32'h3F800000, 1'b1, 1'b0, "cmpf equal");
        expect_cmp(32'h00000000, 32'h80000000, 1'b1, 1'b0, "cmpf +0 == -0");
        expect_cmp(32'h3F800000, 32'h40000000, 1'b0, 1'b1, "cmpf 1 < 2");
        expect_cmp(32'h40000000, 32'h3F800000, 1'b0, 1'b0, "cmpf 2 > 1");
        expect_cmp(32'hBF800000, 32'h3F800000, 1'b0, 1'b1, "cmpf -1 < 1");
        expect_cmp(32'hC0400000, 32'hC0000000, 1'b0, 1'b1, "cmpf -3 < -2");
        expect_cmp(32'h80000000, 32'h3F800000, 1'b0, 1'b1, "cmpf -0 < 1");

        // ---- abort drops the operation ----
        @(negedge clk);
        op = 4'h7; a = 32'h3F800000; b = 32'h40400000; start = 1'b1;
        @(negedge clk);
        start = 1'b0;
        repeat (5) @(negedge clk);
        if (!busy) $fatal(1, "abort test: DIVF finished suspiciously fast");
        abort = 1'b1;
        @(negedge clk);
        abort = 1'b0;
        @(negedge clk);
        if (busy || done) $fatal(1, "abort did not return the FPU to idle");
        repeat (10) @(negedge clk);
        if (done) $fatal(1, "an aborted operation still completed");
        // And the unit still works afterwards.
        expect_val(4'h7, 32'h3F800000, 32'h40000000, 32'h3F000000, 6'b000000,
                   "divf after abort");

        $display("cpu_fpu: all vectors pass");
        $finish;
    end

    initial begin
        #10_000_000;
        $fatal(1, "timed out");
    end

endmodule
