.386
.model flat, stdcall
option casemap:none

include \masm32\include\windows.inc
include \masm32\include\kernel32.inc
include \masm32\include\user32.inc
include \masm32\include\advapi32.inc
includelib \masm32\lib\kernel32.lib
includelib \masm32\lib\user32.lib
includelib \masm32\lib\advapi32.lib
include \masm32\include\winioctl.inc
include \masm32\Macros\Strings.mac
include common.inc

.const

.data

.data?

.code

start proc uses esi edi

  local hSCManager:HANDLE
  local hService:HANDLE
  local acModulePath[MAX_PATH]:CHAR
  local _ss:SERVICE_STATUS
  local hDevice:HANDLE

  local abyScanCodes[7]:BYTE
  local dwBytesReturned:DWORD

  lea esi, abyScanCodes
  assume esi:ptr BYTE
  mov [esi][0*(sizeof BYTE)], 6
  mov [esi][1*(sizeof BYTE)], 01eh
  mov [esi][2*(sizeof BYTE)], 09eh
  mov [esi][3*(sizeof BYTE)], 01eh
  mov [esi][4*(sizeof BYTE)], 09eh
  mov [esi][5*(sizeof BYTE)], 01eh
  mov [esi][6*(sizeof BYTE)], 09eh
  assume esi:nothing

  ; Open a handle to the SC Manager database
  invoke OpenSCManager, NULL, NULL, SC_MANAGER_ALL_ACCESS
  .if eax != NULL
    mov hSCManager, eax

    push eax
    invoke GetFullPathName, $CTA0("r0kedrv.sys"), sizeof acModulePath, addr acModulePath, esp
      pop eax

    ; Install service
    invoke CreateService, hSCManager, $CTA0("r0kedrv"), $CTA0("ring0 keyboard emulator"), \
      SERVICE_START + SERVICE_STOP + DELETE, SERVICE_KERNEL_DRIVER, SERVICE_DEMAND_START, \
      SERVICE_ERROR_IGNORE, addr acModulePath, NULL, NULL, NULL, NULL, NULL

    .if eax != NULL
      mov hService, eax

      ; Driver's DriverEntry procedure will be called
      invoke StartService, hService, 0, NULL
      .if eax != 0

        ; Driver will receive I/O request packet (IRP) of type IRP_MJ_CREATE
        invoke CreateFile, $CTA0("\\\\.\\r0kedrv"), GENERIC_READ + GENERIC_WRITE, \
          0, NULL, OPEN_EXISTING, 0, NULL

        .if eax != INVALID_HANDLE_VALUE
          mov hDevice, eax

;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

          ; Driver will receive IRP of type IRP_MJ_DEVICE_CONTROL
          invoke DeviceIoControl, hDevice, IOCTL_KB_PS2_WRITE, \ 
            addr abyScanCodes, sizeof abyScanCodes, \
            NULL, 0, addr dwBytesReturned, NULL

          .if ( eax == 0 )
            invoke MessageBox, NULL, $CTA0("Can't send scancodes to device."), NULL, MB_OK + MB_ICONSTOP
          ;.else
            ;invoke MessageBox, NULL, $CTA0("Success."), NULL, MB_OK
            ;invoke Sleep, 5000
          .endif

;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

          ; Driver will receive IRP of type IRP_MJ_CLOSE
          invoke CloseHandle, hDevice
        .else
          invoke MessageBox, NULL, $CTA0("Device is not present."), NULL, MB_OK + MB_ICONSTOP
        .endif
        ; DriverUnload proc in our driver will be called
        invoke ControlService, hService, SERVICE_CONTROL_STOP, addr _ss
      .else
        invoke MessageBox, NULL, $CTA0("Can't start driver."), NULL, MB_OK + MB_ICONSTOP
      .endif
      invoke DeleteService, hService
      invoke CloseServiceHandle, hService
    .else
      invoke MessageBox, NULL, $CTA0("Can't register driver."), NULL, MB_OK + MB_ICONSTOP
    .endif
    invoke CloseServiceHandle, hSCManager
  .else
    invoke MessageBox, NULL, $CTA0("Can't connect to Service Control Manager."), NULL, MB_OK + MB_ICONSTOP
  .endif

  invoke ExitProcess, 0

start endp

end start