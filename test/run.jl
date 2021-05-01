using CharDisplay

@info "Initialization..."

d = DisplayP4(
    2, # RS
    3, # RW
    4, # E
    5, # D7
    6, # D6
    7, # D5
    8; # D4
    max_rate = 25000
)

set_cursor(d, 0, 0)
write(d, "Julia +")
set_cursor(d, 0, 1)
write(d, "Raspberry Pi")

display_shift(d)
sleep(1)
display_shift(d)
sleep(1)
display_shift(d)
sleep(1)


@info "STOP!"
