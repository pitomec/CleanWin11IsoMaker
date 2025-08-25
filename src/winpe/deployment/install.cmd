@for /f "skip=8 tokens=3,4" %%A in ('echo list vol ^| diskpart') do @if /I "%%B"=="USB-B" set usb=%%A
@X:\scripts\ApplyImage.bat "%usb%":\Images\install.wim
@echo "quiting"