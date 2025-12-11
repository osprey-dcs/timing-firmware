open_project EVG.xpr

reset_run synth_1
launch_runs -jobs 2 synth_1
wait_on_run synth_1

write_hw_platform -fixed -force EVG.xsa

reset_run impl_1
launch_runs -jobs 2 impl_1 -to_step write_bitstream
wait_on_run impl_1
