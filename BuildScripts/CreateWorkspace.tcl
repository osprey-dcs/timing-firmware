setws Workspace

platform create -name EVG_platform -hw EVG.xsa -os standalone -proc microblaze_0

app create -name EVG -platform EVG_platform -os standalone -proc microblaze_0 -template "Empty Application(C)"
app config -name "EVG" -set build-config "Release"
