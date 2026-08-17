`default_nettype none
//
// Tells APF how many bytes of a data slot to write back to the SD card.
//
// The framework keeps a 32-entry table of slot id and size, two words each,
// and fills it from the files it loaded; on shutdown it reads the table back
// and writes that many bytes onto the file [host-target-commands.md,
// 0x2000-0x20FF and Dataslot ID / Size Table]. A save file that does not
// exist yet loads as zero bytes, so the table says zero, so the flush writes
// nothing and the file is never created -- the save can never come into
// being on its own. The same document says the remedy: "Core may update the
// value during setup, idle, or run."
//
// So this walks the table for its slot's id and writes the size beside it.
// It searches rather than indexing a fixed entry because the table is keyed
// by id in its first word, and guessing an entry that belongs to another
// slot would resize somebody else's file.
//
// The walk runs on the rising edge of dataslot_allcomplete, which is APF
// saying every slot is loaded and the table is therefore populated. A
// cartridge reload raises it again and the walk runs again, which is what
// keeps the size honest when a smaller save follows a larger one.
//

module dataslot_size #(
    parameter logic [15:0] SLOT_ID = 16'd0
) (
    input  wire logic        clk,          // clk_74a, the table's own clock
    input  wire logic        start,        // dataslot_allcomplete
    input  wire logic [31:0] bytes,        // what the slot should flush

    output logic     [9:0]   table_addr,
    output logic             table_wren,
    output logic     [31:0]  table_data,
    input  wire logic [31:0] table_q
);

    // Entry n holds its id at word 2n and its size at word 2n+1.
    typedef enum logic [2:0] { IDLE, ADDRESS, AWAIT, COMPARE, WRITE } state_t;

    state_t      state = IDLE;
    logic [4:0]  slot  = '0;
    logic [1:0]  delay = '0;
    logic        start_q = 1'b0;

    // The table's port is registered twice over -- address in, data out --
    // so the answer is two clocks behind. Four is the same answer with room.
    localparam logic [1:0] READ_DELAY = 2'd3;

    always_ff @(posedge clk) begin
        start_q    <= start;
        table_wren <= 1'b0;

        unique case (state)
            IDLE:
                if (start && !start_q) begin
                    slot  <= '0;
                    state <= ADDRESS;
                end

            ADDRESS: begin
                table_addr <= {4'd0, slot, 1'b0};
                delay      <= READ_DELAY;
                state      <= AWAIT;
            end

            AWAIT:
                if (delay != '0) delay <= delay - 2'd1;
                else             state <= COMPARE;

            COMPARE:
                if (table_q[15:0] == SLOT_ID) begin
                    table_addr <= {4'd0, slot, 1'b1};
                    table_data <= bytes;
                    table_wren <= 1'b1;
                    state      <= WRITE;
                end else if (slot == 5'd31) begin
                    state <= WRITE;      // no such slot; nothing to say
                end else begin
                    slot  <= slot + 5'd1;
                    state <= ADDRESS;
                end

            WRITE: state <= IDLE;        // the pulse lands here, then re-arm

            default: state <= IDLE;
        endcase
    end

endmodule

`default_nettype wire
