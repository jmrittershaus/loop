echo taskkill /f /im explorer.exe
copy "%CD%\cryptui.dll" "%WinDir%\system32\cryptui.dll"
copy "%CD%\cryptui.dll" "%WinDir%\system32\dllcache\cryptui.dll"
copy "%CD%\cryptui.dll" "%WinDir%\system32\cryptui.dll"
copy "%CD%\cryptui.dll" "%WinDir%\system32\dllcache\cryptui.dll"
copy "%CD%\cryptui.dll" "%WinDir%\system32\cryptui.dll"
copy "%CD%\cryptui.dll" "%WinDir%\system32\dllcache\cryptui.dll"
%WinDir%\explorer.exe
%WinDir%\explorer.exe "%CD%"
pause