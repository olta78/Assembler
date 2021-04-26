.386
.model flat, stdcall
option sacemap:none

include \masm32\include\w2k\ntstatus.inc
include \masm32\include\w2k\ntddk.inc
include \masm32\include\w2k\ntoskrnl.inc
includelib \masm32\lib\w2k\ntoskrnl.lib
include \masm32\Macros\Strings.mac
include common.inc

.const
CCOUNTED_UNICODE_STRING "\\Device\\r0kedrv", g_usDeviceName, 4
CCOUNTED_UNICODE_STRING "\\??\\r0kedrv", g_usSymbolicLinkName, 4
;CCOUNTED_UNICODE_STRING "\\DosDevices\\r0kedrv", g_usSymbolicLinkName, 4

.code

DispatchCreateClose proc pDeviceObject:PDEVICE_OBJECT, pIrp:PIRP

  ; CreateFile was called, to get driver handle
  ; CloseHandle was called, to close driver handle
  ; In both cases we are in user process context here

  mov eax, pIrp
  assume eax:ptr _IRP
  mov [eax].IoStatus.Status, STATUS_SUCCESS
  and [eax].IoStatus.Information, 0
  assume eax:nothing

  fastcall IofCompleteRequest, pIrp, IO_NO_INCREMENT

  mov eax, STATUS_SUCCESS
  ret

DispatchCreateClose endp

KbPs2Wait proc

  ; Wait until it's okay to send a command byte to the keyboard controller port.
TestCmdPort:
  in al, 64h
  test al, 2 ; Check cntrlr input buffer full flag.
  jnz TestCmdPort
  ret

KbPs2Wait endp

KbPs2Write proc
  
  ; Save scancode
  mov dl, al
  
  ; Wait until the keyboard controller does not contain data before
  ; proceeding with shoving stuff down its throat.
WaitWhileFull:
  in al, 64h
  test al, 1
  jnz WaitWhileFull
  
  ; Tell the keyboard controller to take the next byte
  ; sent to it and return it as a scan code.
  call KbPs2Wait
  mov al, 0d2h ; Return scan code command.
  out 64h, al

  ; Send the scan code.
  call KbPs2Wait
  mov al, dl
  out 60h, al
  ret

KbPs2Write endp

DispatchControl proc uses esi edi pDeviceObject:PDEVICE_OBJECT, pIrp:PIRP

  ; DeviceIoControl was called
  ; We are in user process context here

  local status:NTSTATUS
  local dwBytesReturned:DWORD

  and dwBytesReturned, 0

  mov esi, pIrp
  assume esi:ptr _IRP

  IoGetCurrentIrpStackLocation esi
  mov edi, eax
  assume edi:ptr IO_STACK_LOCATION

  .if [edi].Parameters.DeviceIoControl.IoControlCode == IOCTL_KB_PS2_WRITE

      mov edi, [esi].AssociatedIrp.SystemBuffer
      assume edi:ptr BYTE

      xor ebx, ebx
      xor ecx, ecx
      mov cl, [edi]
      
      .while( ebx < ecx )
        inc ebx
        mov al, [edi][ebx*(sizeof BYTE)]
        call KbPs2Write
      .endw
      
      mov status, STATUS_SUCCESS
  .else
    mov status, STATUS_INVALID_DEVICE_REQUEST
  .endif

  assume edi:nothing

  push status
  pop [esi].IoStatus.Status

  push dwBytesReturned
  pop [esi].IoStatus.Information

  assume esi:nothing

  fastcall IofCompleteRequest, esi, IO_NO_INCREMENT

  mov eax, status
  ret

DispatchControl endp

DriverUnload proc pDriverObject:PDRIVER_OBJECT

  ; ControlService,,SERVICE_CONTROL_STOP was called
  ; We are in System process (pid = 8) context here

  invoke IoDeleteSymbolicLink, addr g_usSymbolicLinkName

  mov eax, pDriverObject
  invoke IoDeleteDevice, (DRIVER_OBJECT PTR [eax]).DeviceObject

  ret

DriverUnload endp

.code INIT

DriverEntry proc pDriverObject:PDRIVER_OBJECT, pusRegistryPath:PUNICODE_STRING

  ; StartService was called
  ; We are in System process (pid = 8) context here

  local status:NTSTATUS
  local pDeviceObject:PDEVICE_OBJECT

  mov status, STATUS_DEVICE_CONFIGURATION_ERROR

  invoke IoCreateDevice, pDriverObject, 0, addr g_usDeviceName, FILE_DEVICE_UNKNOWN, 0, FALSE, addr pDeviceObject
  .if eax == STATUS_SUCCESS
    invoke IoCreateSymbolicLink, addr g_usSymbolicLinkName, addr g_usDeviceName
    .if eax == STATUS_SUCCESS
      mov eax, pDriverObject
      assume eax:ptr DRIVER_OBJECT
      mov [eax].MajorFunction[IRP_MJ_CREATE*(sizeof PVOID)],      offset DispatchCreateClose
      mov [eax].MajorFunction[IRP_MJ_CLOSE*(sizeof PVOID)],      offset DispatchCreateClose
      mov [eax].MajorFunction[IRP_MJ_DEVICE_CONTROL*(sizeof PVOID)],  offset DispatchControl
      mov [eax].DriverUnload,                      offset DriverUnload
      assume eax:nothing
      mov status, STATUS_SUCCESS
    .else
      invoke IoDeleteDevice, pDeviceObject
    .endif
  .endif

  mov eax, status
  ret

DriverEntry endp

end DriverEntry
