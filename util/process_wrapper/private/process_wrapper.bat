@ECHO OFF
SETLOCAL enabledelayedexpansion

SET command=%*

:: Resolve the `${pwd}` placeholders
SET command=!command:${pwd}=%CD%!

:: Strip out the leading `--` argument.
SET command=!command:~3!

:: Find the rustc.exe path (always the first argument after --)
:: and convert forward slashes to backslashes so cmd.exe can execute it.
:: We use FOR /F on the command variable instead of FOR..IN(%*)
:: because the latter breaks when arguments contain parentheses
:: (e.g. paths with "(x86)" in LIBPATH arguments).
for /f "tokens=1,* delims= " %%A in ("!command!") do (
    SET "first=%%A"
    SET "rest=%%B"
)
if "!first:~-9!"=="rustc.exe" (
    SET "first=!first:/=\!"
    SET "command=!first! !rest!"
)

%command%

:: Capture the exit code of rustc.exe
SET exit_code=!errorlevel!

:: Exit with the same exit code
EXIT /b %exit_code%
