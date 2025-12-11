noTarget:
	@echo "There is no default target.  Specify one of:" >&2
	@echo "   everything" >&2
	@echo "   prepareFirmware" >&2
	@echo "   firmware" >&2
	@echo "   XSA" >&2
	@echo "   createWorkspace" >&2
	@echo "   application" >&2
	@exit -1

all: verilogHeader EVG.runs/impl_1/EVG.bit

everything: prepareFirmware firmware XSA createWorkspace application

prepareFirmware:
	cd Workspace/EVG/src ; make verilogHeader
	vivado -mode batch -source BuildScripts/PrepareFirmware.tcl

firmware:
	vivado -mode batch -source BuildScripts/BuildFirmware.tcl

XSA:
	vivado -mode batch -source BuildScripts/BuildXSA.tcl

createWorkspace:
	tar cf svSrc.tar Workspace/EVG/bedrock/* Workspace/EVG/build/* Workspace/EVG/src/*
	rm -rf Workspace
	-xsct BuildScripts/CreateWorkspace.tcl
	tar xfv svSrc.tar
	rm svSrc.tar
	cd Workspace/EVG/src ; make
	-xsct BuildScripts/BuildApplication.tcl

application:
	cd Workspace/EVG/build ; make
