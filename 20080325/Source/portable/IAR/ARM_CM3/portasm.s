/*
	FreeRTOS.org V4.7.2 - Copyright (C) 2003-2008 Richard Barry.

	This file is part of the FreeRTOS.org distribution.

	FreeRTOS.org is free software; you can redistribute it and/or modify
	it under the terms of the GNU General Public License as published by
	the Free Software Foundation; either version 2 of the License, or
	(at your option) any later version.

	FreeRTOS.org is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	GNU General Public License for more details.

	You should have received a copy of the GNU General Public License
	along with FreeRTOS.org; if not, write to the Free Software
	Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

	A special exception to the GPL can be applied should you wish to distribute
	a combined work that includes FreeRTOS.org, without being obliged to provide
	the source code for any proprietary components.  See the licensing section
	of http://www.FreeRTOS.org for full details of how and when the exception
	can be applied.

	***************************************************************************

	Please ensure to read the configuration and relevant port sections of the
	online documentation.

	+++ http://www.FreeRTOS.org +++
	Documentation, latest information, license and contact details.

	+++ http://www.SafeRTOS.com +++
	A version that is certified for use in safety critical systems.

	+++ http://www.OpenRTOS.com +++
	Commercial support, development, porting, licensing and training services.

	***************************************************************************
*/

/*
	Change from V4.2.1:

	+ Introduced usage of configKERNEL_INTERRUPT_PRIORITY macro to set the
	  interrupt priority used by the kernel.
*/

#include <FreeRTOSConfig.h>

/* For backward compatibility, ensure configKERNEL_INTERRUPT_PRIORITY is
defined.  The value zero should also ensure backward compatibility.
FreeRTOS.org versions prior to V4.3.0 did not include this definition. */
#ifndef configKERNEL_INTERRUPT_PRIORITY
	#define configKERNEL_INTERRUPT_PRIORITY 0
#endif

	
	RSEG    CODE:CODE(2)
	thumb

	EXTERN vPortYieldFromISR
	EXTERN uxCriticalNesting
	EXTERN pxCurrentTCB
	EXTERN vTaskSwitchContext

	PUBLIC vSetMSP
	PUBLIC xPortPendSVHandler
	PUBLIC vPortSetInterruptMask
	PUBLIC vPortClearInterruptMask
	PUBLIC vPortSVCHandler
	PUBLIC vPortStartFirstTask


/*-----------------------------------------------------------*/

vSetMSP
	msr msp, r0
	bx lr
	
/*-----------------------------------------------------------*/

xPortPendSVHandler:
	mrs r0, psp						
	ldr	r3, =pxCurrentTCB			/* Get the location of the current TCB. */
	ldr	r2, [r3]						

	ldr r1, =uxCriticalNesting		/* Save the remaining registers and the critical nesting count onto the task stack. */
	ldr r1, [r1]					
	stmdb r0!, {r1,r4-r11}			
	str r0, [r2]					/* Save the new top of stack into the first member of the TCB. */

	stmdb sp!, {r3, r14}			
	bl vTaskSwitchContext			
	ldmia sp!, {r3, r14}			

	ldr r1, [r3]					
	ldr r2, =uxCriticalNesting	
	ldr r0, [r1]					/* The first item in pxCurrentTCB is the task top of stack. */
	ldmia r0!, {r1, r4-r11}			/* Pop the registers and the critical nesting count. */
	str r1, [r2]					/* Save the new critical nesting value into ulCriticalNesting. */
	msr psp, r0						
	orr r14, r14, #13			

	cbnz r1, sv_disable_interrupts	/* If the nesting count is greater than 0 we need to exit with interrupts masked. */
	bx r14							

sv_disable_interrupts:				
	mov	r1, #configKERNEL_INTERRUPT_PRIORITY
	msr	basepri, r1
	bx r14							

/*-----------------------------------------------------------*/

vPortSetInterruptMask:
	push { r0 }
	mov R0, #configKERNEL_INTERRUPT_PRIORITY
	msr BASEPRI, R0
	pop { R0 }

	bx r14
	
/*-----------------------------------------------------------*/

vPortClearInterruptMask:
	PUSH { r0 }
	MOV R0, #0
	MSR BASEPRI, R0
	POP	 { R0 }

	bx r14

/*-----------------------------------------------------------*/

vPortSVCHandler;
	ldr	r3, =pxCurrentTCB
	ldr r1, [r3]
	ldr r0, [r1]
	ldmia r0!, {r1, r4-r11}
	ldr r2, =uxCriticalNesting
	str r1, [r2]
	msr psp, r0
	orr r14, r14, #13
	bx r14

/*-----------------------------------------------------------*/

vPortStartFirstTask
	msr msp, r0
	svc 0


	END
	