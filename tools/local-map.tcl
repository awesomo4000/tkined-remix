# Build a Tkined map from local network state.
#
# Uses only passive sources -- the routing table, interface config, the
# ARP cache and DNS -- so it needs no ICMP and no root. Run it headless:
#
#   tools/local-map.sh [output.tki]
#
# Writes a .tki map and, if ghostscript is present, a PNG rendering.

wm withdraw .

foreach p {Tkined TkinedCommand TkinedDiagram TkinedDialog TkinedEditor
           TkinedEvent TkinedHelp TkinedMisc TkinedObjects TkinedTool} {
    package require $p 1.6.0
}
package require Tnm

set LOG [open $env(MAP_LOG) w]
proc L {m} { global LOG; puts $LOG $m; flush $LOG }

# ---------------------------------------------------------------- data

proc default_gateway {} {
    if {[catch {exec route -n get default} out]} { return "" }
    foreach line [split $out \n] {
        if {[regexp {gateway:\s*(\S+)} $line -> gw]} { return $gw }
    }
    return ""
}

# Returns {iface ip mask} for each configured IPv4 interface that is up.
proc interfaces {} {
    set res {}
    if {[catch {exec ifconfig} out]} { return $res }
    set iface ""
    foreach line [split $out \n] {
        if {[regexp {^(\w+):} $line -> name]} { set iface $name ; continue }
        if {[regexp {inet (\S+) netmask (\S+)} $line -> ip hex]} {
            if {$ip eq "127.0.0.1"} continue
            # netmask is printed as 0xffffe000
            set m [expr {$hex + 0}]
            set mask [format "%d.%d.%d.%d" \
                [expr {($m >> 24) & 0xff}] [expr {($m >> 16) & 0xff}] \
                [expr {($m >> 8) & 0xff}]  [expr {$m & 0xff}]]
            lappend res [list $iface $ip $mask]
        }
    }
    return $res
}

# ARP cache: real neighbours this host has actually talked to.
proc neighbours {iface} {
    set res {}
    if {[catch {exec arp -an} out]} { return $res }
    foreach line [split $out \n] {
        if {![regexp {\((\S+)\) at (\S+) on (\S+)} $line -> ip mac dev]} continue
        if {$dev ne $iface} continue
        if {$mac eq "ff:ff:ff:ff:ff:ff"} continue
        # "(incomplete)" means the ARP request was never answered, so the
        # host is not actually reachable and does not belong on the map.
        if {[string match "*incomplete*" $mac]} continue
        if {[string match "224.*" $ip] || [string match "239.*" $ip]} continue
        lappend res [list $ip $mac]
    }
    return $res
}

proc resolve {ip} {
    if {[catch {Tnm::dns name $ip} n]} { return "" }
    return $n
}

# --------------------------------------------------------------- build

proc icon_path {name} {
    # Tkined compiles only a handful of bitmaps in. Everything else is an
    # .xbm on disk, and Tk needs the @path form: a bare name is silently
    # ignored and the object keeps its default icon.
    return "@$::tkined(library)/bitmaps/$name.xbm"
}

set editor [EDITOR]
set top [$editor toplevel]
set cv $top.canvas
$editor pagesize A4
$editor orientation landscape

set gw [default_gateway]
L "gateway: $gw"

set y_net 260
set x 140
set placed 0

foreach spec [interfaces] {
    lassign $spec iface ip mask
    set netaddr [Tnm::netdb ip apply $ip $mask]
    set prefix  [Tnm::netdb ip compare $mask 0.0.0.0]
    L "interface $iface  $ip/$mask  net $netaddr"

    set nbrs [neighbours $iface]
    if {[llength $nbrs] == 0} continue

    # the network segment itself
    set net [NETWORK create]
    $net editor $editor
    $net canvas $cv
    $net name "$netaddr"
    $net address $netaddr
    $net label name
    set x2 [expr {$x + 220 + 120 * [llength $nbrs]}]
    $net move $x $y_net
    $net size
    L "  network object $net at $x,$y_net"

    # this host
    set me [NODE create]
    $me editor $editor
    $me canvas $cv
    $me name [info hostname]
    $me address $ip
    $me attribute "interface" $iface
    $me attribute "netmask" $mask
    $me icon [icon_path mac]
    $me label name
    $me move [expr {$x + 40}] [expr {$y_net - 120}]
    if {![catch {LINK create $me $net} lk]} { catch {$lk editor $editor}; catch {$lk canvas $cv} }
    incr placed

    # neighbours from the ARP cache
    set nx [expr {$x + 60}]
    foreach nb $nbrs {
        lassign $nb nip nmac
        if {$nip eq $ip} continue
        set n [NODE create]
        $n editor $editor
        $n canvas $cv
        set nname [resolve $nip]
        if {$nname eq ""} { set nname $nip }
        $n name $nname
        $n address $nip
        $n attribute "mac address" $nmac
        if {$nip eq $gw} {
            $n icon [icon_path router]
            $n attribute "role" "default gateway"
            $n color red
        } else {
            $n icon [icon_path pc]
        }
        $n label name
        $n move $nx [expr {$y_net + 130}]
        if {![catch {LINK create $n $net} lk]} { catch {$lk editor $editor}; catch {$lk canvas $cv} }
        incr nx 210
        incr placed
        L "  node $nip ($nname) mac $nmac"
    }
    set x [expr {$x2 + 80}]
    incr y_net 0
}

L "placed $placed objects"

update
L "canvas items: [llength [$cv find all]]"

set outfile $env(MAP_OUT)
$editor save $outfile
L "saved $outfile"

# Optional: show the real editor window and capture just that window.
# Everything above is offscreen; this is the only step that maps a window.
if {[info exists env(SHOT_OUT)]} {
    set W 1280 ; set H 640 ; set X 40 ; set Y 140
    wm geometry $top ${W}x${H}+${X}+${Y}
    wm deiconify $top
    raise $top
    update idletasks
    update
    after 1200 {
        # capture only this window's own rectangle, never the screen
        catch {exec screencapture -x \
            -R$::X,$::Y,$::W,$::H $env(SHOT_OUT)} err
        set ::shot_done 1
    }
    vwait ::shot_done
    L "captured $env(SHOT_OUT)"
}

# framework-native, offscreen rendering: no window is ever mapped
if {[info exists env(MAP_PS)]} {
    # On Aqua, bitmap items default to the dynamic colors systemTextColor
    # and systemWindowBackgroundColor. Tk cannot express those in
    # PostScript, so the icons come out invisible. Pin them to concrete
    # colors first. tkined's own Editor__postscript does the same for
    # backgrounds.
    foreach item [$cv find all] {
        if {[$cv type $item] eq "bitmap"} {
            catch {$cv itemconfigure $item -foreground black -background white}
        }
    }
    update
    set ps [$editor postscript]
    set f [open $env(MAP_PS) w]
    puts $f $ps
    close $f
    L "postscript written to $env(MAP_PS)"
}
close $LOG
exit 0
