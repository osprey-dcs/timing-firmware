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
	$(MAKE) -C Workspace/EVG/src verilogHeader
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
	$(MAKE) -C Workspace/EVG/src
	-xsct BuildScripts/BuildApplication.tcl

application:
	$(MAKE) -C Workspace/EVG/build
	cp ./Workspace/EVG/build/EVG.bit \
           "EVG-$$(git log -n1 --format=format:%cd-%h HEAD --date=format:%Y%m%d).bit"

.PHONY: noTarget all everything prepareFirmware firmware XSAcreateWorkspace application
