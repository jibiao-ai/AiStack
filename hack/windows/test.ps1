$ErrorActionPreference = "Stop"

# Get the root directory and third_party directory
$ROOT_DIR = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent | Split-Path -Parent | Split-Path -Parent -Resolve

# Include the common functions
. "$ROOT_DIR/hack/lib/windows/init.ps1"

function Test {
    uv run pytest
    if ($LASTEXITCODE -ne 0) {
        AiStack.Log.Fatal "failed to run uv run pytest."
    }
}

#
# main
#

AiStack.Log.Info "+++ TEST +++"
try {
    Test
} catch {
    AiStack.Log.Fatal "failed to test: $($_.Exception.Message)"
}
AiStack.Log.Info "--- TEST ---"
