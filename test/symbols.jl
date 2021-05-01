using CharDisplay

wait_for_key(prompt) = (println(stdout, prompt); read(stdin, 1); nothing)

@info "Writing symbols..."

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

for x in 0x00:0x20:0xe0
    set_cursor(d, 0, 0)
    for i in x:(x + 15)
        write(d, UInt8(i))
    end
    
    set_cursor(d, 0, 1)
    for i in (x + 16):(x + 16 + 15)
        write(d, UInt8(i))
    end
    
    wait_for_key("press any key to continue")
end

function_set(d; second_set = true)

for x in 0x00:0x20:0xe0
    set_cursor(d, 0, 0)
    for i in x:(x + 15)
        write(d, UInt8(i))
    end
    
    set_cursor(d, 0, 1)
    for i in (x + 16):(x + 16 + 15)
        write(d, UInt8(i))
    end
    
    wait_for_key("press any key to continue")
end


@info "STOP."
