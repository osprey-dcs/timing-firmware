setws Workspace

platform create -name EVG_platform -hw EVG.xsa -os standalone -proc microblaze_0

bsp config -append extra_compiler_flags {-Os}

# needs generated EVG_platform/hw/drivers/
exec make -C Workspace/EVG/src

app create -name EVG_app -platform EVG_platform -os standalone -proc microblaze_0 -template "Empty Application(C)"

importsources -name EVG_app -path Workspace/EVG/src -linker-script

app config -name EVG_app -set build-config "Release"

# app config -name test -info compiler-optimization
app config -name EVG_app -set compiler-optimization {Optimize for size (-Os)}

# find generated files in src directory
app config -name EVG_app -add include-path ../../EVG/src/

app build -name EVG_app
