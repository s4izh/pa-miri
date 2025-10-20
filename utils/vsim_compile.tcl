set SV_FILES $env(SV_FILES)
set sv_list [split $SV_FILES]

if {[file exists rtl_work]} {
	vdel -lib rtl_work -all
}
vlib rtl_work
vmap work rtl_work

foreach file $sv_list {
    vlog -work work $file
}
