@for /f "skip=8 tokens=3,4" %%A in ('echo list vol ^| diskpart') do @if /I "%%B"=="USB-B" set usb=%%A
@MD "%usb%":\scratchdir
@dism /capture-image /capturedir:C:\ /ImageFile:"%usb%":\Images\customimage.wim /Name:"CustomImage" /scratchdir:"%usb%":\scratchdir /EA
@dism /export-image /sourceimagefile:"%usb%":\images\customimage.wim /sourceindex:1 /destinationimagefile:"%usb%":\images\CleanWinImage_Pro.wim
@del "%usb%":\images\customimage.wim
wpeutil.exe shutdown