$ErrorActionPreference = "Stop"

# Get the root directory and third_party directory
$ROOT_DIR = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent | Split-Path -Parent | Split-Path -Parent -Resolve

# Include the common functions
. "$ROOT_DIR/hack/lib/windows/init.ps1"

function Generate {
    uv run gen
    if ($LASTEXITCODE -ne 0) {
        AiStack.Log.Fatal "failed to run uv run gen."
    }
}

#
# main
#

AiStack.Log.Info "+++ GENERATE +++"
try {
    Generate
} catch {
    AiStack.Log.Fatal "failed to generate: $($_.Exception.Message)"
}
AiStack.Log.Info "--- GENERATE ---"
