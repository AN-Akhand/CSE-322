set ns [new Simulator]

#===============================================================================
#Define options
set val(chan)           Channel/WirelessChannel
set val(prop)           Propagation/TwoRayGround
set val(netif)          Phy/WirelessPhy/802_15_4
set val(mac)            Mac/802_15_4
set val(rp)             DSDV
set val(ant)            Antenna/OmniAntenna
set val(ll)             LL
set val(ifq)            Queue/RED
set val(ifqlen)         50
set val(redtype)        [lindex $argv 0]
set val(len)            [lindex $argv 1]
set val(nn)             [lindex $argv 2]
set val(nf)             [lindex $argv 3]
set val(pps)            [lindex $argv 4]
set val(tstart)         0.5
set val(tend)           15.0
set val(energymodel)    EnergyModel		;# Energy Model
set val(initialenergy)  12   	        ;# value
# queue parameters
set val(qthresh)        10
set val(qmaxthresh)     30
set val(qweight)        0.002
set val(qminpcksize)    60
#===============================================================================


# Set RED queue parameters
Queue/RED set thresh_ $val(qthresh)
Queue/RED set maxthresh_ $val(qmaxthresh)
Queue/RED set q_weight_ $val(qweight)
Queue/RED set bytes_ false
Queue/RED set queue_in_bytes_ false
Queue/RED set gentle_ false
Queue/RED set min_pcksize_ $val(qminpcksize)
Queue/RED set adaptive_ $val(redtype)
Queue/RED set saredlimit_ 1000


#trace file
set traceFile [open trace.tr w]
$ns trace-all $traceFile

#nam file
set namFile [open animation.nam w]
$ns namtrace-all-wireless $namFile $val(len) $val(len)

# topology: to keep track of node movements
set topo [new Topography]
$topo load_flatgrid $val(len) $val(len)

create-god $val(nn)

# Create channel
set chan_1_ [new $val(chan)]

$ns node-config -adhocRouting $val(rp) \
		-llType $val(ll) \
		-macType $val(mac) \
		-ifqType $val(ifq) \
		-ifqLen $val(ifqlen) \
		-antType $val(ant) \
		-propType $val(prop) \
		-phyType $val(netif) \
		-topoInstance $topo \
		-agentTrace ON \
		-routerTrace ON \
		-macTrace OFF \
		-movementTrace OFF \
		-channel $chan_1_ \
        -energyModel $val(energymodel) \
        -initialEnergy $val(initialenergy) \
        -rxPower 1.0 \
        -txPower 1.0 \
        -idlePower 1.0 \
        -sleepPower 0.001 

expr srand(87)
# Generate nodes at random positions
set points []
for {set i 0} {$i < $val(nn)} {incr i} {
    set x [expr rand() * $val(len)]
    set y [expr rand() * $val(len)]

    while {[lsearch -all -inline $points [list $x $y]] != {}} {
        set x [expr rand() * $val(len)]
        set y [expr rand() * $val(len)]
    }

    set point [list $x $y]
    lappend points $point

    set node_($i) [$ns node]
    $node_($i) random-motion 0
    
    # Set initial node position
    $node_($i) set X_ $x
    $node_($i) set Y_ $y
    $node_($i) set Z_ 0.0
    $ns initial_node_pos $node_($i) 20 
}

# select a node as a source 
set srcNodeNum [expr int(rand() * $val(nn))]

puts "Source node: $srcNodeNum $node_($srcNodeNum)"

# Create random flows
for {set i 0} {$i < $val(nf)} {incr i} {
    # select a node as a sink
    set sinkNodeNum [expr int(rand() * $val(nn))]
    while {$sinkNodeNum == $srcNodeNum} {
        set sinkNodeNum [expr int(rand() * $val(nn))]
    }

    # Create a tcp agent and attach it to source node
    set tcp_($i) [new Agent/TCP]
    # Create a tcp sink agent and attach it to sink node
    set sink_($i) [new Agent/TCPSink]
    $ns attach-agent $node_($srcNodeNum) $tcp_($i)
    $ns attach-agent $node_($sinkNodeNum) $sink_($i)

    $tcp_($i) set packetSize_ $val(qminpcksize)
    $tcp_($i) set maxseq_ $val(pps)
    # $tcp_($i) set window_ [expr 10 * ($val(pps) / 100)]
    # Create the flow
    $ns connect $tcp_($i) $sink_($i)
    # $tcp_($i) set fid_ $i
    
    # Attach an ftp traffic generator to the flow
    set ftp_($i) [new Application/FTP]


    $ftp_($i) attach-agent $tcp_($i)

    $ns at $val(tstart) "$ftp_($i) start"
}

# Tell nodes when the simulation ends
for {set i 0} {$i < $val(nn) } {incr i} {
    $ns at $val(tend) "$node_($i) reset";
}

$ns at $val(tend) "finish"
$ns at [expr $val(tend) + 0.1] "puts \"NS EXITING...\" ; $ns halt"
proc finish {} {
    global ns traceFile namFile
    $ns flush-trace
    close $traceFile
	close $namFile
    # exec nam animation.nam &
    exit 0
}

$ns at [expr $val(tend) + 0.0001] "finish"

$ns run