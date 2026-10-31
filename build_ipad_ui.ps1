# iPad UI System Builder — PowerShell MCP Executor
# Double-click this file or run it from PowerShell to build all widgets
# Server: http://127.0.0.1:8000/mcp

$MCP_URL = "http://127.0.0.1:8000/mcp"
$global:RequestId = 0
$global:SuccessCount = 0
$global:ErrorCount = 0
$global:Log = @()

function Invoke-MCP {
    param(
        [string]$ToolName,
        [hashtable]$Arguments = @{}
    )
    $global:RequestId++
    $body = @{
        jsonrpc = "2.0"
        method  = "tools/call"
        params  = @{
            name      = $ToolName
            arguments = $Arguments
        }
        id = $global:RequestId
    } | ConvertTo-Json -Depth 10

    try {
        $response = Invoke-RestMethod `
            -Uri $MCP_URL `
            -Method POST `
            -ContentType "application/json; charset=utf-8" `
            -Body ([System.Text.Encoding]::UTF8.GetBytes($body)) `
            -TimeoutSec 60

        $global:SuccessCount++
        $global:Log += "OK  [$ToolName]"
        Write-Host "    ✓ $ToolName" -ForegroundColor Green
        return $response
    }
    catch {
        $global:ErrorCount++
        $errMsg = $_.Exception.Message
        $global:Log += "ERR [$ToolName] $errMsg"
        Write-Host "    ✗ $ToolName — $errMsg" -ForegroundColor Red
        return $null
    }
}

function List-Tools {
    $global:RequestId++
    $body = @{
        jsonrpc = "2.0"
        method  = "tools/list"
        params  = @{}
        id      = $global:RequestId
    } | ConvertTo-Json -Depth 5

    try {
        $response = Invoke-RestMethod -Uri $MCP_URL -Method POST -ContentType "application/json" -Body $body -TimeoutSec 15
        return $response.result.tools
    }
    catch {
        Write-Host "  Cannot list tools: $_" -ForegroundColor Yellow
        return @()
    }
}

# ─── DISCOVERY ────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "   📱 iPad UI System Builder — Unreal Engine MCP" -ForegroundColor Cyan
Write-Host "══════════════════════════════════════════════════════════════" -ForegroundColor Cyan

Write-Host "`n🔍 Discovering tools..." -ForegroundColor Yellow
$tools = List-Tools
if ($tools.Count -eq 0) {
    Write-Host "  ⚠  No tools returned. Check server." -ForegroundColor Yellow
} else {
    Write-Host "  ✓ $($tools.Count) tools available:" -ForegroundColor Green
    $tools | ForEach-Object { Write-Host "    • $($_.name)" }
}

# Map tool names (handle variations)
$toolNames = $tools | ForEach-Object { $_.name }
function Get-Tool {
    param([string[]]$Candidates)
    foreach ($c in $Candidates) {
        if ($toolNames -contains $c) { return $c }
    }
    return $Candidates[0]  # fallback to first candidate
}

$T_CREATE_WIDGET  = Get-Tool @("create_widget_blueprint", "create_umg_widget_blueprint", "umg_create_widget")
$T_ADD_WIDGET     = Get-Tool @("add_widget_to_blueprint", "add_widget", "umg_add_widget")
$T_SET_PROPERTY   = Get-Tool @("set_widget_property", "set_widget_properties", "umg_set_property")
$T_ADD_VAR        = Get-Tool @("add_blueprint_variable", "add_variable", "bp_add_variable")
$T_ADD_FUNCTION   = Get-Tool @("add_blueprint_function", "add_function", "bp_add_function")
$T_BIND_EVENT     = Get-Tool @("bind_widget_event", "add_widget_event", "bind_event")
$T_ADD_EVENT_NODE = Get-Tool @("add_event_graph_node", "add_blueprint_node", "bp_add_node")
$T_COMPILE        = Get-Tool @("compile_blueprint", "compile_widget_blueprint", "umg_compile")
$T_SAVE           = Get-Tool @("save_asset", "save_blueprint", "bp_save")
$T_CREATE_ASSET   = Get-Tool @("create_asset", "create_render_target", "asset_create")
$T_CREATE_DIR     = Get-Tool @("create_directory", "create_folder", "make_directory")
$T_EXECUTE        = Get-Tool @("execute_python", "run_python", "execute_command")

Write-Host "`n  Tool mapping:"
Write-Host "    create_widget  = $T_CREATE_WIDGET"
Write-Host "    add_widget     = $T_ADD_WIDGET"
Write-Host "    set_property   = $T_SET_PROPERTY"
Write-Host "    compile        = $T_COMPILE"
Write-Host "    save           = $T_SAVE"

# ─── PHASE 0: Folders ─────────────────────────────────────────────────────────
Write-Host "`n📁 [Phase 0] Creating folder structure..." -ForegroundColor Cyan
@("/Game/UI", "/Game/UI/iPad", "/Game/UI/iPad/Apps", "/Game/UI/iPad/Camera") | ForEach-Object {
    Invoke-MCP -ToolName $T_CREATE_DIR -Arguments @{ path = $_; folder_path = $_ }
}

# ─── PHASE 1: Render Target ───────────────────────────────────────────────────
Write-Host "`n🎥 [Phase 1] Creating Render Target..." -ForegroundColor Cyan
Invoke-MCP -ToolName $T_CREATE_ASSET -Arguments @{
    asset_name   = "RT_CameraFeed"
    package_path = "/Game/UI/iPad/Camera"
    asset_class  = "TextureRenderTarget2D"
    properties   = @{ SizeX = 1280; SizeY = 720 }
}

# ─── PHASE 2: WBP_iPad_LockScreen ────────────────────────────────────────────
Write-Host "`n🔒 [Phase 2] WBP_iPad_LockScreen..." -ForegroundColor Cyan
$WP = "/Game/UI/iPad/WBP_iPad_LockScreen"
Invoke-MCP -ToolName $T_CREATE_WIDGET -Arguments @{ asset_name="WBP_iPad_LockScreen"; package_path="/Game/UI/iPad" }
Start-Sleep -Milliseconds 500

# Root
Invoke-MCP -ToolName $T_ADD_WIDGET -Arguments @{ blueprint_path=$WP; widget_type="CanvasPanel"; widget_name="RootCanvas" }
# Wallpaper
Invoke-MCP -ToolName $T_ADD_WIDGET -Arguments @{ blueprint_path=$WP; widget_type="Image"; widget_name="Img_Wallpaper"; parent_name="RootCanvas" }
Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$WP; widget_name="Img_Wallpaper"; property_name="Anchors"; property_value="FullScreen" }
Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$WP; widget_name="Img_Wallpaper"; property_name="ColorAndOpacity"; property_value="(R=0.04,G=0.05,B=0.18,A=1.0)" }
# Dark overlay
Invoke-MCP -ToolName $T_ADD_WIDGET -Arguments @{ blueprint_path=$WP; widget_type="Image"; widget_name="Img_DarkOverlay"; parent_name="RootCanvas" }
Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$WP; widget_name="Img_DarkOverlay"; property_name="Anchors"; property_value="FullScreen" }
Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$WP; widget_name="Img_DarkOverlay"; property_name="ColorAndOpacity"; property_value="(R=0.0,G=0.0,B=0.0,A=0.35)" }
# Clock VBox
Invoke-MCP -ToolName $T_ADD_WIDGET -Arguments @{ blueprint_path=$WP; widget_type="VerticalBox"; widget_name="VBox_Clock"; parent_name="RootCanvas" }
Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$WP; widget_name="VBox_Clock"; property_name="Anchors"; property_value="TopCenter" }
Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$WP; widget_name="VBox_Clock"; property_name="Position"; property_value="(X=0,Y=150)" }
Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$WP; widget_name="VBox_Clock"; property_name="Alignment"; property_value="(X=0.5,Y=0.0)" }
# TB_Time
Invoke-MCP -ToolName $T_ADD_WIDGET -Arguments @{ blueprint_path=$WP; widget_type="TextBlock"; widget_name="TB_Time"; parent_name="VBox_Clock" }
Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$WP; widget_name="TB_Time"; property_name="Text"; property_value="12:00" }
Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$WP; widget_name="TB_Time"; property_name="FontSize"; property_value="88" }
Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$WP; widget_name="TB_Time"; property_name="ColorAndOpacity"; property_value="(R=1.0,G=1.0,B=1.0,A=1.0)" }
Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$WP; widget_name="TB_Time"; property_name="Justification"; property_value="Center" }
# TB_Date
Invoke-MCP -ToolName $T_ADD_WIDGET -Arguments @{ blueprint_path=$WP; widget_type="TextBlock"; widget_name="TB_Date"; parent_name="VBox_Clock" }
Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$WP; widget_name="TB_Date"; property_name="Text"; property_value="Monday, October 26" }
Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$WP; widget_name="TB_Date"; property_name="FontSize"; property_value="26" }
Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$WP; widget_name="TB_Date"; property_name="ColorAndOpacity"; property_value="(R=1.0,G=1.0,B=1.0,A=0.8)" }
Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$WP; widget_name="TB_Date"; property_name="Justification"; property_value="Center" }
# Unlock panel
Invoke-MCP -ToolName $T_ADD_WIDGET -Arguments @{ blueprint_path=$WP; widget_type="CanvasPanel"; widget_name="CP_UnlockArea"; parent_name="RootCanvas" }
Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$WP; widget_name="CP_UnlockArea"; property_name="Anchors"; property_value="BottomCenter" }
Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$WP; widget_name="CP_UnlockArea"; property_name="Position"; property_value="(X=0,Y=-90)" }
Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$WP; widget_name="CP_UnlockArea"; property_name="Size"; property_value="(X=400,Y=60)" }
Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$WP; widget_name="CP_UnlockArea"; property_name="Alignment"; property_value="(X=0.5,Y=1.0)" }
Invoke-MCP -ToolName $T_ADD_WIDGET -Arguments @{ blueprint_path=$WP; widget_type="Image"; widget_name="Img_SliderBG"; parent_name="CP_UnlockArea" }
Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$WP; widget_name="Img_SliderBG"; property_name="Anchors"; property_value="FullScreen" }
Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$WP; widget_name="Img_SliderBG"; property_name="ColorAndOpacity"; property_value="(R=1,G=1,B=1,A=0.15)" }
Invoke-MCP -ToolName $T_ADD_WIDGET -Arguments @{ blueprint_path=$WP; widget_type="Slider"; widget_name="Slider_Unlock"; parent_name="CP_UnlockArea" }
Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$WP; widget_name="Slider_Unlock"; property_name="Anchors"; property_value="FullScreen" }
Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$WP; widget_name="Slider_Unlock"; property_name="MinValue"; property_value="0.0" }
Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$WP; widget_name="Slider_Unlock"; property_name="MaxValue"; property_value="1.0" }
Invoke-MCP -ToolName $T_ADD_WIDGET -Arguments @{ blueprint_path=$WP; widget_type="TextBlock"; widget_name="TB_UnlockHint"; parent_name="CP_UnlockArea" }
Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$WP; widget_name="TB_UnlockHint"; property_name="Text"; property_value="slide to unlock  ›" }
Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$WP; widget_name="TB_UnlockHint"; property_name="ColorAndOpacity"; property_value="(R=1,G=1,B=1,A=0.65)" }
Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$WP; widget_name="TB_UnlockHint"; property_name="Justification"; property_value="Center" }
Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$WP; widget_name="TB_UnlockHint"; property_name="Anchors"; property_value="Center" }
# Variables
Invoke-MCP -ToolName $T_ADD_VAR -Arguments @{ blueprint_path=$WP; variable_name="ClockTimerHandle"; variable_type="TimerHandle" }
# Functions
Invoke-MCP -ToolName $T_ADD_FUNCTION -Arguments @{ blueprint_path=$WP; function_name="UpdateClock" }
Invoke-MCP -ToolName $T_BIND_EVENT -Arguments @{ blueprint_path=$WP; widget_name="Slider_Unlock"; event_name="OnValueChanged"; function_name="OnSliderUnlockValueChanged" }
Invoke-MCP -ToolName $T_ADD_FUNCTION -Arguments @{ blueprint_path=$WP; function_name="OnSliderUnlockValueChanged" }
Invoke-MCP -ToolName $T_COMPILE -Arguments @{ blueprint_path=$WP }
Invoke-MCP -ToolName $T_SAVE -Arguments @{ asset_path=$WP }
Write-Host "  ✓ LockScreen done" -ForegroundColor Green

# ─── PHASE 3: Calculator ──────────────────────────────────────────────────────
Write-Host "`n🔢 [Phase 3] WBP_iPad_Calculator..." -ForegroundColor Cyan
$WP = "/Game/UI/iPad/Apps/WBP_iPad_Calculator"
Invoke-MCP -ToolName $T_CREATE_WIDGET -Arguments @{ asset_name="WBP_iPad_Calculator"; package_path="/Game/UI/iPad/Apps" }
Start-Sleep -Milliseconds 400

Invoke-MCP -ToolName $T_ADD_VAR -Arguments @{ blueprint_path=$WP; variable_name="CurrentInput";      variable_type="String" }
Invoke-MCP -ToolName $T_ADD_VAR -Arguments @{ blueprint_path=$WP; variable_name="PreviousValue";     variable_type="Float" }
Invoke-MCP -ToolName $T_ADD_VAR -Arguments @{ blueprint_path=$WP; variable_name="CurrentOperator";  variable_type="String" }
Invoke-MCP -ToolName $T_ADD_VAR -Arguments @{ blueprint_path=$WP; variable_name="bWaitingForSecond"; variable_type="Boolean" }

Invoke-MCP -ToolName $T_ADD_WIDGET -Arguments @{ blueprint_path=$WP; widget_type="CanvasPanel"; widget_name="RootCanvas" }
Invoke-MCP -ToolName $T_ADD_WIDGET -Arguments @{ blueprint_path=$WP; widget_type="Image"; widget_name="Img_CalcBG"; parent_name="RootCanvas" }
Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$WP; widget_name="Img_CalcBG"; property_name="Anchors"; property_value="FullScreen" }
Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$WP; widget_name="Img_CalcBG"; property_name="ColorAndOpacity"; property_value="(R=0.12,G=0.12,B=0.12,A=0.97)" }
# Display
Invoke-MCP -ToolName $T_ADD_WIDGET -Arguments @{ blueprint_path=$WP; widget_type="TextBlock"; widget_name="TB_Display"; parent_name="RootCanvas" }
Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$WP; widget_name="TB_Display"; property_name="Text"; property_value="0" }
Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$WP; widget_name="TB_Display"; property_name="FontSize"; property_value="56" }
Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$WP; widget_name="TB_Display"; property_name="ColorAndOpacity"; property_value="(R=1,G=1,B=1,A=1)" }
Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$WP; widget_name="TB_Display"; property_name="Justification"; property_value="Right" }
Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$WP; widget_name="TB_Display"; property_name="Anchors"; property_value="TopStretch" }
Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$WP; widget_name="TB_Display"; property_name="Position"; property_value="(X=0,Y=80)" }
# History
Invoke-MCP -ToolName $T_ADD_WIDGET -Arguments @{ blueprint_path=$WP; widget_type="TextBlock"; widget_name="TB_History"; parent_name="RootCanvas" }
Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$WP; widget_name="TB_History"; property_name="FontSize"; property_value="18" }
Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$WP; widget_name="TB_History"; property_name="ColorAndOpacity"; property_value="(R=0.55,G=0.55,B=0.55,A=1)" }
Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$WP; widget_name="TB_History"; property_name="Justification"; property_value="Right" }
# Close button
Invoke-MCP -ToolName $T_ADD_WIDGET -Arguments @{ blueprint_path=$WP; widget_type="Button"; widget_name="Btn_CalcClose"; parent_name="RootCanvas" }
Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$WP; widget_name="Btn_CalcClose"; property_name="Anchors"; property_value="TopLeft" }
Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$WP; widget_name="Btn_CalcClose"; property_name="Position"; property_value="(X=16,Y=16)" }
Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$WP; widget_name="Btn_CalcClose"; property_name="Size"; property_value="(X=36,Y=36)" }
# VBox buttons
Invoke-MCP -ToolName $T_ADD_WIDGET -Arguments @{ blueprint_path=$WP; widget_type="VerticalBox"; widget_name="VBox_Buttons"; parent_name="RootCanvas" }
Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$WP; widget_name="VBox_Buttons"; property_name="Anchors"; property_value="BottomStretch" }
Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$WP; widget_name="VBox_Buttons"; property_name="Size"; property_value="(Y=470)" }

$calcRows = @(
    @{ row="Sci"; buttons=@( @{l="sin";a="sin"}, @{l="cos";a="cos"}, @{l="tan";a="tan"}, @{l="log";a="log"}, @{l="√";a="sqrt"} ) },
    @{ row="Row1"; buttons=@( @{l="C";a="clear"}, @{l="±";a="negate"}, @{l="%";a="percent"}, @{l="÷";a="div"} ) },
    @{ row="Row2"; buttons=@( @{l="7";a="7"}, @{l="8";a="8"}, @{l="9";a="9"}, @{l="×";a="mul"} ) },
    @{ row="Row3"; buttons=@( @{l="4";a="4"}, @{l="5";a="5"}, @{l="6";a="6"}, @{l="−";a="sub"} ) },
    @{ row="Row4"; buttons=@( @{l="1";a="1"}, @{l="2";a="2"}, @{l="3";a="3"}, @{l="+";a="add"} ) },
    @{ row="Row5"; buttons=@( @{l="0";a="zero"}, @{l=".";a="dot"}, @{l="=";a="equals"} ) }
)
$opButtons   = @("div","mul","sub","add","equals")
$sciButtons  = @("sin","cos","tan","log","sqrt")
$clearButtons = @("clear","negate","percent")

foreach ($rowDef in $calcRows) {
    $hbox = "HBox_$($rowDef.row)"
    Invoke-MCP -ToolName $T_ADD_WIDGET -Arguments @{ blueprint_path=$WP; widget_type="HorizontalBox"; widget_name=$hbox; parent_name="VBox_Buttons" }
    foreach ($btn in $rowDef.buttons) {
        $btnName = "Btn_$($btn.a)"
        Invoke-MCP -ToolName $T_ADD_WIDGET -Arguments @{ blueprint_path=$WP; widget_type="Button"; widget_name=$btnName; parent_name=$hbox }
        $color = if ($opButtons -contains $btn.a)   { "(R=1.0,G=0.62,B=0.04,A=1.0)" }
                 elseif ($sciButtons -contains $btn.a) { "(R=0.28,G=0.28,B=0.30,A=1.0)" }
                 elseif ($clearButtons -contains $btn.a) { "(R=0.65,G=0.65,B=0.65,A=1.0)" }
                 else                                 { "(R=0.20,G=0.20,B=0.22,A=1.0)" }
        Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$WP; widget_name=$btnName; property_name="BackgroundColor"; property_value=$color }
        if ($btn.a -eq "zero") {
            Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$WP; widget_name=$btnName; property_name="WidthOverride"; property_value="192" }
        }
        $lblName = "TBL_$($btn.a)"
        Invoke-MCP -ToolName $T_ADD_WIDGET -Arguments @{ blueprint_path=$WP; widget_type="TextBlock"; widget_name=$lblName; parent_name=$btnName }
        Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$WP; widget_name=$lblName; property_name="Text"; property_value=$btn.l }
        Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$WP; widget_name=$lblName; property_name="FontSize"; property_value="28" }
        Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$WP; widget_name=$lblName; property_name="ColorAndOpacity"; property_value="(R=1,G=1,B=1,A=1)" }
        Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$WP; widget_name=$lblName; property_name="Justification"; property_value="Center" }
    }
}
# Calculator functions
foreach ($fn in @("PressDigit","PressOperator","PressEquals","PressScientific","ClearCalculator","UpdateDisplay")) {
    Invoke-MCP -ToolName $T_ADD_FUNCTION -Arguments @{ blueprint_path=$WP; function_name=$fn }
}
Invoke-MCP -ToolName $T_COMPILE -Arguments @{ blueprint_path=$WP }
Invoke-MCP -ToolName $T_SAVE -Arguments @{ asset_path=$WP }
Write-Host "  ✓ Calculator done" -ForegroundColor Green

# ─── PHASE 4: Browser ─────────────────────────────────────────────────────────
Write-Host "`n🌐 [Phase 4] WBP_iPad_Browser..." -ForegroundColor Cyan
$WP = "/Game/UI/iPad/Apps/WBP_iPad_Browser"
Invoke-MCP -ToolName $T_CREATE_WIDGET -Arguments @{ asset_name="WBP_iPad_Browser"; package_path="/Game/UI/iPad/Apps" }
Start-Sleep -Milliseconds 400

Invoke-MCP -ToolName $T_ADD_WIDGET -Arguments @{ blueprint_path=$WP; widget_type="CanvasPanel"; widget_name="RootCanvas" }
# BG
Invoke-MCP -ToolName $T_ADD_WIDGET -Arguments @{ blueprint_path=$WP; widget_type="Image"; widget_name="Img_BG"; parent_name="RootCanvas" }
Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$WP; widget_name="Img_BG"; property_name="Anchors"; property_value="FullScreen" }
Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$WP; widget_name="Img_BG"; property_name="ColorAndOpacity"; property_value="(R=0.96,G=0.96,B=0.97,A=1.0)" }
# Title bar
Invoke-MCP -ToolName $T_ADD_WIDGET -Arguments @{ blueprint_path=$WP; widget_type="CanvasPanel"; widget_name="CP_TitleBar"; parent_name="RootCanvas" }
Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$WP; widget_name="CP_TitleBar"; property_name="Anchors"; property_value="TopStretch" }
Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$WP; widget_name="CP_TitleBar"; property_name="Size"; property_value="(Y=56)" }
Invoke-MCP -ToolName $T_ADD_WIDGET -Arguments @{ blueprint_path=$WP; widget_type="Image"; widget_name="Img_TitleBarBG"; parent_name="CP_TitleBar" }
Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$WP; widget_name="Img_TitleBarBG"; property_name="Anchors"; property_value="FullScreen" }
Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$WP; widget_name="Img_TitleBarBG"; property_name="ColorAndOpacity"; property_value="(R=0.92,G=0.92,B=0.95,A=1.0)" }
# Close
Invoke-MCP -ToolName $T_ADD_WIDGET -Arguments @{ blueprint_path=$WP; widget_type="Button"; widget_name="Btn_BrowserClose"; parent_name="CP_TitleBar" }
Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$WP; widget_name="Btn_BrowserClose"; property_name="Anchors"; property_value="LeftCenter" }
Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$WP; widget_name="Btn_BrowserClose"; property_name="Position"; property_value="(X=8,Y=0)" }
Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$WP; widget_name="Btn_BrowserClose"; property_name="Size"; property_value="(X=36,Y=36)" }
Invoke-MCP -ToolName $T_ADD_WIDGET -Arguments @{ blueprint_path=$WP; widget_type="TextBlock"; widget_name="TBL_BrowserClose"; parent_name="Btn_BrowserClose" }
Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$WP; widget_name="TBL_BrowserClose"; property_name="Text"; property_value="✕" }
Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$WP; widget_name="TBL_BrowserClose"; property_name="Justification"; property_value="Center" }
# Back
Invoke-MCP -ToolName $T_ADD_WIDGET -Arguments @{ blueprint_path=$WP; widget_type="Button"; widget_name="Btn_Back"; parent_name="CP_TitleBar" }
Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$WP; widget_name="Btn_Back"; property_name="Anchors"; property_value="LeftCenter" }
Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$WP; widget_name="Btn_Back"; property_name="Position"; property_value="(X=52,Y=0)" }
Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$WP; widget_name="Btn_Back"; property_name="Size"; property_value="(X=36,Y=36)" }
Invoke-MCP -ToolName $T_ADD_WIDGET -Arguments @{ blueprint_path=$WP; widget_type="TextBlock"; widget_name="TBL_Back"; parent_name="Btn_Back" }
Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$WP; widget_name="TBL_Back"; property_name="Text"; property_value="‹" }
Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$WP; widget_name="TBL_Back"; property_name="ColorAndOpacity"; property_value="(R=0.2,G=0.5,B=1.0,A=1)" }
Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$WP; widget_name="TBL_Back"; property_name="Justification"; property_value="Center" }
# URL bar
Invoke-MCP -ToolName $T_ADD_WIDGET -Arguments @{ blueprint_path=$WP; widget_type="EditableTextBox"; widget_name="ETB_URL"; parent_name="CP_TitleBar" }
Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$WP; widget_name="ETB_URL"; property_name="Anchors"; property_value="StretchCenter" }
Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$WP; widget_name="ETB_URL"; property_name="Position"; property_value="(X=96,Y=8)" }
Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$WP; widget_name="ETB_URL"; property_name="Size"; property_value="(Y=40)" }
Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$WP; widget_name="ETB_URL"; property_name="HintText"; property_value="Search or type a URL" }
Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$WP; widget_name="ETB_URL"; property_name="Text"; property_value="https://www.google.com" }
# Go button
Invoke-MCP -ToolName $T_ADD_WIDGET -Arguments @{ blueprint_path=$WP; widget_type="Button"; widget_name="Btn_Go"; parent_name="CP_TitleBar" }
Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$WP; widget_name="Btn_Go"; property_name="Anchors"; property_value="RightCenter" }
Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$WP; widget_name="Btn_Go"; property_name="Position"; property_value="(X=-8,Y=0)" }
Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$WP; widget_name="Btn_Go"; property_name="Size"; property_value="(X=60,Y=36)" }
Invoke-MCP -ToolName $T_ADD_WIDGET -Arguments @{ blueprint_path=$WP; widget_type="TextBlock"; widget_name="TBL_Go"; parent_name="Btn_Go" }
Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$WP; widget_name="TBL_Go"; property_name="Text"; property_value="Go" }
Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$WP; widget_name="TBL_Go"; property_name="ColorAndOpacity"; property_value="(R=0.2,G=0.5,B=1.0,A=1)" }
Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$WP; widget_name="TBL_Go"; property_name="Justification"; property_value="Center" }
# WebBrowser
Invoke-MCP -ToolName $T_ADD_WIDGET -Arguments @{ blueprint_path=$WP; widget_type="WebBrowser"; widget_name="WB_Browser"; parent_name="RootCanvas" }
Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$WP; widget_name="WB_Browser"; property_name="Anchors"; property_value="FullScreen" }
Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$WP; widget_name="WB_Browser"; property_name="Offsets"; property_value="(Top=56)" }
Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$WP; widget_name="WB_Browser"; property_name="InitialURL"; property_value="https://www.google.com" }
# Events
Invoke-MCP -ToolName $T_BIND_EVENT -Arguments @{ blueprint_path=$WP; widget_name="Btn_Go"; event_name="OnClicked"; function_name="OnGoClicked" }
Invoke-MCP -ToolName $T_BIND_EVENT -Arguments @{ blueprint_path=$WP; widget_name="ETB_URL"; event_name="OnTextCommitted"; function_name="OnURLCommitted" }
Invoke-MCP -ToolName $T_BIND_EVENT -Arguments @{ blueprint_path=$WP; widget_name="Btn_Back"; event_name="OnClicked"; function_name="OnBackClicked" }
Invoke-MCP -ToolName $T_BIND_EVENT -Arguments @{ blueprint_path=$WP; widget_name="Btn_BrowserClose"; event_name="OnClicked"; function_name="OnBrowserCloseClicked" }
Invoke-MCP -ToolName $T_COMPILE -Arguments @{ blueprint_path=$WP }
Invoke-MCP -ToolName $T_SAVE -Arguments @{ asset_path=$WP }
Write-Host "  ✓ Browser done" -ForegroundColor Green

# ─── PHASE 5: Camera ──────────────────────────────────────────────────────────
Write-Host "`n📷 [Phase 5] WBP_iPad_Camera..." -ForegroundColor Cyan
$WP = "/Game/UI/iPad/Apps/WBP_iPad_Camera"
Invoke-MCP -ToolName $T_CREATE_WIDGET -Arguments @{ asset_name="WBP_iPad_Camera"; package_path="/Game/UI/iPad/Apps" }
Start-Sleep -Milliseconds 400

Invoke-MCP -ToolName $T_ADD_VAR -Arguments @{ blueprint_path=$WP; variable_name="CapturedPhotos"; variable_type="Array<Texture2D>"; is_public=$true }
Invoke-MCP -ToolName $T_ADD_WIDGET -Arguments @{ blueprint_path=$WP; widget_type="CanvasPanel"; widget_name="RootCanvas" }
# Camera feed
Invoke-MCP -ToolName $T_ADD_WIDGET -Arguments @{ blueprint_path=$WP; widget_type="Image"; widget_name="Img_CameraFeed"; parent_name="RootCanvas" }
Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$WP; widget_name="Img_CameraFeed"; property_name="Anchors"; property_value="FullScreen" }
Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$WP; widget_name="Img_CameraFeed"; property_name="Brush.ResourceObject"; property_value="/Game/UI/iPad/Camera/RT_CameraFeed" }
# Flash
Invoke-MCP -ToolName $T_ADD_WIDGET -Arguments @{ blueprint_path=$WP; widget_type="Image"; widget_name="Img_Flash"; parent_name="RootCanvas" }
Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$WP; widget_name="Img_Flash"; property_name="Anchors"; property_value="FullScreen" }
Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$WP; widget_name="Img_Flash"; property_name="ColorAndOpacity"; property_value="(R=1,G=1,B=1,A=0)" }
Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$WP; widget_name="Img_Flash"; property_name="Visibility"; property_value="HitTestInvisible" }
# Control bar
Invoke-MCP -ToolName $T_ADD_WIDGET -Arguments @{ blueprint_path=$WP; widget_type="CanvasPanel"; widget_name="CP_ControlBar"; parent_name="RootCanvas" }
Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$WP; widget_name="CP_ControlBar"; property_name="Anchors"; property_value="BottomStretch" }
Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$WP; widget_name="CP_ControlBar"; property_name="Size"; property_value="(Y=110)" }
Invoke-MCP -ToolName $T_ADD_WIDGET -Arguments @{ blueprint_path=$WP; widget_type="Image"; widget_name="Img_BarBG"; parent_name="CP_ControlBar" }
Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$WP; widget_name="Img_BarBG"; property_name="Anchors"; property_value="FullScreen" }
Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$WP; widget_name="Img_BarBG"; property_name="ColorAndOpacity"; property_value="(R=0,G=0,B=0,A=0.6)" }
# Shutter button
Invoke-MCP -ToolName $T_ADD_WIDGET -Arguments @{ blueprint_path=$WP; widget_type="Button"; widget_name="Btn_Shutter"; parent_name="CP_ControlBar" }
Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$WP; widget_name="Btn_Shutter"; property_name="Anchors"; property_value="Center" }
Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$WP; widget_name="Btn_Shutter"; property_name="Size"; property_value="(X=78,Y=78)" }
Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$WP; widget_name="Btn_Shutter"; property_name="Alignment"; property_value="(X=0.5,Y=0.5)" }
Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$WP; widget_name="Btn_Shutter"; property_name="BackgroundColor"; property_value="(R=1,G=1,B=1,A=0.92)" }
# Close
Invoke-MCP -ToolName $T_ADD_WIDGET -Arguments @{ blueprint_path=$WP; widget_type="Button"; widget_name="Btn_CamClose"; parent_name="CP_ControlBar" }
Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$WP; widget_name="Btn_CamClose"; property_name="Anchors"; property_value="LeftCenter" }
Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$WP; widget_name="Btn_CamClose"; property_name="Position"; property_value="(X=20,Y=0)" }
Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$WP; widget_name="Btn_CamClose"; property_name="Size"; property_value="(X=44,Y=44)" }
Invoke-MCP -ToolName $T_ADD_WIDGET -Arguments @{ blueprint_path=$WP; widget_type="TextBlock"; widget_name="TBL_CamClose"; parent_name="Btn_CamClose" }
Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$WP; widget_name="TBL_CamClose"; property_name="Text"; property_value="✕" }
Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$WP; widget_name="TBL_CamClose"; property_name="ColorAndOpacity"; property_value="(R=1,G=1,B=1,A=1)" }
Invoke-MCP -ToolName $T_BIND_EVENT -Arguments @{ blueprint_path=$WP; widget_name="Btn_Shutter"; event_name="OnClicked"; function_name="OnShutterClicked" }
Invoke-MCP -ToolName $T_BIND_EVENT -Arguments @{ blueprint_path=$WP; widget_name="Btn_CamClose"; event_name="OnClicked"; function_name="OnCamCloseClicked" }
Invoke-MCP -ToolName $T_COMPILE -Arguments @{ blueprint_path=$WP }
Invoke-MCP -ToolName $T_SAVE -Arguments @{ asset_path=$WP }
Write-Host "  ✓ Camera done" -ForegroundColor Green

# ─── PHASE 6: Thumbnail + Files ───────────────────────────────────────────────
Write-Host "`n📁 [Phase 6] WBP_PhotoThumbnail + WBP_iPad_Files..." -ForegroundColor Cyan
# Thumbnail
$TW = "/Game/UI/iPad/Apps/WBP_PhotoThumbnail"
Invoke-MCP -ToolName $T_CREATE_WIDGET -Arguments @{ asset_name="WBP_PhotoThumbnail"; package_path="/Game/UI/iPad/Apps" }
Start-Sleep -Milliseconds 300
Invoke-MCP -ToolName $T_ADD_VAR -Arguments @{ blueprint_path=$TW; variable_name="ThumbTexture"; variable_type="Texture2D"; is_public=$true }
Invoke-MCP -ToolName $T_ADD_WIDGET -Arguments @{ blueprint_path=$TW; widget_type="Button"; widget_name="Btn_Thumb" }
Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$TW; widget_name="Btn_Thumb"; property_name="WidthOverride"; property_value="150" }
Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$TW; widget_name="Btn_Thumb"; property_name="HeightOverride"; property_value="150" }
Invoke-MCP -ToolName $T_ADD_WIDGET -Arguments @{ blueprint_path=$TW; widget_type="Image"; widget_name="Img_Thumb"; parent_name="Btn_Thumb" }
Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$TW; widget_name="Img_Thumb"; property_name="Anchors"; property_value="FullScreen" }
Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$TW; widget_name="Img_Thumb"; property_name="Stretch"; property_value="ScaleToFill" }
Invoke-MCP -ToolName $T_COMPILE -Arguments @{ blueprint_path=$TW }
Invoke-MCP -ToolName $T_SAVE -Arguments @{ asset_path=$TW }

# Files widget
$FW = "/Game/UI/iPad/Apps/WBP_iPad_Files"
Invoke-MCP -ToolName $T_CREATE_WIDGET -Arguments @{ asset_name="WBP_iPad_Files"; package_path="/Game/UI/iPad/Apps" }
Start-Sleep -Milliseconds 300
Invoke-MCP -ToolName $T_ADD_WIDGET -Arguments @{ blueprint_path=$FW; widget_type="CanvasPanel"; widget_name="RootCanvas" }
Invoke-MCP -ToolName $T_ADD_WIDGET -Arguments @{ blueprint_path=$FW; widget_type="Image"; widget_name="Img_BG"; parent_name="RootCanvas" }
Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$FW; widget_name="Img_BG"; property_name="Anchors"; property_value="FullScreen" }
Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$FW; widget_name="Img_BG"; property_name="ColorAndOpacity"; property_value="(R=0.1,G=0.1,B=0.12,A=0.97)" }
# Header
Invoke-MCP -ToolName $T_ADD_WIDGET -Arguments @{ blueprint_path=$FW; widget_type="CanvasPanel"; widget_name="CP_Header"; parent_name="RootCanvas" }
Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$FW; widget_name="CP_Header"; property_name="Anchors"; property_value="TopStretch" }
Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$FW; widget_name="CP_Header"; property_name="Size"; property_value="(Y=64)" }
Invoke-MCP -ToolName $T_ADD_WIDGET -Arguments @{ blueprint_path=$FW; widget_type="TextBlock"; widget_name="TB_FilesTitle"; parent_name="CP_Header" }
Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$FW; widget_name="TB_FilesTitle"; property_name="Text"; property_value="Files" }
Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$FW; widget_name="TB_FilesTitle"; property_name="FontSize"; property_value="28" }
Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$FW; widget_name="TB_FilesTitle"; property_name="ColorAndOpacity"; property_value="(R=1,G=1,B=1,A=1)" }
Invoke-MCP -ToolName $T_ADD_WIDGET -Arguments @{ blueprint_path=$FW; widget_type="Button"; widget_name="Btn_FilesClose"; parent_name="CP_Header" }
Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$FW; widget_name="Btn_FilesClose"; property_name="Anchors"; property_value="RightCenter" }
Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$FW; widget_name="Btn_FilesClose"; property_name="Position"; property_value="(X=-16,Y=0)" }
Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$FW; widget_name="Btn_FilesClose"; property_name="Size"; property_value="(X=36,Y=36)" }
Invoke-MCP -ToolName $T_ADD_WIDGET -Arguments @{ blueprint_path=$FW; widget_type="TextBlock"; widget_name="TBL_FilesClose"; parent_name="Btn_FilesClose" }
Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$FW; widget_name="TBL_FilesClose"; property_name="Text"; property_value="✕" }
Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$FW; widget_name="TBL_FilesClose"; property_name="ColorAndOpacity"; property_value="(R=0.6,G=0.6,B=0.6,A=1)" }
# Scroll + WrapBox
Invoke-MCP -ToolName $T_ADD_WIDGET -Arguments @{ blueprint_path=$FW; widget_type="ScrollBox"; widget_name="SB_Gallery"; parent_name="RootCanvas" }
Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$FW; widget_name="SB_Gallery"; property_name="Anchors"; property_value="FullScreen" }
Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$FW; widget_name="SB_Gallery"; property_name="Offsets"; property_value="(Top=64)" }
Invoke-MCP -ToolName $T_ADD_WIDGET -Arguments @{ blueprint_path=$FW; widget_type="WrapBox"; widget_name="WrapBox_Photos"; parent_name="SB_Gallery" }
Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$FW; widget_name="WrapBox_Photos"; property_name="InnerSlotPadding"; property_value="(X=8,Y=8)" }
# Empty state
Invoke-MCP -ToolName $T_ADD_WIDGET -Arguments @{ blueprint_path=$FW; widget_type="TextBlock"; widget_name="TB_Empty"; parent_name="RootCanvas" }
Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$FW; widget_name="TB_Empty"; property_name="Text"; property_value="No photos yet.`nUse the Camera app to capture images." }
Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$FW; widget_name="TB_Empty"; property_name="FontSize"; property_value="20" }
Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$FW; widget_name="TB_Empty"; property_name="ColorAndOpacity"; property_value="(R=0.5,G=0.5,B=0.5,A=1)" }
Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$FW; widget_name="TB_Empty"; property_name="Justification"; property_value="Center" }
Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$FW; widget_name="TB_Empty"; property_name="Anchors"; property_value="Center" }
Invoke-MCP -ToolName $T_ADD_FUNCTION -Arguments @{ blueprint_path=$FW; function_name="RefreshGallery" }
Invoke-MCP -ToolName $T_BIND_EVENT -Arguments @{ blueprint_path=$FW; widget_name="Btn_FilesClose"; event_name="OnClicked"; function_name="OnFilesCloseClicked" }
Invoke-MCP -ToolName $T_COMPILE -Arguments @{ blueprint_path=$FW }
Invoke-MCP -ToolName $T_SAVE -Arguments @{ asset_path=$FW }
Write-Host "  ✓ Files + Thumbnail done" -ForegroundColor Green

# ─── PHASE 7: MainMenu ────────────────────────────────────────────────────────
Write-Host "`n🏠 [Phase 7] WBP_iPad_MainMenu..." -ForegroundColor Cyan
$WP = "/Game/UI/iPad/WBP_iPad_MainMenu"
Invoke-MCP -ToolName $T_CREATE_WIDGET -Arguments @{ asset_name="WBP_iPad_MainMenu"; package_path="/Game/UI/iPad" }
Start-Sleep -Milliseconds 500

Invoke-MCP -ToolName $T_ADD_WIDGET -Arguments @{ blueprint_path=$WP; widget_type="CanvasPanel"; widget_name="RootCanvas" }
# Wallpaper
Invoke-MCP -ToolName $T_ADD_WIDGET -Arguments @{ blueprint_path=$WP; widget_type="Image"; widget_name="Img_HomeWallpaper"; parent_name="RootCanvas" }
Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$WP; widget_name="Img_HomeWallpaper"; property_name="Anchors"; property_value="FullScreen" }
Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$WP; widget_name="Img_HomeWallpaper"; property_name="ColorAndOpacity"; property_value="(R=0.04,G=0.08,B=0.22,A=1)" }
# App grid
Invoke-MCP -ToolName $T_ADD_WIDGET -Arguments @{ blueprint_path=$WP; widget_type="UniformGridPanel"; widget_name="UGP_AppGrid"; parent_name="RootCanvas" }
Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$WP; widget_name="UGP_AppGrid"; property_name="Anchors"; property_value="Center" }
Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$WP; widget_name="UGP_AppGrid"; property_name="Size"; property_value="(X=540,Y=400)" }
Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$WP; widget_name="UGP_AppGrid"; property_name="Alignment"; property_value="(X=0.5,Y=0.5)" }
Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$WP; widget_name="UGP_AppGrid"; property_name="SlotPadding"; property_value="(All=18)" }

$appIcons = @(
    @{ label="Safari";     row=0; col=0; btn="Btn_Safari";     icon="🌐"; color="(R=0.18,G=0.44,B=0.96,A=1)" },
    @{ label="Camera";     row=0; col=1; btn="Btn_Camera";     icon="📷"; color="(R=0.12,G=0.12,B=0.14,A=1)" },
    @{ label="Calculator"; row=1; col=0; btn="Btn_Calculator"; icon="🔢"; color="(R=0.09,G=0.09,B=0.11,A=1)" },
    @{ label="Files";      row=1; col=1; btn="Btn_Files";      icon="📁"; color="(R=0.22,G=0.54,B=0.32,A=1)" }
)
foreach ($app in $appIcons) {
    $vbox = "VBox_$($app.label)"
    Invoke-MCP -ToolName $T_ADD_WIDGET -Arguments @{
        blueprint_path=$WP; widget_type="VerticalBox"; widget_name=$vbox; parent_name="UGP_AppGrid"
        slot_properties=@{ Row=$app.row; Column=$app.col; HorizontalAlignment="Center"; VerticalAlignment="Center" }
    }
    Invoke-MCP -ToolName $T_ADD_WIDGET -Arguments @{ blueprint_path=$WP; widget_type="Button"; widget_name=$app.btn; parent_name=$vbox }
    Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$WP; widget_name=$app.btn; property_name="WidthOverride"; property_value="120" }
    Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$WP; widget_name=$app.btn; property_name="HeightOverride"; property_value="120" }
    Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$WP; widget_name=$app.btn; property_name="BackgroundColor"; property_value=$app.color }
    $iconLbl = "TBL_$($app.label)Icon"
    Invoke-MCP -ToolName $T_ADD_WIDGET -Arguments @{ blueprint_path=$WP; widget_type="TextBlock"; widget_name=$iconLbl; parent_name=$app.btn }
    Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$WP; widget_name=$iconLbl; property_name="Text"; property_value=$app.icon }
    Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$WP; widget_name=$iconLbl; property_name="FontSize"; property_value="52" }
    Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$WP; widget_name=$iconLbl; property_name="Justification"; property_value="Center" }
    $nameLbl = "TBL_$($app.label)"
    Invoke-MCP -ToolName $T_ADD_WIDGET -Arguments @{ blueprint_path=$WP; widget_type="TextBlock"; widget_name=$nameLbl; parent_name=$vbox }
    Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$WP; widget_name=$nameLbl; property_name="Text"; property_value=$app.label }
    Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$WP; widget_name=$nameLbl; property_name="FontSize"; property_value="14" }
    Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$WP; widget_name=$nameLbl; property_name="ColorAndOpacity"; property_value="(R=1,G=1,B=1,A=0.9)" }
    Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$WP; widget_name=$nameLbl; property_name="Justification"; property_value="Center" }
}
# Dock bar
Invoke-MCP -ToolName $T_ADD_WIDGET -Arguments @{ blueprint_path=$WP; widget_type="Image"; widget_name="Img_DockBG"; parent_name="RootCanvas" }
Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$WP; widget_name="Img_DockBG"; property_name="Anchors"; property_value="BottomStretch" }
Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$WP; widget_name="Img_DockBG"; property_name="Size"; property_value="(Y=96)" }
Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$WP; widget_name="Img_DockBG"; property_name="ColorAndOpacity"; property_value="(R=1,G=1,B=1,A=0.1)" }
# App layer overlay
Invoke-MCP -ToolName $T_ADD_WIDGET -Arguments @{ blueprint_path=$WP; widget_type="CanvasPanel"; widget_name="CP_AppLayer"; parent_name="RootCanvas" }
Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$WP; widget_name="CP_AppLayer"; property_name="Anchors"; property_value="FullScreen" }
Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$WP; widget_name="CP_AppLayer"; property_name="ZOrder"; property_value="10" }
# Embed sub-apps (hidden by default)
$appWidgets = @(
    @{ class="WBP_iPad_Browser";     varname="Browser" },
    @{ class="WBP_iPad_Camera";      varname="Camera" },
    @{ class="WBP_iPad_Calculator";  varname="Calculator" },
    @{ class="WBP_iPad_Files";       varname="Files" }
)
foreach ($aw in $appWidgets) {
    Invoke-MCP -ToolName $T_ADD_WIDGET -Arguments @{ blueprint_path=$WP; widget_type=$aw.class; widget_name=$aw.varname; parent_name="CP_AppLayer" }
    Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$WP; widget_name=$aw.varname; property_name="Anchors"; property_value="FullScreen" }
    Invoke-MCP -ToolName $T_SET_PROPERTY -Arguments @{ blueprint_path=$WP; widget_name=$aw.varname; property_name="Visibility"; property_value="Collapsed" }
}
# Functions + events
Invoke-MCP -ToolName $T_ADD_FUNCTION -Arguments @{ blueprint_path=$WP; function_name="HideAllApps" }
foreach ($app in $appIcons) {
    Invoke-MCP -ToolName $T_BIND_EVENT -Arguments @{ blueprint_path=$WP; widget_name=$app.btn; event_name="OnClicked"; function_name="On$($app.label)Clicked" }
}
Invoke-MCP -ToolName $T_COMPILE -Arguments @{ blueprint_path=$WP }
Invoke-MCP -ToolName $T_SAVE -Arguments @{ asset_path=$WP }
Write-Host "  ✓ MainMenu done" -ForegroundColor Green

# ─── SUMMARY ──────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Build Complete!" -ForegroundColor $(if ($global:ErrorCount -eq 0) { "Green" } else { "Yellow" })
Write-Host "  ✓ Successful calls : $($global:SuccessCount)"
Write-Host "  ✗ Failed calls     : $($global:ErrorCount)"
Write-Host ""
Write-Host "  📂 Widgets at: /Game/UI/iPad/"
Write-Host "  🎮 Add WBP_iPad_LockScreen to your HUD or PlayerController"
Write-Host "══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Save log
$logPath = "$PSScriptRoot\build_log_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
$global:Log | Out-File $logPath
Write-Host "  📋 Log saved to: $logPath" -ForegroundColor Gray
