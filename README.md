# CharDisplay

Raspberry Pi package for controlling 16x2 character display (1602 LCD) on **HD44780U module** written in Julia.

[![GitHub issues](https://img.shields.io/github/issues/metelkin/CharDisplay.jl.svg)](https://GitHub.com/metelkin/CharDisplay.jl/issues/)
[![GitHub license](https://img.shields.io/github/license/metelkin/CharDisplay.jl.svg)](https://github.com/metelkin/CharDisplay.jl/blob/master/LICENSE)
[![Documentation](https://img.shields.io/badge/docs-dev-blue.svg)](https://metelkin.github.io/CharDisplay.jl/dev)

List of compatible modules
- MT–16S2H (КБ1013ВГ6, Angstrem)
- HD44780S (Hitachi)
- KS0066 (Samsung)
- LCD1602 (WaveShare)
- 1602A-1 (SHENZHEN)
- etc.

## More info

[See the docs](https://metelkin.github.io/CharDisplay.jl/dev).

### TODO list

- [x] Parallel 8bit / 4bit bus
- [ ] Extend rate from 333 Hz to 25 KHz
- [ ] Support reading operations
- [ ] Modules with I2C driver

## License

Published under [MIT License](LICENSE)
