# Headless Tkined smoke test.
#
# Loads every Tkined package and constructs an editor without mapping a
# window, so it never steals focus. macOS Aqua wish discards stdout, so
# results go to the file named by TKI_SMOKE_OUT and the exit status
# carries the verdict.

wm withdraw .

set out [open $env(TKI_SMOKE_OUT) w]
proc P {m} { global out; puts $out $m; flush $out }

set failures 0
proc check {label script} {
    global failures
    if {[catch {uplevel 1 $script} err]} {
        P "FAIL $label: $err"
        incr failures
        return 0
    }
    P "ok   $label"
    return 1
}

check "Tk loads"        { package require Tk }
check "Tkined loads"    { package require -exact Tkined 1.6.0 }

foreach p {TkinedCommand TkinedDiagram TkinedDialog TkinedEditor TkinedEvent
           TkinedHelp TkinedMisc TkinedObjects TkinedTool} {
    check "package $p" [list package require $p $tkined(version)]
}

check "tkined(library) set" {
    if {![info exists ::tkined(library)] || ![file isdirectory $::tkined(library)]} {
        error "tkined(library) missing or not a directory"
    }
}

check "bundled apps present" {
    set n [llength [glob -nocomplain [file join $::tkined(library) apps *]]]
    if {$n < 20} { error "expected >= 20 apps, found $n" }
}

# Constructing the editor is the real test: it exercises the C canvas
# item types, not just package loading.
if {[check "editor constructs" { set ::v [EDITOR] }]} {
    check "editor toplevel exists" {
        if {![winfo exists .$::v]} { error "no toplevel .$::v" }
    }
    check "editor has a canvas" {
        set found 0
        foreach w [winfo children .$::v] {
            foreach c [concat [list $w] [winfo children $w]] {
                if {[winfo class $c] eq "Canvas"} { set found 1 }
            }
        }
        if {!$found} { error "no canvas widget in editor" }
    }
    # keep everything unmapped
    foreach w [winfo children .] { catch {wm withdraw $w} }
}

P "failures=$failures"
close $out
exit [expr {$failures ? 1 : 0}]
