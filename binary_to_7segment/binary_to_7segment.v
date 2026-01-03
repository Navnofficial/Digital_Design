// Module: binary_to_7segment
// Description: Converts an 8-bit binary input to BCD and then to 7-segment display outputs.
module binary_to_7segment (
    input wire clk,                  // Clock input
    input wire reset,                // Reset input
    input wire [7:0] binary_input,   // 8-bit binary input (0-255)
    output wire [6:0] seg_hundreds,  // 7-segment for hundreds digit
    output wire [6:0] seg_tens,      // 7-segment for tens digit
    output wire [6:0] seg_units,     // 7-segment for units digit
    output wire [2:0] digit_enable   // Enable signals for digits (optional)
);

    // Internal wires for BCD digits
    wire [3:0] hundreds, tens, units;
    
    // Instantiate the binary to BCD converter
    binary_to_bcd bcd_converter (
        .binary_in(binary_input),
        .hundreds(hundreds),
        .tens(tens),
        .units(units)
    );
    
    // Instantiate BCD to 7-segment decoders for each digit
    bcd_to_7seg seg_decoder_hundreds (
        .bcd_in(hundreds),
        .seg_out(seg_hundreds)
    );
    
    bcd_to_7seg seg_decoder_tens (
        .bcd_in(tens),
        .seg_out(seg_tens)
    );
    
    bcd_to_7seg seg_decoder_units (
        .bcd_in(units),
        .seg_out(seg_units)
    );
    
    // Enable all digits (active low for common anode displays, assuming 0 enables)
    assign digit_enable = 3'b000; 

endmodule


// Module: binary_to_bcd
// Description: Converts an 8-bit binary number to 3 BCD digits using the Double Dabble algorithm.
module binary_to_bcd (
    input wire [7:0] binary_in,
    output reg [3:0] hundreds,
    output reg [3:0] tens,
    output reg [3:0] units
);

    integer i;
    reg [19:0] temp; // 8 bits for binary_in + 3 * 4 bits for BCD = 8 + 12 = 20 bits

    always @(*) begin
        // Initialize temp with binary_in shifted to the right
        temp = {12'b0, binary_in}; // Pad with zeros for BCD digits initially
        
        // Perform 8 shifts (for 8-bit binary input)
        for (i = 0; i < 8; i = i + 1) begin
            // Check and add 3 to each BCD digit if its value is >= 5
            if (temp[11:8] >= 5) // Units digit
                temp[11:8] = temp[11:8] + 3;
            if (temp[15:12] >= 5) // Tens digit
                temp[15:12] = temp[15:12] + 3;
            if (temp[19:16] >= 5) // Hundreds digit
                temp[19:16] = temp[19:16] + 3;
                
            // Shift the entire 'temp' register left by 1 bit
            temp = temp << 1;
        end
        
        // Extract the BCD digits from 'temp'
        units    = temp[11:8];
        tens     = temp[15:12];
        hundreds = temp[19:16];
    end

endmodule


// Module: bcd_to_7seg
// Description: Converts a 4-bit BCD input to a 7-segment display output (active low).
module bcd_to_7seg (
    input wire [3:0] bcd_in,
    output reg [6:0] seg_out
);

    // 7-segment encoding (active low - common anode displays on DE2 board)
    // Segments are typically ordered as: g f e d c b a (where a is top segment, g is middle)
    always @(*) begin
        case (bcd_in)
            4'h0: seg_out = 7'b1000000; // 0 (a,b,c,d,e,f ON; g OFF) -> 0000001 (active high)
            4'h1: seg_out = 7'b1111001; // 1 (b,c ON)
            4'h2: seg_out = 7'b0100100; // 2 (a,b,d,e,g ON)
            4'h3: seg_out = 7'b0110000; // 3 (a,b,c,d,g ON)
            4'h4: seg_out = 7'b0011001; // 4 (b,c,f,g ON)
            4'h5: seg_out = 7'b0010010; // 5 (a,c,d,f,g ON)
            4'h6: seg_out = 7'b0000010; // 6 (a,c,d,e,f,g ON)
            4'h7: seg_out = 7'b1111000; // 7 (a,b,c ON)
            4'h8: seg_out = 7'b0000000; // 8 (all ON)
            4'h9: seg_out = 7'b0010000; // 9 (a,b,c,d,f,g ON)
            default: seg_out = 7'b1111111; // Blank/off (all segments OFF)
        endcase
    end

endmodule


// Optional: Module for Multiplexed display control
// This module is included for completeness if you decide to implement
// multiplexing for the 7-segment displays.
// It is NOT instantiated in the current top_level module, as your
// `binary_to_7segment` directly outputs separate signals for each HEX digit.
module display_multiplexer (
    input wire clk,                  // Main clock (e.g., 50MHz)
    input wire reset,
    input wire [6:0] seg_hundreds,
    input wire [6:0] seg_tens,
    input wire [6:0] seg_units,
    output reg [6:0] seg_out,        // Multiplexed segment output
    output reg [2:0] digit_select    // Digit selection (active low, e.g., for common anodes)
);

    reg [15:0] counter;      // Counter for clock division
    reg [1:0] digit_counter; // Counter to select which digit to display

    // Clock divider to control the refresh rate of the displays
    // For a 50MHz clock, dividing by 50,000 gives 1kHz refresh rate (50,000,000 / 50,000 = 1,000 Hz)
    // This means each digit will be refreshed approximately 1000/3 = 333 times per second.
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            counter <= 0;
            digit_counter <= 0;
        end else begin
            counter <= counter + 1;
            if (counter == 16'd50000) begin // Reset counter after reaching 50,000 cycles
                counter <= 0;
                digit_counter <= digit_counter + 1; // Move to the next digit
                if (digit_counter == 2) // Cycle through 3 digits (0, 1, 2)
                    digit_counter <= 0; // Reset digit counter
            end
        end
    end
    
    // Multiplex the displays based on digit_counter
    always @(*) begin
        case (digit_counter)
            2'b00: begin // Display Units digit
                seg_out = seg_units;
                digit_select = 3'b110; // For example, select HEX0 (units) if 3'b110 maps to its enable pin (active low)
            end
            2'b01: begin // Display Tens digit
                seg_out = seg_tens;
                digit_select = 3'b101; // For example, select HEX1 (tens)
            end
            2'b10: begin // Display Hundreds digit
                seg_out = seg_hundreds;
                digit_select = 3'b011; // For example, select HEX2 (hundreds)
            end
            default: begin // Default to all off
                seg_out = 7'b1111111; // All segments off (active low)
                digit_select = 3'b111; // All digits off
            end
        endcase
    end

endmodule


// Module: top_level
// Description: Main module for the FPGA design, connecting inputs and outputs.
// This should be set as the top-level entity in your Quartus II project.
module top_level (
    input wire clk,                  // Clock input (connect to CLOCK_50 on DE2 board)
    input wire reset,                // Reset input (connect to KEY[0] on DE2 board)
    input wire [7:0] binary_input,   // 8-bit binary input (connect to SW[7:0] on DE2 board)
    output wire [6:0] seg_hundreds,  // 7-segment output for hundreds digit (connect to HEX2 on DE2 board)
    output wire [6:0] seg_tens,      // 7-segment output for tens digit (connect to HEX1 on DE2 board)
    output wire [6:0] seg_units,     // 7-segment output for units digit (connect to HEX0 on DE2 board)
    output wire [2:0] digit_enable   // Enable signals for digits (optional, assuming active low control for 3 digits)
);

    // Instantiate the binary to 7-segment converter module
    // This module directly outputs signals for three separate 7-segment displays.
    // If you intend to use display multiplexing, you would instantiate the
    // 'display_multiplexer' module here and connect its outputs to the
    // appropriate 7-segment display pins (e.g., HEX0, HEX1, HEX2 segments
    // and their common anode enable pins if available for external control).
    binary_to_7segment display_converter (
        .clk(clk),
        .reset(reset),
        .binary_input(binary_input),
        .seg_hundreds(seg_hundreds),
        .seg_tens(seg_tens),
        .seg_units(seg_units),
        .digit_enable(digit_enable)
    );

endmodule