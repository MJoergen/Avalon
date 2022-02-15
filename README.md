# Avalon
This repo contains various utilities for Avalon Memory Map. This is
an industry standard bus interface for connecting peripherals (e.g. memory and
I/O devices) to a bus master (e.g. a CPU).

## Avalon Memory Map interface
Here is a brief summary of the signals involved in the Avalon Memory Map
interface.  For full details, refer to Section 3 of the
[specification](Avalon_Interface_Specifications.pdf).
These blocks all use "Pipelined Read Transfer with Variable Latency",
see section 3.5.4 and Figure 12, and support burst mode, see section 3.5.5.
They do not use the "waitrequestAllowance" property.

Signal | Description
-----: | :---------
`write`         | Asserted by client when sending data to the device.
`read`          | Asserted by client when requesting data from the device.
`address`       | The address (in units of words).
`writedata`     | The data to send to the device.
`byteenable`    | 1-bit for each byte of data to the device.
`burstcount`    | Number of words to transfer.
`readdata`      | Data receive from the device.
`readdatavalid` | Asserted when data from the device is valid.
`waitrequest`   | Asserted by the device when it is busy.

## `avm_memory.vhd`
This generates a block of memory (BRAM).

## `avm_master.vhd`
This acts as an Avalon Master (instead of a CPU) to generate some test trafic.

## `avm_decrease.vhd`
This utility connects a Master and a Slave, where the two have different data
widths. Specifically, the Master data width is expected to be larger than the
Slave data width. A single Master request is converted into a burst mode
request to the Slave.

## `avm_pause.vhd`
This inserts small pauses into the Avalon Memory Map interface. This is useful to
increase test coverage.

