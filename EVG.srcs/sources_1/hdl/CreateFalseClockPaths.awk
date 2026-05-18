# Input is file produced by 'Report Clock Interactions'
/(unsafe)/ {
    printf("set_false_path -from [get_clocks %s] -to [get_clocks %s]\n", $1, $2)
}
