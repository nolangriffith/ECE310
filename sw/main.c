//main for testing


#include "oled.h"
#include "xparameters.h"


int main(){
	char *myString = "Hello World!";
	oledControl myOled;
	initOled(&myOled,XPAR_OLEDCONTROL_0_S00_AXI_BASEADDR);
	clearOled(&myOled);
	printOled(&myOled,myString);
	return 0;
}

