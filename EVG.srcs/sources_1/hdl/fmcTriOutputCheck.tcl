# Custom DRC.  cf. UG894
# select: External OUT and INOUT ports, associated with a net named "FMC*",
#         which connect to an IO cell type not matching "*BUFT*".
# Does not check if .T is actually connected.
proc fmcTriOutputCheck {} {
    set vios {}
    foreach cell [get_cells -of_objects [
            get_nets -of_objects [
                get_ports -filter {DIRECTION != "IN" && IOSTANDARD != ""} -quiet
            ] -filter {NAME =~ "FMC*"} -quiet
        ] -filter {REF_NAME !~ "*BUFT*"} -quiet
    ] {
        puts "fmcTriOutputCheck: $cell"
        set msg "FMC output cell $cell does not tri-state"
        set fname [get_property FILE_NAME $cell]
        set lnum [get_property LINE_NUMBER $cell]
        send_msg_id "IO_FMC_Trig-01" "CRITICAL WARNING" "$msg \[$fname:$lnum\]"
        set vio [create_drc_violation -name {FMCOT-1} -msg $msg $cell]
        lappend vios $vio
    }
    if {[llength $vios] > 0} {
        return -code error $vios
    } else {
        return {}
    }
}
delete_drc_check -quiet {FMCOT-1}
create_drc_check -name {FMCOT-1} -hiername {FMC} \
 -desc {For that FMC outputs have tri-state} \
 -rule_body fmcTriOutputCheck -severity {Critical Warning}
