#include "ospreyEVR.h"
#include "stdio.h"
#include "xil_io.h"

XStatus OSPREYEVR_Reg_SelfTest(void * baseaddr_p)
{
    int triggerCount = (*(volatile unsigned int *)baseaddr_p & 0x1F0) >> 4;
    if ((triggerCount < 2) || (triggerCount > 12)) return XST_FAILURE;
	return XST_SUCCESS;
}
