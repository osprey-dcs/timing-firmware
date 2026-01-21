open_project EVG.xpr

# The first time through, the DCP files are not present.
# However, vivado will barf if they are still referenced :(
# Will be automatically re-added after a successful run.
foreach dcp [get_files -quiet -filter file_type=="Design\ Checkpoint"] {
    if {[get_property IS_AVAILABLE $dcp] == 0} {
        puts "Remove reference to missing DCP $dcp"
        remove_files $dcp
    } else {
        puts "Found DCP: $dcp"
    }
}

reset_run synth_1
launch_runs -jobs 2 synth_1
wait_on_run synth_1

write_hw_platform -fixed -force EVG.xsa

reset_run impl_1
launch_runs -jobs 2 impl_1 -to_step write_bitstream
wait_on_run impl_1
