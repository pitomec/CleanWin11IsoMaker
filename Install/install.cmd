@echo off
:: Remove Edge
call %~dp0edge.bat

:: Run Installers
for /r "." %%a in (*.exe) do start /wait "" "%%~fa" /S

:: Notepad++ corrections
reg.exe import %~dp0Restore_New_Text_Document_context_menu_item.reg
powershell -command "Reset-AppxPackage -Package 'NotepadPlusPlus_1.0.0.0_neutral__2247w0b46hfww'"