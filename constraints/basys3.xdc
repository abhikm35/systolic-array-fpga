## Basys 3 constraints for systolic-array-fpga (accelerator_top)
##
## Pin assignments verified against Digilent Basys-3-Master.xdc (rev B):
##   https://github.com/Digilent/digilent-xdc/blob/master/Basys-3-Master.xdc
##
## Top-level ports (must match accelerator_top.sv exactly):
##   clk, btnC, uart_rx, uart_tx, led[15:0]
##
## UART naming (FPGA-centric, matches RTL):
##   uart_rx  <- USB-UART bridge TX  (Digilent RsRx / UART_TXD_IN)  pin B18
##   uart_tx  -> USB-UART bridge RX  (Digilent RsTx / UART_RXD_OUT) pin A18
##
## Device: xc7a35tcpg236-1 (Basys 3, Artix-7)

## -----------------------------------------------------------------------------
## 100 MHz system clock
## Digilent: CLK100MHZ -> W5
## -----------------------------------------------------------------------------
set_property -dict { PACKAGE_PIN W5   IOSTANDARD LVCMOS33 } [get_ports clk]
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports clk]

## -----------------------------------------------------------------------------
## Reset — center button (btnC), active-high in RTL
## Digilent: BTNC -> U18
## -----------------------------------------------------------------------------
set_property -dict { PACKAGE_PIN U18  IOSTANDARD LVCMOS33 } [get_ports btnC]

## -----------------------------------------------------------------------------
## USB-UART (on-board FTDI bridge, 115200 baud in RTL)
## Digilent: RsRx -> B18, RsTx -> A18
## -----------------------------------------------------------------------------
set_property -dict { PACKAGE_PIN B18  IOSTANDARD LVCMOS33 } [get_ports uart_rx]
set_property -dict { PACKAGE_PIN A18  IOSTANDARD LVCMOS33 } [get_ports uart_tx]

## -----------------------------------------------------------------------------
## LEDs — status driven in accelerator_top.sv
##   led[0] = ctrl_done
##   led[1] = ctrl_busy
##   led[2] = tx_busy
##   led[3] = rx_valid
## Digilent: led[0]..led[15] -> U16, E19, U19, V19, W18, U15, U14, V14,
##                              V13, V3, W3, U3, P3, N3, P1, L1
## -----------------------------------------------------------------------------
set_property -dict { PACKAGE_PIN U16  IOSTANDARD LVCMOS33 } [get_ports {led[0]}]
set_property -dict { PACKAGE_PIN E19  IOSTANDARD LVCMOS33 } [get_ports {led[1]}]
set_property -dict { PACKAGE_PIN U19  IOSTANDARD LVCMOS33 } [get_ports {led[2]}]
set_property -dict { PACKAGE_PIN V19  IOSTANDARD LVCMOS33 } [get_ports {led[3]}]
set_property -dict { PACKAGE_PIN W18  IOSTANDARD LVCMOS33 } [get_ports {led[4]}]
set_property -dict { PACKAGE_PIN U15  IOSTANDARD LVCMOS33 } [get_ports {led[5]}]
set_property -dict { PACKAGE_PIN U14  IOSTANDARD LVCMOS33 } [get_ports {led[6]}]
set_property -dict { PACKAGE_PIN V14  IOSTANDARD LVCMOS33 } [get_ports {led[7]}]
set_property -dict { PACKAGE_PIN V13  IOSTANDARD LVCMOS33 } [get_ports {led[8]}]
set_property -dict { PACKAGE_PIN V3   IOSTANDARD LVCMOS33 } [get_ports {led[9]}]
set_property -dict { PACKAGE_PIN W3   IOSTANDARD LVCMOS33 } [get_ports {led[10]}]
set_property -dict { PACKAGE_PIN U3   IOSTANDARD LVCMOS33 } [get_ports {led[11]}]
set_property -dict { PACKAGE_PIN P3   IOSTANDARD LVCMOS33 } [get_ports {led[12]}]
set_property -dict { PACKAGE_PIN N3   IOSTANDARD LVCMOS33 } [get_ports {led[13]}]
set_property -dict { PACKAGE_PIN P1   IOSTANDARD LVCMOS33 } [get_ports {led[14]}]
set_property -dict { PACKAGE_PIN L1   IOSTANDARD LVCMOS33 } [get_ports {led[15]}]

## -----------------------------------------------------------------------------
## Configuration (from Digilent Basys-3-Master.xdc — required for QSPI boot)
## -----------------------------------------------------------------------------
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]

set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 33 [current_design]
set_property CONFIG_MODE SPIx4 [current_design]
