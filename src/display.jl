# the minimum Julia's sleep time is 1 us # sleep(1e-3)
# Average minimal RasPi's time (500 MHz) is 2 ns

export DisplayP4, DisplayP8
export write, clear_display, return_home, function_set, display_on_off_control, entry_mode_set, set_cursor, cursor_or_display_shift

# UInt8
# RS RW (E)
# D7 D6 D5 D4 D4 D3 D2 D1 D0

abstract type AbstractDisplay end
abstract type DisplayP end


"""
    function DisplayP8(
        RS::Int,
        RW::Union{Int,Nothing},
        E::Int,
        D7::Int,
        D6::Int,
        D5::Int,
        D4::Int
        D3::Int,
        D2::Int,
        D1::Int,
        D0::Int
    )

Initialize object representing character display with parallel bus in 8 bit mode
and prepare it for writing characters. Cursor will be set to the first line and first symbol: (0,0) pisition.

## Arguments

- `RS`-`D0` : GPIO numer connected to corresponding pins.
    You have not to connect `RW` pin, `RW` is allowed to be `nothing`. 
"""
struct DisplayP8 <: DisplayP
    RS::Int  # 0 : manage, 1 : transfer
    RW::Union{Int,Nothing}  # read/write pin, 0 means writing, 1 : reading
    E::Int   # clock pin
    D7::Int
    D6::Int
    D5::Int
    D4::Int
    D3::Int
    D2::Int
    D1::Int
    D0::Int
    max_rate::Int
end

"""
    function DisplayP4(
        RS::Int,
        RW::Union{Int,Nothing},
        E::Int,
        D7::Int,
        D6::Int,
        D5::Int,
        D4::Int
    )

Initialize object representing character display with parallel bus in 4 bit mode
and prepare it for writing characters. Cursor will be set to the first line and first symbol: (0,0) pisition.

## Arguments

- `RS`-`D4` : GPIO numer connected to corresponding pins.
    You have not to connect `RW` pin, `RW` is allowed to be `nothing`. 
"""
struct DisplayP4 <: DisplayP
    RS::Int  # 0 : manage, 1 : transfer
    RW::Union{Int,Nothing}  # read/write pin, 0 means writing, 1 : reading
    E::Int   # clock pin
    D7::Int
    D6::Int
    D5::Int
    D4::Int
    max_rate::Int # Byte/s
    
    function DisplayP4(
        RS::Int,
        RW::Union{Int,Nothing},
        E::Int,
        D7::Int,
        D6::Int,
        D5::Int,
        D4::Int;
        max_rate::Int = 25_000 # Byte/s theoretical: ~ 1Byte/40us = 25000 Byte/s, actual ~ 1Byte/3ms = 333 Byte/s
    )
        #@assert max_rate <= 25_000 "max_rate must be less than 25000 Byte/s, got $max_rate"

        init_gpio()

        pin_vector = [RS, E, D7, D6, D5, D4,]
        gpio_set_mode(pin_vector, :out)
        gpio_set_mode(RW, :out)

        gpio_clear(pin_vector)
        gpio_clear(RW)

        d = new(RS, RW, E, D7, D6, D5, D4, max_rate)

        # init commands
        sleep(20e-3) # wait > 20 ms after power on
        reset(d)

        return d
    end
end

function reset(display::DisplayP)
    # set 8bit mode 3 times (from datasheet)
    gpio_clear([display.RS, display.RW])
    sleep(0.001) # T_AS > 60 ns
    _send_semibyte(display, 0b0011_0000)
    sleep(4.1e-3) # > 4.1 ms
    _send_semibyte(display, 0b0011_0000)
    sleep(0.001) # > 100 us
    _send_semibyte(display, 0b0011_0000)
    sleep(0.001) # t_wait > 37 us

    is_8bit = typeof(display) == DisplayP8

    if !is_8bit
        _send_semibyte(display, 0b0010_0000) # switch to 4bit mode
        sleep(0.001) # t_wait > 37 us
    end

    function_set(display; _8bits = is_8bit) # function set
    display_on_off_control(display) # Display on
    clear_display(display) # clear display
    entry_mode_set(display) # Entry Mode Set

    return nothing
end

"""
    function write(display::DisplayP, symbol::Char)

Write character to the current position and shift cursor to the next position.

## Arguments

- `display` : DisplayP object.
- `symbol` : character to print. The symbol code must be convertable to `UInt8`.
    Full list of available characters can be found in datasheet for the display.
    If some of symbol cannot be converted, "?" sign will be printed.
"""
function Base.write(display::DisplayP, symbol::Char)
    try
        byte = UInt8(symbol)
        write(display, byte)
    catch e
        if isa(e, InexactError)
            @warn "Symbol '$symbol' cannot be converted to UInt8"
            write(display, '?')
        else
            throw(e)
        end
    end
end

"""
    function write(display::DisplayP, string::String)

Write character string starting from the current position.

## Arguments

- `display` : DisplayP object.
- `string` : string to print. Each symbol code must be convertable to `UInt8`.
    Full list of available characters can be found in datasheet for the display.
"""
function Base.write(display::DisplayP, string::String)
    for letter in string
        write(display, letter)
    end
end

"""
    set_cursor(display::DisplayP, col::Int = 0, row::Int = 0)

Set cursor position.
__

## Arguments

- `col` : number of position: integer from `0` to `15`
- `row` : number of string: integer `0` or `1`
"""
function set_cursor(display::DisplayP, col::Int = 0, row::Int = 0)
    if row == 0
        byte = UInt8(col)
    elseif row == 1
        byte = UInt8(4 * 16 + col)
    else
        throw("row must be 0 or 1, got $row")
    end
    set_DDRAM_address(display, byte)
end

### auxilary ###

function _command_byte(display::DisplayP, byte::UInt8)
    gpio_clear([display.RS, display.RW])
    sleep(0.001) # T_AS # > 60 ns

    _send_byte(display, byte)
    sleep(0.001) # t_wait > 37 us

    return nothing
end

function _send_semibyte(display::DisplayP, byte::UInt8)
    pin_array = [
        display.D4,
        display.D5,
        display.D6,
        display.D7,
    ]

    # high order bits
    gpio_set(display.E)
    for i in 0:3
        if (byte >> (0x4 + i)) % 0x2 == 0x1
            gpio_set(pin_array[i + 1])
        else
            gpio_clear(pin_array[i + 1])
        end
    end
    sleep(0.001) # T_DSW > 195 ns
    gpio_clear(display.E)
    sleep(0.001) # T_H > 10 ns

    return nothing
end

# to send splitted by two steps
# width between two cycles t_cyc_E must be > 1000 ns, actual > 1 ms
# PW_EH (E up width) must be > 450 ns, actual > 1 ms
function _send_byte(display::DisplayP4, byte::UInt8)
    pin_array = [
        display.D4,
        display.D5,
        display.D6,
        display.D7,
    ]

    # high order bits
    gpio_set(display.E)
    for i in 0:3
        if (byte >> (0x4 + i)) % 0x2 == 0x1
            gpio_set(pin_array[i + 1])
        else
            gpio_clear(pin_array[i + 1])
        end
    end
    sleep(0.001) # T_DSW > 195 ns
    gpio_clear(display.E)
    sleep(0.001) # T_H > 10 ns

    # low order bits
    gpio_set(display.E)
    for i in 0:3
        if (byte >> i) % 0x2 == 0x1
            gpio_set(pin_array[i + 1])
        else
            gpio_clear(pin_array[i + 1])
        end
    end
    sleep(0.001) # T_DSW > 195 ns
    gpio_clear(display.E)
    sleep(0.001) # T_H > 10 ns

    return nothing
end

function _send_byte(display::DisplayP8, byte::UInt8)
    pin_array = [
        display.D0,
        display.D1,
        display.D2,
        display.D3,
        display.D4,
        display.D5,
        display.D6,
        display.D7,
    ]

    # high order bits
    gpio_set(display.E)
    for i in 0:7
        if (byte >> i) % 0x2 == 0x1
            gpio_set(pin_array[i + 1])
        else
            gpio_clear(pin_array[i + 1])
        end
    end
    sleep(0.001) # T_DSW > 195 ns
    gpio_clear(display.E)
    sleep(0.001) # T_H > 10 ns

    return nothing
end

### low level write ###

"""
    write(display::DisplayP, byte::UInt8)

Write data to CG or DDRAM

_DB7 DB6 DB5 DB4 DB4 DB3 DB2 DB1 DB0_

## Arguments

- `byte` : Byte representing symbol.
"""
function Base.write(display::DisplayP, byte::UInt8)
    gpio_set(display.RS); gpio_clear(display.RW)
    sleep(0.001) # T_AS > 60 ns

    _send_byte(display, byte)
    sleep(0.001) # t_wait # > 37 us

    return nothing
end

### low level commands ###

"""
    clear_display(display::DisplayP)

Clears entire display and sets DDRAM address 0 in address counter.

_0 0 0 0 0 0 0 1_
"""
function clear_display(display::DisplayP)
    _command_byte(display, 0b0000_0001)
    sleep(1.5e-3) # > t_wait_clear > 1500 us
end

"""
    return_home(display::DisplayP)

Sets DDRAM address 0 in address counter.
Also returns display from being shifted to original position.
DDRAM contents remain unchanged.

_0 0 0 0 0 0 1 -_
"""
function return_home(display::DisplayP)
    _command_byte(display, 0b0000_0010) 
    sleep(1.5e-3) # t_wait_clear > 1500 us
end

"""
    entry_mode_set(display::DisplayP; increment::Bool = true, shift::Bool = false)

Sets cursor move direction and specifies display shift.
These operations are performed during data write and read.

_0 0 0 0 0 1 I/D S_

## Arguments

- `increment` : `true` means increment, `false` decrement
- `shift` : `true` accompanies display shift
"""
function entry_mode_set(display::DisplayP; increment::Bool = true, shift::Bool = false)
    byte = UInt8(0b0000_0100 | (increment << 1) | shift)
    _command_byte(display, byte)
end

"""
    display_on_off_control(
        display::DisplayP;
        display_on::Bool = true,
        cursor_on::Bool = true,
        blinking::Bool = false
    )

Sets entire display (D) on/off, cursor on/off (C), and blinking of cursor position character (B).

_0 0 0 0 1 D C B_

## Arguments

- `display_on` : `true` means display on, `false` is off.
- `cursor_on` : `true` means cursor on, `false` is off.
- `blinking` : `true` means blinking cursor character.
"""
function display_on_off_control(display::DisplayP; display_on::Bool = true, cursor_on::Bool = true, blinking::Bool = false)
    byte = UInt8(0b0000_1000 | (display_on << 2) | (cursor_on << 1) | blinking)
    _command_byte(display, byte)
end

"""
    cursor_shift(display::DisplayP; right::Bool = false)

Moves cursor without changing DDRAM contents.

_0 0 0 1 0 R/L - -_
"""
function cursor_shift(display::DisplayP; right::Bool = false)
    byte = UInt8(0b0001_0000 | (right << 2))
    _command_byte(display, byte)
end

"""
    display_shift(display::DisplayP; right::Bool = false)

Shifts display without changing DDRAM contents.

_# 0 0 0 1 1 R/L - -_
"""
function display_shift(display::DisplayP; right::Bool = false)
    byte = UInt8(0b0001_1000 | (right << 2))
    _command_byte(display, byte)
end

"""
    function_set(
        display::DisplayP;
        _8bits::Bool = false,
        _2lines::Bool = true,
        _10pixels::Bool = false,
        second_set::Bool = false
    )

Sets interface data length
(DL), number of display lines
(N), and character font (F)

0 0 1 DL N F P —

## Arguments

- `_8bits` : set 8 bit mode (`true`) or 4 bit model (`false`)
- `_2lines` : `true` means 2 lines, `false` means one line. 
- `_10pixels` : `true` for 5x10 pixel symbols modules. Default (`false`) is 5x8.
- `second_set` : Some modules supports 2 symbols fonts. See the datasheet.
"""
function function_set(display::DisplayP; _8bits::Bool = false, _2lines::Bool = true, _10pixels::Bool = false, second_set::Bool = false)
    byte = UInt8(0b0010_0000 | (_8bits << 4) | (_2lines << 3) | (_10pixels << 2) | (second_set << 1))
    _command_byte(display, byte)
end

"""
    set_CGRAM_address(display::DisplayP, byte::UInt8)

Sets CGRAM address.
CGRAM data is sent and
received after this setting

_0 1 ACG ACG ACG ACG ACG ACG_
"""
function set_CGRAM_address(display::DisplayP, byte::UInt8)
    @assert byte <= 0b0011_1111 "Address must be between 0x00 and 0x3f, got $byte"
    _command_byte(display, 0b0100_0000 | byte)
end

"""
    set_DDRAM_address(display::DisplayP, byte::UInt8)

Sets DDRAM address.
DDRAM data is sent and
received after this setting.

_1 ADD ADD ADD ADD ADD ADD ADD_
"""
function set_DDRAM_address(display::DisplayP, byte::UInt8)
    @assert byte <= 0b0111_1111 "Address must be between 0x00 and 0x7f, got $byte"
    _command_byte(display, 0b1000_0000 | byte)
end

### low level read ###

# 0 1 BF AC AC AC AC AC AC AC
# read_busy_flag_and_address

# ? ? ? ? ? ? ? ?
# Read data from CG or DDRAM
# read
